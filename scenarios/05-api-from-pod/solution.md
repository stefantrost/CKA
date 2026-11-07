## Solution 05 -- Talking to the API server from a Pod

### 1. The Pod

```bash
kubectl -n cka-05 run api-pod-XXXX \
  --image=curlimages/curl:8.11.1 \
  --command -- sleep 1d \
  --dry-run=client -o yaml > pod.yaml
```

Add the ServiceAccount (`kubectl run` has no flag for it):

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-pod-XXXX
  namespace: cka-05
spec:
  serviceAccountName: api-XXXX
  containers:
    - name: api-pod-XXXX
      image: curlimages/curl:8.11.1
      command: ["sleep", "1d"]
```

```bash
kubectl apply -f pod.yaml
```

### 2. Call the API from inside

Every Pod gets the token, the CA and its namespace projected into
`/var/run/secrets/kubernetes.io/serviceaccount/`:

```bash
kubectl -n cka-05 exec -it api-pod-XXXX -- sh

cd /var/run/secrets/kubernetes.io/serviceaccount
curl -s --cacert ca.crt \
  -H "Authorization: Bearer $(cat token)" \
  https://kubernetes.default.svc/api/v1/namespaces/$(cat namespace)/secrets
```

`--cacert ca.crt` is what makes `curl -k` unnecessary: that CA signed the API
server certificate, and `kubernetes.default.svc` is in its SAN list.

A 403 here means the Pod is running as the wrong ServiceAccount -- check
`kubectl -n cka-05 get pod api-pod-XXXX -o jsonpath='{.spec.serviceAccountName}'`.

### 3. Save the output

Run the same command non-interactively and redirect on your workstation:

```bash
mkdir -p answers/05
kubectl -n cka-05 exec api-pod-XXXX -- sh -c \
  'curl -s --cacert /var/run/secrets/kubernetes.io/serviceaccount/ca.crt \
     -H "Authorization: Bearer $(cat /var/run/secrets/kubernetes.io/serviceaccount/token)" \
     https://kubernetes.default.svc/api/v1/namespaces/cka-05/secrets' \
  > answers/05/result.json

jq .kind answers/05/result.json        # "SecretList"
```

Mind the quoting: the `$(cat ...)` must be evaluated **inside** the Pod, so
the whole script goes in single quotes.
