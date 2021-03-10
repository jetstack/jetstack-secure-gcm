# Everything about the deployer image
- [Creating and testing the deployer image](#creating-and-testing-the-deployer-image)
- [Cutting a new release](#cutting-a-new-release)
- [Testing the application without having access to the Billing API](#testing-the-application-without-having-access-to-the-billing-api)
- [How the Application object "wrangles" its components](#how-the-application-object-wrangles-its-components)
- [Installing and manually testing the deployer image](#installing-and-manually-testing-the-deployer-image)
- [Testing and releasing the deployer using Google Cloud Build](#testing-and-releasing-the-deployer-using-google-cloud-build)
  - [Debugging deployer and smoke-tests when run in Cloud Build](#debugging-deployer-and-smoke-tests-when-run-in-cloud-build)
- [Updating the upstream cert-manager chart version](#updating-the-upstream-cert-manager-chart-version)

## Creating and testing the deployer image

> Note: for passing the Google review, we had to enable the Container
> Analysis API:
>
> ```sh
> PROJECT=jetstack-public
> gcloud services --project=$PROJECT enable containeranalysis.googleapis.com
> ```

The deployer image is **only** used when the Jetstack Secure for
cert-manager is deployed in through the UI; it is not used for when
installing the application through the CLI.

The deployer image embeds
everything that is required for applying the correct Kubernetes manifests
to deploy the Jetstack Secure for cert-manager application. In our case,
the image embeds:

- The `helm` tool,
- The Helm charts for cert-manager, google-cas-issuer and preflight.

There are two deployer tags:

```sh
# The main moving tag required by the Marketplace UI:
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1

# A static tag for debugging purposes:
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1.0-gcm.1
```

The minor tag `1.1` (for example) is the tag that the Marketplace UI needs.
The other tags (e.g., `1.1.0` or `1.1.0-gcm.1`) cannot be used for the
Marketplace UI:

> A version should correspond to a minor version (e.g. `1.0`) according to
> semantic versioning  (not a patch version, such as `1.1.0`). Update the
> same version for patch releases, which should be backward-compatible,
> instead of creating a new version.

In the below screenshot, we see that both the deployer tags `1.1.0` and
`1.1.0-gcm.1` are "refused" by the UI:

<img src="https://user-images.githubusercontent.com/2195781/110091031-491bed00-7d98-11eb-8522-ddc91913d010.png" width="500" alt="Only the minor version 1.1 should be pushed, not 1.1.0 or 1.1.0-gcm.1. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

Note that we only push full tags (e.g., `1.1.0-gcm.1`) for all the other
images. For example, let us imagine that `deployer:1.1` was created with
this `schema.yaml`:

```yaml
# schema.yaml
x-google-marketplace:
  publishedVersion: "1.1.0-gcm.1"
```

This means that although the deployer image says `1.1`, the tags used in
the helm release will be using the tag `1.1.0-gcm.1`; the images used in
the pods will look like this:

```plain
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-acmesolver:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-cainjector:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-google-cas-issuer:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-preflight:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/preflight:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/smoke-test:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager/ubbagent:1.1.0-gcm.1
```

Upgrades for patch or build versions (e.g., moving from `1.1.0-gcm.1` to
`1.1.0-gcm.2`, or from `1.1.0-gcm.1` to `1.1.1-gcm.1`) work like this:

1. We update the `publishedVersion` in schema.yaml;
2. Then, we push a new `deployer:1.1` (i.e, `1.1` is a moving tag);
3. The user of the Click-to-deploy solution will have to re-deploy using
   the same `1.1` to get the upgrade.

As a recap about image tags, here is what the tags look like now, taking
`1.1.0-gcm.1` as an example:

```sh
# The deployer image is built and pushed in cloudbuild.yaml:
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1.0-gcm.1

# These images are manually pushed (see below command):
gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.1.0-gcm.1 # this is cert-manager-controller
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-acmesolver:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-cainjector:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-google-cas-issuer:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/preflight:1.1.0-gcm.1

# These images are built and pushed by cloudbuild.yaml:
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/smoke-test:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/ubbagent:1.1.0-gcm.1
```

Here is the command I did to retag all `google-review` images to
`1.1.0-gcm.1` since we don't have yet automated Google-OSPO-compliant image
(will be done in
[#10](https://github.com/jetstack/jetstack-secure-gcm/issues/10)):

```sh
retag() {
  docker pull $1 && docker tag $1 $2 && docker push $2
}
retag gcr.io/jetstack-public/jetstack-secure-for-cert-manager{google-review,1.1.0-gcm.1}
retag gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-acmesolver{google-review,1.1.0-gcm.1}
retag gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-cainjector{google-review,1.1.0-gcm.1}
retag gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook{google-review,1.1.0-gcm.1}
retag gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-google-cas-issuer{google-review,1.1.0-gcm.1}
retag gcr.io/jetstack-public/jetstack-secure-for-cert-manager/preflight{google-review,1.1.0-gcm.1}
retag gcr.io/cloud-marketplace-tools/metering/ubbagent:latest gcr.io/jetstack-public/jetstack-secure-for-cert-manager/ubbagent:1.1.0-gcm.1
EOF
```

## Cutting a new release

First, run Cloud Build. That will push the deployer and smoke-test images
using the version set in `_APP_VERSION`, e.g., `1.1.0-gcm.1`.

```sh
gcloud builds submit --project jetstack-public --timeout 1800s --config cloudbuild.yaml \
  --substitutions _CLUSTER_NAME=smoke-test,_CLUSTER_LOCATION=europe-west2-b,_APP_MINOR_VERSION=1.1,_APP_VERSION=1.1.0-gcm.1
```

Three images are pushed to the "staging" registry:

```sh
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/smoke-test:1.1.0-gcm.1
```

In order to get these images published to the official
`marketplace.gcr.io`, you need to register the version.

If the minor version, e.g. `1.1`, already exists, then you will need to
update the existing minor version:

<img src="https://user-images.githubusercontent.com/2195781/110706910-daf08380-81f8-11eb-92ef-d62ef7ff4de1.png" width="300" alt="To update the already released minor version, first open the existing minor version by clicking on the version itself (it is a link). This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

<img src="https://user-images.githubusercontent.com/2195781/110706906-d9bf5680-81f8-11eb-909f-faa1818b8f56.png" width="300" alt="Then, click on Update images and Save. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

Finally, you will need to click "Submit for review" and wait a couple of
days until the Google team approves the new (or updated) minor version.

## Testing the application without having access to the Billing API

Jetstack members do not have access to the Billing API. In order to test
the UI and CLI flows, the IT team needs to "Purchase" the application. It
does not matter which project, the only important bit is that have the
application purchased. Then, any project that is attached to that same
billing account will be able to "Configure" the application on their own
project, e.g. on `jetstack-mael-valais`.

<img src="https://user-images.githubusercontent.com/2195781/110688721-3105fc80-81e2-11eb-9297-81e65dc8baa0.png" width="500" alt="The app must be purchased once by someone with access to the billing account. The project does not matter. After having it purchased once, any project that is attached to this billing account will be able to Configure the application. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

## How the Application object "wrangles" its components

In order to display its components (Pods, Deployments, ConfigMap, Secret,
CRD, Mutating and Validating webhook), the Application uses a label
selector. The [official Application
API](https://github.com/kubernetes-sigs/application/blob/master/docs/api.md)
reminds us that the `app.kubernetes.io/name` must be used. So we use both
the `name` and `instance` [recommended
labels](https://kubernetes.io/docs/concepts/overview/working-with-objects/common-labels/):

```yaml
# https://github.com/jetstack/jetstack-secure-gcm/blob/main/chart/jetstack-secure-gcm/templates/application.yaml
kind: Application
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: {{ .Chart.Name }}          # Will always be "jetstack-secure-gcm"
      app.kubernetes.io/instance: {{ .Release.Name }}    # Example: "jetstack-secure-for-cert-mana-2"
```

First, we set the name override for all our charts:

```yaml
# https://github.com/jetstack/jetstack-secure-gcm/blob/main/chart/jetstack-secure-gcm/values.yaml
cert-manager:
  nameOverride: jetstack-secure-gcm
google-cas-issuer:
  nameOverride: jetstack-secure-gcm
preflight:
  nameOverride: jetstack-secure-gcm
```

Then we make sure all the objects are set with the labels:

```yaml
# All the manifests and subcharts under
# https://github.com/jetstack/jetstack-secure-gcm/blob/main/chart/jetstack-secure-gcm/templates
metadata:
  app.kubernetes.io/name: "{{ .Chart.Name }}"        # Will be "jetstack-secure-gcm" due to the name override
  app.kubernetes.io/instance: "{{ .Release.Name }}"  # Example: "jetstack-secure-for-cert-mana-2"
```

## Installing and manually testing the deployer image

First, let us set a couple of variables:

```sh
CLUSTER=smoke-test
LOCATION=europe-west2-b
PROJECT=$(gcloud config get-value project | tr ':' '/')
REGISTRY=gcr.io/$PROJECT
SOLUTION=jetstack-secure-for-cert-manager
```

In order to have the google-cas-issuer working, we need to enable [workload
identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity).
Let's create a cluster that has the workload identity enabled:

```sh
gcloud container clusters create $CLUSTER --region $LOCATION --num-nodes=1 --preemptible \
  --workload-pool=$PROJECT.svc.id.goog
```

Then, build and push the deployer image:

```sh
docker build --tag $REGISTRY/$SOLUTION/deployer:1.1.0-gcm.1 .
docker push $REGISTRY/$SOLUTION/deployer:1.1.0-gcm.1
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
  --member=serviceAccount:sa-google-cas-issuer@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts add-iam-policy-binding sa-google-cas-issuer@$PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT.svc.id.goog[test-ns/test-google-cas-issuer-serviceaccount-name]"
kubectl annotate serviceaccount -n test-ns test-google-cas-issuer-serviceaccount-name \
  iam.gke.io/gcp-service-account=sa-google-cas-issuer@$PROJECT.iam.gserviceaccount.com
```


## Testing and releasing the deployer using Google Cloud Build

We use `gcloud builds` in order to automate the release process. Cloud
Build re-publishes the cert-manager images to your project and builds,
tests and pushs the deployer image.

Requirements before running `gcloud builds`:

1. Set a few variables:

   ```sh
   PROJECT=jetstack-public
   CLUSTER=smoke-test
   LOCATION=europe-west2-b
   ```

2. Enable the necessary Google APIs on your project. To enable them, you
      can run the following:

   ```sh
   gcloud services --project=$PROJECT enable cloudbuild.googleapis.com
   gcloud services --project=$PROJECT enable container.googleapis.com
   gcloud services --project=$PROJECT enable containerregistry.googleapis.com
   gcloud services --project=$PROJECT enable storage-api.googleapis.com
   ```

3. You need a GKE cluster with
   [workload-identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
   enabled. You can either update your existing cluster or create a new
   cluster with workload identity enabled with this command:

   ```sh
   export CLUSTER=smoke-test
   export LOCATION=europe-west2-b
   export PROJECT=$(gcloud config get-value project | tr ':' '/')
   gcloud container clusters create $CLUSTER --region $LOCATION --num-nodes=1 --preemptible \
     --workload-pool=$PROJECT.svc.id.goog
   ```

4. A Google CAS root and subordinate CA as well as a Google service account
   that will be "attached" to the Kubernetes service account that will be
   created by the deployer:

   ```sh
   gcloud beta privateca roots create my-ca --subject="CN=root,O=my-ca"
   gcloud beta privateca subordinates create my-sub-ca  --issuer=my-ca --location $LOCATION --subject="CN=intermediate,O=my-ca,OU=my-sub-ca"
   gcloud iam service-accounts create sa-google-cas-issuer
   gcloud beta privateca subordinates add-iam-policy-binding my-sub-ca \
     --role=roles/privateca.certificateRequester \
     --member=serviceAccount:sa-google-cas-issuer@$PROJECT.iam.gserviceaccount.com
   gcloud iam service-accounts add-iam-policy-binding sa-google-cas-issuer@$PROJECT.iam.gserviceaccount.com \
     --role roles/iam.workloadIdentityUser \
     --member "serviceAccount:$PROJECT.svc.id.goog[test-ns/test-google-cas-issuer-serviceaccount-name]"
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

5. Go to [IAM and Admin > Permissions for
   project](https://console.cloud.google.com/iam-admin/iam) and configure
   the `0123456789@cloudbuild.gserviceaccount.com` service account with the
   following roles so that it has permission to deploy RBAC configuration
   to the target cluster and to publish it to a bucket:
   - `Cloud Build Service Agent`
   - `Kubernetes Engine Admin`
   - `Storage Object Admin`

6. Create a bucket **in the same project as your cluster**. The bucket must
   have the same name as your project. To create it, run the following:

   ```sh
   gsutil mb -p $PROJECT gs://$PROJECT
   ```

Then, you can trigger a build:

```sh
gcloud builds submit --project $PROJECT --timeout 1800s --config cloudbuild.yaml \
  --substitutions _CLUSTER_NAME=$CLUSTER,_CLUSTER_LOCATION=$LOCATION
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
helm dependency build chart/jetstack-secure-gcm
```

[schema.md]: https://github.com/GoogleCloudPlatform/marketplace-k8s-app-tools/blob/d9d3a6f/docs/schema.md
[jetstack-secure-for-cert-manager]: https://console.cloud.google.com/partner/editor/jetstack-public/jetstack-secure-for-cert-manager?project=jetstack-public