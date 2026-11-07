## Scenario 04 -- RBAC                    (13 points)

Namespaces `{{S04_NS}}` and `{{S04_OTHER_NS}}` exist.

In namespace `{{S04_NS}}`, create:

  * ServiceAccount `{{S04_SA}}`
  * Role `{{S04_ROLE}}`
  * RoleBinding `{{S04_RB}}`, binding the Role to that ServiceAccount

The ServiceAccount must be allowed to **create** Secrets and ConfigMaps in
`{{S04_NS}}` -- and nothing else. No get, no list, no watch, no update, no
delete, no other resources, and nothing at all in `{{S04_OTHER_NS}}`.

Verify with:

    kubectl auth can-i create secrets \
      --as system:serviceaccount:{{S04_NS}}:{{S04_SA}} -n {{S04_NS}}
