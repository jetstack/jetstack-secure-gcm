
# jsp-gcm

# deployer

## Update upstream cert-manager chart version

From
[building-deployer-helm.md](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/building-deployer-helm.md),
bump the version of the cert-manager chart in requirements.yaml. Then:

```sh
helm repo add jetstack https://charts.jetstack.io
helm dependency build chart/jetstacksecure-mp
```

## Installing manually

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

Finally, use `mpdev` to install jetstack-secure to the `test` namespace:

```sh
# If you don't have it already, install mpdev:
docker run gcr.io/cloud-marketplace-tools/k8s/dev cat /scripts/dev > /tmp/mpdev && install /tmp/mpdev ~/bin

kubectl create ns test
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml
mpdev install --deployer=$REGISTRY/$APP_NAME/deployer --parameters='{"name": "test", "namespace": "test"}'
```

## Releasing using Google Cloud Build

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