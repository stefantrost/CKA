<h1 align="center">CKA practice lab</h1>

<p align="center">
  A local, self-scoring <strong>Certified Kubernetes Administrator</strong> practice
  environment on <code>kind</code>, modelled on the killer.sh simulator.
</p>

<p align="center">
  <img alt="Kubernetes v1.35.8" src="https://img.shields.io/badge/Kubernetes-v1.35.8-326ce5?logo=kubernetes&logoColor=white">
  <img alt="kind" src="https://img.shields.io/badge/kind-3--node%20cluster-326ce5">
  <img alt="CNI Calico" src="https://img.shields.io/badge/CNI-Calico%20v3.33.0-ff6b35">
  <img alt="Shell bash" src="https://img.shields.io/badge/shell-bash%203.2%2B-4eaa25?logo=gnubash&logoColor=white">
  <img alt="Platform macOS and Linux" src="https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey">
</p>

---

Ten scenarios. Each one builds its own starting state, prints a task in the
exam's style, and then scores your solution subtask by subtask against the
**live cluster** -- never against the YAML you wrote. Every FAIL says why.

```console
$ ./lab.sh start 04

## Scenario 04 -- RBAC                    (13 points)

Namespaces `cka-04` and `cka-04-other` exist.

In namespace `cka-04`, create:

  * ServiceAccount `sa-ae4e`
  * Role `role-fd39`
  * RoleBinding `rb-b4e3`, binding the Role to that ServiceAccount

The ServiceAccount must be allowed to **create** Secrets and ConfigMaps in
`cka-04` -- and nothing else. No get, no list, no watch, no update, no
delete, no other resources, and nothing at all in `cka-04-other`.

Timer started. Score with: ./lab.sh check 04

$ ./lab.sh check 04
[FAIL] ServiceAccount sa-ae4e exists in cka-04                    0/1
       -> kubectl -n cka-04 get sa sa-ae4e failed
[FAIL] can create secrets in cka-04                               0/2
       -> auth can-i create secrets is 'no' for system:serviceaccount:cka-04:sa-ae4e
[PASS] cannot get secrets in cka-04                               1/1
[PASS] cannot create secrets in cka-04-other                      1/1
...
scenario 04  score: 5/13 points
elapsed: 0m 01s
```

The object names change on every run -- `sa-ae4e` is a dice roll -- so the
second pass cannot be solved from memory.

## Why

The real exam is six hours of live-cluster work, and the only way to prepare
for it is to break and fix real clusters. killer.sh gives you two attempts;
this gives you unlimited ones on hardware you already own, with the same
shape: randomised tasks, partial credit, a timer, and a 66% pass mark.

* Kubernetes **v1.35.8** (`kindest/node:v1.35.8`), the version the CKA
  currently tests against. Change `NODE_IMAGE` in `cluster/lib.sh` and the
  `image:` lines in `cluster/kind.yaml` together for a different one.
* 1 control-plane + 2 workers, cluster name `cka`, context `kind-cka`.
* kind's default CNI is disabled and **Calico v3.33.0** installed, so
  NetworkPolicies are really enforced.
* **metrics-server v0.9.1** with `--kubelet-insecure-tls`, so `kubectl top`
  and HPAs work.
* The `jetstack` Helm repo is added but cert-manager is **not** installed --
  installing it is scenario 01.

## Requirements

`docker`, `kind`, `kubectl`, `helm`, `jq`, `bash`. `./lab.sh` checks for each
one at startup and prints an install hint for whatever is missing; nothing is
installed system-wide for you.

```bash
brew install kind kubernetes-cli helm jq      # macOS
```

Docker needs roughly 4 CPUs and 6 GB of memory for a three-node cluster.

## Quickstart

```bash
git clone <this repo> && cd cka-lab
./lab.sh up            # create the cluster (~4 minutes the first time)
./lab.sh list          # what is available
./lab.sh start 04      # set up scenario 04, print the task, start a timer
# ... solve it ...
./lab.sh check 04      # PASS/FAIL per subtask, score, elapsed time
./lab.sh solution 04   # the reference solution (asks before spoiling it)
./lab.sh reset 04      # undo everything the scenario created
```

Sitting a full mock exam is `./lab.sh exam`: all ten scenarios in a random
order under one timer, then `./lab.sh exam score` for the total.

## Commands

