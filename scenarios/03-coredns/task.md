## Scenario 03 -- CoreDNS custom domain          (10 points)

Namespace `{{S03_NS}}` runs Deployment/Service `{{S03_SVC}}` and a busybox Pod
named `dns-test` you can use for lookups:

    kubectl -n {{S03_NS}} exec dns-test -- nslookup {{S03_SVC}}.{{S03_NS}}.svc.cluster.local

1. Back up the CoreDNS ConfigMap, unchanged, to

       answers/03/coredns_backup.yaml

2. Reconfigure CoreDNS so that every Service is additionally reachable under
   the domain `{{S03_DOMAIN}}`, exactly the way `cluster.local` works today:

       {{S03_SVC}}.{{S03_NS}}.svc.{{S03_DOMAIN}}   must resolve to the Service IP

   `SERVICE.NAMESPACE.svc.cluster.local` must keep working unchanged.

Note that CoreDNS picks up ConfigMap changes by itself, but it can take up to
a minute. The checker retries for 90 seconds.
