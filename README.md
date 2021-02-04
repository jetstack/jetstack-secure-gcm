
# jsp-gcm

**Content:**

- [Installing and testing manually the deployer](#installing-and-testing-manually-the-deployer)
- [Testing and releasing the deployer using Google Cloud Build](#testing-and-releasing-the-deployer-using-google-cloud-build)
- [Updating the upstream cert-manager chart version](#updating-the-upstream-cert-manager-chart-version)

## Installing and testing manually the deployer

In order to have the google-cas-issuer working, we need to enable [workload
identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity).
Let's create a cluster that has the workload identity enabled:

```sh
gcloud container clusters create foo --region us-east1 --num-nodes=1 --preemptible \
  --workload-pool=$(gcloud config get-value project | tr ':' '/').svc.id.goog
```

Re-publish the images to the project:

```sh
export REGISTRY=gcr.io/$(gcloud config get-value project | tr ':' '/')
export APP_NAME=jetstack-secure
docker pull quay.io/jetstack/cert-manager-controller:v1.1.0
docker pull quay.io/jetstack/cert-manager-cainjector:v1.1.0
docker pull quay.io/jetstack/cert-manager-webhook:v1.1.0
docker pull quay.io/jetstack/cert-manager-google-cas-issuer:0.1.0
docker tag quay.io/jetstack/cert-manager-controller:v1.1.0 $REGISTRY/$APP_NAME/cert-manager-controller:1.1.0
docker tag quay.io/jetstack/cert-manager-cainjector:v1.1.0 $REGISTRY/$APP_NAME/cert-manager-cainjector:1.1.0
docker tag quay.io/jetstack/cert-manager-webhook:v1.1.0 $REGISTRY/$APP_NAME/cert-manager-webhook:1.1.0
docker tag quay.io/jetstack/cert-manager-google-cas-issuer:latest $REGISTRY/$APP_NAME/cert-manager-google-cas-issuer:0.1.0
docker push $REGISTRY/$APP_NAME/cert-manager-controller:1.1.0
docker push $REGISTRY/$APP_NAME/cert-manager-cainjector:1.1.0
docker push $REGISTRY/$APP_NAME/cert-manager-webhook:1.1.0
docker push $REGISTRY/$APP_NAME/cert-manager-google-cas-issuer:0.1.0
```

> Note: although cert-manager's tags are of the form "v1.1.0", we chose to
> use tags of the form "1.1.0" for the Google Marketplace for the sake of
> consistency.

Then, build and push the deployer image:

```sh
docker build --tag $REGISTRY/$APP_NAME/deployer .
docker push $REGISTRY/$APP_NAME/deployer
```

Finally, use `mpdev` to install jetstack-secure to the `test-ns` namespace:

```sh
# If you don't have it already, install mpdev:
docker run gcr.io/cloud-marketplace-tools/k8s/dev cat /scripts/dev > /tmp/mpdev && install /tmp/mpdev ~/bin

kubectl create ns test-ns
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml
mpdev install --deployer=$REGISTRY/$APP_NAME/deployer --parameters='{"name": "test-ns", "namespace": "test"}'
```

Now, we need to have access to a CAS root. To create a "root" certificate
authority as well as an intermediate certificate authority ("subordinate")
in your current Google project, run:

```sh
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

1. a GCP account with [workload-identity][] enabled. To create a project
   with workload identity enabled, you can run:

   ```sh
   export GKE_CLUSTER_NAME=foo
   export GKE_CLUSTER_LOCATION=us-east1
   gcloud container clusters create $GKE_CLUSTER_NAME --region $GKE_CLUSTER_LOCATION --num-nodes=1 --preemptible \
     --workload-pool=$(gcloud config get-value project | tr ':' '/').svc.id.goog
   ```

2. Go to [IAM and Admin > Permissions for
   project](https://console.cloud.google.com/iam-admin/iam) and configure
   the `0123456789@cloudbuild.gserviceaccount.com` service account with the
   following roles so that it has permission to deploy RBAC configuration
   to the target cluster and to publish it to a bucket:
   - `Cloud Build Service Agent`
   - `Kubernetes Engine Admin`
   - `Storage Object Admin`

3. Create a bucket that has the same name as your project. To create it,
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

[workload-identity]: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity

## Updating the upstream cert-manager chart version

From
[building-deployer-helm.md](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/building-deployer-helm.md),
bump the version of the cert-manager chart in requirements.yaml. Then:

```sh
helm repo add jetstack https://charts.jetstack.io
helm dependency build chart/jetstacksecure-mp
```
