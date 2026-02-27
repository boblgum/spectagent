#!/usr/bin/env bash
# ── Install Claude Code agent ────────────────────────────────────────
# Called by the Dockerfile at build time.
# Uses the recommended installer (requires Node.js).
# Prerequisites: curl (already in base image)
set -euo pipefail

echo "[agent] Installing Node.js 22 (required by Claude Code) …"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y --no-install-recommends nodejs
rm -rf /var/lib/apt/lists/*

echo "[agent] Installing Claude Code (recommended installer) …"
curl -fsSL https://claude.ai/install.sh | bash

echo "[agent] Verifying claude binary …"
export PATH="/root/.local/bin:${PATH}"
which claude
claude --version

echo "[agent] Claude Code installed."

