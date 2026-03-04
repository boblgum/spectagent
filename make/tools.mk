# ── Shell / tool access ──────────────────────────────────────────────────────
.PHONY: shell opencode opencode-new specify python uv git omc

shell:          ## Open a bash shell inside the container
	$(COMPOSE) exec $(SERVICE) bash

opencode:       ## Continue last opencode session (use 'make opencode-new' for a fresh one)
	$(COMPOSE) exec $(SERVICE) opencode --continue $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

opencode-new:   ## Start a brand-new opencode session
	$(COMPOSE) exec $(SERVICE) opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

specify:        ## Run specify (spec-kit) inside the container (args: make specify check)
	$(COMPOSE) exec $(SERVICE) specify $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

python:         ## Run python inside the container (args: make python --version)
	$(COMPOSE) exec $(SERVICE) python $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

uv:             ## Run uv inside the container (args: make uv --version)
	$(COMPOSE) exec $(SERVICE) uv $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

git:            ## Run git inside the container (args: make git status)
	$(COMPOSE) exec $(SERVICE) git $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

