## Scenario 02 -- Kustomize overlays and HPA          (15 points)

In `answers/02` there is a Kustomize setup:

    base/      deployment.yaml, configmap.yaml, kustomization.yaml
    staging/   kustomization.yaml, namespace-transformer.yaml, patch-deployment.yaml
    prod/      kustomization.yaml, namespace-transformer.yaml, patch-deployment.yaml

Both overlays are already applied to the cluster: namespaces
`{{S02_STAGING_NS}}` and `{{S02_PROD_NS}}` each run Deployment `{{S02_APP}}`
and a ConfigMap `{{S02_APP}}-config`.

1. The ConfigMap is no longer wanted. Remove it from the base **and** from
   every patch that still references it, so that neither overlay renders a
   ConfigMap any more. `kubectl kustomize answers/02/staging` and
   `kubectl kustomize answers/02/prod` must both still build without errors.

2. Add a HorizontalPodAutoscaler named `{{S02_APP}}` to the **base**, targeting
   Deployment `{{S02_APP}}`:

       minReplicas: {{S02_MIN}}
       maxReplicas: {{S02_MAX}}
       metric:      CPU, averageUtilization {{S02_CPU}}

3. In the **prod overlay only**, override `maxReplicas` to {{S02_PROD_MAX}}.
   Staging keeps {{S02_MAX}}. Do not copy the whole HPA into prod -- patch it.

4. Apply both overlays.

5. Delete the two ConfigMaps that are still live in the cluster.
