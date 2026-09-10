# Strange Lettractor build entry points.
#
# Everything runs on the fixed local let-go runtime named by LGX_LG. Set it in
# the environment, in .env (LGX_LG=...), or on the command line:
#   make build LGX_LG=/path/to/let-go/build/lg
# Without it, the runtime is looked up next to this checkout (the
# let-go-http-cancellation workspace used during development).

SHELL := /bin/bash
.DEFAULT_GOAL := help

-include .env
export

ROOT := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
CANDIDATES := $(ROOT).worktrees/let-go-http-cancellation/build/lg \
              $(ROOT)../let-go-http-cancellation/build/lg
LGX_LG ?= $(firstword $(wildcard $(CANDIDATES)))
LG := $(LGX_LG)
LGX := lgx
TINY_TUI := $(firstword $(wildcard $(HOME)/.lgx/gitlibs/github.com/abogoyavlensky/tiny-tui/*/src))
SOURCE_PATHS := src:test$(if $(TINY_TUI),:$(TINY_TUI))
RUNNER := test/runner.lg
TIMEOUT ?= 1500

TEST_FILES := $(wildcard test/attractor/*_test.lg)

.PHONY: help check-runtime install build test suite runners live-matrix live-smoke \
        providers models clean distclean

help: ## Show this help
	@awk 'BEGIN {FS = ":.*##"; printf "Targets (runtime: %s)\n", "$(LG)"} \
	     /^[a-zA-Z_-]+:.*?##/ { printf "  %-14s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@printf "  %-14s %s\n" "run-<name>" "One test namespace: make run-providers runs attractor.providers-test"

check-runtime: ## Fail unless LGX_LG names an executable let-go runtime
	@test -x "$(LG)" || { echo "LGX_LG is not an executable runtime: '$(LG)'"; \
	  echo "Build let-go from the fix/http-scope-cancellation bookmark and set LGX_LG (see README)."; exit 1; }
	@"$(LG)" -e '(println (str "let-go " (or (System/getProperty "lg.version") "ok")))' >/dev/null 2>&1 || true

install: check-runtime ## Fetch pinned dependencies (tiny-tui) with lgx
	$(LGX) install

build: check-runtime ## Build bin/attractor (removes the old binary first; macOS in-place rebuilds die with 137)
	rm -f bin/attractor
	$(LGX) build

test: check-runtime ## Full suite through lgx (about two minutes)
	perl -e 'alarm $(TIMEOUT); exec @ARGV' $(LGX) test

suite: test ## Alias for test

runners: check-runtime ## Every test namespace in its own process, one summary line each
	@fail=0; for f in $(TEST_FILES); do \
	  ns=attractor.$$(basename "$$f" .lg | tr _ -); printf '%-52s ' "$$ns"; \
	  out=$$(perl -e 'alarm 600; exec @ARGV' "$(LG)" -source-paths $(SOURCE_PATHS) $(RUNNER) "$$ns" 2>&1 \
	        | grep -E -m1 '^\{:error'); \
	  echo "$${out:-no summary line (load or runtime error)}"; \
	  case "$$out" in *":error 0,"*":fail 0}"*) ;; *) fail=1;; esac; \
	done; exit $$fail

run-%: check-runtime ## One test namespace, e.g. make run-providers (attractor.providers-test)
	perl -e 'alarm 600; exec @ARGV' "$(LG)" -source-paths $(SOURCE_PATHS) $(RUNNER) attractor.$(subst _,-,$*)-test

live-matrix: check-runtime ## Credential-gated provider matrix (registry keys; ATTRACTOR_MATRIX_PROVIDERS=a,b to restrict)
	perl -e 'alarm 900; exec @ARGV' "$(LG)" -source-paths src:test test/live/provider_matrix.lg run

live-smoke: check-runtime ## Live Attractor pipeline smoke against ATTRACTOR_LIVE_MODEL
	perl -e 'alarm 900; exec @ARGV' "$(LG)" -source-paths src:test test/live/attractor_smoke.lg run

providers: build ## Show the effective provider registry
	bin/attractor providers

models: build ## List models from every queryable provider (PROVIDER=id to narrow)
	bin/attractor models $(if $(PROVIDER),--provider $(PROVIDER))

clean: ## Remove pipeline artifacts, logs and checkpoints
	rm -rf attractor_runs

distclean: clean ## Also remove the built binary
	rm -f bin/attractor
