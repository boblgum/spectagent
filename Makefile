SERVICE := opencode

# ── Lifecycle ────────────────────────────────────────────────────────────────
.PHONY: build up down restart logs

build:          ## Build (or rebuild) the Docker image
	docker compose build

up:             ## Start container in the background
	docker compose up -d

down:           ## Stop and remove the container
	docker compose down

restart:        ## Rebuild image and restart container
	docker compose up -d --build

logs:           ## Follow container logs
	docker compose logs -f $(SERVICE)

# ── Shell / tool access ──────────────────────────────────────────────────────
.PHONY: shell opencode specify python uv git

shell:          ## Open a bash shell inside the container
	docker compose exec $(SERVICE) bash

opencode:       ## Run opencode inside the container (args: make opencode --help)
	docker compose exec $(SERVICE) opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

specify:        ## Run specify (spec-kit) inside the container (args: make specify check)
	docker compose exec $(SERVICE) specify $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

python:         ## Run python inside the container (args: make python --version)
	docker compose exec $(SERVICE) python $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

uv:             ## Run uv inside the container (args: make uv --version)
	docker compose exec $(SERVICE) uv $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

git:            ## Run git inside the container (args: make git status)
	docker compose exec $(SERVICE) git $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

# ── Setup helpers ────────────────────────────────────────────────────────────
.PHONY: init env

env:            ## Create .env from template if it does not exist yet
	@test -f .env && echo ".env already exists, skipping." || (cp .env.example .env && echo "Created .env – fill in your API keys.")

init: env build up ## Full first-time setup: create .env, build image, start container

# ── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
.DEFAULT_GOAL := help

help:           ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# ── Catch-all for unrecognized targets (prevents Make from trying to build them) ──
%:
	@true

