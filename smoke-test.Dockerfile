# This image runs the smoke tests. It is meant to be made available to the
# command:
#
#     mpdev verify
#
# This smoke test performs simple high-level check such as "can we issue a
# certificate using the Google CAS issuer?"

# Dockerfile: https://github.com/GoogleCloudPlatform/marketplace-testrunner/blob/master/Dockerfile
FROM python:alpine

RUN apk add curl patch bash
RUN pip3 install cram
RUN curl -L https://storage.googleapis.com/kubernetes-release/release/v1.19.6/bin/linux/amd64/kubectl --output-dir /usr/local/bin -O \
    && chmod 755 /usr/local/bin/kubectl

WORKDIR /opt
COPY smoke-test.t .

ENV NAMESPACE=test

# We don't use "kubectl logs" because we need to know to which container each
# logs comes from. Also, stern follows logs and never returns, so we do the
# pause trick.
CMD ["sh", "-c", "cram smoke-test.t"]
