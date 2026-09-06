# Behavior Scenarios

Each scenario has a stable ID, an observable contract, and the strongest appropriate seam.

## Local sentinel scenarios

### SCN-ATTR-PARSE — DOT language compatibility

- Given representative DOT containing defaults, chains, comments, subgraphs, and typed attributes
- When it is parsed
- Then the graph model preserves the specified structure and inheritance currently covered by the parser suite
- Seam: parser integration

### SCN-SUBGRAPH-LABEL — Order-independent subgraph class

- Given a subgraph whose label is declared after its nodes
- When it is parsed and styled
- Then every contained node receives the normalized label class and matching stylesheet properties
- Seam: parser/stylesheet integration

### SCN-ATTR-ENGINE — Deterministic pipeline journey

- Given a validated graph containing success, failure, conditional, and goal-gate routes
- When the pipeline executes with deterministic handlers
- Then every stage executes at most as specified and the selected path, context, events, and final outcome agree
- Seam: engine integration

### SCN-PUBLIC-LIFECYCLE — DOT source to gated execution

- Given DOT source, two registered custom transforms, custom validation rules, and a deterministic handler registry
- When `attractor.pipeline/run` is called
- Then `prepare` returns the final graph and ordered diagnostics without execution; `run` parses once, runs built-ins before custom transforms in registration order, validates the final graph, exposes warnings on its outcome, mirrors graph attributes, and produces an agreeing handler path, event stream, checkpoint, and final outcome
- Given a built-in or custom ERROR diagnostic
- Then `run` throws category `:validation_error` with the complete diagnostics vector and no handler, run directory, initial checkpoint, or pipeline-start event is created
- CLI run/validate/graph and server submission prepare or execute through the same lifecycle API; `attractor.engine/run-pipeline` is documented and tested as the low-level already-prepared-graph seam
- Seam: public pipeline/CLI/server integration

### SCN-TIMEOUT — Deadline cancellation and quiescence

- Given a timed stage that invokes tools, nested agents, or parallel children
- When its deadline expires
- Then work is cooperatively cancelled, tool process groups stop, partial output remains available, no child continues mutating state, and exactly one timeout outcome is observed
- Seam: engine/agent integration

### SCN-STATUS-FILE — Handler-authored status routing

- Given a handler that writes valid `status.json` during its current attempt, including all four optional fields plus an unknown field
- When the handler returns a conflicting in-memory outcome
- Then the file outcome is authoritative; preferred label/suggested IDs drive routing, context updates merge, notes survive, event and checkpoint outcomes agree, and the unknown field is ignored
- Given no file and a valid handler outcome, the handler outcome is persisted and used
- Given a RETRY file followed by an attempt that writes no file, the prior attempt's file is not reused
- Given malformed JSON, invalid outcome enum, or an invalid type for each specified optional field (including a non-string suggested ID), resolution terminates explicitly rather than silently routing
- Given pipeline cancellation or attempt timeout, a status file written before cancellation or late after handler quiescence cannot replace the terminal cancellation/timeout outcome
- Compose proof across the shared runtime contract: exhaustive public `execute-with-retry` schema, precedence, and cancellation cases; main-pipeline integration for both routing mechanisms, context/event/checkpoint agreement, canonical persistence, retry freshness, and terminal malformed input; and representative `execute-subgraph` parity for label/suggested-ID routing, handler fallback persistence, retry freshness, malformed/type-invalid termination, cancellation, and auto-status behavior
- Seam: engine integration

### SCN-AUTO-STATUS — Missing-status synthesis

- Given a handler that produces neither a status file nor a valid outcome in the main or subgraph execution path
- When `auto_status=true`
- Then the engine persists and routes exact JSON equivalent to `{"outcome":"success","notes":"auto-status: handler completed without writing status"}`
- When an explicit node `auto_status=false` overrides an inherited true default, resolution fails instead of synthesizing success in both paths
- Seam: parser/engine integration

