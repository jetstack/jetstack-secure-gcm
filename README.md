# Jetstack Secure for cert-manager on the Google Cloud Marketplace

## Overview

Jetstack Secure runs inside the Kubernetes clusters and provides higher
levels of control and management around machine identity protection. It
exists to solve real enterprise problems from a lack of control and
visibility of machine identities and how they map to the organisation's
cloud infrastructure. As workloads start to scale, the need for machine
identity management grows.

Jetstack Secure is built on top of cert-manager and uses native integration
with the Kubernetes API to secure workloads between clusters and nodes to
protect from outside malicious intent, and provide real-time visual status
on cluster integrity. cert-manager has become the de facto solution for
issuing and renewing certificates from popular public and private
certificate issuers. Platform operators can provide fast and easy
self-service to development teams, whilst maintaining control and
protection at all times.

Key benefits of Jetstack Secure:

- Builds a detailed view of the security posture using a management UI to
  monitor and manage the TLS certificates assigned to each cluster
- Integrates natively with Kubernetes and OpenShift
- Automates the full X.509 certificate lifecycle
- Prevents certificate-related outages and security breaches
- Modern declarative "as code" configuration and automation
- Ensures workloads comply with corporate security best practice
- Enforces security through continuous monitoring of machine identities

## How it works

A lightweight agent is installed to clusters to observe the status and
health of machine identities, including those that have been manually
created by developers. The web based management interface gives visibility
of these identities and the context such as pod, namespace and cluster, to
quickly identify and troubleshoot misconfigurations that risk operational
and security posture. As the infrastructure scales, Jetstack Secure
provides a rich set of additional tools and support capabilities to give
more effective overall management of clusters.

**Contents:**

