#!/usr/bin/env bash
# ── Brain Ingest Script ───────────────────────────────────────────────────────
# Pushes priority knowledge from the spectagent project into Basic Memory via
# its HTTP API.  Run from inside the spectagent container:
#
#   make brain-ingest           # seed / refresh all priority knowledge
#   make brain-sync             # same, used after a feature is completed
#
# The script is idempotent: re-running it updates existing notes (upsert).
#
# Environment:
#   BRAIN_URL   – base URL of the Basic Memory server (default: http://brain:8000)
#   WORKSPACE   – workspace root inside the container   (default: /workspace)
#
# Exit codes:
#   0 – all notes written successfully
#   1 – brain unreachable or one or more writes failed
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

BRAIN_URL="${BRAIN_URL:-http://brain:8000}"
WORKSPACE="${WORKSPACE:-/workspace}"
PROJECT="spectagent"

OK=0
FAIL=0

# ── Helpers ───────────────────────────────────────────────────────────────────

# Check brain reachability
check_brain() {
    if ! curl -sf "${BRAIN_URL}/health" > /dev/null 2>&1; then
        echo "[brain] ERROR  Cannot reach brain at ${BRAIN_URL}" >&2
        echo "[brain]        Make sure 'make brain-start' has been run first." >&2
        exit 1
    fi
    echo "[brain] OK     Brain reachable at ${BRAIN_URL}"
}

# Write a note to Basic Memory.
# Usage: write_note <path-in-brain> <title> <tags-csv> <content>
write_note() {
    local note_path="$1"
    local title="$2"
    local tags="$3"
    local content="$4"

    # Build JSON tags array from csv
    local tags_json
    tags_json="$(printf '%s' "$tags" | tr ',' '\n' | \
        awk 'NF{gsub(/^[[:space:]]+|[[:space:]]+$/, ""); printf "\"%s\",", $0}' | \
        sed 's/,$//')"
    tags_json="[${tags_json}]"

    local payload
    payload="$(printf '{"path":"%s","title":"%s","content":%s,"project":"%s","tags":%s}' \
        "$note_path" \
        "$(printf '%s' "$title"  | sed 's/"/\\"/g')" \
        "$(printf '%s' "$content" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))')" \
        "$PROJECT" \
        "$tags_json")"

    local http_status
    http_status="$(curl -sf -o /dev/null -w "%{http_code}" \
        -X POST "${BRAIN_URL}/api/notes" \
        -H "Content-Type: application/json" \
        -d "$payload" 2>&1)" || true

    if [[ "$http_status" == "200" || "$http_status" == "201" ]]; then
        echo "[brain] OK     ${note_path}"
        OK=$((OK + 1))
    else
        echo "[brain] FAIL   ${note_path}  (HTTP ${http_status})" >&2
        FAIL=$((FAIL + 1))
    fi
}

# Write a note whose content comes from an existing file.
# Usage: write_note_from_file <path-in-brain> <title> <tags-csv> <source-file>
write_note_from_file() {
    local note_path="$1"
    local title="$2"
    local tags="$3"
    local source="$4"

    if [ ! -f "$source" ]; then
        echo "[brain] SKIP   ${note_path}  (source not found: ${source})"
        return
    fi

    write_note "$note_path" "$title" "$tags" "$(cat "$source")"
}

# ── Ingest sections ───────────────────────────────────────────────────────────

ingest_infrastructure() {
    echo ""
    echo "[brain] ── Infrastructure knowledge ──────────────────────────────"

    # Dockerfile – tool locations, build steps
    write_note_from_file \
        "infrastructure/dockerfile" \
        "Spectagent Dockerfile" \
        "infrastructure,docker,build" \
        "/brain/../docker/Dockerfile"  # adjusted path via the :ro mount at /brain

    # Entrypoint – secrets loading mechanism
    write_note_from_file \
        "infrastructure/entrypoint" \
        "Container Entrypoint & Secrets Loading" \
        "infrastructure,docker,secrets" \
        "/brain/entrypoint.sh"

    # docker-compose – service topology
    write_note_from_file \
        "infrastructure/docker-compose" \
        "Docker Compose Service Topology" \
        "infrastructure,docker,volumes" \
        "/brain/docker-compose.yml"
}

