# Codebase, specification and convergence audit — 2026-10-07

## Baseline judgment

The implementation is substantial, but it is not consistently converged on its
specifications or its public execution paths. The uncommitted Continual Harness
is not ready to be described as durable, bounded, or an operational self-improvement
system. The core also has independently reproduced specification defects.

HTTP human interaction **works**. Current-source and compiled loopback journeys
both successfully answered a workflow question. The actual path is
`cli/serve → hub-http → nREPL → hub → HubInterviewer`. The separately named
`web_interviewer.lg` belongs to the older `server.lg` implementation. Neither
router serves a browser application; no HTML/JS/TS/CSS frontend was found.

This records the pre-repair audit, not an approval. Production code was unchanged
during the audit. The user then requested a working-branch checkpoint and revisions:
the pre-existing harness is preserved at `dfa3fed` on
`audit/continual-harness-convergence`. No paid model calls, deployments or tracker
posts were performed.

## Repair checkpoints

This section tracks revisions; findings below retain their original baseline
locations and evidence. The user explicitly included model-training infrastructure,
then clarified that the normal harness must not depend on a trainer. Training is
therefore confined to the explicitly selected `co_learning` handler.

| Findings | Repair checkpoint | Fresh evidence |
|---|---|---|
| R04, R11, R12, R23, R25 | `31208fe` | 87 tests / 532 assertions pass; malformed, null, false, blank, array and scalar arguments do not execute tools; valid `{}` does. Independent review approved. |
| R19, R26 | `ea95ba0` | 48 tests / 219 assertions pass; valid no-coverage holds round-trip, forged contradictions remain rejected, header-only credentials require private files. Independent review approved. |

The normal harness now runs without any trainer configuration. The optional
co-learning path uses explicit scoring, teacher, trainer and activation commands;
a deterministic local trainer updates a small policy and the next rollout consumes
its checkpoint. This verifies the integration contract, not real-model learning
performance or reproduction of the paper's reported results.

| Findings | Repair checkpoint | Fresh evidence |
|---|---|---|
| R01, R02, R09, R10, R24 | `563486c` | 222 tests / 1,277 assertions pass; independent runtime review passes 106 tests / 450 assertions. Implicit defaults, untimed cancellation, parameters and initial CLI events covered. |
| R03, R05–R07, R13–R18 | `e7ee6ae` | Final focused review regressions: 41 tests / 180 assertions pass. Specification and Google quality review approved after persistence, ownership, provider-text and nested-validation corrections. |
| R22 | `e429317` | Root rerun: 28 tests / 122 assertions pass; acquisition race closes exactly once, partial startup releases child/files. Independent source and leak-probe review approved; standalone transport rerun passes 6 tests / 47 assertions. |
| R27 (verification finding) | `23d0239` | 61 tests / 2,022 assertions pass, including both official schema corpora. Per-selector cache retains dialect/registry isolation; independent review passes 21 tests / 91 assertions. |
| R20, R21 | `8a3e7a6` | Atomic MCP admission, acquired-handle rollback and independently bounded teardown covered; independent review approved. |
| R08 and requested training infrastructure | `c7e88bd` | 12 tests / 44 assertions pass, including real subprocess training, changed next-rollout behavior, failed-stage resume, environment continuity and public cancellation. Specification and quality review approved. |

Final integrated verification passes below. Authored evaluator loops have cooperative
checkpoints and owned cancellation; arbitrary native callbacks are not an OS
sandbox or a universal wall-clock bound. External training adapters must provide
real teacher/reward/model services and idempotent activation. Environment continuity
covers declared local state; external services need adapter-specific guarantees.