- [Overview](#overview)
- [How it works](#how-it-works)
- [CLI installation](#cli-installation)
  - [Quick install with Google Cloud Marketplace](#quick-install-with-google-cloud-marketplace)
  - [Command line instructions](#command-line-instructions)
    - [Prerequisites](#prerequisites)
      - [Set up command line tools](#set-up-command-line-tools)
      - [Create a Google Kubernetes Engine cluster](#create-a-google-kubernetes-engine-cluster)
      - [Configure kubectl to connect to the cluster](#configure-kubectl-to-connect-to-the-cluster)
      - [Clone this repo](#clone-this-repo)
      - [Install the Application resource definition](#install-the-application-resource-definition)
    - [Install the application](#install-the-application)
      - [Configure the application with environment variables](#configure-the-application-with-environment-variables)
    - [Download and apply the license](#download-and-apply-the-license)
    - [Expand the manifest template](#expand-the-manifest-template)
      - [Apply the manifest to your Kubernetes cluster](#apply-the-manifest-to-your-kubernetes-cluster)
      - [View the app in the Google Cloud Console](#view-the-app-in-the-google-cloud-console)

## CLI installation

### Quick install with Google Cloud Marketplace

Get up and running with a few clicks! Install the Jetstack Secure for
cert-manager application to a Google Kubernetes Engine cluster using Google
Cloud Marketplace. Follow the [on-screen
instructions](https://console.cloud.google.com/marketplace/details/jetstack/jetstack-secure-for-cert-manager).

### Command line instructions

You can use [Google Cloud Shell](https://cloud.google.com/shell/) or a
local workstation to complete these steps.

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/jetstack/jetstack-secure-gcm&cloudshell_working_dir=/)

#### Prerequisites

##### Set up command line tools

You'll need the following tools in your environment. If you are using Cloud Shell, these tools are installed in your environment by default.

- [gcloud](https://cloud.google.com/sdk/gcloud/)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [docker](https://docs.docker.com/install/)
- [openssl](https://www.openssl.org/)
- [helm](https://helm.sh/docs/using_helm/#installing-helm)
- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)

Configure `gcloud` as a Docker credential helper:

```sh
gcloud auth configure-docker
```

##### Create a Google Kubernetes Engine cluster

The [workload
identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
must be enabled on your cluster. To create a cluster that has _workload
identity_ feature enabled, run the following command:

```sh
export CLUSTER=jetstack-cluster
export ZONE=europe-west1-c

gcloud container clusters create $CLUSTER --zone $ZONE \
  --workload-pool=$(gcloud config get-value project | tr ':' '/').svc.id.goog
```

> For an existing cluster, you can turn the feature on (will restart the
> GKE control plane) with the following command:
>
> ```sh
> gcloud container clusters update $CLUSTER --zone $ZONE \
>   --workload-pool=$(gcloud config get-value project | tr ':' '/').svc.id.goog
> ```

##### Configure kubectl to connect to the cluster

```sh
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE"
```

##### Clone this repo

Clone this repo and the associated tools repo:

```shell
git clone https://github.com/jetstack/jetstack-secure-gcm
cd jetstack-secure-gcm
```

##### Install the Application resource definition

An Application resource is a collection of individual Kubernetes
components, such as Services, Deployments, and so on, that you can manage
as a group.

To set up your cluster to understand Application resources, run the
following command:

```sh
kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
```

You need to run this command once for each cluster.

The Application resource is defined by the [Kubernetes
SIG-apps](https://github.com/kubernetes/community/tree/master/sig-apps)
community. The source code can be found on
[github.com/kubernetes-sigs/application](https://github.com/kubernetes-sigs/application).

#### Install the application

##### Configure the application with environment variables

Choose an instance name and
[namespace](https://kubernetes.io/docs/concepts/overview/working-with-objects/namespaces/)
for the application.

```shell
APP_INSTANCE_NAME=jetstack-secure-1
NAMESPACE=jetstack-secure
```

Create the namespace:

```sh
kubectl create namespace $NAMESPACE
```

Set up the image tag, for example:

```shell
TAG="1.1.0-gcm.1"
```

where `1.1.0` stands for the cert-manager version, and `gcm.1` is the
Google Marketplace "build" version.

> Note: the upstream cert-mananger images are re-built with a
> `/LICENSES.txt` file as well as re-tagged with the Marketplace versioning
> described above, e.g. `1.1.0-gcm.1`. This was done in order to order to
> abide by the
> [schema.md](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/d9d3a6f/docs/schema.md)
> rules, which states that "when users deploy the app from the Google Cloud
> Marketplace, the final image names may be different, but they will follow
> the same release tag and name prefix rule."

#### Download and apply the license

Click the "Generate license key". This will download a `license.yaml` file
to your disk.

<img src="https://user-images.githubusercontent.com/2195781/108194095-7de04100-7116-11eb-8bd5-fa11c4fbbcf5.png" width="500" alt="this screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

Then, add the license to your cluster:

```sh
kubectl apply -n $NAMESPACE -f license.yaml
```

#### Expand the manifest template

Use `helm template` to expand the template. We recommend that you save the
expanded manifest file for future updates to the application.

```shell
helm template "$APP_INSTANCE_NAME" chart/jetstack-secure-gcm \
  --namespace "$NAMESPACE" \
  --set cert-manager.global.rbac.create=true \
  --set cert-manager.serviceAccount.create=true \
  --set cert-manager.image.tag="$TAG" \
  --set cert-manager.acmesolver.image.tag="$TAG" \
  --set cert-manager.webhook.image.tag="$TAG" \
  --set cert-manager.webhook.serviceAccount.create=true \
  --set cert-manager.cainjector.image.tag="$TAG" \
  --set cert-manager.cainjector.serviceAccount.create=true \
  --set google-cas-issuer.image.tag="$TAG" \
  --set google-cas-issuer.serviceAccount.create=true \
  --set google-cas-issuer.serviceAccount.name=google-cas-issuer \
  --set preflight.image.tag="$TAG" \
  --set preflight.serviceAccount.create=true \
  --set preflight.rbac.create=true \
  --set ubbagent.image.tag="$TAG" \
  --set ubbagent.reportingSecretName=$APP_INSTANCE_NAME-license \
  > "${APP_INSTANCE_NAME}_manifest.yaml"
```

> Note: you can also change the default repository values, e.g., with:
>
> ```sh
> --set cert-manager.image.repository=marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager
> --set cert-manager.acmesolver.image.repository=marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-acmesolver
> --set cert-manager.cainjector.image.repository=marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-cainjector
> --set cert-manager.webhook.image.repository=marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook
> --set google-cas-issuer.image.repository=marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-google-cas-issuer
> --set preflight.image.repository=marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/preflight
> --set ubbagent.image.repository=marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/ubbagent
> ```

##### Apply the manifest to your Kubernetes cluster

Use `kubectl` to apply the manifest to your Kubernetes cluster:

```shell
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml"
```

##### View the app in the Google Cloud Console

To get the GCP Console URL for your app, run the following command:

```shell
echo "https://console.cloud.google.com/kubernetes/application/${ZONE}/${CLUSTER}/${NAMESPACE}/${APP_INSTANCE_NAME}"
```

To view the app, open the URL in your browser.

Optionally, you can also:

- Enable the Jetstack Secure web dashboard by following the steps
  [here](https://jetstack.io/jetstack-secure/google-cloud-marketplace#step-2-log-into-the-jetstack-secure-dashboard),
- Set up the Google Certificate Authority Service by following the steps
  [here](https://jetstack.io/jetstack-secure/google-cloud-marketplace#step-3-optional-set-up-the-google-certificate-authority-service).
