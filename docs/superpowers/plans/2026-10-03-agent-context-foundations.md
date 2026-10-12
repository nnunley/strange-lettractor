# Agent Context Foundations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every agent stage a redacted transcript, a usage event, a pre-send context backstop with exact token counts, a per-node tool allowlist, a `read_handle` tool, and a versioning adapter that records tree state as small refs.

**Architecture:** Every setting is resolved per node run: the codergen handler puts the node's settings and stage directory into the per-turn invocation map it already builds, and admission already installs that map into the session's `:tool_hook_context`, so the session reads them per turn instead of at creation. Transcripts are an internal event listener inside the session's existing serialized delivery. The backstop runs in the turn loop just before the provider call. Versioning is a standalone namespace with no agent dependency.

**Tech Stack:** let-go 1.13.0 (Clojure dialect), `clojure.test`, the existing mock adapter and `:complete_fn` injection; `git` and `jj` CLIs for versioning.

**Spec:** `docs/superpowers/specs/2026-10-02-agent-context-foundations-design.md`

## Global Constraints

- Settings are resolved per node run, never only at session creation (nodes on one `fidelity="full"` thread share a session).
- Node attributes, same names reviewers already read: `--context-window`, `--reserve-tokens` (default 8192), `--max-output-tokens` (default: provider default), `--tools` (comma list; default: all).
- Transcripts: `<stage-dir>/transcript.jsonl`, one JSON object per line, every event through `providers/redact`, mode 0600, one `:warning` if the logs root is not VCS-ignored, write failure warns and stops the writer, never fails the stage.
- Backstop: last reported input tokens (cache read/write included) + provider count of newer history; fallback characters/3; fail `:context-length` before sending when count + reserve > window; clamp `:max_tokens` to min(`--max-output-tokens`, headroom); unknown window disables it; a provider context-length rejection maps to the same failure.
- `read_handle` and `diff_refs` only read under the current run's logs root.
- Versioning never commits, stashes, moves refs or touches the index. Ref shape: `{:repo {:protocol :git|:jj|:dir :root path} :base sha-or-nil :patch path-or-nil}`.
- Each numbered PR below is independently mergeable; tasks inside a PR merge together.
- Commit messages carry no AI attribution (enforced by a hook).
- Run tests with: `LGX_LG=/opt/homebrew/bin/lg; "$LGX_LG" -source-paths src:test test/runner.lg <namespace>`.

## Review Focus

1. **Events before the first turn** (`:session_start`, `:skills_loaded`) have no stage directory yet. Expected: buffered and written when the first turn's directory is known, never dropped, never a crash. Test in Task 2.
2. **Parallel tool calls** (`pmap` in the turn loop) produce events concurrently. Expected: every transcript line is a complete JSON object; none interleave. Test in Task 2.
3. **A secret inside tool arguments** (for example a `shell` command containing a key), not just in output. Expected: redacted too, since the whole event is redacted. Test in Task 2.
4. **A token counter that hangs** (llama.cpp busy). Expected: the count gives up after 5 seconds and falls back to characters/3; the turn is never blocked longer. Test in Task 4.
5. **Deleted, renamed and binary files** in a snapshot. Expected: the patch round-trips them (rebuilding base + patch reproduces the tree byte for byte). Test in Task 8.

---

## PR 1 — Node settings, transcripts, usage event

### Task 1: Per-node-run settings

**Files:**
- Create: `src/attractor/node_settings.lg`
- Modify: `src/attractor/task_review_bindings.lg:8-12` (use the shared parser), `src/attractor/handlers.lg:186-196` (add settings to the invocation map)
- Test: `test/attractor/node_settings_test.lg`

**Interfaces:**
- Produces: `(attractor.node-settings/integer-attr node key default) -> int | nil` (the moved `budget` fn); `(attractor.node-settings/turn-settings node) -> {:context_window_size int|nil :reserve_tokens int :max_output_tokens int|nil :tools [string]|nil}`; the invocation map gains `:turn_settings`, so inside a session `(:turn_settings @(:tool_hook_context @session))` holds the current node's settings.

