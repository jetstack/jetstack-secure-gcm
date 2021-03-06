# This image runs the smoke tests. It is meant to be made available to the
# command:
#
#     mpdev verify
#
# This smoke test performs simple high-level check such as "can we issue a
# certificate using the Google CAS issuer?"

# Dockerfile: https://github.com/GoogleCloudPlatform/marketplace-testrunner/blob/master/Dockerfile
FROM gcr.io/cloud-marketplace-tools/testrunner:0.1.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget dnsutils netcat jq \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/kubectl/1.19 \
    && wget -q -O /opt/kubectl/1.19/kubectl \
        https://storage.googleapis.com/kubernetes-release/release/v1.19.6/bin/linux/amd64/kubectl \
    && chmod 755 /opt/kubectl/1.19/kubectl \
    && ln -s /opt/kubectl/1.19/kubectl /usr/bin/kubectl

COPY smoke-test.yaml /smoke-test.yaml

WORKDIR /
ENTRYPOINT ["testrunner", "-logtostderr", "--test_spec=/smoke-test.yaml"]
