## Solution 06 -- crictl on a node

### 1. The Pod, pinned to a node

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: inspect-XXXX
  namespace: cka-06
  labels:
    tier: frontend          # key/value from the task
spec:
  nodeName: cka-worker      # the node from the task
  containers:
    - name: c
      image: busybox:1.36
      command: ["sh", "-c", "echo cka-XXXX; sleep 1d"]
```

```bash
kubectl apply -f pod.yaml
kubectl -n cka-06 get pod inspect-XXXX -o wide     # confirm the node
```

`nodeName` skips the scheduler. A `nodeSelector: {kubernetes.io/hostname: cka-worker}`
works just as well and is the more idiomatic answer.

### 2 + 3. Find the container with crictl

```bash
docker exec -it cka-worker bash        # "ssh" to the node in this lab

crictl ps --name inspect-XXXX
# CONTAINER      IMAGE   ...  POD
# 1f2e3d4c5b6a   ...          inspect-XXXX

ID=$(crictl ps -q --name inspect-XXXX)
crictl inspect $ID | grep runtimeType
#   "runtimeType": "io.containerd.runc.v2",
```

Useful crictl filters: `crictl pods --name X`, `crictl ps --pod <pod-id>`,
`crictl ps -a` for exited containers. `crictl` reads
`/etc/crictl.yaml` on a kubeadm/kind node, so no `--runtime-endpoint` needed.

Back on your workstation:

```bash
mkdir -p answers/06
echo "1f2e3d4c5b6a io.containerd.runc.v2" > answers/06/pod-container.txt
```

### 4. The logs, via crictl

```bash
docker exec cka-worker crictl logs $ID > answers/06/pod-container.log
cat answers/06/pod-container.log        # cka-XXXX
```

`crictl logs` reads the same file the kubelet writes,
`/var/log/pods/<ns>_<pod>_<uid>/<container>/0.log` -- which is what you fall
back to when the API server is down and `kubectl logs` is not an option.
