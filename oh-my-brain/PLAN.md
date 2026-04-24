# Mem0 OpenMemory – Integration Plan

## What is OpenMemory?

OpenMemory is Mem0's self-hosted memory stack. It consists of three Docker services:

| Service | Image | Role |
|---|---|---|
| `openmemory-mcp` | `mem0/openmemory-mcp:latest` | FastAPI backend + **MCP server** at `/mcp` (port 8765) |
| `mem0_store` | `qdrant/qdrant:latest` | Vector store (internal to the compose network) |
| `mem0_ui` *(optional)* | `mem0/openmemory-ui:latest` | React management UI (standalone `docker run`) |

opencode connects to `http://host.docker.internal:8765/mcp` via a `remote` MCP entry in
`config/opencode/opencode.json`.

## Directory layout (all files go here: `oh-my-brain/`)

```
oh-my-brain/
├── PLAN.md                         ← this file
├── docker-compose.yml              ← openmemory-mcp + qdrant (core stack)
├── docker-compose.ui.yml           ← openmemory-ui (optional overlay)
├── .env.example                    ← template for required env vars
├── .env                            ← user's actual env (git-ignored)
└── make/
    └── openmemory.mk               ← Makefile fragment, included by root Makefile
```

---

## Tasks

### Task 1 — `oh-my-brain/.env.example` ✅ done
Template for all env vars the stack needs:
- `OPENAI_API_KEY` – used by openmemory-mcp for LLM extraction and embeddings
- `USER` – memory namespace / user id (defaults to `$(whoami)`)
- `OPENMEMORY_API_PORT` – host port for the MCP/API server (default `8765`)
- `OPENMEMORY_UI_PORT` – host port for the UI (default `3000`)

**Validation:**
```bash
# File exists and contains all four expected variables
grep -c 'OPENAI_API_KEY\|USER\|OPENMEMORY_API_PORT\|OPENMEMORY_UI_PORT' oh-my-brain/.env.example
# Expected output: 4
```

---

### Task 2 — `oh-my-brain/docker-compose.yml` ✅ done
Core stack: `mem0_store` (Qdrant) + `openmemory-mcp`.
- `mem0_store`: `qdrant/qdrant:latest`, internal only, volume `qdrant_data`
- `openmemory-mcp`: `mem0/openmemory-mcp:latest`, port `${OPENMEMORY_API_PORT:-8765}:8765`,
  env `OPENAI_API_KEY`, `USER`, `QDRANT_HOST=mem0_store`, `QDRANT_PORT=6333`,
  volume `openmemory_db:/usr/src/openmemory`, depends on `mem0_store`
- Named volumes: `qdrant_data`, `openmemory_db` — persistent across restarts

**Validation:**
```bash
# Compose file parses without errors
docker compose -f oh-my-brain/docker-compose.yml --env-file oh-my-brain/.env config --quiet
# Expected: no errors, silent output
```

---

### Task 3 — `oh-my-brain/docker-compose.ui.yml` ✅ done
Optional UI overlay:
- `mem0_ui`: `mem0/openmemory-ui:latest`, port `${OPENMEMORY_UI_PORT:-3000}:3000`,
  env `NEXT_PUBLIC_API_URL=http://localhost:${OPENMEMORY_API_PORT:-8765}`,
  `NEXT_PUBLIC_USER_ID=${USER}`

**Validation:**
```bash
# Overlay file parses when merged with the core compose
docker compose -f oh-my-brain/docker-compose.yml -f oh-my-brain/docker-compose.ui.yml \
  --env-file oh-my-brain/.env config --quiet
# Expected: no errors, silent output
```

---

### Task 4 — `oh-my-brain/make/openmemory.mk` ✅ done
Makefile fragment with all management targets:

