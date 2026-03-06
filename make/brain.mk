# ── Brain (Basic Memory MCP knowledge base) ──────────────────────────────────
.PHONY: brain-start brain-stop brain-status brain-ingest brain-sync brain-logs brain-reset

brain-start:    ## Start the Basic Memory brain sidecar (background service)
	@mkdir -p data/brain
	$(COMPOSE) up -d brain
	@echo "  ✓  Brain started at http://localhost:$${BRAIN_PORT:-8765}"
	@echo "     MCP SSE endpoint: http://localhost:$${BRAIN_PORT:-8765}/sse"

brain-stop:     ## Stop the Basic Memory brain sidecar
	$(COMPOSE) stop brain

brain-status:   ## Show brain container status and health
	@$(COMPOSE) ps brain
	@echo ""
	@curl -sf "http://localhost:$${BRAIN_PORT:-8765}/health" \
	  && echo "  ✓  Brain API responding" \
	  || echo "  ✗  Brain API not responding – run  make brain-start"

brain-logs:     ## Tail logs from the brain container
	$(COMPOSE) logs -f brain

brain-ingest:   ## Seed / refresh all priority knowledge into the brain
	@echo ""
	@echo "  → Ingesting knowledge into brain …"
	@mkdir -p data/brain
	$(COMPOSE) run --rm $(SERVICE) bash /brain/ingest.sh

brain-sync:     ## Same as brain-ingest – use after completing a feature
	@$(MAKE) brain-ingest

brain-reset:    ## Wipe the brain data and config volumes (asks for confirmation)
	@echo ""
	@printf "  Delete ALL brain notes and index? [yes/no] → "; \
	read CONFIRM; \
	if [ "$$CONFIRM" != "yes" ] && [ "$$CONFIRM" != "y" ] && \
	   [ "$$CONFIRM" != "YES" ] && [ "$$CONFIRM" != "Y" ]; then \
	  echo "  Aborted. Brain data unchanged."; exit 0; \
	fi
	$(COMPOSE) stop brain
	$(COMPOSE) rm -f brain
	docker volume rm spectagent_brain-config 2>/dev/null || true
	rm -rf data/brain
	@echo "  ✓  Brain data wiped. Run  make brain-start brain-ingest  to reinitialise."

