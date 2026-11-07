## Solution 02 -- Kustomize overlays and HPA

### 1. Remove the ConfigMap

```bash
cd answers/02
rm base/configmap.yaml
```

Drop `- configmap.yaml` from `base/kustomization.yaml`, and delete the
`envFrom:` block that references it from `staging/patch-deployment.yaml` and
`prod/patch-deployment.yaml`. A strategic-merge patch that names a container
must keep the container name, so the patch shrinks to:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2          # prod; 1 in staging
```

Check both overlays still build:

```bash
kubectl kustomize staging | grep -c ConfigMap    # 0
kubectl kustomize prod    | grep -c ConfigMap    # 0
```

### 2. HPA in the base

`base/hpa.yaml` (values from the task text):

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: web
  minReplicas: 2
  maxReplicas: 4
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 50
```

Add `- hpa.yaml` to `base/kustomization.yaml`.

A quick way to get the skeleton without typing:

```bash
kubectl autoscale deployment web --min=2 --max=4 --cpu-percent=50 \
  --dry-run=client -o yaml
```

(That emits `autoscaling/v1`; rewrite it to `autoscaling/v2` with the
`metrics:` block, which is what the checker and the exam expect.)

### 3. Override maxReplicas in prod only

`prod/patch-hpa.yaml`:

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: web
spec:
  maxReplicas: 6
```

and in `prod/kustomization.yaml`:

```yaml
patches:
  - path: patch-deployment.yaml
  - path: patch-hpa.yaml
```

A strategic-merge patch only needs the fields you change plus enough
identity (apiVersion/kind/name) for kustomize to find the target.

### 4 + 5. Apply, then clean up the live ConfigMaps

```bash
kubectl apply -k staging
kubectl apply -k prod

kubectl -n cka-02-staging delete configmap web-config
kubectl -n cka-02-prod    delete configmap web-config

kubectl -n cka-02-staging get hpa
kubectl -n cka-02-prod    get hpa
```

Deleting a resource from a kustomization does **not** delete it from the
cluster -- `kubectl apply` never removes what it no longer sends. Either
delete it by hand (as above) or use `kubectl apply -k --prune`, which needs
a label selector and is easy to get wrong under exam pressure.
