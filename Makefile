# Strange Lettractor build entry points.
#
# This Makefile is a thin passthrough: every target forwards to an lgx task,
# and lgx.edn owns the definitions (runtime version, source paths, arguments).
# `lgx help` lists the same entry points; use either.

SHELL := /bin/bash
.DEFAULT_GOAL := help

-include .env
export

LGX := lgx

.PHONY: help install hooks build test suite audit-coding-loop runners live-matrix live-parity \
        live-smoke live-coding-conformance live-mcp-pilot live-mcp-pilot-live providers models clean distclean

help: ## Show the lgx entry points
	@$(LGX) help

install: ## Fetch pinned dependencies (tiny-tui)
	$(LGX) install

hooks: ## Gate pushes on the full suite (sets core.hooksPath for this clone)
	$(LGX) hooks

build: ## Build bin/attractor
	$(LGX) rebuild

test: ## Full suite (about two and a half minutes)
	$(LGX) suite

suite: test ## Alias for test

audit-coding-loop: ## Original coding-loop contracts and repair regressions
	$(LGX) audit-coding-loop

runners: ## Every test namespace in its own process, one summary line each
	$(LGX) runners

run-%: ## One test namespace, e.g. make run-providers (attractor.providers-test)
	$(LGX) test-ns attractor.$(subst _,-,$*)-test

live-matrix: ## Credential-gated provider matrix
	$(LGX) live-matrix

live-parity: ## Live coding-agent parity matrix against ATTRACTOR_LIVE_MODEL
	$(LGX) live-parity

live-smoke: ## Live Attractor pipeline smoke against ATTRACTOR_LIVE_MODEL
	$(LGX) live-smoke

live-coding-conformance: ## Coding-agent parity and same-session smoke
	$(LGX) live-coding-conformance

live-mcp-pilot: ## MCP pilot dry run (no network): prints plan, exits 2
	$(LGX) live-mcp-pilot

live-mcp-pilot-live: ## LIVE MCP pilot: OAuth + read-only calls (operator browser step)
	$(LGX) live-mcp-pilot-live

providers: ## Show the effective provider registry
	$(LGX) providers

models: ## List models from every queryable provider (PROVIDER=id to narrow)
	@if [ -n "$(PROVIDER)" ]; then $(LGX) models-for $(PROVIDER); else $(LGX) models; fi

clean: ## Remove pipeline artifacts, logs and checkpoints
	$(LGX) clean-runs

distclean: ## Also remove the built binary
	$(LGX) clean-all
