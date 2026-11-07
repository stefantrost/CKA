## Scenario 09 -- Quick wins          (16 points, ~5 minutes)

Five small tasks. Namespace `{{S09_NS}}` is already populated.

**a)** Scale StatefulSet `{{S09_STS}}` in `{{S09_NS}}` to {{S09_REPLICAS}}
replicas. All of its Pods must end up Ready.

**b)** Write the names of all Pods in `{{S09_NS}}` with QoS class
`BestEffort` to `answers/09/besteffort.txt`, one name per line, nothing else.

**c)** Write two executable scripts:

      answers/09/top-node.sh   prints CPU and memory usage of all nodes
      answers/09/top-pod.sh    prints CPU and memory usage of all Pods
                               in namespace {{S09_NS}}

Both must be runnable as `./answers/09/top-node.sh`.

**d)** `answers/09/kubeconfig` is a kubeconfig file (it does not point at this
cluster, it is just a file to read). From it, write:

      answers/09/contexts.txt          the names of all contexts, one per line
      answers/09/current-context.txt   the current context, on one line

**e)** The user `purple-user` in that same kubeconfig has an embedded client
certificate. Write it, decoded, in PEM form, to

      answers/09/client-cert.txt
