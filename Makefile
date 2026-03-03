SERVICE    := spectagent
COMPOSE    := docker compose --env-file docker/.env -f docker/docker-compose.yml -f docker/docker-compose.secrets.yml
# local cache used by omc-install; OMC_FLAGS env var in .env drives the container
OMC_FLAGS  := .omc-flags

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

# ── Shell / tool access ──────────────────────────────────────────────────────
.PHONY: shell opencode opencode-new specify python uv git omc

shell:          ## Open a bash shell inside the container
	$(COMPOSE) exec $(SERVICE) bash

opencode:       ## Continue last opencode session (use 'make opencode-new' for a fresh one)
	$(COMPOSE) exec $(SERVICE) opencode --continue $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

opencode-new:   ## Start a brand-new opencode session
	$(COMPOSE) exec $(SERVICE) opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

omc:            ## Run oh-my-opencode CLI inside the container (args: make omc --help)
	$(COMPOSE) exec $(SERVICE) bunx oh-my-opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

specify:        ## Run specify (spec-kit) inside the container (args: make specify check)
	$(COMPOSE) exec $(SERVICE) specify $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

python:         ## Run python inside the container (args: make python --version)
	$(COMPOSE) exec $(SERVICE) python $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

uv:             ## Run uv inside the container (args: make uv --version)
	$(COMPOSE) exec $(SERVICE) uv $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

git:            ## Run git inside the container (args: make git status)
	$(COMPOSE) exec $(SERVICE) git $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

# ── oh-my-opencode setup ─────────────────────────────────────────────────────
.PHONY: omc-setup omc-install omc-reconfigure

omc-setup:      ## Interactive wizard: choose AI provider subscriptions and save flags
	@OMC_FLAGS_DEST="$(OMC_FLAGS)" bash -c '\
	  echo ""; \
	  echo "╔══════════════════════════════════════════════════════════════╗"; \
	  echo "║        oh-my-opencode — Subscription Setup                   ║"; \
	  echo "╚══════════════════════════════════════════════════════════════╝"; \
	  echo ""; \
	  \
	  printf "1. Do you have a Claude Pro/Max subscription? [yes/no] → "; \
	  read CLAUDE_ANS; \
	  case "$$CLAUDE_ANS" in \
	    yes|y|YES|Y) \
	      printf "   Are you on the max20 (20×) plan? [yes/no] → "; \
	      read MAX20_ANS; \
	      case "$$MAX20_ANS" in \
	        yes|y|YES|Y) CLAUDE_FLAG="max20" ;; \
	        *)           CLAUDE_FLAG="yes"   ;; \
	      esac ;; \
	    *) CLAUDE_FLAG="no" ;; \
	  esac; \
	  if [ "$$CLAUDE_FLAG" = "no" ]; then \
	    echo ""; \
	    echo "  ⚠  WARNING: Without a Claude subscription the Sisyphus agent"; \
	    echo "     may not work ideally. Consider activating a Claude plan."; \
	    echo ""; \
	  fi; \
	  \
	  printf "2. Do you have an OpenAI / ChatGPT Plus subscription? [yes/no] → "; \
	  read OPENAI_ANS; \
	  case "$$OPENAI_ANS" in \
	    yes|y|YES|Y) OPENAI_FLAG="yes" ;; \
	    *)           OPENAI_FLAG="no"  ;; \
	  esac; \
	  \
	  printf "3. Will you integrate Gemini models? [yes/no] → "; \
	  read GEMINI_ANS; \
	  case "$$GEMINI_ANS" in \
	    yes|y|YES|Y) GEMINI_FLAG="yes" ;; \
	    *)           GEMINI_FLAG="no"  ;; \
	  esac; \
	  \
	  printf "4. Do you have a GitHub Copilot subscription? [yes/no] → "; \
	  read COPILOT_ANS; \
	  case "$$COPILOT_ANS" in \
	    yes|y|YES|Y) COPILOT_FLAG="yes" ;; \
	    *)           COPILOT_FLAG="no"  ;; \
	  esac; \
	  \
	  printf "5. Do you have access to OpenCode Zen (opencode/ models)? [yes/no] → "; \
	  read ZEN_ANS; \
	  case "$$ZEN_ANS" in \
	    yes|y|YES|Y) ZEN_FLAG="yes" ;; \
	    *)           ZEN_FLAG="no"  ;; \
	  esac; \
	  \
	  printf "6. Do you have a Z.ai Coding Plan subscription? [yes/no] → "; \
	  read ZAI_ANS; \
	  case "$$ZAI_ANS" in \
	    yes|y|YES|Y) ZAI_FLAG="yes" ;; \
	    *)           ZAI_FLAG="no"  ;; \
	  esac; \
	  \
	  FLAGS="--no-tui --claude=$$CLAUDE_FLAG --openai=$$OPENAI_FLAG --gemini=$$GEMINI_FLAG --copilot=$$COPILOT_FLAG --opencode-zen=$$ZEN_FLAG --zai-coding-plan=$$ZAI_FLAG"; \
	  printf "%s\n" "$$FLAGS" > "$$OMC_FLAGS_DEST"; \
	  if [ -f docker/.env ]; then \
	    if grep -qE "^OMC_FLAGS(_FILE)?=" docker/.env; then \
	      perl -i -pe "s{^OMC_FLAGS(?:_FILE)?=.*}{OMC_FLAGS=$$FLAGS}" docker/.env; \
	    else \
	      printf "\nOMC_FLAGS=$$FLAGS\n" >> docker/.env; \
	    fi; \
	    echo "  ✓  Written to docker/.env (OMC_FLAGS)"; \
	  fi; \
	  echo ""; \
	  echo "  ✓  Saved: $$OMC_FLAGS_DEST"; \
	  echo "     Flags: $$FLAGS"; \
	  echo ""; \
	  echo "  Run  make omc-install  after  make up  to apply the configuration."; \
	'

