
# jsp-gcm

This is the repository that holds the configuration for our Google
Marketplace solution, [jetstack-secure-for-cert-manager][].

**Content:**

- [Technical considerations](#technical-considerations)
- [Installing and manually testing the deployer](#installing-and-manually-testing-the-deployer)
- [Testing and releasing the deployer using Google Cloud Build](#testing-and-releasing-the-deployer-using-google-cloud-build)
- [Updating the upstream cert-manager chart version](#updating-the-upstream-cert-manager-chart-version)

## Technical considerations

**Retagging cert-manager images:**

In order to abide by the [schema.md][], which states:

> When users deploy your app from Google Cloud Marketplace, the final image
> names may be different, but they will follow **the same release tag** and
> name prefix rule.

This means we do re-tag all our images (cert-manager, cas-issuer, ubbagent,
preflight-agent) using a unified tag that is distinct from the cert-manager
regular version. We call this version the "application version". In the
following example, the application version is `1.0.0` although the
cert-manager-controller is `1.1.0`:

```sh
gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-acmesolver:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-cainjector:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-google-cas-issuer:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/preflight:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/ubbagent:1.0.0
```

**cert-manager-controller is the "primary image":**

The "primary" image is pushed to the "root" of the registry, for example:

```sh
# The primary image "cert-manager-controller":
gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.0.0

# All other images:
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook:1.0.0
```

## Installing and manually testing the deployer

In order to have the google-cas-issuer working, we need to enable [workload
identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity).
Let's create a cluster that has the workload identity enabled:

```sh
gcloud container clusters create foo --region us-east1 --num-nodes=1 --preemptible \
  --workload-pool=$(gcloud config get-value project | tr ':' '/').svc.id.goog
```

Now, re-publish the images to the project:

```sh
export REGISTRY=gcr.io/$(gcloud config get-value project | tr ':' '/')
export SOLUTION=jetstack-secure-for-cert-manager

docker pull quay.io/jetstack/cert-manager-controller:v1.1.0
docker pull quay.io/jetstack/cert-manager-acmesolver:v1.1.0
docker pull quay.io/jetstack/cert-manager-cainjector:v1.1.0
docker pull quay.io/jetstack/cert-manager-webhook:v1.1.0
docker pull quay.io/jetstack/cert-manager-google-cas-issuer:0.1.0
docker pull quay.io/jetstack/preflight:0.1.27
docker pull gcr.io/cloud-marketplace-tools/metering/ubbagent:latest

docker tag quay.io/jetstack/cert-manager-controller:v1.1.0 $REGISTRY/$SOLUTION:1.0.0
docker tag quay.io/jetstack/cert-manager-acmesolver:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-acmesolver:1.0.0
docker tag quay.io/jetstack/cert-manager-cainjector:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-cainjector:1.0.0
docker tag quay.io/jetstack/cert-manager-webhook:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-webhook:1.0.0
docker tag quay.io/jetstack/cert-manager-google-cas-issuer:latest $REGISTRY/$SOLUTION/cert-manager-google-cas-issuer:1.0.0
docker tag quay.io/jetstack/preflight:latest $REGISTRY/$SOLUTION/preflight:1.0.0
docker pull gcr.io/cloud-marketplace-tools/metering/ubbagent:latest $REGISTRY/$SOLUTION/ubbagent:1.0.0

docker push $REGISTRY/$SOLUTION:1.0.0
docker push $REGISTRY/$SOLUTION/cert-manager-acmesolver:1.0.0
docker push $REGISTRY/$SOLUTION/cert-manager-cainjector:1.0.0
docker push $REGISTRY/$SOLUTION/cert-manager-webhook:1.0.0
docker push $REGISTRY/$SOLUTION/cert-manager-google-cas-issuer:1.0.0
docker push $REGISTRY/$SOLUTION/preflight:1.0.0
docker push $REGISTRY/$SOLUTION/ubbagent:1.0.0
```

Then, build and push the deployer image:

```sh
docker build --tag $REGISTRY/$SOLUTION/deployer:1.0.0 .
docker push $REGISTRY/$SOLUTION/deployer:1.0.0
```

Finally, use `mpdev` to install jetstack-secure to the `test-ns` namespace:

```sh
# If you don't have it already, install mpdev:
docker run gcr.io/cloud-marketplace-tools/k8s/dev cat /scripts/dev > /tmp/mpdev && install /tmp/mpdev ~/bin

kubectl create ns test-ns
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml
mpdev install --deployer=$REGISTRY/$SOLUTION/deployer --parameters='{"name": "test-ns", "namespace": "test"}'
```

Now, we need to have access to a CAS root. To create a "root" certificate
authority as well as an intermediate certificate authority ("subordinate")
in your current Google project, run:

```sh
gcloud config set privateca/location us-east1
gcloud beta privateca roots create my-ca --subject="CN=root,O=my-ca"
gcloud beta privateca subordinates create my-sub-ca  --issuer=my-ca --location us-east1 --subject="CN=intermediate,O=my-ca,OU=my-sub-ca"
```

> It is recommended to create subordinate CAs for signing leaf
> certificates. See the [official
> documentation](https://cloud.google.com/certificate-authority-service/docs/creating-certificate-authorities).

At this point, the Kubernetes service account created by `mpdev` still does
not have sufficient privileges in order to access the Google CAS API. We
have to "bind" the Kubernetes service account with a new GCP service
account that will have access to the CAS API.

```sh
gcloud iam service-accounts create sa-google-cas-issuer
gcloud beta privateca subordinates add-iam-policy-binding my-sub-ca \
  --role=roles/privateca.certificateRequester \
  --member=serviceAccount:sa-google-cas-issuer@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com
gcloud iam service-accounts add-iam-policy-binding sa-google-cas-issuer@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$(gcloud config get-value project | tr ':' '/').svc.id.goog[test-ns/test-google-cas-issuer-serviceaccount-name]"
kubectl annotate serviceaccount -n test-ns test-google-cas-issuer-serviceaccount-name \
  iam.gke.io/gcp-service-account=sa-google-cas-issuer@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com
```

You can now create an issuer and a certificate:

```sh
cat <<EOF | tee /dev/stderr | kubectl apply -f -
apiVersion: cas-issuer.jetstack.io/v1alpha1
kind: GoogleCASIssuer
metadata:
  name: googlecasissuer
spec:
  project: $(gcloud config get-value project | tr ':' '/')
  location: $(gcloud config get-value privateca/location | tr ':' '/')
  certificateAuthorityID: my-sub-ca
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: demo-certificate
spec:
  secretName: demo-cert-tls
  commonName: cert-manager.io.demo
  dnsNames:
    - cert-manager.io
    - jetstack.io
  duration: 24h
  renewBefore: 8h
  issuerRef:
    group: cas-issuer.jetstack.io
    kind: GoogleCASIssuer
    name: googlecasissuer
EOF
```

You can check that the certificate has been issued with:

```sh
% kubectl describe cert demo-certificate
Events:
  Type    Reason     Age   From          Message
  ----    ------     ----  ----          -------
  Normal  Issuing    20s   cert-manager  Issuing certificate as Secret was previously issued by GoogleCASIssuer.cas-issuer.jetstack.io/googlecasissuer-sample
  Normal  Reused     20s   cert-manager  Reusing private key stored in existing Secret resource "demo-cert-tls"
  Normal  Requested  20s   cert-manager  Created new CertificateRequest resource "demo-certificate-v2rwr"
  Normal  Issuing    20s   cert-manager  The certificate has been successfully issued
```

## Testing and releasing the deployer using Google Cloud Build

We use `gcloud builds` in order to automate the release process. Cloud
Build re-publishes the cert-manager images to your project and builds,
tests and pushs the deployer image.

Requirements before running `gcloud builds`:

1. You need a GKE cluster with
   [workload-identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
   enabled. You can either update your existing cluster or create a new
   cluster with workload identity enabled with this command:

   ```sh
   export GKE_CLUSTER_NAME=foo
   export GKE_CLUSTER_LOCATION=us-east1
   gcloud container clusters create $GKE_CLUSTER_NAME --region $GKE_CLUSTER_LOCATION --num-nodes=1 --preemptible \
     --workload-pool=$(gcloud config get-value project | tr ':' '/').svc.id.goog
   ```

2. A Google CAS root and subordinate CA as well as a Google service account
   that will be "attached" to the Kubernetes service account that will be
   created by the deployer:

   ```sh
   gcloud beta privateca roots create my-ca --subject="CN=root,O=my-ca"
   gcloud beta privateca subordinates create my-sub-ca  --issuer=my-ca --location us-east1 --subject="CN=intermediate,O=my-ca,OU=my-sub-ca"
   gcloud iam service-accounts create sa-google-cas-issuer
   gcloud beta privateca subordinates add-iam-policy-binding my-sub-ca \
     --role=roles/privateca.certificateRequester \
     --member=serviceAccount:sa-google-cas-issuer@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com
   gcloud iam service-accounts add-iam-policy-binding sa-google-cas-issuer@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com \
     --role roles/iam.workloadIdentityUser \
     --member "serviceAccount:$(gcloud config get-value project | tr ':' '/').svc.id.goog[test-ns/test-google-cas-issuer-serviceaccount-name]"
   ```

   > Note: the last step which is adding the annotation to the
   > google-cas-issuer Kubernetes service account is done in
   > `cloudbuild.yml`. The annotation will look like:
   >
   >  ```yaml
   >  metadata:
   >    annotations:
   >      iam.gke.io/gcp-service-account=sa-google-cas-issuer@PROJECT_ID.iam.gserviceaccount.com
   >  ```

3. Go to [IAM and Admin > Permissions for
   project](https://console.cloud.google.com/iam-admin/iam) and configure
   the `0123456789@cloudbuild.gserviceaccount.com` service account with the
   following roles so that it has permission to deploy RBAC configuration
   to the target cluster and to publish it to a bucket:
   - `Cloud Build Service Agent`
   - `Kubernetes Engine Admin`
   - `Storage Object Admin`

4. Create a bucket that has the same name as your project. To create it,
   run:

   ```sh
   gsutil mb gs://$(gcloud config get-value project | tr ':' '/')
   ```

Then, you can trigger a build:

```sh
gcloud builds submit --timeout 1800s --config cloudbuild.yaml \
  --substitutions _CLUSTER_NAME=$GKE_CLUSTER_NAME,_CLUSTER_LOCATION=$GKE_CLUSTER_LOCATION
```

This will also verify the application using the [Google Cloud Marketplace verification tool](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/c5899a928a2ac8d5022463c82823284a9e63b177/scripts/verify).

## Updating the upstream cert-manager chart version

From
[building-deployer-helm.md](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/building-deployer-helm.md),
bump the version of the cert-manager chart in requirements.yaml. Then:

```sh
helm repo add jetstack https://charts.jetstack.io
helm dependency build chart/jetstacksecure-mp
```

[schema.md]: https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/d9d3a6f/docs/schema.md
[jetstack-secure-for-cert-manager]: https://console.cloud.google.com/partner/editor/jetstack-public/jetstack-secure-for-cert-manager?project=jetstack-public