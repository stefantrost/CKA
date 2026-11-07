## Solution 04 -- RBAC

```bash
NS=cka-04
SA=sa-XXXX          # names from the task text
ROLE=role-XXXX
RB=rb-XXXX

kubectl -n $NS create serviceaccount $SA

kubectl -n $NS create role $ROLE \
  --verb=create \
  --resource=secrets,configmaps

kubectl -n $NS create rolebinding $RB \
  --role=$ROLE \
  --serviceaccount=$NS:$SA
```

Two traps worth knowing:

* `--serviceaccount=NS:NAME` on `create rolebinding` takes the namespace in
  the value. `--user=` or `--group=` would create the wrong kind of subject.
* A **Role**Binding to a **Role** keeps the grant inside one namespace. A
  ClusterRoleBinding would hand the ServiceAccount the same rights in every
  namespace, which the checker tests for explicitly.

Verify the way the exam does:

```bash
for v in create get list watch update delete; do
  echo -n "$v secrets: "
  kubectl auth can-i $v secrets --as system:serviceaccount:$NS:$SA -n $NS
done
kubectl auth can-i create secrets --as system:serviceaccount:$NS:$SA -n cka-04-other   # no
```

The YAML equivalent of the Role:

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: role-XXXX
  namespace: cka-04
rules:
  - apiGroups: [""]
    resources: ["secrets", "configmaps"]
    verbs: ["create"]
```
