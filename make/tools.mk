# ── Shell / tool access ──────────────────────────────────────────────────────
.PHONY: shell opencode opencode-new specify python uv git omo

shell:          ## Open a bash shell inside the container (ephemeral, removed on exit)
	$(COMPOSE) run --rm -it $(SERVICE) bash

opencode:       ## Continue last opencode session (use 'make opencode-new' for a fresh one)
	$(COMPOSE) run --rm -it $(SERVICE) opencode --continue $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

opencode-new:   ## Start a brand-new opencode session
	$(COMPOSE) run --rm -it $(SERVICE) opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

specify:        ## Run specify (spec-kit) inside the container (args: make specify check)
	$(COMPOSE) run --rm -it $(SERVICE) specify $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

python:         ## Run python inside the container (args: make python --version)
	$(COMPOSE) run --rm -it $(SERVICE) python $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

uv:             ## Run uv inside the container (args: make uv --version)
	$(COMPOSE) run --rm -it $(SERVICE) uv $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

git:            ## Run git inside the container (args: make git status)
	$(COMPOSE) run --rm -it $(SERVICE) git $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

