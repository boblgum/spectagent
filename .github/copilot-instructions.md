# Spectagent – Project Context

## What this project is
A self-contained Docker image (Debian stable-slim) that bundles `uv`, Python (uv-managed), `git`, a selectable AI coding agent (opencode or claude), and `specify` (GitHub spec-kit CLI). The container mounts a local `workspace/` directory and config files at runtime.

## Repository layout
```
spectagent/
├── Makefile                                # all daily-driver commands
├── README.md
├── .agent                                  # persisted agent choice (git-ignored)
├── .dockerignore
├── .gitignore
├── docker/
│   ├── Dockerfile                          # image definition
│   ├── agents/                             # one install script per AI agent
│   │   ├── opencode.sh                     # installs opencode
│   │   └── claude.sh                       # installs Node.js + Claude Code
│   ├── docker-compose.yml                  # base compose file
│   ├── docker-compose.secrets.yml          # active secrets (git-ignored)
│   ├── docker-compose.secrets.yml.example  # committed template
│   ├── .env                                # host paths (git-ignored)
│   ├── .env.example                        # template for .env
│   └── entrypoint.sh                       # loads /run/secrets/* into env vars
├── config/
│   ├── git/                                # → /root/.config/git (mounted read-only)
│   ├── opencode/                           # → /root/.config/opencode (mounted)
│   └── claude/                             # → /root/.config/claude (mounted)
├── secrets/                                # one API key per file, chmod 600 (git-ignored)
└── workspace/                              # mounted as /workspace inside container (git-ignored)
```

## Agent system
The AI agent is selected at build time via the `AGENT` build arg (persisted in `.agent` file).
Each agent has a self-contained install script in `docker/agents/<name>.sh` that handles all
prerequisites and the agent installation itself. The Dockerfile copies all scripts in, validates
the selection, runs the matching script, and cleans up.

To add a new agent: create `docker/agents/<name>.sh`, add it to the `select-agent` menu in the
Makefile, create `config/<name>/` if the agent needs host-mounted config, and add a volume mount
in `docker-compose.yml`.

## Tech stack
- **Base image**: `debian:stable-slim`
- **Python toolchain**: `uv` (installed from `ghcr.io/astral-sh/uv:latest`)
- **Python**: latest stable, managed by uv, installed to `/python`
- **AI agent**: selected via `AGENT` build arg; install scripts live in `docker/agents/`
  - `opencode`: installed via `curl -fsSL https://opencode.ai/install`, lives at `/root/.opencode/bin`
  - `claude`: Node.js 22 + `npm install -g @anthropic-ai/claude-code`
- **specify**: installed via `uv tool install specify-cli` from `github/spec-kit`, binary at `/usr/local/bin`
- **Compose**: two-file merge — `docker-compose.yml` (base) + `docker-compose.secrets.yml` (secrets overlay)

## Makefile targets
| Target | What it does |
|---|---|
| `make build` | Build/rebuild image (`--pull --no-cache`) with selected agent |
| `make rebuild` | Alias for `make build` |
| `make select-agent` | Interactive menu to choose the AI coding agent |
| `make shell` | Open bash in an ephemeral container (`--rm`) |
| `make opencode [args]` | Run `opencode` in an ephemeral container (`--rm`) |
| `make claude [args]` | Run `claude` in an ephemeral container (`--rm`) |
| `make specify [args]` | Run `specify` in an ephemeral container (`--rm`) |
| `make python [args]` | Run `python` in an ephemeral container (`--rm`) |
| `make uv [args]` | Run `uv` in an ephemeral container (`--rm`) |
| `make git [args]` | Run `git` in an ephemeral container (`--rm`) |
| `make env` | Create `.env` from template (once) |
| `make secrets` | Create `docker-compose.secrets.yml` from example (once) |
| `make init` | Full first-time setup: env → secrets → build |

Tool targets accept trailing args directly: `make specify check` or via `ARGS=`: `make specify ARGS="check"`.

There is **no long-running background service**. Every tool target starts a fresh container on demand and removes it automatically when the command finishes (`docker compose run --rm`).

## Secrets pattern
Each API key lives in its own file under `secrets/` (e.g. `secrets/anthropic_api_key.txt`, `chmod 600`).  
`entrypoint.sh` reads every file under `/run/secrets/` and exports its content as an environment variable named after the file.  
`docker-compose.secrets.yml` maps those secret files and controls which providers are active — edit it to enable/disable providers.

## Important conventions
- Never commit `secrets/`, `.env`, `.agent`, or `docker-compose.secrets.yml` (all git-ignored).
- The compose command always merges both files: `docker compose -f docker/docker-compose.yml -f docker/docker-compose.secrets.yml`.
- `config/git/`, `config/opencode/`, and `config/claude/` are bind-mounted into the container — edit them on the host, they take effect on the next container start (or immediately for opencode config).
- `workspace/` on the host maps to `/workspace` inside the container — this is where all project work happens.
- Agent install scripts in `docker/agents/` must be self-contained: install all prerequisites and the agent itself, clean up apt lists.
- Before any implementation or changes to existing files, present a numbered step-by-step plan and **stop**. Do NOT proceed until the user has explicitly confirmed. This overrides any default agent behavior to act immediately.
