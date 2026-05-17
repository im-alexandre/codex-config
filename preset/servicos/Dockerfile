# syntax=docker/dockerfile:1.7

ARG OLLAMA_VERSION=v0.22.1
ARG OLLAMA_BASE=ollama/ollama:latest

FROM golang:1.24-bookworm AS build
ARG OLLAMA_VERSION

RUN apt-get update \
    && apt-get install -y --no-install-recommends ca-certificates git build-essential \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /src
RUN git clone --depth 1 --branch "${OLLAMA_VERSION}" https://github.com/ollama/ollama.git .

COPY patches/ollama-embedding-num-parallel.patch /tmp/ollama-embedding-num-parallel.patch
RUN git apply --check /tmp/ollama-embedding-num-parallel.patch \
    && git apply /tmp/ollama-embedding-num-parallel.patch

RUN --mount=type=cache,target=/go/pkg/mod \
    --mount=type=cache,target=/root/.cache/go-build \
    version="${OLLAMA_VERSION#v}-codex-embedding-parallel" \
    && go build -trimpath -buildmode=pie -ldflags="-w -s -X=github.com/ollama/ollama/version.Version=${version}" -o /out/ollama .

FROM ${OLLAMA_BASE}

LABEL org.opencontainers.image.description="Ollama com patch local para respeitar OLLAMA_NUM_PARALLEL em modelos embedding-only"

COPY --from=build /out/ollama /bin/ollama
COPY --from=build /out/ollama /usr/bin/ollama
