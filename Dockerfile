# This Dockerfile allows us to create a "deployer" image. The deployer
# image, using this "ombuild" base image, will contain our Marketplace
# application's Helm chart and will in charge of doing the "helm install"
# (which is the only thing the deployer image ever does).
#
# See:
# https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/4335f9/docs/building-deployer-helm.md#build-your-deployer-container

FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild

COPY data-test/ /data-test/

# If you wonder what magic is this, take a look at:
# https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/4335f9/marketplace/deployer_helm_base/onbuild/Dockerfile#L16-L20
