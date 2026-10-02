# Inception of Things

**Inception of Things** is a system administration project focused on Kubernetes and infrastructure automation.

The project progresses through three environments:

1. A two-node K3s cluster created with Vagrant.
2. A K3s server running three web applications behind a Traefik Ingress.
3. A K3d cluster using ArgoCD to automatically deploy an application from a Git repository.

## Learning objectives

This project introduces the following tools and concepts:

- Virtual machines with Vagrant and VirtualBox
- Lightweight Kubernetes clusters with K3s
- Kubernetes workloads: Deployments, Pods and Services
- HTTP routing with Traefik and Ingress
- Local Kubernetes clusters with K3d
- GitOps and continuous deployment with ArgoCD

## Project structure

```text
.
├── README.md
├── docs/
│   ├── app1.md
│   └── app2.md
├── p1/
│   ├── Vagrantfile
│   └── scripts/
├── p2/
│   ├── Vagrantfile
│   ├── scripts/
│   └── confs/
└── p3/
    ├── scripts/
    └── confs/
```

| Directory | Description | Documentation |
|---|---|---|
| `p1/` | Two-node K3s cluster created with Vagrant | [Part 1 guide](docs/app1.md) |
| `p2/` | One-node K3s cluster with three applications and Traefik Ingress | [Part 2 guide](docs/app2.md) |
| `p3/` | K3d cluster and GitOps deployment with ArgoCD | Coming soon |

## Prerequisites

The following tools are required for the completed parts:

- [Vagrant](https://developer.hashicorp.com/vagrant/install)
- [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
- Git

Part 3 will additionally require Docker, K3d and `kubectl`.


## Quick start

Each part is independent and must be launched from its own directory.

### Part 1

Part 1 creates a K3s server and a K3s agent:

```bash
cd p1
vagrant up
```

Verify that both nodes joined the cluster:

```bash
vagrant ssh loginteamS
export KUBECONFIG="$HOME/.kube/config"
kubectl get nodes
```

See the [Part 1 guide](docs/app1.md) for setup details, testing and troubleshooting.

### Part 2

Part 2 creates a K3s server with three web applications:

```bash
cd p2
vagrant up --provision
```

Test the HTTP routing from the host machine:

```bash
curl -s -H 'Host: app1.com' http://192.168.56.110
curl -s -H 'Host: app2.com' http://192.168.56.110
curl -s http://192.168.56.110
```

Expected results:

```text
Application 1
Application 2
Application 3 : Default backend
```

See the [Part 2 guide](docs/app2.md) for architecture details, browser access, testing and troubleshooting.

### Part 3

Part 3 will create a K3d cluster and deploy an application automatically through ArgoCD and GitOps.

The implementation and its documentation will be added later.

## Useful commands

Check the state of a Vagrant environment:

```bash
vagrant status
```

Connect to a Vagrant virtual machine:

```bash
vagrant ssh <machine-name>
```

Stop a Vagrant environment:

```bash
vagrant halt
```

Destroy a Vagrant environment:

```bash
vagrant destroy -f
```

Re-run Vagrant provisioning:

```bash
vagrant provision
```

## Notes

- Launch each part from its own folder; p1 and p2 use separate Vagrant environments.
- Do not run p1 and p2 simultaneously: both use the private IP address `192.168.56.110`.
- The K3s worker token created by p1 is ignored by Git because it is a cluster credential.
- All configuration files and scripts required to recreate the project are stored in this repository.


## Use of AI

Artificial intelligence was used as a learning and documentation assistant during this project.

It was used to:

- Explain Kubernetes, K3s, Vagrant, Traefik and Ingress concepts.
- Help troubleshoot networking issues and debug shell scripts.
- Review and improve shell scripts and Kubernetes manifests.
- Suggest test procedures and documentation structure.
- Help write and review the project documentation.

All generated suggestions were reviewed, adapted and tested manually.  
The infrastructure configuration, debugging process and final validation were performed by the project author.

AI was used as a support tool, not as a replacement for understanding the technologies used in this project.