| Target | What it does |
|---|---|
| `openmemory-env` | Create `oh-my-brain/.env` from template (idempotent) |
| `openmemory-up` | Start core stack (API + Qdrant) in the background |
| `openmemory-ui` | Start UI overlay on top of the running core stack |
| `openmemory-down` | Stop stack, keep named volumes (data survives) |
| `openmemory-reset` | Stop stack + delete named volumes (full wipe, with confirm) |
| `openmemory-logs` | Tail logs of all core services |
| `openmemory-status` | Show running containers in the stack |
| `openmemory-test` | Smoke-test: API config health + MCP endpoint reachability + MCP tools list |

**Validation:**
```bash
# All targets appear in make help
make help | grep openmemory
# Expected: 8 lines, one per target

# Smoke-test passes against live stack (3 checks):
#   1. GET /api/v1/config/ → 200
#   2. POST /mcp/messages/ initialize → 200
#   3. GET /mcp/spectagent/sse/smoke-test → SSE stream with endpoint event
make openmemory-test
# Expected: ✓ All checks passed.
```

---

### Task 5 — Wire `openmemory.mk` into root `Makefile` ✅ done
Add `include make/openmemory.mk` (after existing includes).

**Validation:**
```bash
# Include line is present
grep 'openmemory.mk' Makefile
# Expected: include make/openmemory.mk

# make help resolves without errors
make help
# Expected: openmemory-* targets listed, no "missing separator" errors
```

---

### Task 6 — Register MCP server in `config/opencode/opencode.json` ✅ done
Add under `"mcp"`:
```json
"openmemory": {
  "type": "remote",
  "url": "http://host.docker.internal:8765/mcp",
  "enabled": false
}
```
Disabled by default — user enables it after `make openmemory-up` and `make openmemory-test`
confirm the stack is healthy.

**Validation:**
```bash
# File is valid JSON and contains the new entry
python3 -c "
import json, sys
cfg = json.load(open('config/opencode/opencode.json'))
mcp = cfg.get('mcp', {})
assert 'openmemory' in mcp, 'openmemory key missing'
assert mcp['openmemory']['type'] == 'remote', 'wrong type'
assert '8765' in mcp['openmemory']['url'], 'wrong port'
assert mcp['openmemory']['enabled'] == False, 'should be disabled'
print('OK')
"
# Expected: OK
```

---

### Task 7 — Update `docker/docker-compose.secrets.yml.example` ✅ done
Add a commented-out entry documenting that `openai_api_key` is required for OpenMemory.

**Validation:**
```bash
# Entry is present and commented out
grep 'openai_api_key' docker/docker-compose.secrets.yml.example
# Expected: at least two lines (one under services.spectagent.secrets, one under secrets:)
```

---

### Task 8 — Update root `README.md` ✅ done
Add a "Memory (OpenMemory)" section explaining:
- What it is and what it needs (`OPENAI_API_KEY`)
- `make openmemory-env` → fill in `.env`
- `make openmemory-up` → start stack
- `make openmemory-test` → verify
- How to enable the MCP server in `opencode.json`
- `make openmemory-ui` → optional management UI

**Validation:**
```bash
# Section heading is present
grep '## Memory' README.md
# Expected: ## Memory (OpenMemory)

# All key targets are mentioned
grep -c 'openmemory-env\|openmemory-up\|openmemory-test\|openmemory-ui' README.md
# Expected: 4
```

---

## Execution order

| # | Status | Task | Files touched |
|---|--------|------|---------------|
| 1 | ✅ done | `.env.example` | `oh-my-brain/.env.example` |
| 2 | ✅ done | Core compose | `oh-my-brain/docker-compose.yml` |
| 3 | ✅ done | UI compose overlay | `oh-my-brain/docker-compose.ui.yml` |
| 4 | ✅ done | Makefile fragment | `oh-my-brain/make/openmemory.mk` |
| 5 | ✅ done | Wire into root Makefile | `Makefile` |
| 6 | ✅ done | opencode MCP entry | `config/opencode/opencode.json` |
| 7 | ✅ done | Secrets example | `docker/docker-compose.secrets.yml.example` |
| 8 | ✅ done | README | `README.md` |

