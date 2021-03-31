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
- [Click-to-deploy installation](#click-to-deploy-installation)
  - [Step 1: Install Jestack Secure for cert-manager](#step-1-install-jestack-secure-for-cert-manager)
  - [Step 2: log into the Jetstack Secure dashboard](#step-2-log-into-the-jetstack-secure-dashboard)
  - [Step 3 (optional): set up the Google Certificate Authority Service](#step-3-optional-set-up-the-google-certificate-authority-service)
- [CLI installation](#cli-installation)
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

## Click-to-deploy installation

This guide describes how to install Jetstack Secure for cert-manager via
the Google Cloud Marketplace web UI. Alternatively, you can follow the [CLI
installation instructions](#cli-installation).

### Step 1: Install Jestack Secure for cert-manager

Head over to the [Jetstack Secure for
cert-manager](https://console.cloud.google.com/marketplace/details/jetstack-public/jetstack-secure-for-cert-manager)
solution page on the Google Cloud Marketplace. Click "Configure":

<img src="https://user-images.githubusercontent.com/2195781/109154707-f5dde500-776e-11eb-8bc6-caf97fcecba2.png" width="600px" alt="The Jetstack Secure for cert-manager solution landing page on the Google Cloud Marketplace. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

On the next screen, you will be asked to either select an existing cluster
or create a new one, as well as choosing the Kubernetes namespace in which
the application will be created in.

Note that this application is not meant to be running on multiple instances
on the same cluster. Before installing the application on a cluster, make
sure that no other instance of Jetstack Secure for cert-manager is
running on that cluster.

We recommend avoiding installing Jetstack Secure for cert-manager in the
`default` namespace. Prefer using a different namespace name such as
`jetstack-secure`.

Regarding the App instance name, we recommend using an application name
such as `jetstack-secure`. This app instance name will appear as a prefix
of all the Kubernetes objects.

The remaining of the settings can be left to their default values.

When you are done, click the "Deploy" button:

<img src="https://user-images.githubusercontent.com/2195781/109023553-31b87200-76bd-11eb-8fc4-a9e46ae44582.png" width="600px" alt="this screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

This will install Jetstack Secure for cert-manager, and will redirect to
the [Applications](https://console.cloud.google.com/kubernetes/application) page:

<img src="https://user-images.githubusercontent.com/2195781/110795922-a96acd00-8277-11eb-959e-bf7ea51ae992.png" width="500" alt="The application page for test-1 shows that all the deployments are green. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

**Note:** by default, the `preflight` deployment is scaled to 0. After
completing the steps in the [next
section](#step-2-log-into-the-jetstack-secure-dashboard), the deployment will
start working.

### Step 2: log into the Jetstack Secure dashboard

Head to <https://platform.jetstack.io> and click on the "Getting started"
button:

<img src="https://user-images.githubusercontent.com/2195781/109153986-f3c75680-776d-11eb-964f-589cdf4bf2a1.png" width="600px" alt="The Jetstack Secure platform landing page. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

You will be prompted to log in. If you do not already have an account, you
will be able to create one:

<img src="https://user-images.githubusercontent.com/2195781/109153999-f7f37400-776d-11eb-9042-fb34a2e8accc.png" width="600px" alt="The Jetstack Secure login page. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

Then, click on the "Machine Identity" icon _(1)_ and click the "Add
cluster" button _(2)_:

<img src="https://user-images.githubusercontent.com/2195781/109025110-ba83dd80-76be-11eb-9815-c91408c0096a.png" width="600px" alt="Create cluster button. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

Choose a name for your cluster. This name is not related to the Google
Kubernetes Engine cluster you selected when you deployed the application.
This name is only used to show your cluster in the Jetstack Secure
dashboard.

After picking a name, click on the check mark:

<img src="https://user-images.githubusercontent.com/2195781/109155511-ec08b180-776f-11eb-82e1-45b0c32720d6.png" width="600px" alt="Choose your cluster name and click the check mark button. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

Next, click the button "Copy command to clipboard":

<img src="https://user-images.githubusercontent.com/2195781/109026248-d76ce080-76bf-11eb-94be-bc1c8f54b2cf.png" width="600px" alt="Click the button 'Copy command to clipboard'. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

With the help of a text editor, paste the content and edit it:

1. remove the 6 first lines,
2. remove the last line.

<img src="https://user-images.githubusercontent.com/2195781/109153775-a21ecc00-776d-11eb-89d0-6beea71c7c07.png" width="600px" alt="Click the button 'Open a text editor and change a few lines from the configmap and secret. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

After having removed the above lines, save the content as a file on your
disk. You can call it `agent-config.yaml`.

For the next step, make sure you have the following information available
to you:

- The **namespace** and **cluster name** on which you installed the
  application. If you are not sure about this, you can open the
  [Applications](https://console.cloud.google.com/kubernetes/application)
  page:

  <img src="https://user-images.githubusercontent.com/2195781/109160123-ad75f580-7775-11eb-9da6-2b912ab3de96.png" width="600px" alt="Grab the namespace and cluster name on the  applications page in the Google Kubernetes Engine console. this screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

- The **location** of the cluster in which you installed the application;
  if you are not sure about this, you can open the
  [Applications](https://console.cloud.google.com/kubernetes/application)
  page and click on the name of the cluster:

  <img src="https://user-images.githubusercontent.com/2195781/109160131-af3fb900-7775-11eb-9a46-c1bcebdf8315.png" width="600px" alt="Click on the cluster name on the applications page in the Google Kubernetes Engine console. this screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

  <img src="https://user-images.githubusercontent.com/2195781/109160135-afd84f80-7775-11eb-9f74-0847413cab7f.png" width="600px" alt="Grab the cluster location on the GKE console page of your GKE cluster. this screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

The next steps require to have a terminal open as well as to have the
[gcloud](https://cloud.google.com/sdk/docs/install) and
[kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) tools
installed.

In the terminal window, set the variables from the information we gathrered
in the previous step:

```sh
CLUSTER=foobar
LOCATION=us-east1-b
NAMESPACE=jetstack-secure
```

The next step will make sure `kubectl` can connect to your cluster:

```sh
gcloud auth login
gcloud container clusters get-credentials --zone=$LOCATION $CLUSTER
```

You will now be able to "activate" the Preflight deployment:

```sh
kubectl -n $NAMESPACE scale deploy --replicas=1 --selector=app.kubernetes.io/component=preflight
```

You can then apply the Jetstack Secure agent configuration to your cluster:

```sh
sed '/namespace:/d' agent-config.yaml | kubectl -n $NAMESPACE apply -f-
kubectl -n $NAMESPACE rollout restart $(kubectl -n $NAMESPACE get deploy -oname | grep preflight)
```

You may skip over the "Install agent" section:

# <img src="https://user-images.githubusercontent.com/2195781/109156989-cb415b80-7771-11eb-910c-de247ad67ac2.png" width="600px" alt="Clicking on 'The agent is ready', you should see a green check mark. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

After skipping the "Install agent" section, follow the instructions in the
"Check the agent is running" section.

Here is the command shown in the below screenshot that you can copy-paste
for your convenience:

```sh
kubectl -n $NAMESPACE get pod -l app.kubernetes.io/name=preflight
```

<img src="https://user-images.githubusercontent.com/2195781/109156984-ca102e80-7771-11eb-9087-56c2b2781108.png" width="600px" alt="Use kubectl to check that the pod is ready. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

You should eventually see that the pod is `READY 1/1`:

```sh
% kubectl -n $NAMESPACE get pod -l app.kubernetes.io/name=preflight
NAME                                         READY   STATUS     AGE
jetstack-secure-preflight-6b8d5ccb6f-6gnjm   1/1     Running    20h
```

After seeing `READY 1/1`, you can click on "The agent is ready":

<img src="https://user-images.githubusercontent.com/2195781/109156661-638b1080-7771-11eb-8ee1-da578d915156.png" width="600px" alt="Clicking on 'The agent is ready'. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

A few seconds later, a green mark will appear:

<img src="https://user-images.githubusercontent.com/2195781/109036926-6b43aa00-76ca-11eb-9649-d3c4e5ac71db.png" width="600px" alt="After clicking on 'The agent is ready', you should see a green check mark. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

You can now click on "View clusters" to monitor your certificates. The
documentation about the Jetstack Secure platform is available at
<https://platform.jetstack.io/docs>.

Let us try with an example. We can create a self-signed issuer and sign a
certificate that only lasts for 30 days:

```sh
kubectl apply -f- <<EOF
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: example-selfsigned-issuer
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: example-cert
spec:
  duration: 721h # very short time to live
  secretName: example-cert-tls
  commonName: example-cert
  dnsNames:
  - example.com
  issuerRef:
    name: example-selfsigned-issuer
    kind: Issuer
EOF
```

A few seconds later, you will see the certificate `example-cert` appear in
the Jetstack Secure Platform UI:

<img src="https://user-images.githubusercontent.com/2195781/110807883-bf7e8a80-8283-11eb-9d0d-57be5c063d3d.png" width="500" alt="The certificate example-cert shows in the UI at platform.jetstack.io. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

### Step 3 (optional): set up the Google Certificate Authority Service

[Google Certificate Authority Service][google-cas] is a highly available,
scalable Google Cloud service that enables you to simplify, automate, and
customize the deployment, management, and security of private certificate
authorities (CA).

If you wish to use [Google Certificate Authority Service][google-cas] to issue
certificates, you can create a root certificate authority and a subordinate
certificate authority (i.e., an intermediate CA) on your Google Cloud project.
To create a root and a subordinate CA, please follow the [official
documentation](https://cloud.google.com/certificate-authority-service/docs/creating-certificate-authorities).

[google-cas]: https://cloud.google.com/certificate-authority-service/

After creating the root and subordinate, set the following variable with
the subordinate name:

```sh
LOCATION=europe-west1
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
# The app instance name is the name of the application you created. If you
# forgot which name you gave to your application, take a look at:
# https://console.cloud.google.com/kubernetes/application.
APP_INSTANCE_NAME=some-name

# This is the namespace in which the application has been deployed.
NAMESPACE=some-namespace

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

## CLI installation

You can use [Google Cloud Shell](https://cloud.google.com/shell/) or a
local workstation to complete these steps.

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/jetstack/jetstack-secure-gcm&cloudshell_working_dir=/)

### Prerequisites

#### Set up command line tools

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

#### Create a Google Kubernetes Engine cluster

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

#### Configure kubectl to connect to the cluster

```sh
gcloud container clusters get-credentials "$CLUSTER" --zone "$ZONE"
```

#### Clone this repo

Clone this repo and the associated tools repo:

```shell
git clone https://github.com/jetstack/jetstack-secure-gcm
cd jetstack-secure-gcm
```

#### Install the Application resource definition

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

### Install the application

#### Configure the application with environment variables

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

### Download and apply the license

Click the "Generate license key". This will download a `license.yaml` file
to your disk.

<img src="https://user-images.githubusercontent.com/2195781/108194095-7de04100-7116-11eb-8bd5-fa11c4fbbcf5.png" width="500" alt="this screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

Then, add the license to your cluster:

```sh
kubectl apply -n $NAMESPACE -f license.yaml
```

### Expand the manifest template

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
  --set cert-manager.ubbagent.image.tag="$TAG" \
  --set cert-manager.ubbagent.reportingSecretName=$APP_INSTANCE_NAME-license \
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
> --set cert-manager.ubbagent.image.repository=marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/ubbagent
> ```

#### Apply the manifest to your Kubernetes cluster

Use `kubectl` to apply the manifest to your Kubernetes cluster:

```shell
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml"
```

#### View the app in the Google Cloud Console

To get the GCP Console URL for your app, run the following command:

```shell
echo "https://console.cloud.google.com/kubernetes/application/${ZONE}/${CLUSTER}/${NAMESPACE}/${APP_INSTANCE_NAME}"
```

To view the app, open the URL in your browser.

Optionally, you can also:

- Enable the Jetstack Secure web dashboard by following the steps
  [here](#step-2-log-into-the-jetstack-secure-dashboard),
- Set up the Google Certificate Authority Service by following the steps
  [here](#step-3-optional-set-up-the-google-certificate-authority-service).
