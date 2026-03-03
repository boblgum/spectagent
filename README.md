# Spectagent – Github Spec Kit & Opencode Docker Image

A self-contained Docker image based on **Debian (stable-slim)** that bundles:

| Tool | Purpose |
|---|---|
| **uv** | Fast Python package & project manager |
| **Python** (latest stable, managed by uv) | Runtime |
| **git** (latest from Debian repos) | Version control |
| **opencode** (latest stable) | AI coding agent |
| **Bun** (latest stable) | JavaScript runtime / package runner (`bunx`) |
| **oh-my-opencode** | Agent harness for opencode — orchestrates specialist LLM agents |

## Quick start

```bash
# 1. First-time setup: creates .env, docker-compose.secrets.yml,
#    runs the oh-my-opencode subscription wizard, builds image, starts container,
#    and installs oh-my-opencode with your chosen provider flags.
make init

# 2. Edit docker/docker-compose.secrets.yml – uncomment only the providers you use

# 3. Create the secret files you selected and paste your keys
echo -n "sk-ant-…" > secrets/anthropic_api_key.txt && chmod 600 secrets/anthropic_api_key.txt

# 4. Edit config/git/.gitconfig with your identity

# 5. Restart so the container picks up the new secrets
make restart

# 6. Open a shell inside the running container
make shell
```

Inside the container you have `uv`, `python`, `git`, `opencode`, `bun`/`bunx`, and `specify` available.

## oh-my-opencode

[oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) is an agent harness that supercharges opencode with specialist LLM agents (Sisyphus, Prometheus, Oracle, …), advanced LSP/AST tools, and multi-provider model routing.

### Setup

The subscription wizard (`make omc-setup`) asks which AI provider plans you have and persists the answers to `.omc-flags` (git-ignored). The installer then runs non-interactively inside the container.

```bash
# Step 1 – answer the subscription questions (runs on the host, writes .omc-flags)
make omc-setup

# Step 2 – apply the configuration inside the running container
make omc-install
```

Both steps are run automatically by `make init`.

To change your provider choices later:

```bash
make omc-reconfigure   # re-runs wizard + reinstalls
```

### Provider priority

`Native (anthropic/, openai/, google/) > Kimi for Coding > GitHub Copilot > Venice > OpenCode Zen > Z.ai Coding Plan`

> **Note**: Without a Claude Pro/Max subscription the primary **Sisyphus** agent may not perform ideally. The wizard will warn you if you answer `no` to the Claude question.

### Authentication

After installation, authenticate each provider through opencode's auth flow:

```bash
make shell
opencode auth login   # then select provider and follow OAuth prompts
```


## Makefile targets

Run `make help` to list all available targets:

```
  build          Build (or rebuild) the Docker image
  up             Start container in the background
  down           Stop and remove the container
  restart        Rebuild image and restart container
  logs           Follow container logs
  shell          Open a bash shell inside the container
  opencode       Run opencode inside the container
  omc            Run oh-my-opencode CLI inside the container
  specify        Run specify (spec-kit) inside the container
  python         Run python inside the container
  uv             Run uv inside the container
  git            Run git inside the container
  omc-setup      Interactive wizard: choose AI provider subscriptions and save flags
  omc-install    Run the oh-my-opencode installer inside the container using saved flags
  omc-reconfigure Re-run omc-setup wizard and reinstall
  env            Create .env from template if it does not exist yet
  secrets        Create docker/docker-compose.secrets.yml from example and secrets/ dir
  init           Full first-time setup: env, secrets, omc-setup, build, start, omc-install
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
spectagent/
├── Makefile
├── README.md
├── .dockerignore
├── .gitignore
├── docker/
│   ├── Dockerfile
│   ├── docker-compose.yml                  # base – no secrets
│   ├── docker-compose.secrets.yml.example  # template – committed
│   ├── docker-compose.secrets.yml          # ← your secrets (git-ignored)
│   ├── .env.example
│   └── entrypoint.sh                       # loads /run/secrets/* into env vars
├── config/
│   ├── opencode/
│   │   └── .gitkeep
│   └── git/
│       └── .gitconfig                      # → /root/.gitconfig (read-only)
└── secrets/                                # one key per file (git-ignored)
    └── .gitkeep
```