omc-install:    ## Run the oh-my-opencode installer inside the container using saved flags
	@if [ ! -f $(OMC_FLAGS) ]; then \
	  echo "No flags file found. Run  make omc-setup  first."; exit 1; \
	fi
	@FLAGS=$$(cat $(OMC_FLAGS)); \
	echo "[omc] Installing oh-my-opencode with flags: $$FLAGS"; \
	$(COMPOSE) exec $(SERVICE) sh -c "bunx oh-my-opencode install $$FLAGS"

omc-reconfigure: ## Re-run omc-setup wizard and reinstall (removes sentinel, re-asks questions)
	@$(MAKE) omc-setup
	@$(COMPOSE) exec $(SERVICE) sh -c "rm -f /root/.config/opencode/.omc-installed"
	@$(MAKE) omc-install

# ── Setup helpers ────────────────────────────────────────────────────────────
.PHONY: init reset env secrets

env:            ## Create .env from template if it does not exist yet
	@test -f docker/.env && echo ".env already exists, skipping." || (cp docker/.env.example docker/.env && echo "Created .env – edit host paths if needed.")

secrets:        ## Create docker/docker-compose.secrets.yml from example and secrets/ dir
	@mkdir -p secrets
	@test -f docker/docker-compose.secrets.yml \
		&& echo "docker/docker-compose.secrets.yml already exists, skipping." \
		|| (cp docker/docker-compose.secrets.yml.example docker/docker-compose.secrets.yml \
		    && echo "Created docker/docker-compose.secrets.yml – edit to select your secrets.")
	@echo "Put each API key into its own file under secrets/ (chmod 600)."
	@echo "Example:  echo -n 'sk-ant-…' > secrets/anthropic_api_key.txt && chmod 600 secrets/anthropic_api_key.txt"

reset:          ## Remove all files/dirs generated by  make init  (asks for confirmation)
	@echo ""
	@echo "The following items will be permanently deleted:"
	@echo ""
	@ITEMS=""; \
	 [ -f $(OMC_FLAGS) ]                       && ITEMS="$$ITEMS $(OMC_FLAGS)"; \
	 [ -f docker/.env ]                        && ITEMS="$$ITEMS docker/.env"; \
	 [ -f docker/docker-compose.secrets.yml ]  && ITEMS="$$ITEMS docker/docker-compose.secrets.yml"; \
	 [ -d secrets ]                            && ITEMS="$$ITEMS secrets"; \
	 [ -d workspace ]                          && ITEMS="$$ITEMS workspace"; \
	 if [ -z "$$ITEMS" ]; then \
	   echo "  (nothing to remove – already clean)"; echo ""; exit 0; \
	 fi; \
	 for ITEM in $$ITEMS; do \
	   if [ -d "$$ITEM" ]; then \
	     find "$$ITEM" | sed -e "s|[^/]*/|  |g" -e "s|  \([^/]*\)$$|  └─ \1|"; \
	   else \
	     echo "  └─ $$ITEM"; \
	   fi; \
	 done; \
	 echo ""; \
	 printf "  Also remove Docker image  spectagent:latest ? [yes/no] → "; \
	 read REMOVE_IMAGE; \
	 echo ""; \
	 printf "Delete all of the above? [yes/no] → "; \
	 read CONFIRM; \
	 if [ "$$CONFIRM" != "yes" ] && [ "$$CONFIRM" != "y" ] && [ "$$CONFIRM" != "YES" ] && [ "$$CONFIRM" != "Y" ]; then \
	   echo "Aborted. Nothing was deleted."; exit 0; \
	 fi; \
	 $(COMPOSE) down 2>/dev/null || true; \
	 for ITEM in $$ITEMS; do \
	   rm -rf "$$ITEM" && echo "  ✓  Removed $$ITEM"; \
	 done; \
	 case "$$REMOVE_IMAGE" in yes|y|YES|Y) \
	   docker rmi spectagent:latest 2>/dev/null && echo "  ✓  Removed Docker image spectagent:latest" \
	   || echo "  ·  Image spectagent:latest not found, skipping."; \
	 esac; \
	 echo ""; \
	 echo "  Reset complete."

init: env secrets          ## Full first-time setup: env, secrets, omc-setup, build, start
	@mkdir -p workspace
	@$(MAKE) omc-setup
	@$(MAKE) build
	@$(MAKE) up
	@echo ""
	@echo "  ✓  Container started. oh-my-opencode will be installed automatically"
	@echo "     on first use (check  make logs  to follow progress)."
	@echo "     To reconfigure subscriptions later, run:  make omc-reconfigure"

# ── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
.DEFAULT_GOAL := help

help:           ## Show this help message
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

# ── Catch-all for unrecognized targets (prevents Make from trying to build them) ──
%:
	@true