### SCN-CHECKPOINT — EDN persistence and resume

- Given a partially completed run with context and artifacts
- When it is resumed from the project-standard EDN checkpoint
- Then completed nodes are not rerun and execution continues with equivalent state
- Seam: engine integration

### SCN-PINNED-RECOVERY — Immutable launched workflow

- Given a public run whose prepared DOT source is captured and fingerprinted
- When the original file changes, disappears, or becomes invalid before resume
- Then pinned public resume verifies and executes the captured prepared plan, reports deterministic drift, and never adopts current bytes
- Given a missing, corrupt, mismatched, or partially published workflow bundle
- Then resume fails before engine events or handlers
- Direct `execute-prepared` calls publish before engine start, and every loop-restart segment contains a locally resumable capture with the original fingerprint
- Resume at an outgoing restart edge emits `pipeline.restarting` before starting the fresh segment, preserves the old checkpoint bytes, and resets completed-node history; a restart reached later during resumed execution also republishes the verified captured bundle
- Server registration becomes visible only after verified publication; concurrent callbacks share registration, preparation timeouts remove provisional state and prevent late engine entry, and registered requests return within bounded waits even if signal delivery stalls
- Seam: public pipeline/checkpoint/server integration

### SCN-CONTEXT-ISOLATION — Deep branch isolation

- Given a parent context containing nested EDN maps, vectors, sets, and lists
- When a snapshot and two branch clones are made
- Then every non-empty nested container is non-identical to its source counterpart, the snapshot remains stable after later parent writes, neither clone/sibling/snapshot/parent observes another copy's structural updates, and clone logs are independent
- Given an opaque or mutable non-EDN value
- Then snapshot/clone throws with `:category :unsupported-context-value` and an exact `:path`: `[:values key]` at the root, map keys or sequence indexes for contained values, and `:map-key`/`:set-member` sentinels for unsupported keys/members
- Seam: context unit/integration

### SCN-PIPELINE-COMPOSITION — Context-mapped composition

- Given a valid parent whose project-defined `subpipeline` node declares a child DOT path and quoted `input_map` / `output_map` strings
- When public preparation recursively resolves authorized sources, transforms and validates each physical source once, and captures the complete closure
- Then active source cycles, logical identity collisions, unauthorized paths, invalid UTF-8, and invalid descendants stop execution before publication or handlers; completed physical aliases retain their captured identity
- When the parent invokes a captured child through the public prepared-execution lifecycle, only mapped inputs are deep-copied into the child. Unmapped values are ignored, not rejected. Present `nil` differs from a missing input, which fails before child execution; duplicate or engine-owned destinations fail configuration validation
- All mapped outputs are gathered before one update map is returned after SUCCESS/PARTIAL_SUCCESS. Missing outputs fail transactionally. FAIL/CANCELLED retain status/category/retryability/reason/notes without mapped outputs
- Parent, child, grandchild, and sibling runs have distinct contexts, run roots, checkpoints, completed nodes, outcomes, retries, parallel/manager runtime slots, step budgets, and fidelity histories. Evidence must show state consumption or mutation does not leak, not just compare successful outcomes
- Child budgets select node override, containing graph default, then 10,000 independently of the parent's remaining steps. Each subpipeline call costs one parent step; restart segments share their invocation's budget
- Each ordered child event has exactly `:type`, `:parent_node_id`, `:child_logs_root`, `:child_plan_fingerprint`, and `:event`; the fingerprint is the selected plan digest, not the shared closure digest
- Pipeline and node-timeout cancellation propagate through nested children, join held cleanup before any nested or outer terminal event, and prevent late mapped outputs. Caller custom handlers survive actual child callback handoff and restarts without mutating registry templates
- Safe child/status paths reject escaping and dangling symlinks before cleanup or writes. Fresh UUID child attempts cannot reuse preexisting roots
- Execution and resume never reparse or adopt changed/deleted current sources. An interrupted parent retries its child under a fresh root while retaining every old artifact byte; completed child calls are skipped with outputs intact. Each interrupted child/grandchild checkpoint resumes its own selected captured graph, and restarts preserve the captured closure
- Intended mapping syntax is the Clojure reader superset of EDN. The user-approved ordinary string-map workaround remains a known unmet requirement: metadata/discard acceptance lives in the failing compatibility suite, not in the default passing evidence
- Seam: public pipeline/engine/checkpoint integration, supplemented by compiled CLI file-backed execution and recovery

