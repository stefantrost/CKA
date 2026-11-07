## Solution 07 -- One Pod per node

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: spread-XXXX
  namespace: cka-07
spec:
  replicas: 3
  selector:
    matchLabels:
      app: spread-XXXX
  template:
    metadata:
      labels:
        app: spread-XXXX
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
            - labelSelector:
                matchLabels:
                  app: spread-XXXX
              topologyKey: kubernetes.io/hostname
      containers:
        - name: web-XXXX
          image: nginx:1.27-alpine
        - name: side-XXXX
          image: busybox:1.36
          command: ["sh", "-c", "sleep 1d"]
```

```bash
kubectl apply -f deploy.yaml
kubectl -n cka-07 get pods -o wide
```

Two Pods Running on `cka-worker` and `cka-worker2`, one Pending. The reason
is in the events:

```bash
kubectl -n cka-07 describe pod <pending-pod> | tail -5
#   0/3 nodes are available: 1 node(s) had untolerated taint
#   {node-role.kubernetes.io/control-plane: }, 2 node(s) didn't match
#   pod anti-affinity rules.
```

The equivalent with topology spread constraints:

```yaml
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: kubernetes.io/hostname
          whenUnsatisfiable: DoNotSchedule
          labelSelector:
            matchLabels:
              app: spread-XXXX
```

Two things that cost points here:

* `requiredDuringSchedulingIgnoredDuringExecution` (hard), not
  `preferredDuringScheduling...` (soft) -- a soft rule would stack two Pods
  on one node instead of leaving one Pending.
* the `labelSelector` inside the anti-affinity has to match the Pods'
  **own** labels, otherwise the rule matches nothing and every Pod schedules.
* a bare `busybox` container exits immediately and the Pod would never be
  Running; it needs a long-running command.
