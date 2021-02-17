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
- [Installation](#installation)
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
      - [(optional) Enable the Jetstack Secure web dashboard](#optional-enable-the-jetstack-secure-web-dashboard)
      - [(optional) Set up the Google Certificate Authority Service](#optional-set-up-the-google-certificate-authority-service)

## Installation

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

<!--
The following screenshot is stored in this issue:
https://github.com/jetstack/jetstack-secure-gcm/issues/21
-->

<img src="https://user-images.githubusercontent.com/2195781/108194095-7de04100-7116-11eb-8bd5-fa11c4fbbcf5.png" width="500">

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

##### (optional) Enable the Jetstack Secure web dashboard

This will allow you to vizualize the certificates in your cluster. By
default, the Jetstack Secure agent is installed without configuration. To
set it up, please follow these steps:

1. Create an account on the Jetstack Secure Platform at
   <https://platform.jetstack.io>
2. Click the "Machine Identity" button in the tool bar on the left
3. Click "ADD CLUSTER"
4. Follow the instructions
5. Click "COPY COMMAND TO CLIPBOARD" to copy the credentials and configuration command to the clipboard
6. Paste the command into a text editor and change the namespace to match `$NAMESPACE`
7. Execute the command in your terminal

##### (optional) Set up the Google Certificate Authority Service

[Google Certificate Authority Service][] is a highly available, scalable Google Cloud
service that enables you to simplify, automate, and customize the
deployment, management, and security of private certificate authorities
(CA).

[Google Certificate Authority Service]: https://cloud.google.com/certificate-authority-service/

If you wish to use [Google Certificate Authority
Service](https://cloud.google.com/certificate-authority-service) to issue
certificates, you can create a root certificate authority and a subordinate
certificate authority (i.e., an intermediate CA) on your Google Cloud
project. To create a root and a subordinate CA, please follow the [official
documentation](https://cloud.google.com/certificate-authority-service/docs/creating-certificate-authorities).

After creating the root and subordinate, set the following variable with
the subordinate name:

```sh
SUBORDINATE=example-ca-1
```

> Note that you can list your current subordinate CAs with the following
> command:
>
> ```sh
> % gcloud beta privateca subordinates list
> NAME          LOCATION      STATE         NOT_BEFORE         NOT_AFTER
> example-ca-1  europe-west1  ENABLED       2021-02-02T11:41Z  2024-02-03T05:08Z
> ```

The next step is to create a Google service account that will be used by
the application in order to reach the Google Certificate Authority Service
API:

```sh
gcloud iam service-accounts create $APP_INSTANCE_NAME
```

Give the Google service account the permission to issue certificates using
the Google CAS API:

```sh
gcloud beta privateca subordinates add-iam-policy-binding $SUBORDINATE \
  --role=roles/privateca.certificateRequester \
  --member=serviceAccount:$APP_INSTANCE_NAME@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com
```

Finally, bind this Google service account to the Kubernetes service account
that was created by the above `kubectl apply` command. To bind them, run
the following:

```sh
gcloud iam service-accounts add-iam-policy-binding $APP_INSTANCE_NAME@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$(gcloud config get-value project | tr ':' '/').svc.id.goog[$NAMESPACE/google-cas-issuer]"
```

You can now create a cert-manager Google CAS issuer and have a certificate
issued with the following:

```sh
cat <<EOF | tee /dev/stderr | kubectl apply -f -
apiVersion: cas-issuer.jetstack.io/v1alpha1
kind: GoogleCASIssuer
metadata:
  name: googlecasissuer
spec:
  project: $(gcloud config get-value project | tr ':' '/')
  location: $LOCATION
  certificateAuthorityID: $SUBORDINATE
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: demo-certificate
spec:
  secretName: demo-cert-tls
  commonName: example.com
  dnsNames:
    - example.com
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
