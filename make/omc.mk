# ── oh-my-opencode setup ─────────────────────────────────────────────────────
.PHONY: omc omc-setup omc-install omc-auth omc-reconfigure

omc:            ## Run oh-my-opencode CLI inside the container (args: make omc --help)
	$(COMPOSE) exec $(SERVICE) bunx oh-my-opencode $(ARGS) $(filter-out $@,$(MAKECMDGOALS))

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

omc-install:    ## Interactively install oh-my-opencode inside the container (TTY), then verify and auth
	@$(COMPOSE) run --rm -i $(SERVICE) bash -c '\
	  SENTINEL="/root/.config/opencode/.omc-installed"; \
	  echo "[omc] Running oh-my-opencode installer ..."; \
	  if bunx oh-my-opencode install; then \
	    touch "$$SENTINEL"; \
	    echo "[omc] Installation complete."; \
	    echo ""; \
	    echo "[omc] --- Step 3: Verify Setup ---"; \
	    VER=$$(opencode --version 2>/dev/null | grep -oE "[0-9]+\.[0-9]+\.[0-9]+" | head -1); \
	    if [ -z "$$VER" ]; then \
	      echo "[omc] WARN  opencode not found or returned no version."; \
	    else \
	      echo "[omc] OK    opencode version $$VER"; \
	    fi; \
	    CFG="/root/.config/opencode/opencode.json"; \
	    if [ -f "$$CFG" ] && grep -q "oh-my-opencode" "$$CFG"; then \
	      echo "[omc] OK    oh-my-opencode registered in $$CFG"; \
	    else \
	      echo "[omc] WARN  oh-my-opencode NOT found in $$CFG"; \
	    fi; \
	    echo ""; \
	    printf "[omc] Configure authentication now? [y/N] "; \
	    read -r AUTH_ANS; \
	    case "$$AUTH_ANS" in \
	      [Yy]*) echo "[omc] Launching opencode auth login ..."; opencode auth login ;; \
	      *)     echo "[omc] Skipped. Run  make omc-auth  later to authenticate." ;; \
	    esac; \
	  else \
	    echo "[omc] Installation failed — check the output above."; \
	    exit 1; \
	  fi \
	'

omc-auth:       ## Run opencode auth login inside the container interactively
	@$(COMPOSE) run --rm -i $(SERVICE) opencode auth login

omc-reconfigure: ## Remove sentinel and re-run the interactive installer
	@rm -f config/opencode/.omc-installed
	@$(MAKE) omc-install

