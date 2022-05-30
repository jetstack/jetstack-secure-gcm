# Everything about the deployer image

> Note: for passing the Google review, we had to enable the Container
> Analysis API:
>
> ```sh
> PROJECT=jetstack-public
> gcloud services --project=$PROJECT enable containeranalysis.googleapis.com
> ```

**Contents:**

- [Cutting a new release](#cutting-a-new-release)
- [Run the smoke tests locally](#run-the-smoke-tests-locally)
  - [Unused: set up Google CAS for the smoke test](#unused-set-up-google-cas-for-the-smoke-test)
- [What is this "deployer" thing?](#what-is-this-deployer-thing)
  - [Pricing mechanism](#pricing-mechanism)
  - [How the Application object "wrangles" its components](#how-the-application-object-wrangles-its-components)
- [Deprecated: set up your project to use `cloudbuild.yaml`](#deprecated-set-up-your-project-to-use-cloudbuildyaml)
  - [Debugging deployer and smoke-tests when run in Cloud Build](#debugging-deployer-and-smoke-tests-when-run-in-cloud-build)
- [Updating the upstream cert-manager chart version](#updating-the-upstream-cert-manager-chart-version)

## Cutting a new release

⚠ All the versions that we have published must past `mpdev verify` before
submitting. When you are submitting, Google will review all of your versions
(e.g., 1.1, 1.3, 1.4, etc.), not "just" the version that you added.

Since the process is manual and evolves from release to release, we document all
the steps that were taken in each release directly on the GitHub Release itself
in a `<details>` block that looks like this:

> ▶ 📦 Recording of the manual steps of the release process

Imagining that you want to release `1.1.0-gcm.5`, the steps are:

1. Copy the `<details>` block from the previous release [1.1.0-gcm.4](https://github.com/jetstack/jetstack-secure-gcm/releases/tag/1.1.0-gcm.4)
2. In an editor, change the references to `1.1.0-gcm.4`.
3. Follow the steps and tick the checkboxes.
4. After the `1.1.0-gcm.5` is pushed to GitHub, create a GitHub Release for that
   tag and paste the content into the `<details>` block into the GitHub Release
   you just created (see `PASTE HERE` below). The GitHub Release description
   should look like this:

   ```md
   ## Changelog

   <!-- TODO -->

   ## Notes

   <details>

   <summary>📦 Recording of the manual steps of the release process</summary>

   <!-- PASTE HERE -->

   </details>
   ```

## Run the smoke tests locally

Let us imagine that you have successfully built a deployer image by following
the [cutting-a-new-release](#cutting-a-new-release) instructions. Let's imagine
the deployer image is:

```
gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.1.0-gcm.9
```

First, you need to create your own cluster since the project `jetstack-public`
won't allow you to create `Roles` and `RoleBindings` (due to the fact that your
account, e.g. `mael.valais@jetstack.io`, does not have the role
`container.clusterRoles.create`). First, let us set a couple of variables:

```sh
CLUSTER=smoke-test
LOCATION=europe-west2-b
PROJECT=jetstack-mael-valais
```

Then, create a cluster:

```sh
gcloud container clusters create $CLUSTER --zone=$LOCATION --workload-pool=$PROJECT.svc.id.goog --num-nodes=2 --preemptible --async --project $PROJECT
```

> Note: the `--workload-pool` argument lets us use the google-cas-issuer (see
> [workload
> identity](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)).

You will then need to push all the images from `jetstack-public` to your own
project. To do that, get the script `retagall` and `retag` with the two
following commands:

```sh
tee ~/bin/retagall <<'EOF' && chmod +x ~/bin/retagall
#! /bin/bash
set -uxeo pipefail
# Usage: retagall FROM_REGISTRY FROM_TAG TO_REGISTRY TO_TAG
FROM=$1 TO=$2 FROM_TAG=$3 TO_TAG=$4
retag "$FROM":"$FROM_TAG" "$TO":"$TO_TAG" || exit 1
retag "$FROM"/cert-manager-acmesolver:"$FROM_TAG" "$TO"/cert-manager-acmesolver:"$TO_TAG" || exit 1
retag "$FROM"/cert-manager-cainjector:"$FROM_TAG" "$TO"/cert-manager-cainjector:"$TO_TAG" || exit 1
retag "$FROM"/cert-manager-webhook:"$FROM_TAG" "$TO"/cert-manager-webhook:"$TO_TAG" || exit 1
retag "$FROM"/cert-manager-google-cas-issuer:"$FROM_TAG" "$TO"/cert-manager-google-cas-issuer:"$TO_TAG" || exit 1
retag "$FROM"/preflight:"$FROM_TAG" "$TO"/preflight:"$TO_TAG" || exit 1
retag gcr.io/cloud-marketplace-tools/metering/ubbagent:latest "$TO"/ubbagent:"$TO_TAG" || exit 1
EOF
tee ~/bin/retag <<'EOF' && chmod +x ~/bin/retag
#! /bin/bash
set -uxeo pipefail
# Usage: retag FROM_IMAGE_WITH_TAG TO_IMAGE_WITH_TAG
FROM=$1
TO=$2

docker pull "$FROM"
docker tag "$FROM" "$TO"
docker push "$TO"
EOF
```

Then, run:

```sh
retagall gcr.io/{jetstack-public,$PROJECT}/jetstack-secure-for-cert-manager 1.1.0-gcm.9{,}
retag gcr.io/{jetstack-public,$PROJECT}/jetstack-secure-for-cert-manager/deployer:1.1.0-gcm.9
```

Finally, use `mpdev` to install jetstack-secure to the `test` namespace:

```sh
# If you don't have it already, install mpdev:
docker run gcr.io/cloud-marketplace-tools/k8s/dev cat /scripts/dev > /tmp/mpdev && install /tmp/mpdev ~/bin

kubectl apply -f https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml
kubectl create ns test
mpdev install --deployer=gcr.io/$PROJECT/jetstack-secure-for-cert-manager/deployer:1.1.0-gcm.9 \
  --parameters='{"namespace": "test", "name": "test"}'
```

You will see that the cert-manager Deployment is failing due to the Secret
`test-license` is being missing. Go to the
[Marketplace](https://console.cloud.google.com/marketplace/product/jetstack-public/jetstack-secure-for-cert-manager)
and click "Configure" and "Deploy via command line". Click "Generate license
key":

<img src="https://user-images.githubusercontent.com/2195781/110790775-c0a6bc00-8271-11eb-9ea4-c701ef7f58a1.png" width="300" alt="To download the lincese.yaml file, click on Download license key. This screenshot is stored in this issue: https://github.com/jetstack/jetstack-secure-gcm/issues/21">

> You may not have access to a billing-enabled service account. In that case,
> see [this link](https://github.com/jetstack/platform-board/issues/338)
> (Jetstack internal) to ask for a billing-bound service account created by the
> IT team.

Finally, do:

```sh
cat license.yaml | sed 's/name:.*/name: test-license/' | k apply -f- -n test
```

Check that the cert-manager Deployment is now running:

```
% kubectl -n test get deploy cert-manager
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
cert-manager   1/1     1            1           9m14s
```

Finally, you can then the smoke tests:

```sh
docker build --file smoke-test.Dockerfile -t runner .
docker run -it -v ~/.kube:/root/.kube -v $PWD:/opt -e NAMESPACE=test runner
```

### Unused: set up Google CAS for the smoke test

> ⚠ Currently, the smoke tests are not running Google CAS tests; use the
> following section if you would like to add these smoke tests.

Now, we need to have access to a CAS root. To create a "root" certificate
authority as well as an intermediate certificate authority ("subordinate") in
your current Google project, run:

```sh
gcloud config set privateca/location us-east1
gcloud beta privateca roots create my-ca --subject="CN=root,O=my-ca"
gcloud beta privateca subordinates create my-sub-ca  --issuer=my-ca --location us-east1 --subject="CN=intermediate,O=my-ca,OU=my-sub-ca"
```

Now, bind the Kubernetes service account with a new GCP service account that
will have access to the CAS API:

```sh
gcloud iam service-accounts create sa-google-cas-issuer
gcloud beta privateca subordinates add-iam-policy-binding my-sub-ca \
  --role=roles/privateca.certificateRequester \
  --member=serviceAccount:sa-google-cas-issuer@$PROJECT.iam.gserviceaccount.com
gcloud iam service-accounts add-iam-policy-binding sa-google-cas-issuer@$PROJECT.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:$PROJECT.svc.id.goog[test/test-google-cas-issuer-serviceaccount-name]"
kubectl annotate serviceaccount -n test test-google-cas-issuer-serviceaccount-name \
  iam.gke.io/gcp-service-account=sa-google-cas-issuer@$PROJECT.iam.gserviceaccount.com
```

## What is this "deployer" thing?

We call "deployer" a Docker image that contains Helm and a `chart.tgz` (which
contains the charts for cert-manager + jetstack-secure + google-cas-issuer).

The deployer image is **only** used when the Jetstack Secure for cert-manager is
deployed in through the UI; it is not used for when installing the application
through the CLI instructions that are available on the README.

We keep two deployer tags:

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
> semantic versioning (not a patch version, such as `1.1.0`). Update the
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

Upgrades for patch or build versions (e.g., moving from `1.1.0-gcm.0` to
`1.1.0-gcm.1`, or from `1.1.0-gcm.0` to `1.1.1-gcm.0`) work like this:

1. We update the `publishedVersion` in schema.yaml;
2. Then, we re-push the existing `deployer:1.1` (i.e, `1.1` is a moving tag);
3. Users of click-to-deploy have to use the CLI to update using this repo's
   README.

As a recap about image tags, here is what the tags look like now, taking
`1.1.0-gcm.1` as an example:

```sh
# The deployer and tester images is built and pushed in cloudbuild.yaml:
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/deployer:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/smoke-test:1.1.0-gcm.1

# These images are manually pushed (see below command):
gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.1.0-gcm.1 # this is cert-manager-controller
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-acmesolver:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-cainjector:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-google-cas-issuer:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/cert-manager-webhook:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/preflight:1.1.0-gcm.1
gcr.io/jetstack-public/jetstack-secure-for-cert-manager/ubbagent:1.1.0-gcm.1
```

Here is the command I did to retag all `google-review` images to
`1.1.0-gcm.2` since we don't have yet automated Google-OSPO-compliant image
(will be done in
[#10](https://github.com/jetstack/jetstack-secure-gcm/issues/10)):

```sh
retag() { # Usage: retag FROM_IMAGE_WITH_TAG TO_IMAGE_WITH_TAG
  local FROM=$1 TO=$2
  docker pull $FROM && docker tag $FROM $TO && docker push $TO
}
retagall() { # Usage: retagall FROM_REGISTRY FROM_TAG TO_REGISTRY TO_TAG
  local FROM=$1 TO=$2 FROM_TAG=$3 TO_TAG=$4
  retag $FROM:$FROM_TAG $TO:$TO_TAG || exit 1
  retag $FROM/cert-manager-acmesolver:$FROM_TAG $TO/cert-manager-acmesolver:$TO_TAG || exit 1
  retag $FROM/cert-manager-cainjector:$FROM_TAG $TO/cert-manager-cainjector:$TO_TAG || exit 1
  retag $FROM/cert-manager-webhook:$FROM_TAG $TO/cert-manager-webhook:$TO_TAG || exit 1
  retag $FROM/cert-manager-google-cas-issuer:$FROM_TAG $TO/cert-manager-google-cas-issuer:$TO_TAG || exit 1
  retag $FROM/preflight:$FROM_TAG $TO/preflight:$TO_TAG || exit 1
  retag gcr.io/cloud-marketplace-tools/metering/ubbagent:latest $TO/ubbagent:$TO_TAG || exit 1
}
APP_VERSION=1.1.0-gcm.2
retagall gcr.io/jetstack-public/jetstack-secure-for-cert-manager{,} google-review $APP_VERSION
```

### Pricing mechanism

Each cluster is priced at $50 a month, billed hourly ($0.07/hour). This is configured
in the admin panel:

![Screenshot from 2022-05-30 13-45-34](https://user-images.githubusercontent.com/2195781/170986210-29df68c4-ad28-4a15-baaa-6b6c58a7b7c1.png)

The way the hourly billing works is by running `ubbagent` which is set
as a side-car container to the cert-manager controller
[deployment](https://github.com/jetstack/jetstack-secure-gcm/blob/c43be00b36f7fd1d01f15771025308b8f5ab69f7/chart/jetstack-secure-gcm/charts/cert-manager/templates/deployment.yaml#L1).
The ubbagent pings the Google Billing API every hour; each ping will add a value
of `1` to the `time` value. The unit for `time` is something we have configured
in the [pricing
panel](https://console.cloud.google.com/partner/editor/jetstack-public/jetstack-secure-for-cert-manager?project=jetstack-public&authuser=4&form=saasK8sPricingPanel).

| Field | Value  |
| ----- | ------ |
| ID    | `time` |
| Unit  | `h`    |

Note that the cert-manager deployment should always be run with replicas=1.
High-availability (replicas > 1) is not supported yet, and the application will
be billed for each replica on the cluster.

The ubbagent's ping period is configured using the `intervalSeconds` field (in
seconds!) in the
[billing-agent-config.yml](https://github.com/jetstack/jetstack-secure-gcm/blob/c43be00b36f7fd1d01f15771025308b8f5ab69f7/chart/jetstack-secure-gcm/templates/billing-agent-config.yml#L15-L74)
that looks like:

```yaml
# File: billing-agent-config.yml

# The metrics section defines the metric that will be reported.
# Metric names should match verbatim the identifiers created
# during pricing setup.
metrics:
  - name: time
    type: int
    endpoints:
      - name: servicecontrol

# The endpoints section defines where metering data is ultimately
# sent. Currently supported endpoints include:
# * disk - some directory on the local filesystem
# * servicecontrol - Google Service Control
endpoints:
  - name: servicecontrol
    servicecontrol:
      identity: gcp
      # This service name comes from the service name that Google gave us in
      # jetstack-secure-for-cert-manager.yaml (see below).
      serviceName: jetstack-secure-for-cert-manager.mp-jetstack-public.appspot.com
      consumerId: $AGENT_CONSUMER_ID

# The sources section lists metric data sources run by the agent
# itself. The currently-supported source is 'heartbeat', which
# sends a defined value to a metric at a defined interval.
sources:
  - name: instance_time_heartbeat
    heartbeat:
      # The heartbeat sends a 1-hour value through the "time" metric every
      # hour.
      metric: time
      intervalSeconds: 3600
      value:
        int64Value: 1
```

For information, here is the `jetstack-secure-for-cert-manager.yaml` that was
[provided to us](https://github.com/jetstack/platform-board/issues/347); this
file contains the name of the "services" that can be used in the above
`billing-agent-config.yml`:

```yaml
# This manifest is called jetstack-secure-for-cert-manager.yaml and was
# provided by Google on 5 March 2021 in an onboarding email.
# See: https://github.com/jetstack/platform-board/issues/347.

type: google.api.Service
config_version: 3
name: jetstack-secure-for-cert-manager.mp-jetstack-public.appspot.com
title: "Jetstack Ltd. Jetstack Secure for cert-manager Reporting Service"
producer_project_id: mp-jetstack-public

control:
  environment: servicecontrol.googleapis.com

metrics:
  - name: jetstack-secure-for-cert-manager.mp-jetstack-public.appspot.com/time
    metric_kind: DELTA
    value_type: INT64
    unit: h

billing:
  metrics:
    - jetstack-secure-for-cert-manager.mp-jetstack-public.appspot.com/time
  rules:
    - selector: "*"
      allowed_statuses:
        - current
```

### How the Application object "wrangles" its components

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
      app.kubernetes.io/name: { { .Chart.Name } } # Will always be "jetstack-secure-gcm"
      app.kubernetes.io/instance: { { .Release.Name } } # Example: "jetstack-secure-for-cert-mana-2"
```

Then, we use the `nameOverride` and `fullnameOverride`:

1. `nameOverride` makes sure that all the objects across all subcharts have
   the following label:
   ```yaml
   app.kubernetes.io/name: "jetstack-secure-gcm"
   ```
2. `fullnameOverride` makes sure that the object names actually make sense;
   if we did not use this, we would end up with duplicate names in
   deployments and services.

```yaml
# https://github.com/jetstack/jetstack-secure-gcm/blob/main/chart/jetstack-secure-gcm/values.yaml
cert-manager:
  nameOverride: jetstack-secure-gcm
  fullnameOverride: jetstack-secure-gcm
google-cas-issuer:
  nameOverride: jetstack-secure-gcm
  fullnameOverride: google-cas-issuer
preflight:
  nameOverride: jetstack-secure-gcm
  fullnameOverride: preflight
```

Then we make sure all the objects are set with the labels:

```yaml
# All the manifests and subcharts under
# https://github.com/jetstack/jetstack-secure-gcm/blob/main/chart/jetstack-secure-gcm/templates
metadata:
  app.kubernetes.io/name: "{{ .Chart.Name }}" # Will be "jetstack-secure-gcm" due to the name override
  app.kubernetes.io/instance: "{{ .Release.Name }}" # Example: "jetstack-secure-for-cert-mana-2"
```

## Deprecated: set up your project to use `cloudbuild.yaml`

> ⚠ The project `jetstack-public` already have the necessary Google APIs
> enabled, you can use it to run `gcloud builds submit`. To see the instructions
> on how to run `gcloud builds`, see the "Cut a new release" instructions.
>
> Only follow the next section if you want to be able to run `gcloud builds submit` on a different project than `jetstack-public`.

We use `gcloud builds` in order to automate the release process. Cloud Build
re-publishes the cert-manager images to your project and builds, tests and push
the deployer image.

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

3. A Google CAS root and subordinate CA as well as a Google service account
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

4. Go to [IAM and Admin > Permissions for
   project](https://console.cloud.google.com/iam-admin/iam) and configure
   the `0123456789@cloudbuild.gserviceaccount.com` service account with the
   following roles so that it has permission to deploy RBAC configuration
   to the target cluster and to publish it to a bucket:

   - `Cloud Build Service Agent`
   - `Kubernetes Engine Admin`
   - `Storage Object Admin`

5. Create a bucket **in the same project as your cluster**. The bucket must
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
  - name: "{{ .Env.TEST_NAME }}"
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
