# Build arguments
ARG AZURE_CLI_VERSION
ARG TERRAFORM_VERSION
ARG PYTHON_MAJOR_VERSION=3.11
ARG DEBIAN_VERSION=bookworm-20230725-slim
ARG CURL=7.88.1-10+deb12u1
ARG CA-CERTIFICATES=20230311
ARG GIT=1:2.30.2-1+deb11u2
ARG GNUPG=2.2.40-1.1
ARG PYTHON3=${PYTHON_MAJOR_VERSION}.2-1+b1
ARG PYTHON3-PIP=23.0.1+dfsg-1
ARG PYTHON3-DISTUTILS=${PYTHON_MAJOR_VERSION}.2-3
ARG PYPI_PIP_VERSION=23.2.1
ARG SETUPTOOLS=68.0.0
ARG UNZIP=6.0-28

# Download Terraform binary
FROM debian:${DEBIAN_VERSION} as terraform-cli
ARG TERRAFORM_VERSION
RUN apt-get update
RUN apt-get install --no-install-recommends -y CURL=${CURL}
RUN apt-get install --no-install-recommends -y ca-certificates=${CA-CERTIFICATES}
RUN apt-get install --no-install-recommends -y unzip=${UNZIP}
RUN apt-get install --no-install-recommends -y gnupg=${GNUPG}
WORKDIR /workspace
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
RUN curl -Os https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig
COPY hashicorp.asc hashicorp.asc
RUN gpg --import hashicorp.asc
RUN gpg --verify terraform_${TERRAFORM_VERSION}_SHA256SUMS.sig terraform_${TERRAFORM_VERSION}_SHA256SUMS
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN grep terraform_${TERRAFORM_VERSION}_linux_amd64.zip terraform_${TERRAFORM_VERSION}_SHA256SUMS | sha256sum -c -
RUN unzip -j terraform_${TERRAFORM_VERSION}_linux_amd64.zip

# Install az CLI using PIP
FROM debian:${DEBIAN_VERSION} as azure-cli
ARG AZURE_CLI_VERSION
ARG PYTHON_MAJOR_VERSION
RUN apt-get update
RUN apt-get install -y --no-install-recommends python3=${PYTHON3}
RUN apt-get install -y --no-install-recommends python3-pip=${PYTHON3-PIP}
RUN python -m pip install --upgrade pip==${PYPI_PIP_VERSION}
RUN pip3 install --no-cache-dir setuptools==${SETUPTOOLS}
RUN pip3 install --no-cache-dir azure-cli==${AZURE_CLI_VERSION}

# Build final image
FROM debian:${DEBIAN_VERSION}
LABEL maintainer="bgauduch@github"
ARG PYTHON_MAJOR_VERSION
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates=${CA-CERTIFICATES} \
    git=${GIT} \
    python3=${PYTHON3} \
    python3-distutils=${PYTHON3-DISTUTILS} \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* \
  && update-alternatives --install /usr/bin/python python /usr/bin/python${PYTHON_MAJOR_VERSION} 1
WORKDIR /workspace
COPY --from=terraform-cli /workspace/terraform /usr/local/bin/terraform
COPY --from=azure-cli /usr/local/bin/az* /usr/local/bin/
COPY --from=azure-cli /usr/local/lib/python${PYTHON_MAJOR_VERSION}/dist-packages /usr/local/lib/python${PYTHON_MAJOR_VERSION}/dist-packages
COPY --from=azure-cli /usr/lib/python3/dist-packages /usr/lib/python3/dist-packages

RUN groupadd --gid 1001 nonroot \
  # user needs a home folder to store azure credentials
  && useradd --gid nonroot --create-home --uid 1001 nonroot \
  && chown nonroot:nonroot /workspace
USER nonroot

CMD ["bash"]
