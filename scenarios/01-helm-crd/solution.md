## Solution 01 -- Helm and CRDs

Names below come from the randomised task text; substitute your own.

```bash
# 1) namespace
kubectl create namespace cert-manager

# 2) the chart, with CRDs
helm repo update jetstack
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --set crds.enabled=true

helm -n cert-manager list          # STATUS should be "deployed"
kubectl -n cert-manager get pods
kubectl get crd | grep cert-manager
```

`crds.enabled=true` makes the chart render the CRD manifests as part of the
release. Without it you have to apply `cert-manager.crds.yaml` yourself, and
the CRDs are then not owned by the release.

```bash
# 3) find the field first -- this only works once the CRDs exist
kubectl explain clusterissuer.spec.selfSigned
```

Edit `answers/01/clusterissuer.yaml` into:

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: selfsigned-XXXX            # the name from the task
spec:
  selfSigned:
    crlDistributionPoints:
      - http://crl.cka-lab.local/XXXX.crl
```

```bash
# 4) apply and verify
kubectl apply -f answers/01/clusterissuer.yaml
kubectl get clusterissuer selfsigned-XXXX -o yaml | grep -A2 selfSigned
kubectl get clusterissuer selfsigned-XXXX   # READY should be True
```

A ClusterIssuer is cluster-scoped, so no `-n` anywhere. If `kubectl apply`
reports `no matches for kind "ClusterIssuer"`, the CRDs were not installed.
