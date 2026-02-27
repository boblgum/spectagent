FROM debian:stable-slim

# ── Build argument: which AI agent to install ────────────────────────
# Supported values: opencode, claude
# Each agent has a matching install script in docker/agents/<name>.sh
ARG AGENT=opencode

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

# ── Install AI agent (selected via AGENT build arg) ─────────────────
# Each agent lives in its own install script under docker/agents/
COPY docker/agents/ /tmp/agents/
RUN chmod +x /tmp/agents/*.sh && \
    if [ ! -f "/tmp/agents/${AGENT}.sh" ]; then \
        echo "ERROR: Unknown agent '${AGENT}'. Available:" && \
        ls /tmp/agents/*.sh | sed 's|.*/||;s|\.sh$||' && \
        exit 1; \
    fi && \
    /tmp/agents/${AGENT}.sh && \
    rm -rf /tmp/agents

# Add agent binaries to PATH
# opencode → /root/.opencode/bin   claude → /root/.local/bin (recommended installer)
ENV PATH="/root/.opencode/bin:/root/.local/bin:${PATH}"

# Persist the selected agent name for the entrypoint
ENV AGENT=${AGENT}

# ── Install GitHub Spec-Kit ─────────────────────────────────────────
RUN uv tool install specify-cli --from git+https://github.com/github/spec-kit.git

# ── Config & workspace directories ───────────────────────────────────
# Created here so they exist in the image; mounted from host at runtime
# Only the selected agent gets a config directory
RUN mkdir -p /workspace \
             /root/.config/${AGENT} \
             /root/.config/git

WORKDIR /workspace

# ── Entrypoint: loads Docker secrets into env vars at runtime ────────
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh


ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]