## Volumes / mounts

All configuration and the workspace are **mounted from the host** – nothing is baked into the image.

| Host path (default) | Container path | Mode |
|---|---|---|
| `./workspace` | `/workspace` | read-write |
| `./config/opencode` | `/root/.config/opencode` | read-write |
| `./config/git/.gitconfig` | `/root/.gitconfig` | read-only |
| `./.omc-flags` (or placeholder) | `/run/omc-flags` | read-only |

Override the host paths via environment variables in `docker/.env`:

- `APP_DIR` – workspace directory
- `OPENCODE_CONFIG_DIR` – opencode config directory
- `GIT_CONFIG_FILE` – git global config file
- `OMC_FLAGS_FILE` – oh-my-opencode subscription flags file (relative to `docker/`, written by `make omc-setup`)

## Secrets (API keys)

Secrets are **user-defined** — not everyone uses the same providers.
The base `docker/docker-compose.yml` contains no secrets at all.
Each user creates their own `docker/docker-compose.secrets.yml` that declares
only the keys they need.

### First-time setup

```bash
# 1. Copy the template (done automatically by  make init)
cp docker/docker-compose.secrets.yml.example docker/docker-compose.secrets.yml

# 2. Edit docker/docker-compose.secrets.yml:
#    - Uncomment the providers you use
#    - Remove or comment out the ones you don't

# 3. Create the matching secret files
echo -n "sk-ant-…" > secrets/anthropic_api_key.txt
chmod 600 secrets/anthropic_api_key.txt
```

### Adding a new provider

To add a secret that isn't in the template (e.g. Mistral):

1. Create the file: `echo -n "key…" > secrets/mistral_api_key.txt && chmod 600 secrets/mistral_api_key.txt`
2. Add it to `docker/docker-compose.secrets.yml`:
   ```yaml
   services:
     spectagent:
       secrets:
         - mistral_api_key        # ← add here

   secrets:
     mistral_api_key:
       file: ../secrets/mistral_api_key.txt   # ← and here
   ```
3. `make restart`

The entrypoint automatically exports it as `MISTRAL_API_KEY`.

### How it works

1. The Makefile merges both compose files: `-f docker/docker-compose.yml -f docker/docker-compose.secrets.yml`.
2. Docker Compose mounts each declared secret as a read-only file on **tmpfs** at `/run/secrets/`.
3. `entrypoint.sh` discovers every file in `/run/secrets/`, sanitises the name, and exports an upper-cased env var.
4. A blocklist prevents overwriting critical vars (`PATH`, `LD_PRELOAD`, …).

### Security properties

- Secrets live on **tmpfs** — RAM-backed, never written to the container filesystem.
- Keys do **not** appear in `docker inspect`, `docker compose config`, or daemon logs.
- `docker/docker-compose.secrets.yml` and `secrets/*.txt` are git-ignored.
- File permissions default to `chmod 600` (owner-only).
- The entrypoint rejects filenames that would overwrite security-critical env vars.

## Building the image only

```bash
make build
```

## Running without Compose

When running outside Compose, mount your secret files to `/run/secrets/`
so the entrypoint can pick them up:

```bash
docker run -it --rm \
  -v "$(pwd)/workspace:/workspace" \
  -v "$(pwd)/config/opencode:/root/.config/opencode" \
  -v "$(pwd)/config/git/.gitconfig:/root/.gitconfig:ro" \
  -v "$(pwd)/.omc-flags:/run/omc-flags:ro" \
  -v "$(pwd)/secrets/anthropic_api_key.txt:/run/secrets/anthropic_api_key:ro" \
  spectagent:latest
```

Add one `-v …:/run/secrets/<name>:ro` flag per secret you need.

