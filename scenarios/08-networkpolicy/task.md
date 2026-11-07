## Scenario 08 -- NetworkPolicy egress          (16 points)

Namespace `{{S08_NS}}` runs four StatefulSets, each with one Pod, plus a
Service of the same name:

    backend                       (has curl, label app=backend)
    db1     listening on {{S08_DB1_PORT}} and on {{S08_VAULT_PORT}}
    db2     listening on {{S08_DB2_PORT}}
    vault   listening on {{S08_VAULT_PORT}}

Right now `backend` can reach all three. Check for yourself:

    kubectl -n {{S08_NS}} exec backend-0 -- curl -s -m 3 db1:{{S08_DB1_PORT}}

Create a NetworkPolicy named `{{S08_POLICY}}` in `{{S08_NS}}` so that Pods
with label `app=backend` can reach **only**:

    db1 on port {{S08_DB1_PORT}}
    db2 on port {{S08_DB2_PORT}}

Everything else outgoing must be blocked -- `vault`, and db1 on port
{{S08_VAULT_PORT}}, in particular. Other Pods
in the namespace must keep their current connectivity; the policy applies to
`backend` only.

Careful: the curl commands above use Service **names**, so backend still has
to be able to talk to DNS.
