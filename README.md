# Agentic – Opencode Docker Image

A self-contained Docker image based on **Alpine Linux (latest)** that bundles:

| Tool | Purpose |
|---|---|
| **uv** | Fast Python package & project manager |
| **Python** (latest stable, managed by uv) | Runtime |
| **git** (latest from Alpine repos) | Version control |
| **opencode** (latest stable) | AI coding agent |

## Quick start

```bash
# 1. First-time setup: creates .env, builds the image, starts the container
make init

# 2. Edit .env with your API keys and config/git/.gitconfig with your identity

# 3. Open a shell inside the running container
make shell
```

Inside the container you have `uv`, `python`, `git`, `opencode`, and `specify` available.

## Makefile targets

Run `make help` to list all available targets:

```
  build        Build (or rebuild) the Docker image
  up           Start container in the background
  down         Stop and remove the container
  restart      Rebuild image and restart container
  logs         Follow container logs
  shell        Open a bash shell inside the container
  opencode     Run opencode inside the container
  specify      Run specify (spec-kit) inside the container
  python       Run python inside the container
  uv           Run uv inside the container
  git          Run git inside the container
  env          Create .env from template if it does not exist yet
  init         Full first-time setup: create .env, build image, start container
```

**Lifecycle targets** (`build`, `up`, `down`, `restart`, `logs`) already have necessary flags built in, so just run them directly:

```bash
make up        # already runs with -d flag
make restart   # already runs with --build flag
make logs      # already follows output
```

**Tool targets** accept arguments directly (no `ARGS=` parameter needed):

```bash
make opencode --help
make specify check
make python -c 'import sys; print(sys.version)'
make git status
make uv --version
```

Or use the `ARGS` variable for more complex commands:

```bash
make opencode ARGS="--help"
make specify ARGS="check"
```

## Directory layout

```
agentic/
├── Dockerfile
├── docker-compose.yml
├── .env.example          # template – copy to .env
├── .dockerignore
├── config/
│   ├── opencode/         # → mounted to /root/.config/opencode
│   │   └── .gitkeep
│   └── git/
│       └── .gitconfig    # → mounted to /root/.gitconfig (read-only)
└── workspace/            # → mounted to /workspace (the working directory)
    └── .gitkeep
```

## Volumes / mounts

All configuration and the workspace are **mounted from the host** – nothing is baked into the image.

| Host path (default) | Container path | Mode |
|---|---|---|
| `./workspace` | `/workspace` | read-write |
| `./config/opencode` | `/root/.config/opencode` | read-write |
| `./config/git/.gitconfig` | `/root/.gitconfig` | read-only |

Override the host paths via environment variables in `.env`:

- `APP_DIR` – workspace directory
- `OPENCODE_CONFIG_DIR` – opencode config directory
- `GIT_CONFIG_FILE` – git global config file

## Environment variables

Pass API keys required by opencode through `.env`:

```dotenv
ANTHROPIC_API_KEY=sk-ant-...
OPENAI_API_KEY=sk-...
```

## Building the image only

```bash
make build
```

## Running without Compose

```bash
docker run -it --rm \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/config/opencode:/root/.config/opencode" \
  -v "$(pwd)/config/git/.gitconfig:/root/.gitconfig:ro" \
  -e ANTHROPIC_API_KEY="$ANTHROPIC_API_KEY" \
  agentic-opencode:latest
```