- [ ] **Step 1: Write the failing tests**

```clojure
(deftest turn-settings-reads-node-attributes
  (is (= {:context_window_size 64000 :reserve_tokens 4096 :max_output_tokens 2048
          :tools ["read_file" "grep"]}
         (ns/turn-settings {:--context-window "64000" :--reserve-tokens 4096
                            :--max-output-tokens "2048" :--tools "read_file, grep"}))))

(deftest turn-settings-defaults
  (is (= {:context_window_size nil :reserve_tokens 8192 :max_output_tokens nil :tools nil}
         (ns/turn-settings {}))))

(deftest invocation-carries-turn-settings
  ;; drive make-codergen-handler with a capturing backend; the node passed to
  ;; the backend has :attractor.tool-hooks/invocation containing
  ;; {:node_id "n" :stage_dir "<logs>/n" :turn_settings {... :reserve_tokens 8192 ...}}
  )
```

- [ ] **Step 2: Run and confirm failure** — `"$LGX_LG" -source-paths src:test test/runner.lg attractor.node-settings-test`; expected: namespace not found.
- [ ] **Step 3: Implement** `integer-attr` (moved verbatim from `task_review_bindings.lg` `budget`), `turn-settings`; make `task_review_bindings.lg` call `integer-attr`; in `make-codergen-handler` add `:turn_settings (node-settings/turn-settings node)` to the invocation map's initial value `{:node_id node-id :stage_dir stage-dir}`.
- [ ] **Step 4: Run** the new test plus `attractor.task-review-bindings-test` — all pass.
- [ ] **Step 5: Commit** — `feat(agent): resolve LLM node settings per node run`

### Task 2: Transcript writer

**Files:**
- Create: `src/attractor/transcript.lg`
- Modify: `src/attractor/agent.lg` (`make-session` ~362: add `:transcript` state; `deliver-event!` ~38: call the writer before listeners)
- Test: `test/attractor/transcript_test.lg`

**Interfaces:**
- Consumes: `:stage_dir` from `@(:tool_hook_context @session)` (Task 1); `attractor.providers/redact`.
- Produces: `(attractor.transcript/make-writer {:path-fn (fn [] path-or-nil) :warn-fn (fn [event-map])}) -> writer`; `(attractor.transcript/write! writer event)`; session option `:transcript_path` (explicit path, overrides the stage directory); session option `:transcripts? false` disables.

- [ ] **Step 1: Write the failing tests** (session with `:complete_fn` scripting one tool call then a final answer, a fixture tool returning a 60,000-character string, `:tool_hooks {:stage_dir tmp}` standing in for the handler)

```clojure
(deftest transcript-records-turn-in-order
  ;; types in transcript.jsonl, in order, include
  ;; :user_input :tool_call_start :tool_call_end :assistant_text_end
  ;; and the :tool_call_end :output is the full 60,000 characters
  )
(deftest transcript-buffers-events-before-first-turn
  ;; :session_start appears as the first line once the first turn runs
  )
(deftest transcript-lines-are-whole-under-parallel-tools
  ;; three tool calls in one round with parallel execution enabled;
  ;; every line parses as JSON
  )
(deftest transcript-redacts-arguments-and-output
  ;; with a configured provider key K (providers registry via test fixture),
  ;; a tool call whose arguments and output both contain K yields no line
  ;; containing K and at least one containing "<credential>"
  )
(deftest transcript-file-is-private
  ;; (os/stat path) mode is 0600
  )
(deftest transcript-warns-once-when-logs-root-not-ignored
  ;; stage_dir inside a fresh `git init` repo with no ignore rule:
  ;; exactly one :warning with :category :transcript_not_ignored
  )
(deftest transcript-write-failure-warns-and-stage-completes
  ;; stage_dir is a read-only directory: one :warning :transcript_write_failed,
  ;; process-input returns normally
  )
```

