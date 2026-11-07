## Scenario 10 -- Control-plane static Pods          (16 points)

"SSH" to the control plane with

    docker exec -it cka-control-plane bash

### Part 1 -- read the etcd manifest          (6 points)

Look at the static Pod manifest of etcd in `/etc/kubernetes/manifests` and
write exactly three lines to `answers/10/etcd-info.txt`:

    key-file: <value of the --key-file argument>
    expiry: <notAfter date of the etcd *server* certificate>
    client-cert-auth: <value of the --client-cert-auth argument>

For the expiry, take the value `openssl x509 -noout -enddate` prints after
`notAfter=`, verbatim.

### Part 2 -- change a kube-apiserver flag          (10 points)

1. Edit `/etc/kubernetes/manifests/kube-apiserver.yaml` on the control plane
   so the API server allocates NodePorts from the range

       {{S10_NODEPORT_LO}}-{{S10_NODEPORT_HI}}

   The kubelet restarts the static Pod on its own; the API server is
   unreachable for a few seconds afterwards.

2. The cluster should hand out Service IPs from an additional range. Create
   a ServiceCIDR named `{{S10_CIDR_NAME}}` for `{{S10_CIDR}}`, then create a
   ClusterIP Service `{{S10_SVC}}` in namespace `{{S10_NS}}` with
   `clusterIP: {{S10_SVC_IP}}`, port 80, to prove an IP from the new range
   can be allocated.

A mistake in the manifest takes the API server down. The kubelet logs on the
node (`journalctl -u kubelet` or `crictl ps -a`) are then your only way in.
`./lab.sh reset 10` restores the original manifest.
