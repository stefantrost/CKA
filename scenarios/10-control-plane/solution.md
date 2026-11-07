## Solution 10 -- Control-plane static Pods

### Part 1 -- read the etcd manifest

```bash
docker exec -it cka-control-plane bash

grep -E 'key-file|client-cert-auth' /etc/kubernetes/manifests/etcd.yaml
#     - --key-file=/etc/kubernetes/pki/etcd/server.key
#     - --client-cert-auth=true

openssl x509 -in /etc/kubernetes/pki/etcd/server.crt -noout -enddate
# notAfter=Nov  6 08:03:02 2027 GMT
```

Write the three lines on your workstation:

```bash
mkdir -p answers/10
cat > answers/10/etcd-info.txt <<'EOF2'
key-file: /etc/kubernetes/pki/etcd/server.key
expiry: Nov  6 08:03:02 2027 GMT
client-cert-auth: true
EOF2
```

`kubeadm certs check-expiration` gives the same dates for every control-plane
certificate in one table -- worth knowing, it is faster than openssl per file.

### Part 2.1 -- the NodePort range

```bash
docker exec -it cka-control-plane bash
vim /etc/kubernetes/manifests/kube-apiserver.yaml
```

Add one line to the container's `command:` list, keeping the `- ` indentation
of the neighbouring flags:

```yaml
    - --service-node-port-range=30500-30600
```

Save and leave the node. The kubelet watches that directory and restarts the
static Pod within seconds:

```bash
kubectl -n kube-system get pod kube-apiserver-cka-control-plane -w
kubectl get --raw /readyz
```

`kubectl` refusing to connect for 10-30 seconds is normal. If it never comes
back, the manifest has a YAML error -- `docker exec cka-control-plane crictl ps -a`
shows the crash-looping container, and `crictl logs <id>` the reason.

Verify the new range took effect:

```bash
kubectl -n cka-10 create svc nodeport np-probe --tcp=80:80
kubectl -n cka-10 get svc np-probe -o jsonpath='{.spec.ports[0].nodePort}'
kubectl -n cka-10 delete svc np-probe
```

### Part 2.2 -- an additional ServiceCIDR

Since the MultiCIDRServiceAllocator went GA, extra Service ranges are an API
object rather than another flag:

```yaml
apiVersion: networking.k8s.io/v1
kind: ServiceCIDR
metadata:
  name: extra-XXXX
spec:
  cidrs:
    - 10.97.0.0/24
```

```bash
kubectl apply -f servicecidr.yaml
kubectl get servicecidr            # Ready should be True

kubectl -n cka-10 create service clusterip extra-svc --tcp=80:80 \
  --dry-run=client -o yaml > svc.yaml
# add spec.clusterIP: 10.97.0.10
kubectl apply -f svc.yaml

kubectl -n cka-10 get svc extra-svc -o jsonpath='{.spec.clusterIP}'
```

The allocator only hands out addresses from a secondary range on request, so
a Service without an explicit `clusterIP` still gets one from 10.96.0.0/16.
Asking for `10.97.0.10` before the ServiceCIDR exists fails with
`provided IP is not in the valid range`.
