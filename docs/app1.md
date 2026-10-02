# Part 1 — K3s and Vagrant

This part of the **Inception of Things** project creates a lightweight Kubernetes cluster with Vagrant and VirtualBox.

The cluster is composed of two virtual machines:

- a K3s server node, which manages the Kubernetes cluster;
- a K3s agent node, which joins the server and can run workloads.

## Objective

The project uses two Ubuntu virtual machines created with Vagrant.

| Machine | Hostname | Role | Private IP address |
|---|---|---|---|
| Server | `loginteamS` | K3s server / control plane | `192.168.56.110` |
| Worker | `loginteamSW` | K3s agent / worker node | `192.168.56.111` |

Both machines use one CPU and 1024 MB of RAM.

## Architecture

```text
Host machine
    |
    | Vagrant + VirtualBox
    |
    +--> loginteamS
    |      IP: 192.168.56.110
    |      Role: K3s server
    |      Kubernetes API: port 6443
    |
    +--> loginteamSW
           IP: 192.168.56.111
           Role: K3s agent
           Connects to loginteamS:6443
```

The server initializes the K3s cluster and creates a node token.  
The worker reads this token from the shared Vagrant directory and uses it to authenticate to the server before joining the cluster.

## Project structure

```text
p1/
├── Vagrantfile
├── scripts/
│   ├── init_server.sh
│   └── init_worker.sh
└── token
```

The `token` file is generated automatically during the server provisioning. It is stored in the shared `/vagrant` directory so that the worker can access it.

> The `token` file contains a credential allowing a node to join the cluster. It must not be committed to Git. Add it to `.gitignore`.

## File roles

- `Vagrantfile`: defines the two Vagrant virtual machines, their resources, hostnames, private IP addresses, and provisioning scripts.
- `scripts/init_server.sh`: installs K3s in server mode, prepares the `kubectl` configuration for the `vagrant` user, then writes the node token to `/vagrant/token`.
- `scripts/init_worker.sh`: reads the server IP address and node token, then installs K3s in agent mode and joins the existing cluster.
- `token`: generated at runtime by the server; used by the worker to authenticate to the K3s server.

## Prerequisites

The following tools must be installed on the host machine:

- Vagrant
- VirtualBox

On macOS, the terminal application used to launch Vagrant may require the **Local Network** permission to communicate with the VMs.

The permission is available in:

```text
System Settings > Privacy & Security > Local Network
```

## Launch the cluster

From the root of the repository:

```bash
cd p1
vagrant up
```

Vagrant creates and provisions both virtual machines.

The server provisioning script runs first, installs K3s, waits for its configuration file, and writes the cluster node token to `/vagrant/token`. The worker then uses this token and the server IP address to join the cluster.

> If the worker starts before the token has been created, run the following command after the server provisioning has completed:

```bash
vagrant provision loginteamSW
```

## Connect through SSH

Connect to the server:

```bash
vagrant ssh loginteamS
```

Connect to the worker:

```bash
vagrant ssh loginteamSW
```

Vagrant configures SSH access without requiring a password.

## Check the network configuration

On the server:

```bash
vagrant ssh loginteamS
ip -br address
hostname
```

Expected values:

```text
loginteamS
192.168.56.110
```

On the worker:

```bash
vagrant ssh loginteamSW
ip -br address
hostname
```

Expected values:

```text
loginteamSW
192.168.56.111
```

The private-network interface name can vary depending on the operating system and VirtualBox configuration. Use `ip -br address` rather than assuming it is named `eth1`.

## Check the Kubernetes cluster

Connect to the server:

```bash
vagrant ssh loginteamS
```

Configure `kubectl` for the `vagrant` user:

```bash
export KUBECONFIG="$HOME/.kube/config"
```

Check the cluster nodes:

```bash
kubectl get nodes -o wide
```

Expected result:

```text
NAME           STATUS   ROLES                  AGE   VERSION
loginteamS     Ready    control-plane,master   ...   ...
loginteamSW    Ready    <none>                 ...   ...
```

Both nodes must be in the `Ready` state.

Check all system Pods:

```bash
kubectl get pods -A
```

The Pods in the `kube-system` namespace should be in the `Running` or `Completed` state.

## Verify the worker connection

From the server, verify that the worker is registered:

```bash
export KUBECONFIG="$HOME/.kube/config"
kubectl get nodes
```

From the worker, verify the K3s agent service:

```bash
vagrant ssh loginteamSW
sudo systemctl status k3s-agent --no-pager
```

The service should be active and running.

To inspect the agent logs:

```bash
sudo journalctl -u k3s-agent -n 50 --no-pager
```

## Stop and rebuild

Stop both virtual machines without deleting them:

```bash
vagrant halt
```

Restart the machines:

```bash
vagrant up
```

Re-run all provisioning scripts:

```bash
vagrant provision
```

Destroy both virtual machines:

```bash
vagrant destroy -f
```

Remove the runtime token before rebuilding the cluster:

```bash
rm -f token
```

Recreate the cluster from scratch:

```bash
vagrant up
```

## Troubleshooting

### The worker does not join the cluster

Check that the token exists on the host:

```bash
cat token
```

Check that the worker can reach the K3s API server:

```bash
vagrant ssh loginteamSW -c "ping -c 3 192.168.56.110"
```

Check the agent service and its logs:

```bash
vagrant ssh loginteamSW
sudo systemctl status k3s-agent --no-pager
sudo journalctl -u k3s-agent -n 50 --no-pager
```

If the token was not available when the worker was provisioned:

```bash
vagrant provision loginteamSW
```

### kubectl does not work on the server

Set the K3s kubeconfig path:

```bash
export KUBECONFIG="$HOME/.kube/config"
```

Then retry:

```bash
kubectl get nodes
```

### A node is not Ready

On the server, check the K3s service:

```bash
sudo systemctl status k3s --no-pager
sudo journalctl -u k3s -n 50 --no-pager
```

Check the cluster state:

```bash
export KUBECONFIG="$HOME/.kube/config"
kubectl get nodes
kubectl get pods -A
```

### The host cannot reach a VM

Check the status of the virtual machines:

```bash
vagrant status
```

Test their private addresses from the host:

```bash
ping -c 3 192.168.56.110
ping -c 3 192.168.56.111
```

On macOS, verify that the terminal application has Local Network access if the requests are blocked.
