# ── Build stage ──────────────────────────────────────────
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    build-essential \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://go.dev/dl/go1.26.2.linux-$(dpkg --print-architecture).tar.gz | tar -C /usr/local -xzf -
ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /build

COPY installer/go.mod installer/go.sum ./
RUN go mod download

COPY installer/ ./
RUN go build -o /build/dots ./cmd/dots

# ── Runtime stage ───────────────────────────────────────
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive
ENV HOME=/root

RUN apt-get update && apt-get install -y \
    curl \
    git \
    locales \
    sudo \
    zsh \
    python3 \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

RUN locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8
ENV LC_ALL=en_US.UTF-8

WORKDIR /app
ENV DOTFILES_DIR=/app
ENV PATH="/app:${PATH}"

# Only copy what's needed for installation
COPY --from=builder /build/dots .
COPY home ./home
COPY assets ./assets
COPY installer/e2e ./installer/e2e

RUN chmod +x installer/e2e/e2e_test.sh

CMD ["./dots", "install", "--yes"]
