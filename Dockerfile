FROM debian:bookworm-20230725-slim
ARG AZURE_CLI_VERSION
ARG TERRAFORM_VERSION
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    gosu=1.14-1+b6 \
    ca-certificates=20230311 \
    curl=7.88.1-10+deb12u1 \
    gnupg=2.2.40-1.1 \
    apt-transport-https=2.6.1 \
    lsb-release=12.0-1 \
    software-properties-common=0.99.30-4 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN mkdir -p /etc/apt/keyrings && \
    curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | tee /etc/apt/keyrings/microsoft.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/microsoft.gpg && \
    AZ_REPO=$(lsb_release -cs) && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ $AZ_REPO main" | \
    tee /etc/apt/sources.list.d/azure-cli.list

RUN curl -sLS https://apt.releases.hashicorp.com/gpg | gpg --dearmor | tee /etc/apt/keyrings/hashicorp-archive-keyring.gpg > /dev/null && \
    chmod go+r /etc/apt/keyrings/hashicorp-archive-keyring.gpg && \
    echo "deb [signed-by=//etc/apt/keyrings/hashicorp-archive-keyring.gpg] \
    https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
    tee /etc/apt/sources.list.d/hashicorp.list

RUN apt-get update && \
    apt-get install --no-install-recommends -y azure-cli="${AZURE_CLI_VERSION}" terraform="${TERRAFORM_VERSION}" && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN groupadd --gid 1001 nonroot && \
    # user needs a home folder to store azure credentials
    useradd --gid nonroot --create-home --uid 1001 nonroot && \
    chown nonroot:nonroot /workspace
USER nonroot

ENTRYPOINT ["terraform"]
