# Evaluation Harness Extension Specification

**Status:** Proposed NLSpec

**Purpose:** Extend Attractor from a workflow executor into an observable,
independently evaluable harness. A run must produce enough bounded, structured
evidence to compare task outcomes, harness configurations, and later harness
revisions without confusing implementation-time checks with independent quality
evaluation.

This specification is primarily informed by two arXiv papers:

- [The Last Harness You'll Ever Build](https://arxiv.org/abs/2604.21003),
  which separates Worker, Evaluator, and Evolution roles and adds a
  meta-evolution loop.
- [Harness-of-Harness: Multi-Day Autonomous Software Development with Continual
  Improvement](https://arxiv.org/abs/2609.01481), which separates testing during
  implementation from independent evaluation and improves harnesses through
  repeated, verifiable iterations.

Public ASDLC material on workflow-as-code, context gates, compound learning,
skills, MCP, adversarial review, and evaluation anchors is background reference
only. It is not normative, not a default evaluation input, and not part of
generated-code inputs. This specification does not modify or extend the external
ASDLC dataset.

This is an extension to Attractor. It does not replace the core Attractor,
coding-agent-loop, or unified-LLM specifications. It does not make an LLM
verdict authoritative merely because it is structured or successful.

---

## 1. Goals and non-goals

### 1.1 Goals

The extension MUST:

1. Record a stable, bounded, provenance-rich evaluation subject for every
   evaluated run.
2. Separate implementation-time verification from independent evaluation.
3. Support deterministic scoring before model-based judging.
4. Support adversarial evaluator agents with structured, reviewable reports.
5. Compare repeated runs and multiple harness configurations on the same task.
6. Preserve artifacts, scores, evidence, and evaluator identity across resume and
   later inspection.
7. Provide a roadmap for project skills and MCP tools without treating either as
   automatically trusted.
8. Support automatically drafted let-go code only through an explicit,
   capability-restricted execution path.
9. Keep hard gates, schemas, anchors, resource limits, and provenance outside
   the authority of generated prompts, skills, MCP servers, and evaluator agents.

### 1.2 Non-goals

This extension does not initially:

- claim that an LLM score is ground truth;
- permit an evaluator to approve its own implementation evidence;
- allow generated code to use ambient host filesystem, environment, network,
  host clock, host randomness, process table, credentials, or arbitrary namespaces;
- implement unrestricted self-modification of the Attractor engine;
- automatically promote a new evaluator, skill, MCP server, or generated code
  draft into trusted production behavior;
- define a universal quality score across unrelated task domains;
- require online learning or model fine-tuning;
- make MCP or skills mandatory for the first evaluation milestone.

---

## 2. Terminology

- **Task:** A versioned objective with requirements, acceptance checks, inputs,
  and declared output contract.
- **Run:** One execution of a prepared workflow for one task and one harness
  configuration.
- **Harness configuration:** The complete versioned configuration that affects a
  run: graph, model/provider settings, prompts, tools, skills, MCP manifests,
  generated code capabilities, evaluator profile, and relevant runtime version.
- **Implementation verification:** Checks used by the worker while producing the
  result, such as tests, builds, linters, or local assertions.
- **Independent evaluation:** A later evaluation performed from a frozen or
  separately captured evidence packet. It MUST NOT rely only on the worker's
  self-reported success.
- **Evaluator:** A deterministic scorer, model-based critic, or composite gate
  that evaluates a run against a task contract.
- **Anchor set:** Human-governed, versioned evaluation cases used to compare
  evaluator versions or harness revisions. The active anchor set is immutable
  during an evaluation epoch.
- **Epoch:** A period during which evaluator identity, scoring rubric, anchor
  version, and hard gates remain fixed.
- **Skill:** A versioned, task-scoped instruction and procedure package. Skills
  provide context and workflow guidance; they do not grant capabilities.
- **MCP server:** A declared external tool/resource provider. MCP connectivity is
  a capability subject to policy, not an implicit trust boundary.
- **Generated let-go module:** Let-go source drafted by a model and compiled or
  loaded only through the restricted generated-code runner.
- **Provided data:** Data explicitly present in the generated module's input
  envelope or explicitly returned by an approved capability. Ambient data is not
  provided data.

---

## 3. Authority and trust model

The system MUST distinguish these authority classes:

| Class | Examples | Can be changed by a worker/evaluator? |
|---|---|---|
| Hard harness | schema validators, resource limits, capability policy, anchor set, provenance rules | No |
| Task contract | requirements, acceptance checks, output schema | No during evaluation |
| Harness configuration | prompts, graph, model, tools, skill selection, MCP selection | Proposal only |
| Evaluator configuration | rubric, judge prompt, deterministic metrics | Proposal only; promotion is gated |
| Run evidence | events, status, artifacts, logs, outputs | Append-only or atomically published |
| Candidate change | generated code, skill revision, MCP manifest, evaluator proposal | Quarantined until gates pass |

A successful model call, process exit, or structured response MUST NOT by itself
promote a candidate into a trusted class.

All evaluator and evolution decisions MUST record:

- task ID and task revision;
- run ID and harness configuration digest;
- evaluator ID, evaluator revision, and rubric digest;
- anchor-set ID and epoch;
- input and evidence digests;
- deterministic gate results;
- model/provider identity when a model was involved;
- whether a human approved promotion.

Secrets, credentials, raw authorization headers, and unrestricted environment
values MUST NOT enter evaluation packets, score records, generated-code inputs,
skill packages, MCP manifests, or model prompts unless a separate declared
capability explicitly permits a redacted representation.

Public ASDLC material MAY be cited as explanatory background. It MUST NOT be
treated as task truth, evaluator truth, authorization, or capability evidence.

---

## 4. Evaluation subject and evidence contract

### 4.1 Evaluation subject

Attractor MUST expose a normalized `EvaluationSubject` after a run reaches a
terminal state or an explicit evaluation checkpoint. The subject MUST contain:

```edn
{:schema_version 1
 :task {:id "..." :revision "..." :requirements [...] :acceptance [...]}
 :run {:id "..." :status :success|:fail|:cancelled
       :started_at ... :finished_at ...}
 :harness {:id "..." :digest "..." :graph_digest "..."
           :model_profile "..." :tool_profile "..."
           :evaluator_profile "..." :rubric_digest "..."
           :anchor_set "..." :epoch "..."
           :skills [...] :mcp [...] :generated_modules [...]}
 :verification {:checks [...] :implementation_status :pass|:fail|:unknown}
 :artifacts [{:id "..." :digest "..." :media_type "..." :metadata {...}}]
 :events {:count ... :digest "..." :bounded_summary [...]}
 :resources {:llm_requests ... :input_tokens ... :output_tokens ...
             :tool_calls ... :elapsed_ms ...}
 :provenance {:runtime_revision "..." :source_digests [...]}}
```

The subject records the harness-configured default evaluator. The score record
records the actual evaluator that produced the score. If they differ, both
identities MUST be retained.

The exact internal representation may differ, but public serialized records MUST
be data-only and schema-versioned. The subject MUST be reproducible from the
published run state or explicitly mark fields as unavailable.

### 4.2 Evidence capture

Evidence capture MUST:

- preserve raw event/artifact data in the run store subject to existing
  retention and size controls;
- expose bounded evaluator packets separately from complete stored evidence;
- identify every truncation, redaction, omitted field, and failed collection;
- use stable content digests for packets and artifacts;
- reject a packet when required evidence is missing rather than silently scoring
  an incomplete packet as a pass;
- prevent worker-produced text from being interpreted as evaluator instructions;
- preserve the distinction between observed facts and claims made by a worker or
  evaluator.

Packets are immutable and identified by digest. Collecting a packet twice from
unchanged run state MUST yield the same digest. If run state changes after a
packet digest was issued, the old digest MUST NOT be scored; evaluation MUST
either mint a new packet or fail closed with a provenance mismatch.

### 4.3 Independent-evaluation boundary

Implementation checks MAY influence routing during a worker run, but they MUST
be labeled `implementation_verification`. Independent evaluators MUST receive a
separately assembled subject or packet and MUST record whether each score came
from deterministic observation, artifact inspection, model judgment, human
judgment, or an unavailable/unsupported source.

The system MUST NOT merge these sources into one unexplained scalar.

---

## 5. Scoring contract

### 5.1 Deterministic scoring first

The evaluator pipeline MUST execute deterministic checks before model-based
judging. Examples include:

- required artifact existence and schema validity;
- declared acceptance checks and test exit status;
- graph/run terminal status and goal-gate status;
- output size, format, and digest checks;
- resource budgets and timeout compliance;
- forbidden capability use;
- provenance and evidence completeness;
- regression comparison against a baseline run.

A deterministic hard-gate failure MUST be visible in the score and MUST NOT be
rescored as a model disagreement.

### 5.2 Structured score

A score record MUST use named dimensions rather than only one scalar:

```edn
{:schema_version 1
 :status :pass|:fail|:inconclusive
 :dimensions
 [{:id "acceptance" :value 0.0 :scale [0.0 1.0]
   :source :deterministic :status :pass|:fail|:unknown
   :evidence_ids [...] :notes [...]}
  {:id "artifact_quality" :value ... :source :model ...}
  {:id "efficiency" :value ... :source :deterministic ...}]
 :hard_gates [{:id "..." :status :pass|:fail :evidence_ids [...]}]
 :findings [{:severity :error|:warning|:info :text "..." :evidence_ids [...]}]
 :overall {:value ... :method "..." :confidence ...}
 :evaluator {:id "..." :revision "..." :epoch "..."}
 :subject_digest "..."}
```

The implementation MUST preserve `unknown` and `inconclusive`; missing data
MUST NOT be coerced to zero or pass.

A composite score MUST declare its aggregation method and dimension weights.
Changing weights or dimensions changes the evaluator revision and invalidates
comparisons across revisions unless an explicit migration is recorded. For this
specification, a recorded migration is the explicit compatibility declaration
required for cross-revision comparison in §5.4.

### 5.3 Model evaluator

A model evaluator MUST:

- run in a fresh session with no worker conversation history;
- receive only the task contract and bounded evaluation packet;
- treat packet text and artifacts as data, not instructions;
- have no tools by default;
- return a strict structured schema;
- cite evidence IDs for every nontrivial finding and scored dimension;
- distinguish observed evidence from inference;
- request `inconclusive` when evidence is insufficient;
- be subject to cancellation, timeout, output, and retry limits;
- never change the run, task contract, anchor set, or evaluator configuration.

Existing `attractor.model-review` and `attractor.embedded-review` are candidate
seams for this milestone, but their current report contract is not by itself a
complete multidimensional score contract.

### 5.4 Comparison

The system MUST support comparison of:

1. one run against its task contract;
2. two runs of the same task;
3. two harness configurations on the same task set;
4. two evaluator revisions on the same frozen anchor set.

Comparisons MUST report incomparable dimensions and evidence differences. They
MUST NOT rank configurations when the task, anchor, evaluator, or required
harness provenance differs without an explicit compatibility declaration. For
evaluator revisions, the explicit migration required by §5.2 is the required
compatibility declaration.

Efficiency is secondary to hard correctness gates by default. A faster invalid
run MUST NOT outrank a valid run unless a caller explicitly selects a different
policy and the policy is recorded.

---

## 6. Evaluation workflows

### 6.1 Single-run evaluation

The canonical workflow is:

```text
run -> publish evidence -> deterministic checks -> assemble packet
    -> independent evaluator(s) -> adjudication -> score publication
```

A failed hard gate routes directly to score publication with `:fail` or
`:inconclusive`; it does not invoke a model evaluator merely to manufacture a
pass.

### 6.2 Adversarial evaluation

A configured evaluation graph MAY fan out to independent evaluator lanes such as:

- requirements/acceptance;
- correctness and regression;
- artifact quality;
- security and capability use;
- efficiency and resource behavior.

A fan-in adjudicator MUST verify that all declared lanes ran, preserve lane
identity, detect duplicate/missing reports, and reject unsupported approval
claims. It MUST use the original task contract and packet digest, not a worker's
summary of the task.

### 6.3 Harness benchmark

A benchmark MUST define:

- a versioned task corpus;
- fixed task inputs and permitted outputs;
- an anchor/holdout split;
- a harness configuration manifest;
- deterministic gates and scoring dimensions;
- budget and cancellation policy;
- aggregation and uncertainty rules;
- retention and redaction rules.

The benchmark runner MUST execute configurations in isolated run roots. It MUST
NOT share writable state, hidden artifacts, worker/evaluator conversation
history, or unpromoted generated code between candidates unless the benchmark
explicitly tests that behavior. Versioned task corpora and pinned manifests MAY
be shared read-only; all writable run state MUST remain isolated.

### 6.4 Harness evolution roadmap

The system SHOULD later support the following staged loop:

```text
seed harness -> run task corpus -> independently evaluate
    -> diagnose failure patterns -> draft candidate change
    -> validate deterministic gates + frozen anchors
    -> compare against incumbent -> human or policy promotion
```

A candidate evaluator, skill, MCP manifest, prompt, or generated module MUST be
quarantined until it passes the same promotion protocol. The active evaluator
and anchor set MUST remain frozen inside an epoch. Scores from a retired
evaluator MUST NOT be silently mixed with scores from its successor.

Meta-evolution — learning which Worker/Evaluator/Evolution blueprint converges
best — is a later milestone. It MUST consume published benchmark records rather
than mutate the scoring contract during the benchmark it scores.

---

## 7. Skills roadmap

Skills are a roadmap capability, not an implicit trust mechanism.

### 7.1 Skill manifest

A skill package SHOULD have a data-only manifest containing:

- stable skill ID and revision;
- name, description, and explicit invocation/selection metadata;
- supported task types and required inputs;
- referenced prompt/procedure files and their digests;
- declared tool and MCP requirements;
- expected outputs and artifacts;
- resource limits;
- provenance and license metadata.

Skill source MUST be treated as data until selected by a trusted workflow policy.
A skill MUST NOT grant access to a tool, namespace, filesystem path, secret, or
network endpoint merely by mentioning it.

### 7.2 Skill loading

The first skill milestone SHOULD support:

- explicit skill selection by workflow configuration;
- project and user skill roots with deterministic precedence;
- digest-pinned loading;
- bounded skill text and description budgets;
- conflict detection for duplicate IDs;
- evidence recording of every loaded skill;
- a static roster/index for always-relevant context and active loading only for
  task-specific procedures.

Automatic skill selection MAY be added later, but selection decisions MUST be
observable and reproducible. Static, always-relevant project guidance SHOULD stay
in an AGENTS-style context file rather than requiring an agent to discover it.

### 7.3 Skill evaluation

A skill revision MUST be evaluated against a held-out task subset before
promotion. Skill evaluation MUST measure both benefit and cost:

- task success and hard-gate pass rate;
- false activation or missed activation rate;
- token/context overhead;
- tool-call and latency overhead;
- regressions on tasks where the skill is irrelevant.

A skill MUST NOT be considered improved solely because it increases evaluator
scores on the tasks that selected or authored it.

---

## 8. MCP roadmap

MCP support is a later capability layer. It MUST NOT be treated as equivalent to
local trusted tools.

### 8.1 MCP manifest and admission

An MCP server declaration MUST be data-only and include:

- stable server ID and manifest revision;
- transport and endpoint class;
- tool/resource names and schemas;
- declared data classes and side effects;
- allowed task types and workflows;
- timeout, output, and concurrency limits;
- credential reference by name, never credential value;
- provenance, approval status, and digest.

The workflow MUST explicitly select permitted MCP servers. Discovery MUST NOT
silently add tools to an active session. Tool names MUST be namespaced and
collision checked.

### 8.2 MCP trust boundaries

Implemented admission policy: [MCP tool admission](mcp.md). The initial
read-only slice now also admits write tools through explicit host grants tied
to exact tool names and manifest digests. Human approval, where required by the
host, precedes supplying that grant.

Each MCP invocation MUST have:

- an explicit request ID and run/session identity;
- a bounded request and response;
- cancellation and timeout propagation;
- an audit event recording server, tool, arguments digest, result digest, and
  redaction status;
- a declared side-effect policy;
- a failure mode that does not convert an unavailable server into successful
  empty data.

MCP results MUST be labeled as externally supplied evidence. They MUST NOT be
implicitly trusted as task truth, evaluator truth, or authorization.

The first MCP implementation SHOULD support read-only resources and pure or
idempotent tools before write-capable or credential-bearing tools. Write tools
MUST require a separate policy and, where configured, human approval.

### 8.3 MCP evaluation

Benchmarks MUST distinguish local evidence from MCP evidence and report network
availability, server revision, and data freshness. A run that depends on an
unavailable MCP server is `:inconclusive` unless the task explicitly defines
that unavailability as a tested failure case. Live MCP responses MUST NOT
satisfy deterministic hard gates unless the task contract and MCP admission
policy explicitly permit that named MCP input. Until Slice E policy is settled,
MCP evidence MUST be treated as externally supplied, non-deterministic evidence.

---

## 9. Generated let-go code

Generated let-go code is a high-risk capability. It MUST be implemented as a
quarantined, capability-oriented runner rather than by evaluating arbitrary
model text in the host process.

### 9.1 Drafting contract

A drafting workflow MAY ask a model to produce let-go source for a declared,
small operation. The draft request MUST include:

- module ID and revision;
- operation name and input/output schemas;
- complete provided-data envelope schema;
- allowed imports and capabilities;
- maximum source size;
- maximum execution time, memory, output bytes, and collection sizes;
- required deterministic tests;
- forbidden behavior list;
- expected artifact and provenance outputs.

The model MUST receive the request as a bounded packet. It MUST NOT receive
ambient credentials, unrestricted repository contents, hidden evaluator prompts,
or arbitrary host state merely because it is drafting code.

The draft MUST be stored as an untrusted artifact with source digest, prompt
packet digest, model/provider identity, and draft timestamp. Drafting success is
not compilation success or promotion success.

### 9.2 Capability manifest

Every generated module MUST be accompanied by a capability manifest. The
manifest MUST be explicit, deny-by-default, and immutable for the execution:

```edn
{:module_id "..."
 :revision "..."
 :entry "run"
 :input_schema {...}
 :output_schema {...}
 :imports []
 :capabilities []
 :limits {:source_bytes ... :runtime_ms ... :output_bytes ...
          :max_items ... :max_recursion ...}
 :provided_data_schema {...}
 :provenance {:source_digest "..." :task_digest "..." :draft_digest "..."}}
```

An empty capability list MUST be valid and SHOULD be the default. A capability
MUST be granted by the trusted runner, not requested dynamically by generated
code. Generated code MUST NOT widen its own manifest.

### 9.3 Pure default profile

The default generated-code profile MUST permit only:

- data transformation over the provided input envelope;
- approved pure standard-library operations;
- bounded serialization to the declared output schema;
- deterministic local computation within declared limits.

The default profile MUST deny:

- filesystem reads or writes;
- environment-variable access;
- process creation, shell execution, subprocesses, or signals;
- network, sockets, HTTP, DNS, MCP, or IPC;
- clocks, sleeps, randomness, UUID generation, or process identity;
- reflection, dynamic namespace loading, eval, reader-eval, macro loading, or
  access to compiler/runtime internals;
- credentials, secret stores, hub sessions, parent context, other run roots, or
  hidden evaluator state;
- mutation of host atoms or shared process state;
- access to data not present in the provided envelope or returned by an explicit
  capability.

The runner MUST reject source that imports or references denied namespaces or
capabilities. Static checks are necessary but not sufficient: execution MUST
also occur in an isolated scope/process with resource limits and a final
capability audit.

### 9.4 Explicit capability profiles

Later profiles MAY grant narrow, explicitly declared capabilities. These are bounded exceptions to the ambient-access ban, not general host access. Examples include:

- `:artifact-read` for named, digest-pinned artifacts;
- `:workspace-read` for an allowlisted path set and read budget;
- `:mcp-read` for a named read-only MCP resource;
- `:clock` for a supplied logical timestamp constant;
- `:random` for a supplied deterministic seed constant.

Every capability MUST declare its input schema, output schema, side effects,
resource limits, and audit events. A capability result MUST be treated as
provided data and MUST carry an identity and digest. Supplied time and seed
constants do not grant access to host clocks, timers, sleeps, RNGs, or process
identity; the default prohibition on host time and randomness remains. Path traversal, symlink
escape, absolute-path escape, undeclared artifact access, and capability
confusion MUST fail closed.

Write, shell, network, credential, and arbitrary MCP capabilities MUST remain
separate profiles. They MUST NOT be silently available to generated code or
ordinary coding-agent tools.

### 9.5 Compilation, execution, and promotion

The generated-code runner MUST:

1. parse source without executing it;
2. validate source size, syntax, imports, entry point, and manifest;
3. compile in a disposable isolated build root;
4. run static forbidden-capability checks;
5. run deterministic unit and property checks supplied by the trusted workflow;
6. execute only with the manifest's capabilities and limits;
7. validate output against the declared schema;
8. record source, compiler/runtime, inputs, outputs, capability, and resource
   digests;
9. publish the result as a quarantined candidate artifact;
10. require the configured evaluation and promotion gates before exposure to a
    worker or production workflow.

The build root and process isolation belong to the trusted runner. They do not
grant the generated module filesystem, process, network, or ambient-state
capabilities.

A compile or execution error MUST be distinct from a task failure and from an
evaluator disagreement. Timeouts, output overflow, capability violations, and
isolation failures MUST be terminal failures for that candidate.

Generated code MUST NOT be exposed as an ordinary tool until it has passed the
configured promotion policy. The initial promotion authority MUST NOT be
selected until the §14 promotion decision is recorded. When configured, the
first promotion policy SHOULD require human approval or a frozen-anchor
benchmark plus deterministic security checks.

### 9.6 Exposure to coding agents

When promoted, generated code MAY be exposed to an agent as a namespaced,
opaque tool with a typed schema. The agent MUST see only the declared input and
output contract, limits, and failure categories. It MUST NOT receive arbitrary
source-evaluation or host-execution powers through the tool description.

Every invocation MUST record module ID/revision, run/session ID, input digest,
output digest, capability profile, resource use, and terminal status. A tool
result MUST identify whether it came from a promoted module, an explicitly
authorized quarantined validation run, or a fallback implementation.
Quarantined modules MUST NOT be callable through normal agent tool paths. They
MAY be invoked only by the promotion-validation harness for the configured
promotion gate.

---

## 10. Roadmap and delivery slices

The work MUST be delivered in evidence-locked slices. Later autonomy MUST NOT
be used to silently broaden earlier slices.

### Slice A — Evaluation records and deterministic scoring

Implement the `EvaluationSubject`, packet digesting, deterministic score schema,
hard-gate results, resource summaries, and persisted score publication. Reuse
existing run artifacts, checkpoints, event history, and review packet seams.

Acceptance requires repeated packet collection, missing-evidence refusal,
redaction/truncation reporting, stable digests, resume preservation, and a
comparison of two runs of the same task.

### Slice B — Independent evaluator and adjudication

Implement a no-tools evaluator profile and structured multidimensional reports.
Support one evaluator, parallel evaluator lanes, and an adjudicator. Preserve
reviewer identity, packet digest, evidence IDs, inconclusive results, and
cancellation. Do not implement evaluator self-promotion in this slice.

Acceptance requires that a worker's self-reported pass cannot substitute for an
independent evaluation, unsupported findings are visible, and evaluator output
cannot mutate the run or task contract.

### Slice C — Benchmark and harness comparison

Implement versioned task corpora, anchor/holdout splits, isolated candidate run
roots, configuration digests, aggregation, uncertainty, and comparison reports.
Support repeated runs and configuration matrices before any evolution loop.

Acceptance requires no cross-candidate state leakage, explicit incomparable
results, deterministic reruns for deterministic profiles, and a report that
separates hard gates from model dimensions.

### Slice D — Skills

Add manifest-based, digest-pinned skill loading with bounded context, explicit
selection, deterministic precedence, and skill evidence. Evaluate benefit,
cost, activation behavior, and irrelevant-task regressions.

Skills remain context/procedure packages. They do not grant capabilities.
New skill revisions remain candidates until promotion gates pass.

### Slice E — MCP read-only integration

Add namespaced MCP manifests, explicit admission, bounded cancellation-aware
calls, audit events, provenance, and read-only resources/pure tools. Add MCP
availability and freshness to evaluation subjects. Defer write and
credential-bearing tools until separate policy work is approved. New MCP servers
and manifest revisions remain candidates until admission and promotion policy
pass.

### Slice F — Generated let-go pure modules

Add the pure default generated-code runner with deny-by-default capabilities,
data-only inputs, static checks, isolated compilation/execution, resource
limits, schema validation, candidate quarantine, and promotion evidence. Begin
with transformations that require no ambient data.

### Slice G — Capability profiles and evolution proposals

Add named capability profiles, evaluator-driven candidate proposals, frozen
anchor epochs, incumbent/challenger comparison, and human or explicit-policy
promotion. Generated modules, skills, MCP manifests, evaluator prompts, and
workflow changes remain proposals until promotion.

### Slice H — Meta-evolution

Only after the preceding slices have stable benchmark and provenance records,
consider learning Worker/Evaluator/Evolution blueprints across task families.
Meta-evolution MUST consume immutable benchmark records and MUST NOT alter the
active scoring contract while it is being evaluated.

---

## 11. Security and failure requirements

The implementation MUST fail closed when:

- a packet is incomplete, changes during collection, or exceeds bounds;
- a score lacks required evidence or uses an unknown evaluator revision;
- a task, harness, evaluator, or anchor digest is missing or mismatched;
- a skill or MCP manifest is malformed, ambiguous, or not admitted;
- generated source imports denied namespaces or exceeds static limits;
- generated execution attempts undeclared data access or capability use;
- a generated output fails its schema or resource limits;
- an MCP server is unavailable for a required input;
- a candidate attempts to modify hard harness policy or evaluation anchors;
- cancellation or cleanup cannot be joined.

The implementation MUST preserve partial evidence and the primary failure cause
when safe to do so. It MUST NOT turn a security or provenance failure into an
ordinary evaluator `:revise` result.

No generated code, skill, MCP server, evaluator, or evolution agent MUST write
credentials, alter hard policy, erase evidence, or publish itself as trusted.

---

## 12. Acceptance scenarios

The implementation MUST add public-contract scenarios with stable IDs. The
following scenarios define the minimum evidence expected from the corresponding
roadmap slices:

- **SCN-EVAL-SUBJECT:** A completed public pipeline publishes one
  `EvaluationSubject` containing task, run, harness, verification, artifacts,
  resources, and provenance identities.
- **SCN-EVAL-PACKET-REPEAT:** Collecting an evaluator packet twice from unchanged
  state produces the same digest. If run state changes after a packet digest is
  issued, the old digest is not scored; evaluation mints a new packet or refuses
  it with a provenance mismatch.
- **SCN-EVAL-HARD-GATE:** A missing required artifact or failed deterministic
  check publishes a visible hard-gate failure without asking a model evaluator
  to convert it into a pass.
- **SCN-EVAL-INDEPENDENT:** A worker claims success while the independent
  evaluator receives a fresh packet and returns `:inconclusive` or `:fail`; the
  final score preserves both records and does not use the worker claim as
  approval.
- **SCN-EVAL-PARALLEL:** Two evaluator lanes and an adjudicator run through the
  public workflow. Missing, duplicate, changed-packet, or malformed reports are
  rejected and cannot be replaced by a fan-in best result.
- **SCN-EVAL-COMPARE:** Two runs of the same task produce a comparison that
  separates hard-gate status, named dimensions, resource use, evaluator
  revision, and incomparable evidence.
- **SCN-SKILL-BOUNDARY:** A selected digest-pinned skill changes the bounded
  prompt/context packet and is recorded in the harness digest, but cannot grant
  an unlisted tool, path, secret, or MCP server.
- **SCN-MCP-READONLY:** An admitted read-only MCP call records namespaced tool,
  request/result digests, timeout/cancellation, server revision, and freshness;
  an unavailable required server yields explicit inconclusive/failed state.
- **SCN-GENERATED-PURE:** A generated let-go module transforms only its supplied
  input envelope. Attempts to read a file, environment variable, clock,
  network, process, credential, hidden context, or undeclared namespace fail
  closed and produce an audit record.
- **SCN-GENERATED-PROMOTION:** A generated module compiles, passes deterministic
  tests, obeys resource limits, validates output, and remains quarantined until
  the configured promotion gate approves it. Only a promoted revision is
  callable through its typed namespaced tool.
- **SCN-EPOCH-PROMOTION:** A challenger evaluator or harness revision is
  evaluated against a frozen anchor set. Its scores record the candidate and
  incumbent separately; no retired-evaluator scores are silently mixed into the
  active epoch.

## 13. Definition of Done

- [ ] Evaluation subject is published for a terminal run and is schema-versioned.
- [ ] Evidence packets are bounded, digestable, reproducible, and fail closed on
      missing or changed evidence.
- [ ] Implementation verification and independent evaluation are distinct in
      records, routing, and reports.
- [ ] Deterministic hard gates run before model-based judging.
- [ ] Multidimensional score records preserve unknown and inconclusive states.
- [ ] Fresh no-tools evaluator sessions produce evidence-linked structured reports.
- [ ] Parallel evaluator lanes and adjudication reject missing, duplicate, or
      unsupported approvals.
- [ ] Run comparison reports configuration, evaluator, anchor, and evidence
      compatibility before ranking.
- [ ] Benchmark runs use isolated roots and versioned task/anchor manifests.
- [ ] Skills have digest-pinned data-only manifests and cannot grant capabilities.
- [ ] MCP read-only support is explicit, namespaced, bounded, cancellable, and
      audited; unavailable required data is inconclusive or failed explicitly.
- [ ] Generated let-go drafts are quarantined and provenance-linked.
- [ ] The default generated-code profile has no ambient filesystem, environment,
      process, network, clock, randomness, credential, eval, or hidden-state access.
- [ ] Generated source is statically checked, isolated at compile/run time,
      resource-bounded, output-validated, and capability-audited.
- [ ] Generated modules are exposed to agents only after promotion gates.
- [ ] Candidate evaluator, skill, MCP, workflow, and generated-code revisions
      are compared against frozen anchors before promotion.
- [ ] Security, provenance, cancellation, and cleanup failures are distinct from
      ordinary task or evaluator failures.
- [ ] Public acceptance scenarios cover the delivered slices and preserve stable
      scenario IDs.
- [ ] Each delivered slice has focused tests, a real public API journey, and
      evidence that does not rely only on model claims.

---

## 14. Open design decisions

Before Slice C, settle the public score API and whether benchmark records are
stored only under run roots or also indexed by a local evaluation catalog.

Before Slice D, settle skill package locations, signed/digest-pinned distribution,
and whether project skills may override user skills.

Before Slice E, settle the supported MCP transport/client boundary, server
lifecycle ownership, authentication references, and whether read-only MCP calls
are permitted in deterministic gates.

Before Slice F, settle the compilation isolation mechanism available in the
supported let-go runtime. If source-level static checks cannot establish the
required boundary, use a stronger process/container boundary rather than
claiming safety from a parser alone.

Before Slice G, settle the promotion authority: explicit human approval,
frozen-anchor statistical promotion, or both. Do not implement evaluator or
harness self-promotion before this decision is recorded.
