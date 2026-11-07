## Scenario 01 -- Helm and CRDs          (10 points)

Namespace `{{S01_NS}}` does not exist yet.

1. Create namespace `{{S01_NS}}`.

2. Install the Helm chart `jetstack/cert-manager` into that namespace as
   release name `{{S01_RELEASE}}`. The chart must install its CRDs
   (`crds.enabled=true`). The jetstack repo is already added.

3. The file `answers/01/clusterissuer.yaml` contains a ClusterIssuer named
   `{{S01_ISSUER}}`. Extend it so that the self-signed issuer publishes a CRL
   distribution point:

       spec.selfSigned.crlDistributionPoints  ->  a list with the single entry
       {{S01_CRL}}

4. Apply the edited file. The ClusterIssuer should end up Ready.

Hint: `helm show values jetstack/cert-manager | grep -A3 crds` and
`kubectl explain clusterissuer.spec.selfSigned` once the CRDs are installed.
