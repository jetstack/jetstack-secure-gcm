
# jsp-gcm
=======

# deployer

## Update upstream cert-manager chart version

From
[building-deployer-helm.md](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/building-deployer-helm.md),
bump the version of the cert-manager chart in requirements.yaml. Then:

```sh
helm repo add jetstack https://charts.jetstack.io
helm dependency build chart/jetstacksecure-mp
```

=======
## Test

```sh
export REGISTRY=gcr.io/$(gcloud config get-value project | tr ':' '/')
export APP_NAME=jetstack-secure

docker pull quay.io/jetstack/cert-manager-controller:v1.1.0
docker pull quay.io/jetstack/cert-manager-cainjector:v1.1.0
docker pull quay.io/jetstack/cert-manager-webhook:v1.1.0
docker tag quay.io/jetstack/cert-manager-controller:v1.1.0 $REGISTRY/$APP_NAME/cert-manager-controller:v1.1.0
docker tag quay.io/jetstack/cert-manager-cainjector:v1.1.0 $REGISTRY/$APP_NAME/cert-manager-cainjector:v1.1.0
docker tag quay.io/jetstack/cert-manager-webhook:v1.1.0 $REGISTRY/$APP_NAME/cert-manager-webhook:v1.1.0
docker push $REGISTRY/$APP_NAME/cert-manager-controller:v1.1.0
docker push $REGISTRY/$APP_NAME/cert-manager-cainjector:v1.1.0
docker push $REGISTRY/$APP_NAME/cert-manager-webhook:v1.1.0


# Install mpdev:
docker run gcr.io/cloud-marketplace-tools/k8s/dev cat /scripts/dev > /tmp/mpdev && install /tmp/mpdev ~/bin

kubectl create namespace test
docker build --tag $REGISTRY/$APP_NAME/deployer .
docker push $REGISTRY/$APP_NAME/deployer
mpdev install --deployer=$REGISTRY/$APP_NAME/deployer --parameters='{"name": "test", "namespace": "test"}'
```

## Google Cloud Build

You can deploy the Google Market Place images and the deployer to `gcr.io/<PROJECT>/cert-manager` using `gcloud builds` as follows:

```
gcloud builds submit  --timeout 1800s --config cloudbuild.yaml \
  --substitutions _CLUSTER_NAME=$GKE_CLUSTER_NAME,_CLUSTER_LOCATION=$GKE_CLUSTER_LOCATION 
```

This will also verify the application using the [Google Cloud Marketplace verification tool](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/c5899a928a2ac8d5022463c82823284a9e63b177/scripts/verify).

NB: Configure the `?????@cloudbuild.gserviceaccount.com` with the roles: `Cloud Build Service Agent` and `Kubernetes Engine Admin` so that it has permission to deploy RBAC configuration to the target cluster. 
See: [IAM and Admin > Permissions for project](https://console.cloud.google.com/iam-admin/iam) on Google Cloud Consol.
