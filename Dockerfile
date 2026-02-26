FROM debian:stable-slim

# ── System dependencies ──────────────────────────────────────────────
RUN apt-get update && apt-get install -y --no-install-recommends \
    bash \
    curl \
    ca-certificates \
    git \
    gcc \
    libffi-dev \
    libssl-dev \
    && rm -rf /var/lib/apt/lists/*

# ── Install uv (Python package manager) ─────────────────────────────
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /usr/local/bin/

# ── Install latest stable Python via uv ──────────────────────────────
ENV UV_PYTHON_INSTALL_DIR=/python
ENV UV_PYTHON_PREFERENCE=only-managed
RUN uv python install

# Ensure uv-managed Python is on PATH
ENV PATH="/python/bin:${PATH}"

# Make uv tool binaries globally available
ENV UV_TOOL_BIN_DIR=/usr/local/bin

# ── Install opencode agent ───────────────────────────────────────────
RUN curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
ENV PATH="/root/.opencode/bin:${PATH}"

# ── Install GitHub Spec-Kit ─────────────────────────────────────────
RUN uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# ── Config & workspace directories ───────────────────────────────────
# Created here so they exist in the image; mounted from host at runtime
RUN mkdir -p /workspace \
             /root/.config/opencode \
             /root/.config/git

WORKDIR /workspace

# ── Entrypoint: loads Docker secrets into env vars at runtime ────────
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# ── Initialize Spec-Kit in workspace with opencode agent ─────────────
RUN specify init . --ai opencode --no-git --script sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]