### SCN-GRAPH-MERGE — Transform-based graph composition

- Given two independently parsed graphs and a caller custom transform that merges nodes and edges into one valid graph
- When public preparation validates and captures the transformed graph, then execution runs it
- Then the merged nodes and edges are present in validation and the captured plan, execution traverses the intended merged route, and the original parsed inputs remain unchanged
- And a copied checkpoint/workflow bundle resumes that captured route after current root/donor sources change, without rerunning transforms or changing the original recovery artifacts
- Seam: public transform/validation/pipeline/checkpoint integration; complete component evidence in `graph_merge_contract_test.lg` (3 tests / 63 assertions), not a new built-in merger API. Recovery evidence covers checkpoint and workflow-bundle bytes, not ancillary execution logs.

### SCN-CLOJURE-READER — Safe Clojure data-reading syntax

- Given valid metadata and reader-discard forms in project data, including quoted context-mapping strings
- When data is read without evaluation and validated against the artifact's schema
- Then the resulting values preserve Clojure reader semantics; mappings contain exactly one resulting string/string map and files retain `.edn` names
- The temporary scanner must not be mistaken for completion: the five compatibility acceptance assertions currently fail and must move into default discovery when native support is restored
- Seam: native reader/application integration; dependent on upstream compatibility fixes, not a local PEG redesign

### SCN-LOOP-RESTART — Fresh-run restart edge

- Given a selected edge with `loop_restart=true`
- When the source stage completes
- Then `pipeline.restarting` contains exact keys `:old_logs_root`, `:new_logs_root`, and `:target` before the fresh `pipeline.started` and target `stage.started`, and execution targets that node under the fresh root
- Across two rapid restarts, roots are pairwise unique, prior roots and their checkpoint/status/artifacts remain intact, and each new root begins without inherited files
- A step is one nonterminal handler execution or one goal-gate reroute; recognizing a satisfied terminal is free. Exact-limit handler-then-terminal execution succeeds, while an exhausted budget rejects another handler or unsatisfied-terminal reroute before its event. A nonterminating restart cycle reaches the one invocation-wide bound without stack growth, returns FAIL with exact reason `Pipeline step limit exceeded (<limit> steps)`, and emits the matching `pipeline.failed`; the positive-integer default remains 10,000 and invalid values fail before execution
- The prepared graph, custom registrations, cancellation predicate, event sink, semantic context atom/values/logs, and selected restart edge are preserved; the edge's fidelity/thread data reaches the target. Run-scoped parallel/manager slots, fidelity maps/sessions, completed nodes, node outcomes, retry counters, first-node fidelity override, checkpoint, and per-stage files reset; caller registry runtime atoms remain untouched
- Context remirrors authoritative `graph.*` values, replaces `run.id`, and sets `current_node` on target entry. Scrubbing removes only string or unnamespaced-keyword spellings exactly equal to `run.id`, `current_node`, `outcome`, or `preferred_label`, plus those beginning `internal.retry_count.`; namespaced keywords, symbols, other key types, and boundary names are retained. A sorted/custom top-level values map retains its representation, order/comparator behavior, metadata, and nested value identities
- Each departed and final full-fidelity session closes once. Cleanup attempts every close and clears the session map even after a close error, preserves a primary execution error over cleanup errors, and otherwise surfaces the first cleanup error; restart also closes caller-provided fidelity state, while ordinary non-restart completion retains caller ownership
- Seam: engine integration

