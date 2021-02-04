# This Dockerfile allows us to create a "deployer" image. The deployer
# image, using this "ombuild" base image, will contain our Marketplace
# application's Helm chart and will in charge of doing the "helm install"
# (which is the only thing the deployer image ever does).
#
# See:
# https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/building-deployer-helm.md#build-your-deployer-container
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild
