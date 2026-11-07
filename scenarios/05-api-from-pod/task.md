## Scenario 05 -- Talking to the API server from a Pod          (10 points)

Namespace `{{S05_NS}}` already contains ServiceAccount `{{S05_SA}}`, which is
allowed to get and list Secrets in that namespace, and a Secret named
`{{S05_SECRET}}`.

1. Create Pod `{{S05_POD}}` in namespace `{{S05_NS}}`:

     * image `{{S05_IMAGE}}`
     * command: `sleep 1d`
     * it must run as ServiceAccount `{{S05_SA}}`

2. From **inside that Pod**, call the Kubernetes API with the Pod's
   ServiceAccount token and list the Secrets of namespace `{{S05_NS}}`.
   Use the mounted CA certificate; do not use `curl -k`.

3. Write the JSON the API returned -- the complete SecretList -- to

       answers/05/result.json
