# Creating and testing the deployer image

The deployer image embeds everything that is required for applying the
correct Kubernetes manifests to deploy the Jetstack Secure for
cert-manager application. In our case, the image embeds:

- The `helm` tool,
- The Helm charts for cert-manager, google-cas-issuer and preflight.

The deployer images look like this:

```sh
# We provide these three tags:
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.1.0-gcm.1
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.1.0
marketplace.gcr.io/jetstack-public/jetstack-secure-for-cert-manager:1.1
```

## Installing and manually testing the deployer image

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

docker tag quay.io/jetstack/cert-manager-controller:v1.1.0 $REGISTRY/$SOLUTION:1.1.0-gcm.1
docker tag quay.io/jetstack/cert-manager-acmesolver:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-acmesolver:1.1.0-gcm.1
docker tag quay.io/jetstack/cert-manager-cainjector:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-cainjector:1.1.0-gcm.1
docker tag quay.io/jetstack/cert-manager-webhook:v1.1.0 $REGISTRY/$SOLUTION/cert-manager-webhook:1.1.0-gcm.1
docker tag quay.io/jetstack/cert-manager-google-cas-issuer:latest $REGISTRY/$SOLUTION/cert-manager-google-cas-issuer:1.1.0-gcm.1
docker tag quay.io/jetstack/preflight:latest $REGISTRY/$SOLUTION/preflight:1.1.0-gcm.1
docker tag gcr.io/cloud-marketplace-tools/metering/ubbagent:latest $REGISTRY/$SOLUTION/ubbagent:1.1.0-gcm.1

docker push $REGISTRY/$SOLUTION:1.1.0-gcm.1
docker push $REGISTRY/$SOLUTION/cert-manager-acmesolver:1.1.0-gcm.1
docker push $REGISTRY/$SOLUTION/cert-manager-cainjector:1.1.0-gcm.1
docker push $REGISTRY/$SOLUTION/cert-manager-webhook:1.1.0-gcm.1
docker push $REGISTRY/$SOLUTION/cert-manager-google-cas-issuer:1.1.0-gcm.1
docker push $REGISTRY/$SOLUTION/preflight:1.1.0-gcm.1
docker push $REGISTRY/$SOLUTION/ubbagent:1.1.0-gcm.1
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