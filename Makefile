SERVICE := spectagent
COMPOSE := docker compose --env-file .env -f docker/docker-compose.yml -f docker/docker-compose.secrets.yml

# ── Agent selection ──────────────────────────────────────────────────
# Supported agents (add new ones here)
SUPPORTED_AGENTS := opencode claude

# Read persisted selection; default to opencode
AGENT_FILE := .agent
AGENT ?= $(shell cat $(AGENT_FILE) 2>/dev/null || echo opencode)
export AGENT

# ── Lifecycle ────────────────────────────────────────────────────────────────
.PHONY: build up down restart logs

build:          ## Build (or rebuild) the Docker image
	@echo "Building with agent: $(AGENT)"
	$(COMPOSE) build --pull --no-cache

up:             ## Start container in the background
	$(COMPOSE) up -d

down:           ## Stop and remove the container
	$(COMPOSE) down

restart:        ## Rebuild image and restart container
	$(COMPOSE) up -d --build

logs:           ## Follow container logs
	$(COMPOSE) logs -f $(SERVICE)

# ── Agent selection ──────────────────────────────────────────────────────────
.PHONY: select-agent

select-agent:   ## Interactive menu to choose the AI coding agent
	@echo ""
	@echo "  ┌──────────────────────────────────────┐"
	@echo "  │   Select an AI coding agent           │"
	@echo "  ├──────────────────────────────────────┤"
	@echo "  │  1) opencode                          │"
	@echo "  │  2) claude                            │"
	@echo "  └──────────────────────────────────────┘"
	@echo ""
	@current=$$(cat $(AGENT_FILE) 2>/dev/null || echo opencode); \
	echo "  Current: $$current"; \
	echo ""; \
	printf "  Enter number [1-2]: "; \
	read choice; \
	case "$$choice" in \
		1) agent=opencode ;; \
		2) agent=claude ;; \
		*) echo "  Invalid choice. Keeping current: $$current"; exit 0 ;; \
	esac; \
	echo "$$agent" > $(AGENT_FILE); \
	if [ -f .env ] && grep -q '^AGENT=' .env; then \
		sed -i'' -e "s/^AGENT=.*/AGENT=$$agent/" .env; \
	else \
		echo "AGENT=$$agent" >> .env; \
	fi; \
	echo ""; \
	echo "  ✓ Agent set to: $$agent"; \
	echo "  Run 'make build' to rebuild the image with the new agent."

# ── Shell / tool access ──────────────────────────────────────────────────────
.PHONY: shell opencode claude specify python uv git

shell:          ## Open a bash shell inside the container
	$(COMPOSE) exec $(SERVICE) bash

opencode:       ## Run opencode inside the container (args: make opencode --help)
	$(COMPOSE) exec $(SERVICE) opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

claude:         ## Run claude inside the container (args: make claude --help)
	$(COMPOSE) exec $(SERVICE) claude $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

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
	@test -f .env && echo ".env already exists, skipping." || (cp docker/.env.example .env && echo "Created .env – edit host paths if needed.")

secrets:        ## Create docker/docker-compose.secrets.yml from example and secrets/ dir
	@mkdir -p secrets
	@test -f docker/docker-compose.secrets.yml \
		&& echo "docker/docker-compose.secrets.yml already exists, skipping." \
		|| (cp docker/docker-compose.secrets.yml.example docker/docker-compose.secrets.yml \
		    && echo "Created docker/docker-compose.secrets.yml – edit to select your secrets.")
	@echo "Put each API key into its own file under secrets/ (chmod 600)."
	@echo "Example:  echo -n 'sk-ant-…' > secrets/anthropic_api_key.txt && chmod 600 secrets/anthropic_api_key.txt"

init: env secrets select-agent   ## Full first-time setup: env, secrets, select agent, build, start
	@mkdir -p workspace
	@$(MAKE) build up

# ── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
.DEFAULT_GOAL := help

help:           ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# ── Catch-all for unrecognized targets (prevents Make from trying to build them) ──
%:
	@true

