# ── OpenMemory (Mem0 self-hosted memory stack) ────────────────────────────────
.PHONY: openmemory-env openmemory-up openmemory-ui openmemory-down \
        openmemory-reset openmemory-logs openmemory-status openmemory-test

OPENMEMORY_DIR      := oh-my-brain
OPENMEMORY_COMPOSE  := docker compose \
                         -f $(OPENMEMORY_DIR)/docker-compose.yml \
                         --env-file $(OPENMEMORY_DIR)/.env
OPENMEMORY_COMPOSE_UI := docker compose \
                           -f $(OPENMEMORY_DIR)/docker-compose.yml \
                           -f $(OPENMEMORY_DIR)/docker-compose.ui.yml \
                           --env-file $(OPENMEMORY_DIR)/.env

openmemory-env:     ## Create oh-my-brain/.env from template (idempotent)
	@test -f $(OPENMEMORY_DIR)/.env \
		&& echo "oh-my-brain/.env already exists, skipping." \
		|| (cp $(OPENMEMORY_DIR)/.env.example $(OPENMEMORY_DIR)/.env \
		    && echo "Created oh-my-brain/.env")

openmemory-up:      ## Start OpenMemory core stack (API + Qdrant) in the background
	@test -f $(OPENMEMORY_DIR)/.env || $(MAKE) openmemory-env
	@echo "→ Pulling latest OpenMemory images…"
	@$(OPENMEMORY_COMPOSE) pull --quiet
	@echo "→ Starting openmemory-mcp + mem0_store…"
	@$(OPENMEMORY_COMPOSE) up -d --remove-orphans
	@echo "✓ OpenMemory API available at http://localhost:$$(grep OPENMEMORY_API_PORT $(OPENMEMORY_DIR)/.env 2>/dev/null | cut -d= -f2 | tr -d '[:space:]' || echo 8765)"

openmemory-ui:      ## Start optional OpenMemory UI (requires core stack running)
	@test -f $(OPENMEMORY_DIR)/.env || $(MAKE) openmemory-env
	@echo "→ Starting mem0_ui…"
	@$(OPENMEMORY_COMPOSE_UI) up -d mem0_ui
	@echo "✓ OpenMemory UI available at http://localhost:$$(grep OPENMEMORY_UI_PORT $(OPENMEMORY_DIR)/.env 2>/dev/null | cut -d= -f2 | tr -d '[:space:]' || echo 3000)"

openmemory-down:    ## Stop OpenMemory stack (volumes are preserved)
	@$(OPENMEMORY_COMPOSE_UI) down --remove-orphans
	@echo "✓ OpenMemory stopped. Data volumes preserved."

openmemory-reset:   ## Stop OpenMemory stack and wipe all data volumes (irreversible)
	@echo ""
	@echo "  This will permanently delete all OpenMemory memories and vector data."
	@echo ""
	@printf "  Delete all OpenMemory data? [yes/no] → "; \
	read CONFIRM; \
	if [ "$$CONFIRM" != "yes" ] && [ "$$CONFIRM" != "y" ] && \
	   [ "$$CONFIRM" != "YES" ] && [ "$$CONFIRM" != "Y" ]; then \
	  echo "  Aborted. Nothing was deleted."; exit 0; \
	fi; \
	$(OPENMEMORY_COMPOSE_UI) down -v --remove-orphans; \
	echo "  ✓ OpenMemory stack and volumes removed."

openmemory-logs:    ## Tail logs for all OpenMemory core services
	@$(OPENMEMORY_COMPOSE) logs -f

openmemory-status:  ## Show running status of OpenMemory containers
	@$(OPENMEMORY_COMPOSE_UI) ps

openmemory-test:    ## Smoke-test: API health + MCP endpoint reachability + MCP tools list
	@echo "── OpenMemory smoke-test ──────────────────────────────────────"
	@set -e; \
	 API_PORT=$$(grep '^OPENMEMORY_API_PORT' $(OPENMEMORY_DIR)/.env 2>/dev/null \
	               | cut -d= -f2 | tr -d '[:space:]'); \
	 API_PORT=$${API_PORT:-8765}; \
	 API="http://localhost:$$API_PORT"; \
	 \
	 echo "1/3  Checking API config at $$API/api/v1/config/ …"; \
	 for i in $$(seq 1 20); do \
	   STATUS=$$(curl -s -o /dev/null -w '%{http_code}' "$$API/api/v1/config/" 2>/dev/null); \
	   if [ "$$STATUS" = "200" ]; then break; fi; \
	   if [ "$$i" = "20" ]; then echo "     FAIL – API not reachable (HTTP $$STATUS)"; exit 1; fi; \
	   printf "     waiting ($$i/20)…\r"; sleep 3; \
	 done; \
	 echo "     OK"; \
	 \
	 echo "2/3  Checking MCP endpoint at $$API/mcp/messages/ …"; \
	 MCP_STATUS=$$(curl -s -o /dev/null -w '%{http_code}' -X POST "$$API/mcp/messages/" \
	   -H 'Content-Type: application/json' \
	   -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0"}}}' \
	   2>/dev/null); \
	 if [ "$$MCP_STATUS" != "200" ]; then \
	   echo "     FAIL – MCP endpoint returned HTTP $$MCP_STATUS"; exit 1; \
	 fi; \
	 echo "     OK"; \
	 \
	 echo "3/3  Verifying MCP SSE stream at $$API/mcp/spectagent/sse/smoke-test …"; \
	 SSE=$$(curl -s --max-time 3 "$$API/mcp/spectagent/sse/smoke-test" 2>/dev/null || true); \
	 if echo "$$SSE" | grep -q 'endpoint'; then \
	   echo "     OK – SSE stream live, session endpoint returned"; \
	 else \
	   echo "     FAIL – unexpected SSE response: $$SSE"; exit 1; \
	 fi; \
	 \
	 echo "──────────────────────────────────────────────────────────────"; \
	 echo "✓ All checks passed."

