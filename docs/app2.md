# Partie 2 — K3s et trois applications

<!-- Translate in english -->

This part of the project **Inception of Things** deploys a virtual machine with Vagrant and VirtualBox.  
The VM runs a K3s cluster in server mode, with three web applications accessible via a Traefik Ingress.

## Objectives

The HTTP routing depends on the value of the `Host` header in the request. The expected behavior is summarized in the following table:

| Request | Expected Result |
|---|---|
| `Host: app1.com` | Application 1 |
| `Host: app2.com` | Application 2 |
| Any other Host name or IP | Application 3 — default backend |

Application 2 is deployed with **three replicas**.

## Architecture

```text
Client : browser or curl
              |
              | HTTP, port 80
              v
      192.168.56.110
              |
              v
     Traefik Ingress Controller
              |
              +--> Host: app1.com --> app1-service --> app1
              |
              +--> Host: app2.com --> app2-service --> app2 x3
              |
              +--> Any other Host    --> app3-service --> app3
```

K3s installs Traefik by default. Traefik receives HTTP requests on the VM and forwards them to the corresponding Kubernetes Service, according to the rules defined in the Ingress.

## Project structure

```text
p2/
├── Vagrantfile
├── scripts/
│   └── init_server.sh
└── confs/
    ├── app1.yaml
    ├── app2.yaml
    ├── app3.yaml
    └── ingress.yaml
```

## File roles

- `Vagrantfile` : creates and configures the virtual machine.
- `scripts/init_server.sh` : installs and configures K3s, then applies the Kubernetes manifests.
- `confs/app1.yaml` : defines the Deployment and Service of application 1.
- `confs/app2.yaml` : defines the Deployment with three replicas and the Service of application 2.
- `confs/app3.yaml` : defines the Deployment and Service of application 3.
- `confs/ingress.yaml` : defines the HTTP routing rules managed by Traefik.

## Prerequisites

The following software must be installed on the host machine :

- Vagrant
- VirtualBox

On macOS, the app from which the VM is launched and the browser may need the **Local Network** permission to communicate with the private address of the VM. 


This permission is accessible in :

```text
System Preferences > Privacy & Security > Local Network
```

Safari can be used to test access to the VM if another browser is blocked.

## Launch the project

From the root of the repository :

```bash
cd p2
vagrant up --provision
```

The first execution downloads the VM image, creates the machine, installs K3s and deploys the manifests. This can take several minutes.

To connect to the VM :

```bash
vagrant ssh
```

## Check the cluster state

Once connected to the VM :

```bash
export KUBECONFIG="$HOME/.kube/config"

kubectl get nodes
kubectl get pods -A
kubectl get deployments
kubectl get services
kubectl get ingress
```

Expected results :

- the K3s node is in the `Ready` state ;
- the Pods `app1`, `app2` and `app3` are in the `Running` state ;
- the Deployment `app2` shows `3/3` available replicas ;
- Traefik is present in the `kube-system` namespace.

## Check the replicas of app2

```bash
export KUBECONFIG="$HOME/.kube/config"

kubectl get deployment app2
kubectl get pods -l app=app2 -o wide
```

The command should display three distinct Pods for application 2.

## Check the Ingress

```bash
export KUBECONFIG="$HOME/.kube/config"

kubectl get ingress
kubectl describe ingress
```

The Ingress should contain :

- Two rules for the hosts `app1.com` and `app2.com` ;
- A default backend for any other host name or direct IP access 

## Tests with curl

The following tests should be run from the host machine, in a terminal located in `p2/`.

```bash
ping -c 3 192.168.56.110
```

The VM should respond to the ping.

Testing the routing for app1 :

```bash
curl -s -H 'Host: app1.com' http://192.168.56.110
```

Expected result :

```text
Application 1
```

Testing the routing for app2 :

```bash
curl -s -H 'Host: app2.com' http://192.168.56.110
```

Expected result :

```text
Application 2
```

Testing the default backend for any other host name or IP address :

```bash
curl -s http://192.168.56.110
```

Expected result :

```text
Application 3 : Default backend
```

An unknown domain name should also redirect to application 3 :

```bash
curl -s -H 'Host: unknown.test' http://192.168.56.110
```

## Accessing the applications from a browser

To open app1 and app2 by their domain names, add this line to the `/etc/hosts` file on the host machine :

```text
192.168.56.110 app1.com app2.com
```

On macOS, open a terminal and edit the file with `nano` :

```bash
sudo nano /etc/hosts
```

Add the line, save with `Ctrl + O`, confirm with `Enter`, then exit with `Ctrl + X`.

Clear the DNS cache on macOS :

```bash
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
```

Next open a browser and test the following URLs :

```text
http://app1.com
http://app2.com
http://192.168.56.110
```

Expected results :

- `http://app1.com` displays Application 1 ;
- `http://app2.com` displays Application 2 ;
- `http://192.168.56.110` displays Application 3, the default backend.

## Stop and reload

Stop the VM without deleting it :

```bash
vagrant halt
```

Restart the VM :

```bash
vagrant up
```

Re-run the provisioning script  :

```bash
vagrant provision
```

Delete the VM and all its data :

```bash
vagrant destroy -f
```

Recreate the VM from scratch and reapply the manifests :

```bash
rm -rf .vagrant
vagrant up --provision
```

## Troubleshooting

### The VM is not responding

Check its status :

```bash
vagrant status
```

Verify its connectivity :

```bash
ping -c 3 192.168.56.110
curl -v -H 'Host: app1.com' http://192.168.56.110
```

### kubectl not working

In VM, check export of the KUBECONFIG variable :

```bash
export KUBECONFIG="$HOME/.kube/config"
```

Check the cluster state :

```bash
kubectl get nodes
kubectl get pods -A
```

### Pods not running

Inside the VM :

```bash
export KUBECONFIG="$HOME/.kube/config"

kubectl get pods
kubectl get services
kubectl get ingress
kubectl describe ingress
```

All the application pods must be in the `Running` state. Also verify that the Services and Ingress rules target the correct labels and ports.

### The browser is not accessing the VM

First, test access with `curl`. If `curl` works but the browser fails, check the **Local Network** permission in macOS settings or try with Safari.