- [ ] **Step 2: Run and confirm failure.**
- [ ] **Step 3: Implement.** The writer appends with one `spit :append` per event (delivery is already serialized by `drain-event-deliveries!`, so no extra lock); it holds events in memory until `path-fn` returns non-nil, then flushes them; it creates the file with mode 0600 before the first append; on the first write it runs `git -C <dir> check-ignore -q <path>` when the directory is inside a git or git-backed jj repository (skipping the check otherwise) and emits `{:type :warning :category :transcript_not_ignored :path p}` once; on any write exception it emits `{:type :warning :category :transcript_write_failed :message m}` and disables itself. Redact with `(providers/redact event)` before JSON encoding. The warnings go through `emit-event!`, so they reach `:on_event` listeners too.
- [ ] **Step 4: Run** the new tests plus `attractor.agent-test`, `attractor.tool-output-contract-test`, `attractor.agent-event-origin-test` — all pass.
- [ ] **Step 5: Commit** — `feat(agent): write a redacted transcript for every agent stage`

### Task 3: Usage event

**Files:**
- Modify: `src/attractor/agent.lg` (after the assistant turn is appended, ~1072)
- Test: `test/attractor/agent_test.lg` (add)

**Interfaces:**
- Produces: event `{:type :usage :input_tokens int :output_tokens int :cache_read_tokens int? :cache_write_tokens int?}` after each model call; Task 5 reads the last one.

- [ ] **Step 1: Failing test** — `usage-event-follows-each-model-call`: two-round scripted session whose mock responses carry `{:input_tokens 120 :output_tokens 30}` then `{:input_tokens 200 :output_tokens 10 :cache_read_tokens 150}`; assert two `:usage` events with exactly those values, each after its `:assistant_text_end`.
- [ ] **Step 2: Run, confirm failure.**
- [ ] **Step 3: Implement** — emit from `(:usage response)`, omitting cache keys the provider did not report; also store it as `(:last_usage @session)`.
- [ ] **Step 4: Run** `attractor.agent-test` — pass.
- [ ] **Step 5: Commit** — `feat(agent): emit a usage event after each model call`

## PR 2 — Pre-send backstop

### Task 4: Token counting

**Files:**
- Create: `src/attractor/token_count.lg`
- Test: `test/attractor/token_count_test.lg`

**Interfaces:**
- Consumes: the session's `:context_capacity` (`{:source :llamacpp :endpoint base ...}` from `context_discovery.lg`) to recognise llama.cpp; provider registry entries for Anthropic/Gemini base URLs and keys.
- Produces: `(attractor.token-count/count-messages counter messages) -> {:tokens int :exact? bool}`; `(attractor.token-count/make-counter {:protocol kw :base_url s :api_key s :model s :llamacpp? bool :http-fn f :timeout_ms 5000}) -> counter`. Session option `:count_tokens_fn (fn [messages] -> {:tokens :exact?} | nil)` overrides the counter (used by tests).

- [ ] **Step 1: Failing tests** (inject `:http-fn` returning canned responses)

```clojure
(deftest llamacpp-counts-with-tokenize
  ;; POST <base>/tokenize body {"content" text} -> {"tokens" [1 2 3 4]}
  (is (= {:tokens 4 :exact? true} (tc/count-messages llama-counter msgs))))
(deftest anthropic-counts-with-count-tokens
  ;; POST <base>/messages/count_tokens -> {"input_tokens" 57}
  )
(deftest gemini-counts-with-count-tokens
  ;; POST <base>/models/<model>:countTokens -> {"totalTokens" 41}
  )
(deftest no-counter-falls-back-to-chars-over-3
  ;; openai-compat without llama.cpp: 300 characters of content -> {:tokens 100 :exact? false}
  )
(deftest hung-counter-falls-back-after-timeout
  ;; http-fn sleeps 10s, :timeout_ms 200 -> returns within 1s, :exact? false
  )
(deftest failed-counter-falls-back
  ;; http-fn returns status 500 -> :exact? false
  )
```

- [ ] **Step 2: Run, confirm failure.**
- [ ] **Step 3: Implement.** Text for llama.cpp is the messages' contents joined with newlines (no chat template; the reserve absorbs template tokens). Use the same HTTP client `context_discovery.lg` uses, wrapped in a future with `deref` timeout.
- [ ] **Step 4: Run** — pass.
- [ ] **Step 5: Commit** — `feat(llm): count request tokens with provider counters`

