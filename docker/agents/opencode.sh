#!/usr/bin/env bash
# ── Install opencode agent ───────────────────────────────────────────
# Called by the Dockerfile at build time.
# Prerequisites: curl (already in base image)
set -euo pipefail

echo "[agent] Installing opencode …"
curl -fsSL https://opencode.ai/install | bash -s -- --no-modify-path
echo "[agent] opencode installed."

