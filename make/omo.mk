# ── oh-my-opencode setup ─────────────────────────────────────────────────────
.PHONY: omo omo-install omo-auth omo-reconfigure

omo:            ## Run oh-my-opencode CLI inside the container (args: make omo --help)
	$(COMPOSE) run --rm -it $(SERVICE) bunx oh-my-opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))


omo-install:    ## Interactively install oh-my-opencode inside the container (TTY), then verify and auth
	@$(COMPOSE) run --rm -i $(SERVICE) bash -c '\
	  SENTINEL="/root/.config/opencode/.omo-installed"; \
	  echo "[omo] Running oh-my-opencode installer ..."; \
	  if bunx oh-my-opencode install; then \
	    touch "$$SENTINEL"; \
	    echo "[omo] Installation complete."; \
	    echo ""; \
	    echo "[omo] --- Step 3: Verify Setup ---"; \
	    VER=$$(opencode --version 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1); \
	    if [ -z "$$VER" ]; then \
	      echo "[omo] WARN  opencode not found or returned no version."; \
	    else \
	      echo "[omo] OK    opencode version $$VER"; \
	    fi; \
	    CFG="/root/.config/opencode/opencode.json"; \
	    if [ -f "$$CFG" ] && grep -q "oh-my-opencode" "$$CFG"; then \
	      echo "[omo] OK    oh-my-opencode registered in $$CFG"; \
	    else \
	      echo "[omo] WARN  oh-my-opencode NOT found in $$CFG"; \
	    fi; \
	    echo ""; \
	    printf "[omo] Configure authentication now? [y/N] "; \
	    read -r AUTH_ANS; \
	    case "$$AUTH_ANS" in \
	      [Yy]*) echo "[omo] Launching opencode auth login ..."; opencode auth login ;; \
	      *)     echo "[omo] Skipped. Run  make omo-auth  later to authenticate." ;; \
	    esac; \
	  else \
	    echo "[omo] Installation failed — check the output above."; \
	    exit 1; \
	  fi \
	'

omo-auth:       ## Run opencode auth login inside the container interactively
	@$(COMPOSE) run --rm -i $(SERVICE) opencode auth login

omo-reconfigure: ## Remove sentinel and re-run the interactive installer
	@rm -f config/opencode/.omo-installed
	@$(MAKE) omo-install