| command | what it does |
| --- | --- |
| `./lab.sh up` | create the cluster and install Calico, metrics-server, the jetstack repo |
| `./lab.sh down` | delete the cluster and the lab's `.state/` |
| `./lab.sh status` | cluster health and which scenarios are running |
| `./lab.sh list` | scenarios with their maximum points |
| `./lab.sh start NN` | run `setup.sh`, print `task.md`, start the timer |
| `./lab.sh task NN` | re-print the task text |
| `./lab.sh check NN` | run `check.sh`, print the score and elapsed time |
| `./lab.sh solution NN` | show `solution.md` after a confirmation prompt |
| `./lab.sh reset NN` | run `reset.sh` and forget the scenario's state |
| `./lab.sh exam` | set up **all** scenarios in a random order, one timer |
| `./lab.sh exam score` | score everything and print a total (pass mark 66%) |
| `./lab.sh exam reset` | reset every scenario |

## Scenarios

| NN | topic | points |
| --- | --- | --- |
| 01 | Helm, chart values, CRDs (cert-manager + ClusterIssuer) | 10 |
| 02 | Kustomize overlays, patches, HPA | 15 |
| 03 | CoreDNS: backup the ConfigMap, add a custom domain | 10 |
| 04 | RBAC: ServiceAccount + Role + RoleBinding, verified with `auth can-i` | 13 |
| 05 | Calling the API server from a Pod with its ServiceAccount token | 10 |
| 06 | `crictl` on a node: container id, runtimeType, logs | 11 |
| 07 | Deployment spread across nodes, exact container names/images | 12 |
| 08 | NetworkPolicy egress, verified with a live connectivity matrix | 16 |
| 09 | Quick wins: scaling, QoS classes, `kubectl top`, kubeconfig | 16 |
| 10 | Control-plane static Pods: etcd manifest, apiserver flag, ServiceCIDR | 16 |
| | **total** | **129** |

## Conventions

* **Answers go in `./answers/NN/`** -- the lab's stand-in for `/course/NN` on
  the real exam. Some scenarios also *provide* files there (the Kustomize
  tree, a kubeconfig, a ClusterIssuer to edit).
* **"SSH to a node"** means `docker exec -it cka-worker bash` (or
  `cka-worker2`, `cka-control-plane`). Task texts say so where it matters.
* **Each scenario owns its namespaces** (`cka-NN...`), so nothing interferes.
* **Names and values are randomised** per run -- replica counts, ports, label
  values, ServiceAccount names. They are written into the task text, so you
  cannot solve a scenario from memory on the second pass.
* Checks query the live cluster (`kubectl get`, `auth can-i`, `exec`, `curl`,
  `crictl`, `nslookup`) and print a one-line reason for every FAIL.
* `./lab.sh` always talks to the `kind-cka` context. Your own kubectl should
  too -- `kubectl config use-context kind-cka`. `./lab.sh up` sets it.

### Shared setup bundles

Scenarios that do not interfere share one setup, so a cold start is a few
seconds instead of a few minutes:

| bundle | sets up for | contents |
| --- | --- | --- |
| `bundles/apps.sh` | 01, 02, 07, 08, 09 | the ClusterIssuer file, the Kustomize tree and its live state, the NetworkPolicy StatefulSets, the QoS zoo and a kubeconfig |
| `bundles/auth.sh` | 04, 05 | namespaces, the ServiceAccount and Secret for scenario 05 |
| `bundles/cluster.sh` | 03, 06, 10 | the DNS test Pod and Service, plus pristine backups of the CoreDNS ConfigMap and the kube-apiserver manifest |

`./lab.sh start NN` runs the bundle its scenario belongs to -- which also
creates the starting state of its siblings. A bundle runs once per cluster
(marker files in `.state/bundles/`); `reset NN` clears the marker so the next
`start` rebuilds it. Bundles and all `setup.sh`/`reset.sh` scripts are
idempotent and safe to re-run.

### Resetting

```bash
./lab.sh reset NN      # one scenario: deletes its namespaces, files and
                       # restores anything it changed cluster-wide
./lab.sh exam reset    # all of them
./lab.sh down && ./lab.sh up    # the big hammer: a brand new cluster
```

Scenarios 03 and 10 change the cluster itself (the CoreDNS ConfigMap, the
kube-apiserver static Pod manifest). Their setup takes a pristine copy into
`.state/` first and `reset.sh` puts it back, waiting for CoreDNS and the API
server to come up again. If you ever break the API server beyond that,
`./lab.sh down && ./lab.sh up` always works.

Your work in `./answers/` is deleted by `reset NN` for the scenarios that own
files there, but never by `./lab.sh down`.

## What this lab deliberately does not cover