### Task 5: Backstop in the turn loop

**Files:**
- Create: `src/attractor/context_budget.lg`
- Modify: `src/attractor/agent.lg` (turn loop, just before the provider call ~1034; `recover-context-overflow!` ~889)
- Test: `test/attractor/context_budget_test.lg`

**Interfaces:**
- Consumes: `(:last_usage @session)` and the history length at that usage (Task 3); `count-messages` (Task 4); `:turn_settings` (Task 1); window = `(:context_window_size turn-settings)` when set, else `(get-in @session [:provider_profile :context_window_size])` after `refresh-context-capacity!`.
- Produces: `(attractor.context-budget/check {:window int|nil :reserve int :base_tokens int :new_tokens int :exact? bool :max_output int|nil}) -> {:ok? true :max_tokens int|nil} | {:ok? false :error {...}}`.

- [ ] **Step 1: Failing tests**

```clojure
(deftest check-passes-and-clamps
  (is (= {:ok? true :max_tokens 1808}
         (cb/check {:window 10000 :reserve 8192 :base_tokens 0 :new_tokens 0
                    :exact? true :max_output 4096}))))
(deftest check-fails-over-window
  (is (= false (:ok? (cb/check {:window 1000 :reserve 100 :base_tokens 800
                                :new_tokens 200 :exact? true :max_output nil})))))
(deftest unknown-window-disables-check
  (is (:ok? (cb/check {:window nil :reserve 8192 :base_tokens 10 :new_tokens 10}))))
(deftest session-fails-before-sending
  ;; :context_window_size 2000, history of 20,000 chars, :count_tokens_fn exact;
  ;; process-input throws ex-info :category :context-length with
  ;; ex-data keys :tokens :reserve :window :exact?; the scripted :complete_fn
  ;; recorded zero calls
  )
(deftest session-counts-only-new-history
  ;; second request: :count_tokens_fn receives only messages added since the
  ;; last :usage, and the check uses last input_tokens (+cache) + that count
  )
(deftest node-window-overrides-discovered-window
  ;; discovered window 131072, :turn_settings {:context_window_size 2000}: the check uses 2000
  )
(deftest request-max-tokens-clamped
  ;; --max-output-tokens 4096 via :turn_settings, headroom 1000 -> request :max_tokens 1000
  )
(deftest provider-context-rejection-maps-to-context-length
  ;; :complete_fn throws the llama.cpp 400 shape (exceed_context_size_error);
  ;; process-input throws :category :context-length with :exact? false
  )
```

- [ ] **Step 2: Run, confirm failure.**
- [ ] **Step 3: Implement** `check` (headroom = window − (base + new) − reserve; fail when headroom < 0; `:max_tokens` = min of `max_output` and headroom, or headroom when `max_output` is nil). In the turn loop: compute base and new tokens, call `check`, throw on failure, otherwise `assoc` `:max_tokens` onto the request. In `recover-context-overflow!`, rethrow the provider's context-length error as the same `:context-length` shape instead of only warning.
- [ ] **Step 4: Run** the new tests plus `attractor.context-capacity-test`, `attractor.agent-test` — pass.
- [ ] **Step 5: Commit** — `feat(agent): fail a request that would exceed the context window before sending it`

## PR 3 — Tool allowlist

### Task 6: Per-turn tool allowlist

**Files:**
- Modify: `src/attractor/agent.lg` (request `:tools` ~1027; `execute-single-tool` registry lookup ~749)
- Test: `test/attractor/tool_allowlist_test.lg`

**Interfaces:**
- Consumes: `(:tools (:turn_settings @(:tool_hook_context @session)))` (Task 1).

- [ ] **Step 1: Failing tests**

