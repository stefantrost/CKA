## Scenario 06 -- crictl on a node          (11 points)

1. In namespace `{{S06_NS}}`, create Pod `{{S06_POD}}`:

     * image `{{S06_IMAGE}}`
     * label `{{S06_LABEL_KEY}}={{S06_LABEL_VAL}}`
     * it must run on node `{{S06_NODE}}`
     * command: `sh -c 'echo {{S06_TOKEN}}; sleep 1d'`

2. "SSH" to that node -- in this lab that is

       docker exec -it {{S06_NODE}} bash

   and use `crictl` to find the container of that Pod.

3. Write one line to `answers/06/pod-container.txt`:

       <container-id> <runtimeType>

   The container id as crictl shows it, a single space, then the
   `runtimeType` reported by `crictl inspect`.

4. Write the container's logs -- read through crictl on the node, not through
   kubectl -- to `answers/06/pod-container.log`.
