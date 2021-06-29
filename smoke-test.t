This file is written using the "cram" format. We could have used a simple Bash
script, but cram tests make it very easy to spot when something "changes" e.g.
stderr or stdout mismatch.

This file is used in the smoke-test image (smoke-test.Dockerfile) to run the
test suite. This image is used in a Job in data-test. mpdev verify detects the
presence of this Job thanks to the annotation
 "marketplace.cloud.google.com/verification: test"

First, let us create a self-signed Issuer and a Certificate. This is a good way
to spot webhook misconfigurations.

  $ kubectl apply -n ${NAMESPACE} -f - <<EOF
  > apiVersion: cert-manager.io/v1
  > kind: Issuer
  > metadata:
  >   name: selfsigned-issuer
  > spec:
  >   selfSigned: {}
  > ---
  > apiVersion: cert-manager.io/v1
  > kind: Certificate
  > metadata:
  >   name: selfsigned-cert
  > spec:
  >   dnsNames:
  >     - example.com
  >   secretName: selfsigned-cert-tls
  >   issuerRef:
  >     name: selfsigned-issuer
  > EOF
  issuer.cert-manager.io/selfsigned-issuer created
  certificate.cert-manager.io/selfsigned-cert created

Now, let us wait until the Certificate becomes Ready. An error here might
indicate that the cert-manager-controller is running but keeps failing at the
leader election step. We know that cert-manager-controller is available because
"mpdev verify" only runs this test suite after cert-manager-controller becomes
available.

  $ kubectl wait -n ${NAMESPACE} --for=condition=Ready --timeout=2m certificate selfsigned-cert
  certificate.cert-manager.io/selfsigned-cert condition met

Get the Secret associated to the Certificate:

  $ kubectl get secret -n ${NAMESPACE} selfsigned-cert-tls
  NAME                  TYPE                DATA   AGE
  selfsigned-cert-tls   kubernetes.io/tls   3      * (glob)

Delete the self-signed Issuer and the Certificate:

  $ kubectl delete -n ${NAMESPACE} issuer selfsigned-issuer
  issuer.cert-manager.io "selfsigned-issuer" deleted

  $ kubectl delete -n ${NAMESPACE} certificate selfsigned-cert
  certificate.cert-manager.io "selfsigned-cert" deleted


Create a GoogleCASIssuer and a Certificate:

  $ kubectl apply -n ${NAMESPACE} -f - <<EOF
  > apiVersion: cas-issuer.jetstack.io/v1beta1
  > kind: GoogleCASIssuer
  > metadata:
  >   name: googlecas-issuer
  > spec:
  >   project: "todo"
  >   location: "todo"
  >   caPoolId: "todo"
  > ---
  > apiVersion: cert-manager.io/v1
  > kind: Certificate
  > metadata:
  >   name: googlecas-cert
  > spec:
  >   secretName: demo-cert-tls
  >   commonName: cert-manager.io.demo
  >   dnsNames:
  >     - cert-manager.io
  >     - jetstack.io
  >   duration: 24h
  >   renewBefore: 8h
  >   issuerRef:
  >     group: cas-issuer.jetstack.io
  >     kind: GoogleCASIssuer
  >     name: googlecas-issuer
  > EOF
  googlecasissuer.cas-issuer.jetstack.io/googlecas-issuer created
  certificate.cert-manager.io/googlecas-cert created

We don't know yet how, as part of this smoke test file, to create a GCP service
account and then create a Kubernetes service account and bind the two together
using the "workload identity" feature.

Right now, the above GoogleCASIssuer does nothing, and the certificate will
never be issued. This TODO is tracked at
https://github.com/jetstack/jetstack-secure-gcm/issues/19.

Now, let us delete the GoogleCASIssuer and Certificate.

  $ kubectl delete -n ${NAMESPACE} googlecasissuer googlecas-issuer
  googlecasissuer.cas-issuer.jetstack.io "googlecas-issuer" deleted

  $ kubectl delete -n ${NAMESPACE} certificate googlecas-cert
  certificate.cert-manager.io "googlecas-cert" deleted
