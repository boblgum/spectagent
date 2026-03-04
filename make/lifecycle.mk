# ── Lifecycle ────────────────────────────────────────────────────────────────
.PHONY: build up down restart logs

build:          ## Build (or rebuild) the Docker image
	$(COMPOSE) build --pull --no-cache

up:             ## Start container in the background
	$(COMPOSE) up -d

down:           ## Stop and remove the container
	$(COMPOSE) down

restart:        ## Rebuild image and restart container
	$(COMPOSE) up -d --build

logs:           ## Follow container logs
	$(COMPOSE) logs -f $(SERVICE)

