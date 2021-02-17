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
    - [Expand the manifest template](#expand-the-manifest-template)
      - [Apply the manifest to your Kubernetes cluster](#apply-the-manifest-to-your-kubernetes-cluster)
      - [View the app in the Google Cloud Console](#view-the-app-in-the-google-cloud-console)
      - [(optional) Set up the Google Certificate Authority Service](#optional-set-up-the-google-certificate-authority-service)
- [Technical considerations](#technical-considerations)
- [Installing and manually testing the deployer](#installing-and-manually-testing-the-deployer)
- [Testing and releasing the deployer using Google Cloud Build](#testing-and-releasing-the-deployer-using-google-cloud-build)
  - [Debugging deployer and smoke-tests when run in Cloud Build](#debugging-deployer-and-smoke-tests-when-run-in-cloud-build)
- [Updating the upstream cert-manager chart version](#updating-the-upstream-cert-manager-chart-version)

## Installation

### Quick install with Google Cloud Marketplace

Get up and running with a few clicks! Install the Jetstack Secure for
cert-manager application to a Google Kubernetes Engine cluster using Google
Cloud Marketplace. Follow the [on-screen
instructions](https://console.cloud.google.com/marketplace/details/jetstack/jetstack-secure-for-cert-manager).

### Command line instructions

You can use [Google Cloud Shell](https://cloud.google.com/shell/) or a
local workstation to complete these steps.

[![Open in Cloud Shell](http://gstatic.com/cloudssh/images/open-btn.svg)](https://console.cloud.google.com/cloudshell/editor?cloudshell_git_repo=https://github.com/jetstack/jsp-gcm&cloudshell_working_dir=/)

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
git clone https://github.com/jetstack/jsp-gcm
cd jsp-gcm
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
for the application. In most cases, you can use the `default` namespace.

```shell
APP_INSTANCE_NAME=jetstack-secure-1
NAMESPACE=default
```

Set up the image tag, for example:

```shell
TAG="1.1.0-gcm.1"
```

where `1.1.0` stands for the cert-manager version, and `gcm.1` is the
Google Marketplace "build" version. The available types of tags are:

```sh
TAG=1.1.0-gcm.1        # stable tag (recommended)
TAG=1.1.0              # moving tag, targets cert-manager 1.1.0
TAG=1.1                # moving tag, targets cert-manager 1.1
```

The available tags are listed on the [Marketplace Container
Registry](marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager).

#### Expand the manifest template

Use `helm template` to expand the template. We recommend that you save the
expanded manifest file for future updates to the application.

```shell
helm template "$APP_INSTANCE_NAME" chart/jetstacksecure-mp \
  --namespace "$NAMESPACE" \
  --set cert-manager.image.repository="$TAG"
  --set cert-manager.webhook.image.repository="$TAG"
  --set cert-manager.acmesolver.image.repository="$TAG"
  --set cert-manager.cainjector.image.repository="$TAG"
  --set google-cas-issuer.image.repository="$TAG"
  --set preflight.image.repository="$TAG"
  --set ubbagent.image.repository="$TAG"
  --set google-cas-issuer.serviceAccount.create=true
  --set google-cas-issuer.serviceAccount.name=google-cas-issuer-sa
  > "${APP_INSTANCE_NAME}_manifest.yaml"
```

##### Apply the manifest to your Kubernetes cluster

Use `kubectl` to apply the manifest to your Kubernetes cluster:

```shell
kubectl apply -f "${APP_INSTANCE_NAME}_manifest.yaml" --namespace "${NAMESPACE}"
```

##### View the app in the Google Cloud Console

To get the GCP Console URL for your app, run the following command:

```shell
echo "https://console.cloud.google.com/kubernetes/application/${ZONE}/${CLUSTER}/${NAMESPACE}/${APP_INSTANCE_NAME}"
```

To view the app, open the URL in your browser.

##### (optional) Set up the Google Certificate Authority Service

The Certificate Authority Service is a highly available, scalable Google Cloud
service that enables you to simplify, automate, and customize the
deployment, management, and security of private certificate authorities
(CA).

If you wish to use [Google Certificate Authority
Service](https://cloud.google.com/certificate-authority-service) to issue
certificates, you can create a root certificate authority and a subordinate
certificate authority (i.e., an intermediate CA) on your Google Cloud
project with the following:

```sh
gcloud beta privateca roots create my-ca --location $LOCATION --subject="CN=root,O=my-ca"
gcloud beta privateca subordinates create my-sub-ca  --issuer=my-ca --location $LOCATION --subject="CN=intermediate,O=my-ca,OU=my-sub-ca"
```

Note that it is
[recommended](https://cloud.google.com/certificate-authority-service/docs/creating-certificate-authorities)
to create a subordinate CA for signing leaf certificates as opposed to
using a root CA directly.

The next step is to create a Google service account that will be used by
the application in order to reach the Google Certificate Authority Service
API:

```sh
gcloud iam service-accounts create $APP_INSTANCE_NAME
```

Give the Google service account the permission to issue certificates using
the Google CAS API:

```sh
gcloud beta privateca subordinates add-iam-policy-binding my-sub-ca \
  --role=roles/privateca.certificateRequester \
  --member=serviceAccount:$APP_INSTANCE_NAME@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com
```

Finally, bind this Google service account to the Kubernetes service account
that was created by the above `kubectl apply` command. To bind them, run
the following:

```sh
gcloud iam service-accounts add-iam-policy-binding $APP_INSTANCE_NAME@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$(gcloud config get-value project | tr ':' '/').svc.id.goog[$NAMESPACE/google-cas-issuer-sa]"
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
  certificateAuthorityID: my-sub-ca
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

---

This is the repository that holds the configuration for our Google
Marketplace solution, [jetstack-secure-for-cert-manager][].

## Technical considerations

**Retagging cert-manager images:**

In order to abide by the [schema.md][], which states:

> When users deploy your app from Google Cloud Marketplace, the final image
> names may be different, but they will follow **the same release tag** and
> name prefix rule.

This means we do re-tag all our images (cert-manager, cas-issuer, ubbagent,
preflight-agent) using a unified tag that is distinct from the cert-manager
regular version. We call this version the "application version". In the
following example, the application version is `1.0.0` although the
cert-manager-controller is `1.1.0`:

```sh
gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-acmesolver:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-cainjector:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-google-cas-issuer:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/preflight:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/ubbagent:1.0.0
```

**cert-manager-controller is the "primary image":**

The "primary" image is pushed to the "root" of the registry, for example:

```sh
# The primary image "cert-manager-controller":
gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.0.0

# All other images:
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.0.0
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook:1.0.0
```

## Installing and manually testing the deployer

In order to have the google-cas-issuer working, we need to enable [workload
identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity).
Let's create a cluster that has the workload identity enabled:

```sh
gcloud container clusters create foo --region us-east1 --num-nodes=1 --preemptible \
  --workload-pool=$(gcloud config get-value project | tr ':' '/').svc.id.goog
```

Now, re-publish the images to the project:

```sh
export REGISTRY=gcr.io/$(gcloud config get-value project | tr ':' '/')
export SOLUTION=jetstack-secure-for-cert-manager

docker pull quay.io/jetstack/cert-manager-controller:v1.1.0
docker pull quay.io/jetstack/cert-manager-acmesolver:v1.1.0
docker pull quay.io/jetstack/cert-manager-cainjector:v1.1.0
docker pull quay.io/jetstack/cert-manager-webhook:v1.1.0
docker pull quay.io/jetstack/cert-manager-google-cas-issuer:0.1.0
docker pull quay.io/jetstack/preflight:0.1.27
docker pull gcr.io/cloud-marketplace-tools/metering/ubbagent:latest

docker tag quay.io/jetstack/cert-manager-controller:v1.1.0 $REGISTRY/$SOLUTION:1.0.0
docker tag quay.io/jetstack/cert-manager-acmesolver:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-acmesolver:1.0.0
docker tag quay.io/jetstack/cert-manager-cainjector:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-cainjector:1.0.0
docker tag quay.io/jetstack/cert-manager-webhook:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-webhook:1.0.0
docker tag quay.io/jetstack/cert-manager-google-cas-issuer:latest $REGISTRY/$SOLUTION/cert-manager-google-cas-issuer:1.0.0
docker tag quay.io/jetstack/preflight:latest $REGISTRY/$SOLUTION/preflight:1.0.0
docker tag gcr.io/cloud-marketplace-tools/metering/ubbagent:latest $REGISTRY/$SOLUTION/ubbagent:1.0.0

docker push $REGISTRY/$SOLUTION:1.0.0
docker push $REGISTRY/$SOLUTION/cert-manager-acmesolver:1.0.0
docker push $REGISTRY/$SOLUTION/cert-manager-cainjector:1.0.0
docker push $REGISTRY/$SOLUTION/cert-manager-webhook:1.0.0
docker push $REGISTRY/$SOLUTION/cert-manager-google-cas-issuer:1.0.0
docker push $REGISTRY/$SOLUTION/preflight:1.0.0
docker push $REGISTRY/$SOLUTION/ubbagent:1.0.0
```

Then, build and push the deployer image:

```sh
docker build --tag $REGISTRY/$SOLUTION/deployer:1.0.0 .
docker push $REGISTRY/$SOLUTION/deployer:1.0.0
```

Finally, use `mpdev` to install jetstack-secure to the `test-ns` namespace:

```sh
# If you don't have it already, install mpdev:
docker run gcr.io/cloud-marketplace-tools/k8s/dev cat /scripts/dev > /tmp/mpdev && install /tmp/mpdev ~/bin

kubectl create ns test-ns
kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml
mpdev install --deployer=$REGISTRY/$SOLUTION/deployer --parameters='{"name": "test-ns", "namespace": "test"}'
```

Now, we need to have access to a CAS root. To create a "root" certificate
authority as well as an intermediate certificate authority ("subordinate")
in your current Google project, run:

```sh
gcloud config set privateca/location us-east1
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


## Testing and releasing the deployer using Google Cloud Build

We use `gcloud builds` in order to automate the release process. Cloud
Build re-publishes the cert-manager images to your project and builds,
tests and pushs the deployer image.

Requirements before running `gcloud builds`:

1. You need a GKE cluster with
   [workload-identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
   enabled. You can either update your existing cluster or create a new
   cluster with workload identity enabled with this command:

   ```sh
   export GKE_CLUSTER_NAME=foo
   export GKE_CLUSTER_LOCATION=us-east1
   gcloud container clusters create $GKE_CLUSTER_NAME --region $GKE_CLUSTER_LOCATION --num-nodes=1 --preemptible \
     --workload-pool=$(gcloud config get-value project | tr ':' '/').svc.id.goog
   ```

2. A Google CAS root and subordinate CA as well as a Google service account
   that will be "attached" to the Kubernetes service account that will be
   created by the deployer:

   ```sh
   gcloud beta privateca roots create my-ca --subject="CN=root,O=my-ca"
   gcloud beta privateca subordinates create my-sub-ca  --issuer=my-ca --location us-east1 --subject="CN=intermediate,O=my-ca,OU=my-sub-ca"
   gcloud iam service-accounts create sa-google-cas-issuer
   gcloud beta privateca subordinates add-iam-policy-binding my-sub-ca \
     --role=roles/privateca.certificateRequester \
     --member=serviceAccount:sa-google-cas-issuer@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com
   gcloud iam service-accounts add-iam-policy-binding sa-google-cas-issuer@$(gcloud config get-value project | tr ':' '/').iam.gserviceaccount.com \
     --role roles/iam.workloadIdentityUser \
     --member "serviceAccount:$(gcloud config get-value project | tr ':' '/').svc.id.goog[test-ns/test-google-cas-issuer-serviceaccount-name]"
   ```

   > Note: the last step which is adding the annotation to the
   > google-cas-issuer Kubernetes service account is done in
   > `cloudbuild.yml`. The annotation will look like:
   >
   >  ```yaml
   >  metadata:
   >    annotations:
   >      iam.gke.io/gcp-service-account=sa-google-cas-issuer@PROJECT_ID.iam.gserviceaccount.com
   >  ```

3. Go to [IAM and Admin > Permissions for
   project](https://console.cloud.google.com/iam-admin/iam) and configure
   the `0123456789@cloudbuild.gserviceaccount.com` service account with the
   following roles so that it has permission to deploy RBAC configuration
   to the target cluster and to publish it to a bucket:
   - `Cloud Build Service Agent`
   - `Kubernetes Engine Admin`
   - `Storage Object Admin`

4. Create a bucket that has the same name as your project. To create it,
   run:

   ```sh
   gsutil mb gs://$(gcloud config get-value project | tr ':' '/')
   ```

Then, you can trigger a build:

```sh
gcloud builds submit --timeout 1800s --config cloudbuild.yaml \
  --substitutions _CLUSTER_NAME=$GKE_CLUSTER_NAME,_CLUSTER_LOCATION=$GKE_CLUSTER_LOCATION
```

This will run [`mpdev verify`]([Google Cloud Marketplace verification
tool](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/c5899a928a2ac8d5022463c82823284a9e63b177/scripts/verify)),
which runs [smoke tests](/smoke-test.yaml).

Note that debugging `mpdev verify` is quite tricky. In order to inspect the
state of the namespace created by `mpdev verify`, we can artificially pause
`mpdev verify` when it tries to [delete the application](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/4ecf535/scripts/verify#L301-L304):

### Debugging deployer and smoke-tests when run in Cloud Build

There is no official spec for the `smoke-test.yaml` file, although there is
the example [suite.yaml](https://github.com/GoogleCloudPlatform/marketplace-testrunner/blob/4245fa9/specs/testdata/suite.yaml):

```yaml
actions:
- name: {{ .Env.TEST_NAME }}
  httpTest:
    url: http://{{ .Var.MainVmIp }}:9012
    expect:
      statusCode:
        equals: 200
      statusText:
        contains: OK
      bodyText:
        html:
          title:
            contains: Hello World!
- name: Update success variable
  gcp:
    setRuntimeConfigVar:
      runtimeConfigSelfLink: https://runtimeconfig.googleapis.com/v1beta1/projects/my-project/configs/my-config
      variablePath: status/success
      base64Value: c3VjY2Vzcwo=
- name: Can echo to stdout and stderr
  bashTest:
    script: |-
      echo "Text1"
      >2& echo "Text2"
    expect:
      exitCode:
        equals: 0
        notEquals: 1
      stdout:
        contains: "Text1"
        notContains: "Foo"
        matches: "T.xt1"
      stderr:
        contains: "Text2"
        notContains: "Foo"
        matches: "T.xt2"
```

Unfortunately, the `stdout` or `stderr` output won't be shown whenever a
step fails. Reason: the
[logic in bash.go](https://github.com/GoogleCloudPlatform/marketplace-testrunner/blob/4245fa9/tests/bash.go#L88-L96)
first checks the status code and returns if mismatch, then checks the
stdout and returns if mismatch, and finally checks stderr.

**Workaround:**: add to `smoke-test.yaml` a step that hangs, e.g.:

```yaml
  - name: hang for debugging purposes
    bashTest:
      script: sleep 1200
```

then you can `exec` into the snoke-test pod and debug around.

## Updating the upstream cert-manager chart version

From
[building-deployer-helm.md](https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/master/docs/building-deployer-helm.md),
bump the version of the cert-manager chart in requirements.yaml. Then:

```sh
helm repo add jetstack https://charts.jetstack.io
helm dependency build chart/jetstacksecure-mp
```

[schema.md]: https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/d9d3a6f/docs/schema.md
[jetstack-secure-for-cert-manager]: https://console.cloud.google.com/partner/editor/jetstack-public/jetstack-secure-for-cert-manager?project=jetstack-public