R25 intentionally follows the native Responses protocol's top-level function name
rather than the pinned spec's nested form. This interpretation is grounded in the
[official Responses function-choice type](https://github.com/openai/openai-python/blob/main/src/openai/types/responses/tool_choice_function_param.py).
Chat Completions keeps its separate translation.

## Integrated verification after repairs

**Initial repair result:** `LGX_LG=/opt/homebrew/bin/lg lgx suite` exits 0 with
**1,676 tests / 14,691 assertions / zero failures** after the schema repair.
The source checkpoint is `23d0239`, documented at `be53efb`. The subsequent
interactive-session and context follow-up below changes production code again;
this earlier suite does not certify those changes.
`final-suite-schema-fixed.log`, `final-build.log` and
`final-http-question-probe.log` retain the final evidence. All R01–R27 findings
have repair checkpoints above, with the explicit capability limits retained.
The following intermediate results explain how full verification was reached.

The fresh compiled HTTP human-question probe passes all seven checks, including
answer delivery, cleanup and timeout defaults. A fresh `lgx build` succeeds.

The first repaired monolithic suite was stopped after thirteen minutes with no
final result. A diagnostic process-per-namespace run completed 177 of 179 selected
namespaces: 1,659 tests / 12,948 assertions, zero assertion failures or errors.
The two official schema dialect/reference corpora exceeded their 120-second
limits. Codex agent tests were excluded while their repair was active; a subsequent
independent Codex agent/transport/MCP-client run passes 28 tests / 122 assertions.
These overlapping counts must not be added together.

The schema timeout investigation identified repeated vocabulary URI validation
while indexing the same immutable registry: a trivial reference example made
2,329 selector calls, all recalculating vocabulary declarations. A per-selector
cache reduced repeated calculations to 26 in the diagnostic probe. The cache repair is committed at `23d0239`; both official corpora plus focused
schema contracts pass (61 tests / 2,022 assertions). This is R27, a performance
defect uncovered by integrated verification, rather than a schema semantic change.
The cache belongs to one immutable registry selector and cannot reuse another
registry's vocabulary decisions. See `schema-timeout-diagnosis.md` and
`schema-cache-review.md` in the evidence directory.

A reviewer's concurrent Codex run observed four assertions fail in the existing
partial-EOF timing test. Root's combined run and the reviewer's subsequent standalone
transport run both passed. Timing contention is plausible but not established;
the discrepancy remains recorded in `codex-final-review.md`.

## Baseline and authority

Follow-up review after this audit found the sibling checkout
`/Users/ndn/development/prime-agent` at `75648beea`. Its interactive session owns
conversation, steering/follow-up queues, persistent execution and background
refinement. The original repairs did not complete that interaction model.
Interactive integration is checkpointed at `93a860b`, and context recovery at
`41fb759`. The [interactive iteration plan](superpowers/plans/2026-10-07-interactive-harness.md)
records the added public journeys, specification review and Google quality review.

The user's subsequent llama.cpp failure (134,031 prompt tokens versus 131,072
capacity) exposed an additional main-branch gap: advisory history-size warnings
did not budget or compact complete requests, and `exceed_context_size_error` was
misclassified when accompanied by numeric code 400.

The repair separates the full transcript from the model-context projection,
admits estimated complete requests with output and uncertainty allowances, and
uses bounded rolling checkpoints. It recognizes the actual server error and
retries generation once after a smaller request, retaining the server limit for
later tool rounds in that turn. Accepted steering/follow-up input survives
recoverable overflow. Review also fixed start-only streaming events mistaken for
visible output and native provider options bypassing managed context limits.
Ordinary harness operation still requires no trainer. Exact tokenizer admission,
live-model summary quality and full conversation recovery after restart remain
outside this verification.

October 8 verification uses the user-requested
`/Users/ndn/development/let-go/bin/lg`. It exposed a shutdown publication gap:
after joining cancelled workers, the host now resolves remaining aggregate turn
promises. A baseline LLM timeout fixture assumed cancelled sleep resumed ordinary
code; `eb3de5e` replaces that assumption with explicit acquisition/finalization
handoffs and passes all 85 LLM tests / 525 assertions.

The first complete run on this runtime produced 45 failed assertions across
1,713 tests. Its typed cancellation semantics exposed both fixture assumptions
and missing cancellation normalization. `636ea99` fixes owned cancellation at
parallel, timed-handler and Codex boundaries, preserves steering provenance in
recovered queues, and updates cleanup fixtures without dropping join/identity
assertions. The affected groups and independent specification review pass;
Google quality review approves the migration. The first-run log is retained as
`full-suite-before-cancellation-migration.log` in the interactive evidence directory.

**Final October 8 result:** at `636ea99`, the complete suite passes **1,713 tests /
14,888 assertions / zero failures** using the requested `lg dev (0cfd343)` runtime.
`lgx rebuild` and the compiled offline two-turn console journey pass, including
context inspection, durable harness inspection and clean shutdown. Evidence is
under `evidence/interactive-harness-2026-10-07/`: `full-suite.log`, `build.log`,
and `compiled-console-transcript.log`. The public tool/environment/memory journey
and repeated compaction are covered by the integrated regression suite. No live
model quality or paper-result reproduction claim is made.

