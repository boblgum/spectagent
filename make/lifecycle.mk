# ── Lifecycle ────────────────────────────────────────────────────────────────
.PHONY: build rebuild

build:          ## Build (or rebuild) the Docker image
	$(COMPOSE) build --pull --no-cache

rebuild:        ## Rebuild the Docker image (alias for build)
	$(COMPOSE) build --pull --no-cache

