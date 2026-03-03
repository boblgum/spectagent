#!/usr/bin/env bash
# ── Load Docker secrets into environment variables ────────────────────
# Docker Compose mounts each secret as a read-only file on tmpfs at
# /run/secrets/<name>.  Tools like opencode expect plain env vars,
# so we bridge the two here.
#
# Every file found in /run/secrets/ is exported as an upper-cased
# environment variable (e.g. /run/secrets/anthropic_api_key → ANTHROPIC_API_KEY).
#
# Safety measures:
#   • A blocklist prevents overwriting security-critical env vars.
#   • Filenames are sanitised to valid shell variable names.
#   • Only trailing whitespace / newlines are stripped (internal
#     spaces in values are preserved).
set -euo pipefail

SECRETS_DIR="/run/secrets"

# ── Env vars that must never be overwritten by a secret file ──────────
BLOCKED="PATH LD_PRELOAD LD_LIBRARY_PATH HOME USER LOGNAME SHELL TERM HOSTNAME IFS"

is_blocked() {
    local check="$1"
    for b in $BLOCKED; do
        [ "$check" = "$b" ] && return 0
    done
    return 1
}

if [ -d "$SECRETS_DIR" ]; then
    for file in "$SECRETS_DIR"/*; do
        [ -f "$file" ] || continue

        # derive env var name: basename → sanitise → UPPER_CASE
        name="$(basename "$file")"

        # replace any character that is not alphanumeric or underscore
        var="$(printf '%s' "$name" | sed 's/[^a-zA-Z0-9_]/_/g' | tr '[:lower:]' '[:upper:]')"

        # skip empty or invalid names (must not start with a digit)
        if [ -z "$var" ] || printf '%s' "$var" | grep -qE '^[0-9]'; then
            echo "[secrets] SKIP  invalid var name derived from: $name" >&2
            continue
        fi

        # guard against overwriting critical variables
        if is_blocked "$var"; then
            echo "[secrets] SKIP  blocked var: $var (from $name)" >&2
            continue
        fi

        # read value, strip only trailing whitespace (preserve internal spaces)
        val="$(sed -e 's/[[:space:]]*$//' "$file")"

        if [ -n "$val" ]; then
            export "$var=$val"
            echo "[secrets] OK    $var loaded" >&2
        else
            echo "[secrets] SKIP  $name is empty" >&2
        fi
    done
fi

# ── Initialize Spec-Kit in workspace (once) ───────────────────────────
# specify init creates .specify/ and .opencode/ directories.
# This must run at container start (not at build time) because
# /workspace is a volume mount that hides the image layer.
if [ ! -d "/workspace/.specify" ]; then
    echo "[spec-kit] Initializing Spec-Kit in /workspace …" >&2
    specify init . --ai opencode --no-git --force --script sh 2>&1 | sed 's/^/[spec-kit] /' >&2
    echo "[spec-kit] Done." >&2
else
    echo "[spec-kit] .specify/ already exists, skipping init." >&2
fi

# ── Install / configure oh-my-opencode (once) ─────────────────────────
# oh-my-opencode writes its config into the opencode.json that lives in
# /root/.config/opencode (bind-mounted from host config/opencode/).
# The installer is run non-interactively using the OMC_FLAGS env var,
# which is written to .env on the host by  make omc-setup  and injected
# into the container via docker-compose.yml environment: block.
#
# We use a sentinel file (.omc-installed) inside the opencode config dir
# so the installer only runs once per host config directory.
OMC_SENTINEL="/root/.config/opencode/.omc-installed"

if [ -z "${OMC_FLAGS:-}" ]; then
    echo "[omc] OMC_FLAGS not set — skipping oh-my-opencode install." >&2
    echo "[omc] Run  make omc-setup  then  make restart  to configure." >&2
elif [ -f "$OMC_SENTINEL" ]; then
    echo "[omc] oh-my-opencode already configured, skipping install." >&2
else
    echo "[omc] Running oh-my-opencode installer with flags: $OMC_FLAGS" >&2
    # shellcheck disable=SC2086
    if bunx oh-my-opencode install $OMC_FLAGS 2>&1 | sed 's/^/[omc] /' >&2; then
        touch "$OMC_SENTINEL"
        echo "[omc] Installation complete. Sentinel written to $OMC_SENTINEL" >&2
    else
        echo "[omc] Installation failed — check logs above." >&2
    fi
fi

exec "$@"

