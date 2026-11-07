## Solution 03 -- CoreDNS custom domain

### 1. Back it up first

```bash
mkdir -p answers/03
kubectl -n kube-system get configmap coredns -o yaml > answers/03/coredns_backup.yaml
```

Do this *before* editing. The checker compares the backup against the
pristine Corefile, so a backup taken after the edit scores zero -- which is
exactly how the exam treats it, because the backup is your rollback.

### 2. Add the domain to the kubernetes plugin

```bash
kubectl -n kube-system edit configmap coredns
```

The `kubernetes` line lists the zones CoreDNS answers authoritatively for.
Append the custom domain:

```
    kubernetes cluster.local custom-domain in-addr.arpa ip6.arpa {
       pods insecure
       fallthrough in-addr.arpa ip6.arpa
       ttl 30
    }
```

Only the first line changes -- everything else in the Corefile stays as it is.

### 3. Wait for the reload and verify

The Corefile contains a `reload` plugin, so CoreDNS re-reads the ConfigMap on
its own; the kubelet needs up to a minute to project the new ConfigMap into
the Pods. To not wait:

```bash
kubectl -n kube-system rollout restart deployment coredns
kubectl -n kube-system rollout status deployment coredns
```

```bash
kubectl -n cka-03 exec dns-test -- nslookup web.cka-03.svc.cluster.local
kubectl -n cka-03 exec dns-test -- nslookup web.cka-03.svc.custom-domain
kubectl -n cka-03 get svc web          # same ClusterIP in both answers
```

If lookups break entirely, the Corefile has a syntax error:

```bash
kubectl -n kube-system logs -l k8s-app=kube-dns --tail=20
```

Restore with `kubectl -n kube-system replace -f answers/03/coredns_backup.yaml`.
