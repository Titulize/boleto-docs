# Ambiente do site de documentação (Docusaurus) sobre Amazon Linux 2023.
# Os valores do bloco abaixo vêm do versions.toml (npm run sync). A CI falha se divergirem.

# >>> platform-versions
# Gerado por sync-versions.mjs a partir de versions.toml (local). Não edite este bloco.
ARG AL2023_IMAGE=public.ecr.aws/amazonlinux/amazonlinux:2023.12.20261117.0@sha256:3f018977be7a3473a0a473ed105b244b8bdec8683ecb24962f675db23017137b
ARG NODE_VERSION=26.13.1
ARG NODE_SHA256_X64=5c063e46bab0fbc1c17cc445d7ff129cbdcd0471be6ed83b6ab864f8143bc864
ARG NODE_SHA256_ARM64=89e1853138db51e8b82d3e98ba9c0d3f2956a28e5e55ea1b7e12d25aae92d5dd
# <<< platform-versions

FROM ${AL2023_IMAGE}

ARG TARGETARCH
ARG NODE_VERSION
ARG NODE_SHA256_X64
ARG NODE_SHA256_ARM64

RUN dnf install -y --setopt=install_weak_deps=False tar xz gzip shadow-utils libatomic \
    && dnf clean all \
    && rm -rf /var/cache/dnf

# Node.js oficial, com verificação de sha256.
RUN set -eux; \
    case "${TARGETARCH:-amd64}" in \
      amd64) NODE_ARCH=x64; NODE_SHA256="${NODE_SHA256_X64}" ;; \
      arm64) NODE_ARCH=arm64; NODE_SHA256="${NODE_SHA256_ARM64}" ;; \
      *) echo "arquitetura não suportada: ${TARGETARCH}" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://nodejs.org/dist/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-${NODE_ARCH}.tar.xz" -o /tmp/node.tar.xz; \
    echo "${NODE_SHA256}  /tmp/node.tar.xz" | sha256sum -c -; \
    tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1; \
    rm /tmp/node.tar.xz; \
    node --version; npm --version

RUN useradd --create-home --uid 1000 app \
    && mkdir -p /app/node_modules \
    && chown -R app:app /app

USER app
WORKDIR /app
ENV NODE_ENV=development \
    DO_NOT_TRACK=1 \
    DOCUSAURUS_IGNORE_SSG_WARNINGS=false

EXPOSE 3000
CMD ["sh", "-c", "npm ci --no-audit --no-fund && npm run start"]