ingest_spectagent_meta() {
    echo ""
    echo "[brain] ── Spectagent meta knowledge ─────────────────────────────"

    # AGENTS.md – pipeline, anti-patterns, conventions (Tier 1)
    write_note_from_file \
        "spectagent/agents-knowledge" \
        "SpecKit Pipeline & Agent Conventions (AGENTS.md)" \
        "speckit,pipeline,conventions,anti-patterns,tier1" \
        "${WORKSPACE}/AGENTS.md"

    # README – feature overview and command reference (Tier 1)
    write_note_from_file \
        "spectagent/readme" \
        "SpecKit README – Commands & Integration" \
        "speckit,commands,readme,tier1" \
        "${WORKSPACE}/README.md"
}

ingest_constitution() {
    echo ""
    echo "[brain] ── Project constitutions ─────────────────────────────────"

    local found=0
    # Glob all constitution files across specs directories
    while IFS= read -r -d '' constitution; do
        local rel="${constitution#${WORKSPACE}/}"
        local feature_dir
        feature_dir="$(dirname "$rel")"  # e.g. specs/001-user-auth/memory
        write_note_from_file \
            "constitutions/${feature_dir//\//-}" \
            "Constitution: ${feature_dir}" \
            "constitution,governance,tier1" \
            "$constitution"
        found=$((found + 1))
    done < <(find "${WORKSPACE}" -path "*/.specify/memory/constitution.md" -print0 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        echo "[brain] SKIP   No constitution.md files found under ${WORKSPACE}"
    fi
}

ingest_spec_artifacts() {
    echo ""
    echo "[brain] ── Spec artifacts (closed features) ──────────────────────"

    local found=0
    # Iterate over all specs/<NNN-*>/ directories
    while IFS= read -r -d '' spec_dir; do
        local feature
        feature="$(basename "$spec_dir")"

        for artifact in spec.md plan.md data-model.md research.md; do
            local src="${spec_dir}/${artifact}"
            [ -f "$src" ] || continue

            local note_key="${artifact%.md}"
            write_note_from_file \
                "specs/${feature}/${note_key}" \
                "${feature}: ${artifact}" \
                "spec,${note_key},tier2" \
                "$src"
            found=$((found + 1))
        done

        # contracts/ directory
        if [ -d "${spec_dir}/contracts" ]; then
            while IFS= read -r -d '' contract; do
                local cname
                cname="$(basename "$contract" .md)"
                write_note_from_file \
                    "specs/${feature}/contracts/${cname}" \
                    "${feature}: contract/${cname}" \
                    "spec,contract,tier2" \
                    "$contract"
                found=$((found + 1))
            done < <(find "${spec_dir}/contracts" -name "*.md" -print0 2>/dev/null)
        fi
    done < <(find "${WORKSPACE}/specs" -maxdepth 1 -mindepth 1 -type d -print0 2>/dev/null)

    if [ "$found" -eq 0 ]; then
        echo "[brain] SKIP   No spec artifacts found under ${WORKSPACE}/specs"
    fi
}

ingest_model_catalogue() {
    echo ""
    echo "[brain] ── Provider / model catalogue ───────────────────────────"

    local cfg="/root/.config/opencode/opencode.json"
    if [ -f "$cfg" ]; then
        write_note_from_file \
            "infrastructure/model-catalogue" \
            "AI Provider & Model Catalogue (opencode.json)" \
            "models,providers,infrastructure,tier4" \
            "$cfg"
    else
        echo "[brain] SKIP   opencode.json not found at ${cfg}"
    fi
}

# ── Summary ───────────────────────────────────────────────────────────────────

summary() {
    echo ""
    echo "[brain] ────────────────────────────────────────────────────────"
    echo "[brain] Ingest complete.  OK: ${OK}   FAILED: ${FAIL}"
    echo "[brain] Brain URL: ${BRAIN_URL}"
    echo "[brain] ────────────────────────────────────────────────────────"
    if [ "$FAIL" -gt 0 ]; then
        exit 1
    fi
}

# ── Main ─────────────────────────────────────────────────────────────────────

main() {
    echo "[brain] Starting brain ingest …"
    check_brain
    ingest_infrastructure
    ingest_spectagent_meta
    ingest_constitution
    ingest_spec_artifacts
    ingest_model_catalogue
    summary
}

main "$@"

