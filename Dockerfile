# This Dockerfile allows us to create a "deployer" image. The deployer
# image, using this "ombuild" base image, will contain our Marketplace
# application's Helm chart and will be in charge of doing the "helm install"
# (which is the only thing the deployer image ever does).
#
# See:
# https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/4335f9/docs/building-deployer-helm.md#build-your-deployer-container

FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm/onbuild

# The schema,yaml and chart/ have already been added thanks to the
# "onbuild" Dockerfile:
# https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/4335f9/marketplace/deployer_helm_base/onbuild/Dockerfile#L4-L12
#
# Since the deployer image must only contain compressed charts, i.e.,
# chart/chart.tar.gz (which is created by the "onbuild" Docker image), and
# a data-test/chart/chart.tar.gz. That is why we need to tar the chart in
# data-test.
COPY data-test/schema.yaml /data-test/schema.yaml
COPY data-test/chart /tmp/data-test/chart.tmp
RUN cd /tmp/data-test \
        && mv chart.tmp/* chart \
        && tar -czvf /tmp/data-test/chart.tar.gz chart \
        && mv chart.tar.gz /data-test/chart/

# If you wonder what magic is this, take a look at:
# https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/4335f9/marketplace/deployer_helm_base/onbuild/Dockerfile#L16-L20
