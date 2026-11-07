## Scenario 07 -- One Pod per node          (12 points)

In namespace `{{S07_NS}}`, create Deployment `{{S07_DEPLOY}}`:

  * {{S07_REPLICAS}} replicas
  * two containers:

        name {{S07_C1}}   image {{S07_IMAGE1}}
        name {{S07_C2}}   image {{S07_IMAGE2}}   command: sh -c "sleep 1d"

  * no two Pods of this Deployment may run on the same node.
    Use podAntiAffinity or topologySpreadConstraints on the node label
    `kubernetes.io/hostname`.

The cluster has two schedulable worker nodes, so with {{S07_REPLICAS}}
replicas exactly one Pod will stay **Pending**. That is the expected end
state -- do not relax the constraint to get it scheduled.
