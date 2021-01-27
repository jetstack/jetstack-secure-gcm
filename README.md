
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
