include make/vars.mk
include make/lifecycle.mk
include make/tools.mk
include make/omo.mk
include make/setup.mk
include oh-my-brain/make/openmemory.mk

# ── Help ─────────────────────────────────────────────────────────────────────
.PHONY: help
.DEFAULT_GOAL := help

help:           ## Show this help message
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'

# ── Catch-all for unrecognized targets (prevents Make from trying to build them) ──
%:
	@true

