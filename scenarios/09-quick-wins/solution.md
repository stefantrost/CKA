## Solution 09 -- Quick wins

### a) Scale the StatefulSet

```bash
kubectl -n cka-09 scale statefulset web --replicas=4
kubectl -n cka-09 rollout status statefulset web
```

### b) BestEffort Pods

A Pod is BestEffort when **no** container sets any request or limit. Do not
work it out by hand -- the API already computed it:

```bash
kubectl -n cka-09 get pods \
  -o jsonpath='{range .items[?(@.status.qosClass=="BestEffort")]}{.metadata.name}{"\n"}{end}' \
  > answers/09/besteffort.txt
```

or with jq:

```bash
kubectl -n cka-09 get pods -o json \
  | jq -r '.items[] | select(.status.qosClass=="BestEffort") | .metadata.name' \
  > answers/09/besteffort.txt
```

### c) The two top scripts

```bash
cat > answers/09/top-node.sh <<'SH'
#!/usr/bin/env bash
kubectl top node
SH

cat > answers/09/top-pod.sh <<'SH'
#!/usr/bin/env bash
kubectl top pod -n cka-09
SH

chmod +x answers/09/top-node.sh answers/09/top-pod.sh
```

Forgetting `chmod +x` is the usual way to lose this point. If `kubectl top`
answers `Metrics API not available`, metrics-server is not ready yet --
`kubectl -n kube-system get deploy metrics-server`.

### d) Reading the kubeconfig

```bash
K=answers/09/kubeconfig

kubectl --kubeconfig $K config get-contexts -o name > answers/09/contexts.txt
kubectl --kubeconfig $K config current-context    > answers/09/current-context.txt
```

`-o name` prints bare names, which is what the checker wants;
`config get-contexts` without it prints a table with a `CURRENT` column.

### e) The embedded client certificate

```bash
kubectl --kubeconfig $K config view --raw \
  -o jsonpath='{.users[?(@.name=="purple-user")].user.client-certificate-data}' \
  | base64 -d > answers/09/client-cert.txt

openssl x509 -in answers/09/client-cert.txt -noout -subject -dates
```

`--raw` is essential: without it `config view` redacts the certificate and
key data to `DATA+OMITTED`. On Linux the flag is `base64 -d`, on macOS
`base64 -D` also works.