This prompted deeper review of the unmerged context-foundations token counter.
Its llama.cpp path tokenizes concatenated message text, excluding chat-template
and tool-schema overhead, yet marks the result exact. Its heuristic fallback
also excludes schemas. This qualifies the earlier aggregate branch review:
those counters must not be adopted as exact admission evidence. That branch has
not been merged or modified by this iteration.

- Main checkout: `d81c047`, with an existing modified `agent.lg`, three untracked
  harness modules, four untracked test namespaces, and a continual-harness example.
- No commits dated October 5–7 occur in the available local refs. Remote refs
  were inspected as cached locally; no remote freshness claim is made.
- The latest two active commit dates are October 2–3: 40 commits, with aggregate
  range `cdd825b^..ee19ccc`. The implementation commits are on the unmerged
  `context-foundations` branch, not on this main checkout.
- The user-specified harness research target is [Continual Harness](https://arxiv.org/html/2605.09998v1), especially §§2–3 and Appendix D. The paper-alignment section below takes precedence over interpreting the older evaluation proposal as this harness's target.
- `specs/` is the original three-spec baseline. `docs/specs/` contains historical
  annotated copies. Project RFCs and accepted extension requests add requirements;
  archives describe historical states, not additional simultaneous authorities.
- The October 6 request in
  `.agents/teamwork/orchestrator/ORIGINAL_REQUEST.md` explicitly asks for session-capable
  dynamic let-go tools, lifecycle isolation, bounded execution and serialization.
  It supersedes treating all generated code as a toy pure-function sandbox.
  The older proposed evaluation extension still needs reconciliation with it.
- No prime-agent source implementation was found in this repository. Its local
  acceptance request can be audited; parity with an external implementation and
  authorship attribution cannot be independently established here. The prime-number
  autoresearch example is a different project concept.

Applied Google Engineering Practices imports:
`~/.claude/skills/codereview-reviewing/SKILL.md`, `codereview-standard/SKILL.md`,
and `codereview-comments/SKILL.md`, alongside Lynx/Rook. The Google imports exist
as actual skills, but were absent from this session's Codex skill catalog.
Design, functionality, complexity, tests, naming, comments, style and documentation
were assessed; no style-only objection is presented as a blocker.

## Must fix: core and lifecycle correctness

### R24 — P1: CLI can miss a human question emitted before it attaches

Locations: `src/attractor/cli.lg:142–146,537–538`, `hub.lg:446–450`.
`run` starts the workflow before `pump-events!` attaches a client. Attachment
starts at the newest event cursor, so an already-emitted question is skipped;
the pump does not reconcile pending questions. A deterministic scheduling probe
delays attachment until the real workflow publishes its gate: one question remains
pending, the interviewer is never called, and execution does not finish until
explicit cancellation. The launch-before-subscription pattern also affects resume
and initial external-agent output. Subscribe before launch and retain that cursor.
Regression: an immediately waiting human gate and an immediately completing agent
must both be observed. Proof: `evidence/codebase-audit-2026-10-07/attractor-cli-attach-race-probe.lg`.

### R01 — P1: Implicit DOT nodes lose defaults, including goal gates

Location: `src/attractor/parser.lg:418–440`.
Nodes first introduced by an edge use an ad hoc partial constructor instead of
the ordinary default promotion. `prompt`, `llm_model`, `timeout` and `goal_gate`
remain blank/absent/false even when their defaults survive in `:attrs`.
This violates Attractor §2.11 and affects actual execution: a defaulted tool
`false` with `goal_gate=true` followed by a fail edge to exit yields pipeline
SUCCESS when implicit; adding only `work;` makes the run fail its goal gate.
Use one node construction path. Regression: execute both syntactic forms and
require identical prompt/model/deadline/gate behavior.
Proof: `evidence/codebase-audit-2026-10-07/attractor-runtime-contract-probe.lg`,
`evidence/codebase-audit-2026-10-07/attractor-default-gate-probe.lg`.

### R02 — P1: Untimed tools continue side effects after cancellation

Locations: `src/attractor/handlers.lg:84–85,153–157`, `engine.lg:486–491`.
Without a DOT timeout, execution takes raw `os/sh` and never observes the node
cancellation predicate. A public pipeline running `sleep 0.5; echo ... > sentinel`
still creates the sentinel after cancellation. Adding only `timeout="5s"` stops
the side effect. An indefinitely blocked command also prevents settlement.
Use owned cancellation-aware execution whether or not a deadline is configured.
Regression: cancel an untimed tool through the public hub and verify no later
side effect and joined shutdown. Proof: `evidence/codebase-audit-2026-10-07/attractor-web-cancel-probe.lg`.

### R03 — P1: Normal coding-agent construction bypasses retries

Locations: `src/attractor/agent.lg:967–974`, `cli.lg:271–281`.
The retry wrapper is used only with an injected `:llm_client`. Normal CLI-created
sessions call low-level `llm/stream` or `llm/complete` directly; neither retries.
Offline 503 probes in both modes make one call and close the session despite
`max_retries=2`. Existing wire tests inject a client and miss the production branch.
This contradicts coding-loop Appendix B/§9.11. Share the attempt boundary while
preserving the no-replay rule after observable streaming output.
Regression: default-session construction, transient failure then success, in both
modes. Proof: `evidence/codebase-audit-2026-10-07/attractor-agent-retry-audit.lg`.

### R04 — P1: Malformed Anthropic streamed arguments can execute a tool

Location: `src/attractor/llm.lg:2440`.
JSON parse failure is replaced with `{}`. A permissive or zero-argument tool
therefore passes schema validation and executes despite malformed wire arguments.
A public streaming probe supplied `{bad` and observed the side-effect executor
called with `{}`. Unified LLM §5.8 requires rejection, not execution.
Preserve the malformed argument failure through normalization and tool dispatch.
Regression: malformed arguments must execute zero tools on every native adapter.
Proof: `evidence/codebase-audit-2026-10-07/attractor-anthropic-malformed-audit.lg`.

### R05 — P1: Periodic refinement can deadlock session lifecycle

Locations: `src/attractor/agent.lg:1148–1169`, `refiner.lg:141–145`.
Refinement performs synchronous LLM work and invokes callbacks while holding
the session lock. A `refine_complete` callback that closes its session reenters
that lock and deadlocks. A bounded mock probe records callback entered, callback
never finished, turn blocked. Concurrent cancellation also waits on refiner I/O,
whose request has no abort signal. Move I/O and callbacks outside the lock and
connect them to existing operation ownership.
Regression: close from the callback and cancel during held refiner I/O.
Proof: `evidence/codebase-audit-2026-10-07/attractor-refiner-lock-probe.lg`.

### R06 — P1: Evaluation timeout returns while evaluated work remains alive

Location: `src/attractor/evaluator.lg:57–68`.
Timed `deref` does not cancel or join the future. A computation times out at
100 ms and later mutates its environment at 250 ms; infinite loops remain live.
Compilation also evaluates arbitrary top-level code without this deadline.
The existing infinite-loop test only checks the returned timeout value.
Reuse owned runtime scopes and enforce cleanup, while retaining the session
filesystem/shell capabilities requested by the user.
Regression: timeout followed by an observation period with no mutation/live worker.
Proof: `evidence/codebase-audit-2026-10-07/attractor-harness-probe.lg`.

### R07 — P1: Session harness changes are never persisted automatically

Locations: `src/attractor/agent.lg:369–375,1454–1512`, `harness.lg:79–94`.
The agent loads or creates an atom, but no production caller invokes
`save-harness!`. Normal session/process termination loses remembered information
and dynamic tools despite the durable-state API/documentation claims.
Tests save explicitly and therefore prove a different lifecycle.
Regression: define/remember through a real session, close, reopen from its declared
storage location, and use the restored state without a test-side save.

### R08 — P1: The co-learning example does not perform co-learning

Locations: `examples/continual-harness/co-learning.dot:53–56`,
`src/attractor/handlers.lg:44`, `engine.lg:67–76`.
The milestone edges have labels but no conditions. The conditional handler
does not make an LLM decision; unconditional lexical routing chooses `exit`
before `teacher_relabel`. The advertised teacher/SFT branch is skipped.
Even manually forcing it only invokes generic prompts: no dataset/training adapter,
optimizer or model-weight update is implemented. README weight-update claims
exceed the implementation. Label it conceptual or implement and verify the complete
loop. Regression: an end-to-end example run with asserted teacher/training effects.
Proof: deterministic edge-selection probe in `evidence/codebase-audit-2026-10-07/attractor-harness-probe.lg`.

## Should fix: contracts, integration and evidence

| ID | Location | Confirmed failure and required regression |
|---|---|---|
| R09, P2 | `handlers.lg:81–85,153–157` | Untimed tools omit all exported workflow parameters. The RFC §R-export-env promises them to every tool. Identical public runs print `MISSING` without timeout and `solve.lg` with timeout. Parameterize the existing export test over omitted/explicit/inherited timeout. |
| R10, P2 | `conditions.lg` clause parsing | Leading/trailing/doubled `&&`, including bare `&&`, are accepted as valid; blank clauses become true. Attractor §10.2 requires clauses. Reject malformed conditions during preparation and prove they cannot select an edge. |
| R11, P2 | `llm.lg:559–568` | Overescaped extension regexes classify a local `.jpg` as `image/png` across all three native adapters when MIME is omitted. Fix extension inference; assert actual outgoing MIME for JPEG/GIF/WebP and explicit overrides. |
| R12, P2 | `llm.lg:2973–2974,1287–1330` | `OPENAI_ORG_ID` and `OPENAI_PROJECT_ID` are loaded into adapter config but never become headers. A public client probe confirms they disappear on the wire. Implement or explicitly reject unsupported options; test configured header propagation. |
| R13, P2 | `harness.lg:55–74`; `evaluator.lg:155–166` | JSON reload leaves entry keys as strings, while consumers read keywords. One saved tool reports restoration count 1 but restores no registry entry. Normalize nested data and count successful restoration; exercise EDN and JSON roundtrips. |
| R14, P2 | `refiner.lg:70`; `agent.lg:1119–1123` | Actual tool turns use `:results`/`:content`; refiner reads `:tool_results`/`:output`, dropping failure evidence. Test formatting of actual recorded agent history, not invented fixture shapes. |
| R15, P2 | `refiner.lg:139`; `agent.lg:1511`; `evaluator.lg:134–166` | Refiner tool CRUD updates only the ledger. New tools are uncallable, changed tools stay stale and deleted tools stay callable until another lifecycle path intervenes. Reconcile live registry and ledger transactionally, including rollback. |
| R16, P2 | `evaluator.lg:107–114` | Any exception retries the function with a different arity. A variadic mutating function runs twice for one call. Enforce the documented signature without replaying runtime failures; assert one side effect on exception. |
| R17, P2 | `agent.lg:1564–1582,1161–1168`; example DOT:17–18 | `harness.interval="8"` is never parsed, leaving automatic refinement interval zero. Static backend calculations also overwrite merged per-node session options. Test the actual backend with the documented DOT/config interface. |
| R18, P2 | `harness.lg:37–42` | Timestamp code reads `:exit-code`/`:stdout`, but `os/sh` returns `:exit`/`:out`. Every timestamp falls back to the Unix epoch. Test chronological ledger metadata with the real runtime result shape. |
| R19, P2 | `skill_eval.lg:505–507` versus `406–428` | Aggregate evaluation legitimately returns `:hold` for absent irrelevant-task coverage with no regressions; its own validator rejects that report. Roundtrip every generated promotion verdict through validation. |
| R20, P2 | `mcp_client.lg:369–375`; `agent.lg:511–514` | Legacy HTTP DELETE teardown ignores request timeout and abort. A 20 ms configured budget waits for a 200 ms fake transport; an unanswered request can prevent session cleanup indefinitely. Give teardown an owned bounded cleanup budget. |
| R21, P2 | `mcp.lg:1021–1031,932–934` | Later multi-server admission failure leaves earlier tools installed without server evidence or cleanup handles. A two-server collision probe leaves `a__query` registered, `mcp_servers=nil`, zero close functions. Roll back or stage admission, and own resources immediately. |
| R22, P2 | `agents/codex.lg:37–46,66–79` | Startup requests ignore cancellation and transport failure while waiting on their reply promise. A pre-cancelled request still opens transport, sends initialize, waits its entire budget and returns timeout. Check cancellation before launch and during all handshakes; use a whole-operation deadline. |
| R23, P2 | `test/attractor/llm_test.lg:1982–1989` | A test assumes built-in Gemini credential aliases while using the ambient provider registry. The focused run fails two assertions with the local override and passes after process-local built-in isolation. Fixture/restore registry state; do not edit the operator's configuration to make tests pass. |
| R25, P2 | `llm.lg:929–936`; `test/attractor/llm_test.lg:1183` | Native OpenAI Responses named tool choice uses nested `function.name`; its API requires top-level `name`. This matches a pinned-spec example but conflicts with that spec's native-protocol mandate. Record the interpretation and test native versus Chat Completions shapes separately. No live rejection is claimed. |
| R26, P2 | `providers.lg:205–214` | File privacy enforcement checks `:api_key` but overlooks equally sensitive `:credential_headers`. A synthetic 0644 config is accepted for the latter and refused for the former. Apply the same permission check to every credential-bearing field; this is not evidence of an actual secret leak. |

Source paths in this table are relative to `src/attractor/` unless otherwise stated.
R25 was verified against the required fields in
[OpenAI's generated Responses tool-choice type](https://raw.githubusercontent.com/openai/openai-python/main/src/openai/types/responses/tool_choice_function_param.py).

## Alignment with the requested Continual Harness paper

The core method updates an agent's harness within an uninterrupted episode. After warm-up W, refinement runs every F steps, using recent trajectory evidence and retained failure knowledge. Four component passes replace the adaptable system prompt and edit subagents, skills and memory through the same meta-tool interface available to the agent. Skills include executable routines. A separate extension trains model weights: bounded rollouts feed transition scoring, teacher relabeling and soft SFT while environment state continues across iterations. Appendix D adds training warm-up and concrete training settings. Missing weight training therefore does not alone disprove a core harness implementation; the two claims must be assessed separately. [Source: §§2–3 and Appendix D](https://arxiv.org/html/2605.09998v1).

The following code comparison uses repository evidence. Missing weight training
alone does **not** disprove a core harness implementation; R08 concerns the separate
training example's explicit claims.

| Dimension |Repository implementation and evidence | Assessment |
|---|---|---|
| Scheduling: F/W | agent.lg:1161–1168 increments only when a complete user-input cycle finishes. No warm-up setting/state. DOT harness.interval is never parsed at agent.lg:1564–1582; interval defaults to zero at :427. Repetition-triggered refinement and explicit calls exist. | Partial trigger support; periodic algorithm absent in example. |
| Prompt editing | refiner.lg:19 and harness.lg:213 explicitly declare immutable base; agent.lg:232–265 appends a bounded overview. Prompt entries are independently truncated to 240 characters and capped at ten. No replaceable adaptive prompt field. | Deliberate divergence, currently described as implementation rather than adaptation. Keeping host policy immutable is sensible; a separate replaceable task prompt would allow alignment. |
| Component passes | refiner.lg:91–122 makes one completion request returning one mixed JSON proposal; no pass sequence or component-specific iteration. apply-proposal! applies edits without validating full proposal shape. | Single proposal mechanism, not staged refinement. |
| Shared edit interface | Agent exposes remember/recall/define_subagent/refine_harness/eval_letgo/define_tool (agent.lg:1454–1511). Refiner gets no :tools and directly emits JSON (refiner.lg:112–114). Agent lacks direct general update/delete/read tools for all stores; refine_harness delegates to a different pathway. | Shared ledger underneath, incompatible operational interfaces above it. |
| Subagent execution | define_subagent stores role text; spawn_agent(role) looks it up and passes it as :user_instructions to a real child session (agent.lg:1341–1376). Children share harness atom and fork execution environment. | Real executable delegation exists; unknown roles silently fall back to generic children, and no role usage/productivity metrics feed refinement. |
| Skill execution | :skill entries appear only as truncated text in harness.lg:233–239. Separate :tool entries compile with evaluator/make-dynamic-tool and register through define_tool; ordinary profile dispatch can invoke them. | Text skills and agent-created executable tools exist, but separate stores/API require explicit mapping. Refiner-created/updated/deleted tools do not reconcile the runtime registry. |
| Trajectory evidence | Session history survives refinement. Formatter defaults to eight message records, crops text at 300 characters and looks for :tool_results/:output instead of actual :results/:content (refiner.lg:58–89; agent.lg:1119–1123). Offline probe lost the entire tool failure body. | Conversation retention works; refiner's view loses decisive execution evidence. |
| Retained failure knowledge | :refinements ledger accumulates proposals, but format-harness-overview never exposes it and refiner receives no retrieval tool. Old history falls outside its window. A memory edit may preserve a lesson, but only ten truncated entries reach this refiner prompt and it cannot call recall. | No reliable cumulative failure-memory access. |
| In-process continuity | Same session/harness atom persists across agent rounds; full-fidelity thread cache reuses a session at agent.lg:1587–1614. Refinement does not deliberately clear history/environment. | Useful functioning core primitive. Periodic callback deadlock and abandoned eval futures still break operational reliability (prior report H1/H2). |
| Save/load and bootstrap | EDN manual save/load plus bootstrap-tool restoration pass tests. No agent lifecycle calls save-harness!; JSON nested keys prevent usable restoration. | Partial library primitive, not durable runtime integration. |
| Disabled refinement | loop detection invokes refiner whenever a harness exists, ignoring :auto_refine false (agent.lg:1134–1137). | No reliable frozen-bootstrap mode through that switch; necessary behavior should be made explicit. |
| Effective use/evidence | Four integration tests verify injected text, registry operations, loop edit and manual EDN transfer, not whether a repaired routine gets invoked next and resolves a measured failure. | Function-level evidence; no demonstrated task-performance improvement or complete faithful core loop. |

The same in-process harness and real role-based subagents are useful primitives.
However, the current source does not establish a faithful, reliable core refinement
loop or measured improvement. A first acceptance journey should preserve one
persistent environment, encounter a real failing routine, feed its actual result
to refinement, apply and invoke the repaired routine on the next step, and prove
that both successful behavior and reloadable state survive. A frozen configuration
must perform zero refinement calls. Exact game choice and experimental model names
are not prerequisites for this engineering acceptance test.

## Why the implementation and documents have not converged

**Multiple implementations own the same behavior.** Legacy `server.lg` owns an
independent execution registry, SSE, cancellation and question answers. The current
CLI explicitly avoids it. Legacy answer POST accepts missing/unknown questions;
the hub adapter rejects them. Its tests cannot certify the deployed CLI route.
Both core agent and high-level LLM loops implement tool execution/retry ownership;
R03/R04 show behavior differs by constructor or adapter. The new evaluator ignores
the existing `context-discovery/call!` owned-scope-and-join primitive.

**Passing tests often exercise a substitute path.** Retry tests inject a client;
parameter export tests always add a timeout; persistence tests explicitly save;
timeout tests assert an error response rather than stopped work; harness tests
do not traverse the co-learning DOT; refiner fixtures use the wrong history shape.
These are concrete evidence gaps, not a criticism of unit tests in general.

**Documentation is accumulated history, not a single current contract.** The tree
contains 78 source `.lg` files (24,531 lines, including the new untracked modules)
and 246 documentation Markdown files, plus the root README. Of those 247 Markdown
documents, 77 are archives, 67 methodology references and 43 design/spec/plan files;
the remaining 60 include guides, status and audit documents. Three copies of the
upstream specs exist across `specs/`, `docs/specs/`, and the archive.

The document index correctly says historical checkbox counts are not proof.
However, current-looking ledgers still combine old pending statements with later
completion paragraphs, and the roadmap repeats contradictory status fragments.
Historical human-interaction notes point to the legacy server and deleted runtime
patches. A mechanical local-link scan reports 38 unresolved references, some of
which are imported website paths or templates rather than actionable broken links.
Confirmed stale project links include deleted `runtime-patches/README.md` from
`http-question-audit.md` and `let-go-runtime-issues.md`, and the old upstream spec
path from `stream-schema-audits.md`.

**Extension authorities conflict without a supersession record.** The proposed
evaluation extension requires quarantined pure generated modules and promotion
gates; the later October 6 request authorizes interactive, session-capable tools.
Those can be distinct APIs, but current prose does not clearly say so. Existing
digest-pinned skills/MCP admission and the harness's ad hoc skill/tool ledger also
have no shared promotion/evidence contract. Do not label the newly authorized
capabilities themselves a vulnerability by applying the older proposal blindly.

## Claim ledger

| Claim | Verdict | Evidence |
|---|---|---|
| Web human interaction is reachable | Real | Current-source HTTP/nREPL/hub question/answer and timeout journey passes. |
| A browser UI is supplied | Unproven/absent in this tree | No frontend or root page route; API transport is operational. |
| One control plane owns all supported execution | Partial | CLI uses hub, but separately executable legacy server remains. |
| Core implements the three specifications completely | Partial | Substantial runtime/client/agent implementation, but R01–R04 and other core defects remain. |
| Harness can register and invoke dynamic tools | Real, narrow | Mock integration tests execute registered tools and inject prompt state. |
| Harness is durable, bounded and self-improving | Mirage as currently stated | R05–R08 and R13–R18 contradict the claimed guarantees. |
| Proposed model-weight co-learning is implemented | Mirage | Routing exits and no actual training implementation exists. |
| Context foundations are shipped on main | False | Implementation lives on an unmerged branch; main contains design/plan only. |
| All native-provider conformance is proved | Unproven | Coding parity and Unified LLM matrices differ; live subsets and explicit gaps remain. No new live calls made. |
| Archived findings are all current defects | False | Several schema, streaming, provider and runtime issues have documented repairs and regression coverage. |

## Recent committed work

The context-foundations branch is materially better integrated than the uncommitted
harness. Node settings reach the agent; tool allowlists affect declarations and
dispatch; budget admission precedes model requests; usage baselines are invalidated;
transcripts apply privacy/redaction; versioning has meaningful containment tests.
Its focused verification passed 73 tests / 293 assertions. That initial aggregate
review found no new blocker; the subsequent context investigation identified the
counting limitations recorded in the follow-up above.

All 40 commit subjects and 33 changed files were inventoried. The complete new
context-budget, token-count, transcript, node-settings and versioning modules and
aggregate changes to agent/LLM/CLI/handlers/review bindings were read. This does not
mean every intermediate commit diff or every new test/doc line was independently
reviewed. Live tokenizer exactness and future automatic snapshot/dispatch integration
remain unproved; foundation primitives do not establish the future dispatch loop.

## Evidence, coverage and residual risk

Source reading covered all 78 production `.lg` files across the review team,
including the main LLM validator, separate schema modules, authentication,
credentials, console, external agents, workflow capture/recovery and extensions.
The file-by-file inventory is `evidence/codebase-audit-2026-10-07/source-inventory.tsv`.
Reading coverage is not a formal proof of every normative sentence. Tests and
documentation were selected by subsystem/claim, not all read line-by-line;
methodology references and every intermediate historical diff were not individually
certified. Native model behavior, training performance and live vendor interoperability
remain unproved beyond the cited existing evidence.

Fresh focused results:

- HTTP/interviewer suites: 25 tests / 212 assertions pass. Both compiled and
  current-source question/answer journeys pass all seven checks.
- Harness suites: 13 tests / 87 assertions pass despite the reproduced integration
  defects.
- LLM/stream/loop subset: 100 tests / 624 assertions, two failures with ambient
  configuration; the same subset passes after process-local registry isolation.
- Unmerged context-foundations subset: 73 tests / 293 assertions pass.
- Root independently reran probes for failed goal gates, retry bypass, malformed
  Anthropic arguments, post-timeout mutation, JSON tool restoration, duplicate
  execution, missing refiner evidence, skill verdict roundtrip, MCP teardown/admission,
  provider credential permissions and Codex startup cancellation.

The ordinary `lgx suite` was interrupted after over twelve minutes without a
result (exit 143). The identical generated harness was launched directly to expose
progress. That baseline run was also stopped after fourteen minutes, having
observed seven failed assertions in CLI event output, Codex initialization and
the ambient-provider fixture. It had reached the official schema reference
namespace but produced no final total. No baseline full-suite pass is claimed.
Logs and reproduction scripts are collected
under `evidence/codebase-audit-2026-10-07/`, ignored according to the existing
verification-output policy. Some scripts intentionally create temporary fixture
directories; production source is always the repository checkout.

All seven Lynx categories have findings: correctness/invariants, boundaries,
failure paths, API contracts, state/concurrency, tests, and documentation claims.
All five Rook claim surfaces contain claims: prose, tests, API/types, module
boundaries and runtime control flow. No category is silently treated as proved
by the existence of files or green aggregate counts.

Execution-boundary review covered arbitrary let-go evaluation, shell processes,
FFI-backed runtime scopes, filesystem snapshots and MCP subprocess/HTTP lifecycle.
This is not a language-runtime/OS sandbox security audit. The evaluator and MCP
cleanup findings leave important ownership invariants unproved or disproved.

## Convergence sequence

1. Fix the high-impact core behaviors first: implicit defaults, cancellation,
   retry construction and malformed streamed arguments. Add regressions at the
   public constructors and entry points that currently escape existing tests.
2. Make one small harness vertical slice honest: define tool → execute → refine
   using actual results → reconcile registry → save → reopen → execute restored
   tool, including timeout/cancellation and callback reentrancy failures.
3. Mark co-learning conceptual until a real end-to-end training adapter and
   observable model update exist. Do not infer learning from an LLM's narrative.
4. Decide support for legacy server APIs: compatibility facade over hub, explicit
   separate support with shared contract tests, or retirement. Avoid maintaining
   two implementations accidentally.
5. Give every active guarantee one current contract, one runtime owner and a
   public regression/evidence pointer. Add supersession notices to historical
   records; keep methodology references outside current implementation status.
6. Reconcile main versus context-foundations deliberately, then perform integrated
   verification on the resulting tree. Branch-only evidence cannot certify main
   or the uncommitted harness combination.

The remedy is integration and contract closure. More decomposition, more parallel
status documents, or higher test counts alone will not address these failures.
