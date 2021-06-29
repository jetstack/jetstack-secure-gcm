# This image runs the smoke tests. It is meant to be made available to the
# command:
#
#     mpdev verify
#
# This smoke test performs simple high-level check such as "can we issue a
# certificate using the Google CAS issuer?"

# Dockerfile: https://github.com/GoogleCloudPlatform/marketplace-testrunner/blob/master/Dockerfile
FROM python:alpine

RUN apk add curl patch
RUN pip3 install cram
RUN curl -L https://github.com/stern/stern/releases/download/v1.19.0/stern_1.19.0_linux_amd64.tar.gz | tar xz -C /tmp \
    && mv /tmp/stern_1.19.0_linux_amd64/stern /usr/local/bin \
    && curl -L https://storage.googleapis.com/kubernetes-release/release/v1.19.6/bin/linux/amd64/kubectl --output-dir /usr/local/bin -O \
    && chmod 755 /usr/local/bin/kubectl

WORKDIR /opt
COPY smoke-test.t .

ENV NAMESPACE=test

CMD ["sh", "-c", "stern -A -l app.kubernetes.io/name=jetstack-secure-gcm & cram smoke-test.t"]