### SCN-TRANSFORM-ORDER — Deterministic custom transforms

- Given a caller-owned parsed graph, built-in transforms, and two ordered custom transforms
- When `attractor.transforms/apply-transforms` is called directly
- Then built-ins run first, custom transforms receive one another's returned graphs in registration order, the returned graph contains every change, and the caller's original graph remains structurally unchanged
- Given the same transforms on the DOT-source public lifecycle
- Then validation observes the final returned graph rather than the pre-transform graph
- Seam: transform/validation integration

### SCN-FIRST-SUCCESS — Early parallel completion

- Given a bounded parallel fork with a successful branch and a native-blocked loser
- When policy is `first_success` and SUCCESS is observed
- Then queued launches stop, the loser observes cancellation, and all launched workers and registered descendants are joined before return; held cleanup prevents fork/pipeline terminal events and fan-in entry
- External cancellation during cleanup wins; successful routing enters fan-in exactly once after cleanup
- Branch contexts remain isolated and checkpoint results retain original edge order and boundary routing
- Thrown primary execution errors survive fidelity cleanup failures; ordinary returned FAIL and retryable handler exceptions retain their existing retry semantics
- Direct evidence also covers replenishment, duplicate targets, exact SUCCESS, wait_all, clone/launch/worker errors, and sibling scope isolation
- Seam: real public pipeline/engine/checkpoint integration plus direct native concurrency contracts; async helper ownership limitation remains tracked in let-go #806

### SCN-ARTIFACT-DISCOVERY — Handler artifact lifecycle

- Given a handler that produces small and threshold-exceeding artifacts
- When the pipeline finishes and resumes
- Then artifacts are discoverable from run state, correctly inline/file backed, and preserved across checkpoint resume
- Seam: engine/artifact integration

### SCN-FANIN-RANKING — Prompted and heuristic fan-in

- Given real wait-all branches with ordered, scored outcomes and a configured unified client
- A prompted fan-in selects against the heuristic through a real in-memory provider; complete EDN candidate envelopes retain original indices, statuses and branch evidence
- A blank prompt chooses the higher score without invoking the provider
- Saved checkpoints agree with returned winners, winner statuses, ordered results and completed nodes
- Independent and captured-child runs preserve caller registry maps and mutable runtime state
- Copied pinned recovery uses the captured prompt despite source drift, does not rerun completed branches, and leaves all original artifacts unchanged
- External cancellation and injected-clock node timeout cannot return or emit terminal events until held provider cleanup joins; no winner is published afterward
- Seam: public pipeline/engine/native scope/unified client/checkpoint integration; CLI and offline compiled HTTP checks supplement this, not live-provider parity

### SCN-HUMAN-TIMEOUT — Non-blocking console question

- Given no console input and a bounded question timeout
- When a question is asked
- Then the interviewer returns timeout without an indefinitely blocked input read
- Seam: interviewer integration with injectable clock/input

### SCN-SSE-LIVE — Maintained event stream

- Given a running pipeline with a delayed later stage
- When a client attaches to `/events` before completion
- Then it receives later ordered events on the same connection and a terminal close signal
- Seam: HTTP integration

### SCN-EVENT-FAMILIES — Complete ordered observability

- Given successful, failed, timed-out, parallel, checkpoint, and human-interview runs
- When their event streams are recorded
- Then every specified pipeline/stage/parallel/interview/checkpoint family appears once in causal order with the required outcome detail
- Seam: engine/server integration

### SCN-CAL-FAILURE-SHUTDOWN — Session error and flush contract