```clojure
(deftest allowlist-limits-definitions-sent
  ;; :turn_settings {:tools ["read_file" "grep"]}: the request :tools names are exactly those two
  )
(deftest call-outside-allowlist-is-tool-error
  ;; model calls "shell": tool result :is_error true, text "Tool not allowed for this node: shell"
  )
(deftest unknown-tool-name-fails-at-start
  ;; :tools ["read_file" "nope"]: process-input throws :category :configuration
  ;; naming "nope", before any provider call
  )
(deftest allowlist-is-per-node-on-a-shared-thread
  ;; two turns on one session, first with :tools ["read_file"], second with none:
  ;; second request sends the full tool set
  )
```

- [ ] **Step 2: Run, confirm failure.**
- [ ] **Step 3: Implement** a private `(allowed-tools session) -> set|nil`; filter `profile-tools` by it; in `execute-single-tool`, treat a registered tool outside the set like `nil registered` but with the message above; validate names against the registry at admission.
- [ ] **Step 4: Run** the new tests plus `attractor.agent-test` — pass.
- [ ] **Step 5: Commit** — `feat(agent): restrict a node's agent to an allowlist of tools`

## PR 4 — read_handle

### Task 7: `read_handle` tool

**Files:**
- Modify: `src/attractor/agent.lg` (register next to `register-subagent-tools!` ~1373, from `make-session`)
- Test: `test/attractor/read_handle_test.lg`

**Interfaces:**
- Consumes: logs root = parent of `:stage_dir` from `@(:tool_hook_context @session)`; when no stage directory, the tool errors with "read_handle needs a pipeline run".
- Produces: tool `read_handle` with parameters `{path string, offset integer (1-based line, default 1), limit integer (lines, default 400)}`, output `N | line` numbered like `read_file`, plus a final line `[lines a-b of N]`. Task 9 registers `diff_refs` the same way.

- [ ] **Step 1: Failing tests** — `read-handle-pages-by-lines` (1,000-line file, offset 401 limit 400 returns lines 401-800 and `[lines 401-800 of 1000]`); `read-handle-refuses-outside-logs-root` (`../../etc/passwd` and an absolute path elsewhere → tool error); `read-handle-refuses-symlink-escape` (symlink inside logs root pointing outside → tool error).
- [ ] **Step 2: Run, confirm failure.**
- [ ] **Step 3: Implement** — resolve the canonical path and require it to start with the canonical logs root.
- [ ] **Step 4: Run** — pass.
- [ ] **Step 5: Commit** — `feat(agent): add read_handle for paging files under the logs root`

## PR 5 — Versioning adapter

### Task 8: `attractor.versioning`

**Files:**
- Create: `src/attractor/versioning.lg`
- Test: `test/attractor/versioning_test.lg`

**Interfaces:**
- Produces: `(defprotocol IVersioning (snapshot! [v label]) (changed-files [v from to]) (diff [v from to opts]))`; `(versioning/open root & [{:patch-dir dir}]) -> IVersioning` detecting `.jj`, then `.git`, else `:dir`; refs as in Global Constraints; `snapshot!` writes `<patch-dir>/<label>.patch` and `<patch-dir>/<label>.ref.edn` (the ref map) and returns the ref; `(versioning/read-ref path) -> ref`.

- [ ] **Step 1: Failing tests**, each run against a fresh git repo, a fresh jj repo (`jj git init`) and a plain directory in a temp dir:

```clojure
(deftest snapshot-leaves-repository-untouched
  ;; record `git rev-parse HEAD`, `git stash list`, `git status --porcelain`
  ;; (jj: `jj log -r @ -T commit_id`) before and after snapshot!; all equal
  )
(deftest clean-tree-snapshot-has-nil-patch)
(deftest changed-files-between-snapshots
  ;; s1, edit a.txt + add b.txt + delete c.txt, s2 -> #{"a.txt" "b.txt" "c.txt"}
  )
(deftest diff-shared-base-and-rebuilt
  ;; same base: diff from patch files; then commit (git) so s3 has a new base:
  ;; diff s1 s3 still lists the same paths and the text applies cleanly with `git apply --check`
  )
(deftest patch-round-trips-deletes-renames-binary
  ;; rebuild base + patch in a temp dir; the tree is byte-identical to the working tree
  )
(deftest dir-protocol-uses-initial-copy)
(deftest diff-paths-filter)
```

