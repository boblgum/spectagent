SERVICE := opencode
COMPOSE := docker compose -f docker-compose.yml -f docker-compose.secrets.yml

# ── Lifecycle ────────────────────────────────────────────────────────────────
.PHONY: build up down restart logs

build:          ## Build (or rebuild) the Docker image
	$(COMPOSE) build

up:             ## Start container in the background
	$(COMPOSE) up -d

down:           ## Stop and remove the container
	$(COMPOSE) down

restart:        ## Rebuild image and restart container
	$(COMPOSE) up -d --build

logs:           ## Follow container logs
	$(COMPOSE) logs -f $(SERVICE)

# ── Shell / tool access ──────────────────────────────────────────────────────
.PHONY: shell opencode specify python uv git

shell:          ## Open a bash shell inside the container
	$(COMPOSE) exec $(SERVICE) bash

opencode:       ## Run opencode inside the container (args: make opencode --help)
	$(COMPOSE) exec $(SERVICE) opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

specify:        ## Run specify (spec-kit) inside the container (args: make specify check)
	$(COMPOSE) exec $(SERVICE) specify $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

python:         ## Run python inside the container (args: make python --version)
	$(COMPOSE) exec $(SERVICE) python $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

uv:             ## Run uv inside the container (args: make uv --version)
	$(COMPOSE) exec $(SERVICE) uv $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

git:            ## Run git inside the container (args: make git status)
	$(COMPOSE) exec $(SERVICE) git $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

# ── Setup helpers ────────────────────────────────────────────────────────────
.PHONY: init env secrets

env:            ## Create .env from template if it does not exist yet
	@test -f .env && echo ".env already exists, skipping." || (cp .env.example .env && echo "Created .env – edit host paths if needed.")

secrets:        ## Create docker-compose.secrets.yml from example and secrets/ dir
	@mkdir -p secrets
	@test -f docker-compose.secrets.yml \
		&& echo "docker-compose.secrets.yml already exists, skipping." \
		|| (cp docker-compose.secrets.yml.example docker-compose.secrets.yml \
		    && echo "Created docker-compose.secrets.yml – edit to select your secrets.")
	@echo "Put each API key into its own file under secrets/ (chmod 600)."
	@echo "Example:  echo -n 'sk-ant-…' > secrets/anthropic_api_key.txt && chmod 600 secrets/anthropic_api_key.txt"

init: env secrets build up ## Full first-time setup: env, secrets, build, start

# ── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
.DEFAULT_GOAL := help

help:           ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# ── Catch-all for unrecognized targets (prevents Make from trying to build them) ──
%:
	@true