- Given auth, rate-limit, transport, protocol, cancellation, and tool failures
- When a session handles each failure
- Then auth is never retried, only retryable failures back off, graceful shutdown flushes terminal events in order, and resources close once
- Seam: coding-loop integration. Local deterministic-client journey is verified in `agent_loop_contract_test.lg` (3 tests / 43 assertions): sequential and queued follow-up inputs, actual tool-result continuation, steering/reasoning boundaries, exact normal event order, per-input versus session limits, and enabled/disabled loop warnings. This does not establish streaming, failure/shutdown event completeness, or native-provider parity.

### SCN-TOOL-HOOKS — Tool pre/post hooks

- Given configured pre- and post-hooks around an LLM tool call
- When pre succeeds, the tool runs and post observes its result; when pre fails, the tool is skipped; when post fails, the tool result is retained and failure evidence is emitted
- Seam: coding-loop integration

### SCN-HANDLER-MATRIX — Registry-to-engine dispatch

- Given each built-in handler shape/type and a registered custom handler
- When each node executes through the engine registry
- Then the correct handler receives the node/context and its outcome controls routing
- Fixed expectations cover eight executable shapes, eleven explicit types (including custom/subpipeline), and three unknown-type/shape fallbacks
- Explicit registered types override conflicting shapes; missing registrations fall through shape then codergen
- Suggested routing overrides the higher-weight default branch; handler witness, branch-observed context, invocation counts and checkpoint agree
- Caller registry and its mutable parallel/manager runtime values remain unchanged
- Msquare resolves to exit but the engine recognizes terminal completion before dispatch, as required by the upstream core loop; explicit exit type on a nonterminal node separately exercises the registry entry
- A bounded wrong-registration control loses the expected witness and takes the default route
- Seam: real low-level engine with registry spies; native handler behavior is covered separately, and this matrix does not claim public validation accepts every synthetic graph

### SCN-INTERVIEWERS — Interviewer contract matrix

- Given console-injectable, callback, queue, auto-approve, and recording interviewers
- When questions use choices, accelerators, defaults, and free text
- Then normalized answers, metadata, recording, and routing match the question contract
- Seam: interviewer integration

### SCN-VALIDATION — Diagnostics and execution gate

- Given malformed, unreachable, and custom-rule-invalid graphs
- When validation runs through the public lifecycle
- Then `validate` returns diagnostics with keyword keys `:rule`, `:severity`, and `:message` plus applicable `:node_id`, `:edge`, and `:fix`; severities use `:error`/`:warning`/`:info`; built-ins precede custom rules; reachability is ERROR; and `validate-or-raise` throws `:validation_error` with the complete diagnostics vector
- Through the public lifecycle, ERROR diagnostics reach no handler and create no execution state, while WARNING diagnostics remain observable and permit execution
- Seam: validation/engine integration

### SCN-CAL-LOOP — Complete local agent session

- Given sequential user inputs, reasoning changes, steering, repeated tool calls, loop detection, and a follow-up
- When the session runs against a deterministic adapter
- Then history and lifecycle events remain ordered, stop conditions are enforced, and follow-up continues the same session
- Seam: coding-loop integration

### SCN-CAL-PROFILES — Provider-aligned profile contracts

- Given OpenAI, Anthropic, Gemini, and custom profiles
- When their tool registries and base instructions are materialized
- Then file/edit/shell/search/subagent tools, schemas, defaults, and provider options match each profile
- Seam: profile contract

### SCN-CAL-TOOLS — Built-in tool execution matrix

- Given filesystem, edit, shell, search, and subagent calls that succeed, fail, exceed output bounds, or are cancelled
- When each runs through the coding loop
- Then its schema/result contract is correct, cancellation reaches the operation, raw events retain full output, and model history receives bounded output
- Seam: coding-loop integration

### SCN-CAL-SUBAGENTS — Subagent lifecycle

- Given nested subagents at and below the configured depth/turn bounds
- When the parent uses spawn, send-input, wait, and close operations
- Then histories remain independent, bounds are enforced, results propagate, and cancellation closes descendants
- Seam: coding-loop integration

