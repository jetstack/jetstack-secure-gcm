# This image is the "smoke-test" image. It is meant to be made available to
# "mpdev verify" and performs simple high-level tests such as "can we issue
# a certificate using the Google CAS issuer?"

FROM gcr.io/cloud-marketplace-tools/testrunner:0.1.2

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget dnsutils netcat jq \
    && rm -rf /var/lib/apt/lists/*

RUN mkdir -p /opt/kubectl/1.19 \
    && wget -q -O /opt/kubectl/1.19/kubectl \
        https://storage.googleapis.com/kubernetes-release/release/v1.19.6/bin/linux/amd64/kubectl \
    && chmod 755 /opt/kubectl/1.19/kubectl \
    && ln -s /opt/kubectl/1.19/kubectl /usr/bin/kubectl

COPY smoke-test-suite.yaml /smoke-test-suite.yaml

WORKDIR /
ENTRYPOINT ["testrunner", "-logtostderr", "--test_spec=/smoke-test-suite.yaml"]
