# ── uv stage (pinned to amd64 so the binary matches the runtime arch) ────────
FROM --platform=linux/amd64 ghcr.io/astral-sh/uv:latest AS uv

# ── Builder stage ────────────────────────────────────────────────────
FROM --platform=linux/amd64 debian:stable-slim AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    gcc \
    libffi-dev \
    libssl-dev \
    build-essential \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Install Rust (needed by py-rust-stemmers / fastembed transitive dep)
RUN curl https://sh.rustup.rs -sSf | sh -s -- -y --profile minimal
ENV PATH="/root/.cargo/bin:${PATH}"

# Install uv
COPY --from=uv /uv /uvx /usr/local/bin/

# Install Python via uv
ENV UV_PYTHON_INSTALL_DIR=/python
ENV UV_PYTHON_PREFERENCE=only-managed
RUN uv python install

# Install basic-memory (latest); tool envs land in /root/.local/share/uv/tools/
ENV UV_TOOL_BIN_DIR=/usr/local/bin
RUN uv tool install basic-memory


# ── Final stage ──────────────────────────────────────────────────────
FROM --platform=linux/amd64 debian:stable-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    libffi8 \
    libssl3 \
    && rm -rf /var/lib/apt/lists/*

# uv binary (needed at runtime for PATH / managed-python resolution)
COPY --from=uv /uv /uvx /usr/local/bin/

# uv-managed Python
COPY --from=builder /python /python
ENV UV_PYTHON_INSTALL_DIR=/python
ENV UV_PYTHON_PREFERENCE=only-managed
ENV PATH="/python/bin:${PATH}"

# basic-memory tool environment + binary
COPY --from=builder /root/.local/share/uv/tools /root/.local/share/uv/tools
COPY --from=builder /usr/local/bin/basic-memory /usr/local/bin/basic-memory

# ── Data & config directories ─────────────────────────────────────────
# /app/data – mount your knowledge-base / Obsidian vault here
RUN mkdir -p /app/data /app/.basic-memory

WORKDIR /app/data

# ── Runtime configuration ─────────────────────────────────────────────
ENV BASIC_MEMORY_DEFAULT_PROJECT=main
ENV BASIC_MEMORY_SYNC_CHANGES=true
ENV BASIC_MEMORY_LOG_LEVEL=INFO
ENV BASIC_MEMORY_SYNC_DELAY=1000

# Run the MCP server over HTTP (streamable-http) so the container is reachable
# as a networked service. stdio transport requires a parent MCP client process
# on the same stdin/stdout and is not suitable for Docker service deployments.
CMD ["basic-memory", "mcp", "--transport", "streamable-http", "--host", "0.0.0.0", "--port", "8000"]