### SCN-CAL-ENV — Execution environment result contract

- Given successful, failing, and cancelled local commands
- When the coding loop executes them
- Then exit status, duration, stdout, stderr, cancellation, and partial output have exact documented values
- Seam: environment integration

### SCN-CAL-TRUNCATION — Raw and model output separation

- Given pathological 10 MB, single-line, and two-line tool output
- When it is recorded and returned to the model
- Then events retain full raw output while model history receives deterministic bounded head/tail content with an explicit marker
- Seam: coding-loop integration

### SCN-SYSTEM-PROMPT-BOUND — Bounded repository context

- Given repository instructions larger than 32 KB plus platform, working-directory, and git metadata
- When the layered system prompt is built
- Then required metadata is present and instructions are deterministically bounded with an explicit truncation marker
- Seam: prompt-builder integration

### SCN-FAIL-RETRY-CONTRACT — Returned failure semantics

- Given a handler that returns FAIL under a configured retry policy
- When the pipeline executes
- Then behavior matches the documented resolution of the upstream §3.5 versus Definition-of-Done conflict and remains stable under regression
- Seam: engine integration

### SCN-ULLM-CANCEL — Real transport cancellation

- Given a local HTTP server that stalls headers, body, or stream chunks
- When cancellation/deadline fires
- Then the client closes promptly, retains partial chunks where applicable, and emits one normalized terminal cancellation
- Seam: local HTTP integration

### SCN-ULLM-HTTP-ERRORS — Normalized transport failures

- Given a controllable local HTTP server returning retry statuses/headers, malformed bodies, and dropped connections
- When each adapter calls it
- Then retry timing and normalized terminal errors match policy
- Seam: local HTTP integration

### SCN-ULLM-CLIENT — Client and middleware contract

- Given environment/programmatic clients, a default client, multiple providers, and ordered middleware
- When completion is invoked
- Then routing/default selection and onion-order middleware execution are deterministic for completion and streaming, stream wrappers observe ordered iterator events, and concurrent requests do not leak state
- Seam: client integration

### SCN-ULLM-HIGHLEVEL — High-level and structured generation

- Given valid and mutually-exclusive prompt/message inputs plus valid/invalid schemas
- When generate, stream, generate-object, and stream-object run
- Then results accumulate equivalently and structured-output failures are normalized
- Seam: high-level API integration

### SCN-ULLM-TOOLS — Active/passive tool contract

- Given tool-choice modes, passive tools, active tools, invalid arguments, parallel calls, and a bounded round limit
- When generation continues through tool results
- Then validation/repair, ordering, round limits, and provider continuation messages match contract
- Seam: client/tool integration

### SCN-ULLM-ADAPTERS — Native provider payload contracts

- Given the common message/content model and provider-specific options
- When each native adapter serializes and parses complete/stream responses
- Then roles, images, reasoning, caching, usage, rate limits, warnings, finish reasons, tools, and beta/options fields round-trip without cross-provider leakage
- Seam: local recording-server contract

### SCN-OPENAI-COMPAT — OpenAI-compatible endpoint extension

- Given a custom base URL and model for an OpenAI-compatible endpoint
- When completion and streaming run
- Then endpoint/auth configuration and normalized results follow the documented extension contract
- Seam: local HTTP integration

## Credential-gated residual scenarios

### SCN-ATTR-SMOKE-LIVE — Real Attractor journey

- Run the reference pipeline through one configured real provider and assert routing, artifacts, checkpointing, and completion
- Seam: opt-in end to end

### SCN-PROVIDER-MATRIX — OpenAI/Anthropic/Gemini parity

- Run equivalent text, image URL/base64, structured output, stream, tool-call continuation, reasoning, mid-session steering, caching/usage, provider-options, invalid-key, rate-limit, and coding-loop profile/tool/subagent journeys against each configured provider
- Record provider/model IDs and redact secrets
- Seam: opt-in live provider contract