**`kubeadm upgrade` and `kubeadm join` cannot be practised honestly in kind.**
kind nodes are containers started from a prebuilt image with the kubelet and
the control plane already in place; there is no package manager state to
upgrade, `kubeadm upgrade plan` has nothing to plan against, and joining a
"new node" is just another container from the same image. Faking it would
teach you the wrong commands, so those scenarios are not here.

Practise them instead on:

* **killercoda.com/cka** -- free, browser-based, real multi-node VMs. The
  "Cluster Upgrade" and "Add a node" scenarios are exactly the exam's.
* **Two local Ubuntu VMs with Multipass**, which is the closest thing to the
  exam environment you can run on a laptop:

```bash
brew install multipass

multipass launch --name cp     --cpus 2 --memory 2G --disk 10G 24.04
multipass launch --name node01 --cpus 2 --memory 2G --disk 10G 24.04

# on BOTH VMs: multipass shell cp   /   multipass shell node01
sudo swapoff -a && sudo sed -i '/ swap / s/^/#/' /etc/fstab
sudo modprobe br_netfilter
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/k8s.conf
sudo sysctl --system
sudo apt-get update && sudo apt-get install -y containerd apt-transport-https gpg
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml >/dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd

# install one minor version BELOW the target, so there is something to upgrade
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.34/deb/Release.key \
  | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] \
  https://pkgs.k8s.io/core:/stable:/v1.34/deb/ /' \
  | sudo tee /etc/apt/sources.list.d/kubernetes.list
sudo apt-get update
sudo apt-get install -y kubelet=1.34.1-1.1 kubeadm=1.34.1-1.1 kubectl=1.34.1-1.1
sudo apt-mark hold kubelet kubeadm kubectl

# on cp only
sudo kubeadm init --pod-network-cidr=192.168.0.0/16
mkdir -p ~/.kube && sudo cp /etc/kubernetes/admin.conf ~/.kube/config
sudo chown $(id -u):$(id -g) ~/.kube/config
kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.33.0/manifests/calico.yaml
kubeadm token create --print-join-command          # <-- practise `join` with this

# on node01: paste the printed command
sudo kubeadm join <cp-ip>:6443 --token ... --discovery-token-ca-cert-hash sha256:...

# then practise the upgrade, control plane first, one node at a time:
#   sudo sed -i 's#v1.34#v1.35#' /etc/apt/sources.list.d/kubernetes.list
#   sudo apt-get update
#   sudo apt-mark unhold kubeadm && sudo apt-get install -y kubeadm=1.35.0-1.1
#   sudo kubeadm upgrade plan
#   sudo kubeadm upgrade apply v1.35.0
#   kubectl drain cp --ignore-daemonsets
#   sudo apt-mark unhold kubelet kubectl
#   sudo apt-get install -y kubelet=1.35.0-1.1 kubectl=1.35.0-1.1
#   sudo systemctl daemon-reload && sudo systemctl restart kubelet
#   kubectl uncordon cp
#   # on node01: kubeadm upgrade node, then the same kubelet steps
```

Exact package versions change; `apt-cache madison kubeadm` lists what the
repo currently has.

## Layout

```
cka-lab/
  README.md
  AGENTS.md                 working rules for agents hacking on the lab
  docs/                     architecture, and how to add a scenario
  lab.sh                    entrypoint
  cluster/
    kind.yaml               3-node cluster, no default CNI
    bootstrap.sh            create + Calico + metrics-server + helm repo
    lib.sh                  shared helpers: scoring, state, randomisation
  bundles/                  shared starting state for groups of scenarios
  scenarios/NN-name/
    task.md                 task text ({{VAR}} placeholders, rendered on start)
    setup.sh                idempotent; runs the scenario's bundle
    check.sh                scores each subtask, prints PASS/FAIL + total
    solution.md             reference solution with commands and explanation
    reset.sh                idempotent; removes what the scenario created
  answers/NN/               your answers (and provided files)
  .state/                   rendered tasks, randomised values, timers, backups
```

## Hacking on the lab

* [docs/architecture.md](docs/architecture.md) -- how `lab.sh`, the shared
  bundles, the randomised `vars.env` and the scoring fit together, plus a
  reference for every `cluster/lib.sh` helper.
* [docs/adding-a-scenario.md](docs/adding-a-scenario.md) -- the five-file
  contract for a scenario, the end-to-end test loop a change has to pass, and
  the traps that cost a debugging round the first time.
* [AGENTS.md](AGENTS.md) -- the same rules, condensed for coding agents.