- [ ] **Step 2: Run, confirm failure.**
- [ ] **Step 3: Implement.** git: base `git rev-parse HEAD`; patch = `git diff --binary HEAD` plus untracked files via a temporary index (`GIT_INDEX_FILE=<tmp> git add -A && git diff --binary --cached HEAD`), never the real index. jj: base = `@-` commit id; patch = `jj diff --git -r @`. dir: first snapshot copies the tree to `<patch-dir>/.base`, later patches are `git diff --no-index --binary`. Rebuilding for different bases uses `git worktree`-free temp copies (`git archive <base> | tar -x`, then `git apply`).
- [ ] **Step 4: Run** — pass.
- [ ] **Step 5: Commit** — `feat: add a versioning adapter that records tree state as base-plus-patch refs`

### Task 9: `diff_refs`, `attractor diff`, `:snapshot` event

**Files:**
- Modify: `src/attractor/agent.lg` (register `diff_refs` like Task 7; add `record-snapshot!`), `src/attractor/cli.lg` (new `diff` subcommand)
- Test: `test/attractor/versioning_tools_test.lg`

**Interfaces:**
- Consumes: Task 7's registration pattern and logs-root check; Task 8's `open`/`diff`.
- Produces: tool `diff_refs {from string (path to a ref .edn file under the logs root), to string, paths array?}`, paged like `read_handle`; `(agent/record-snapshot! session label ref)` emits `{:type :snapshot :label label :ref ref}`; CLI `attractor diff <from.edn> <to.edn> [paths...]` prints the diff.

- [ ] **Step 1: Failing tests** — `diff-refs-matches-cli` (same text from the tool and from `cli/-main ["diff" ...]` captured stdout); `diff-refs-refuses-outside-logs-root`; `record-snapshot-appears-in-transcript-without-diff-text` (transcript has the `:snapshot` line with the ref map, no `@@` hunk text).
- [ ] **Step 2: Run, confirm failure.**
- [ ] **Step 3: Implement** — both entry points load refs with `versioning/read-ref` and call `diff` on an adapter opened from the ref's `:repo :root`.
- [ ] **Step 4: Run** — pass.
- [ ] **Step 5: Commit** — `feat: read diffs between snapshot refs from agents and the CLI`

## PR 6 — Stylesheet wiring and live check

### Task 10: Stylesheet attributes reach the session; live opt-in

**Files:**
- Test: `test/attractor/node_settings_pipeline_test.lg`; create `dev/context_backstop_live.lg`
- Modify: `docs/context-capacity.md` (document the attributes, the backstop and transcripts; replace the "does not compact history" note with the backstop's behaviour)

- [ ] **Step 1: Failing test** — `stylesheet-settings-reach-the-agent`: a DOT graph with `model_stylesheet=".r { --tools: read_file; --reserve-tokens: 4096; --context-window: 50000; }"` and a box node `class="r"`, run through `pipeline/run` with a mock backend built by `make-agent-codergen-backend` and `:complete_fn`; assert the request's tool names are `["read_file"]` and the session saw `:reserve_tokens 4096`, and that `<logs>/<node>/transcript.jsonl` exists.
- [ ] **Step 2: Run, confirm failure (or pass if Tasks 1-6 already wired it — then keep it as a regression test).**
- [ ] **Step 3: Write `dev/context_backstop_live.lg`**: exits 3 with a skip message unless `ATTRACTOR_LIVE_LLAMACPP_MODEL` is set; otherwise runs one agent stage on `llamacpp/<model>` with `--context-window 8192` and a task that reads a large file, and asserts the stage fails with `:context-length`, `:exact? true`, and the transcript shows the reads.
- [ ] **Step 4: Run** the pipeline test and the full suite: `"$LGX_LG" -source-paths src:test test/runner.lg --all` — no new failures.
- [ ] **Step 5: Commit** — `test: verify stylesheet context settings end to end`
