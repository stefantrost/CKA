## Solution 08 -- NetworkPolicy egress

```bash
kubectl -n cka-08 get pods --show-labels
kubectl -n cka-08 exec backend-0 -- curl -s -m 3 vault:3333    # works, for now
```

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: backend-egress
  namespace: cka-08
spec:
  podSelector:
    matchLabels:
      app: backend
  policyTypes:
    - Egress
  egress:
    # the two allowed destinations
    - to:
        - podSelector:
            matchLabels:
              app: db1
      ports:
        - protocol: TCP
          port: 1111
    - to:
        - podSelector:
            matchLabels:
              app: db2
      ports:
        - protocol: TCP
          port: 2222
    # DNS, or nothing resolves any more
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
```

```bash
kubectl apply -f netpol.yaml

kubectl -n cka-08 exec backend-0 -- curl -s -m 3 db1:1111      # db1
kubectl -n cka-08 exec backend-0 -- curl -s -m 3 db2:2222      # db2
kubectl -n cka-08 exec backend-0 -- curl -s -m 3 vault:3333    # times out
kubectl -n cka-08 exec probe     -- curl -s -m 3 vault:3333    # still works
```

What to remember:

* The moment a Pod is selected by any policy with `Egress` in `policyTypes`,
  **all** its egress is denied except what the rules allow. That includes
  DNS -- the single most common reason a "correct" policy makes everything
  time out. The symptom is `curl: (6) Could not resolve host`, not a timeout.
* `to:` and `ports:` inside **one** rule are an AND. Two entries under a
  single `to:` list would be an OR over destinations sharing those ports --
  here each database needs its own port, so they must be separate rules.
* Egress policies select the **source** Pods. `podSelector` is the backend,
  the databases appear under `to:`.
* The `kubernetes.io/metadata.name` label is set automatically on every
  namespace, which makes it the reliable way to select `kube-system`.
