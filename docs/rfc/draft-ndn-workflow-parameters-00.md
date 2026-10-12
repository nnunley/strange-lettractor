# draft-ndn-workflow-parameters-00: Workflow Input Parameters for DOT Pipelines

**Status:** DRAFT
**Corpus:** red (spec-first — evidence is the acceptance criteria)
**Category:** Standards-Track
**Authors:** Norman Nunley, Jr <nnunley@gmail.com>, Claude (drafting agent)

## Abstract

This document defines workflow input parameters for attractor DOT pipelines:
typed values declared in the workflow, supplied at launch, and substituted
into attribute values before the run begins. It is for authors who need one
workflow to serve many targets, and for callers who launch a workflow they
did not write. It also defines the trust level a launch carries, which
bounds what a delegated caller may set.

## Motivation

A DOT workflow is fixed text. Every value it needs is written into the file,
and nothing outside the file can change one. The `examples/autoresearch`
workflow shows the cost directly: its README instructs the reader to edit
the workflow to change the researcher's model (`model_stylesheet`) and to
change the per-experiment budget (`timeout` on two nodes), and its per-target
settings live in a `research.env` file that the workflow never sees — a shell
script sources it behind a tool node, so the workflow's own inputs are
invisible to `validate`, to the event log, and to anyone reading the graph.

The same cost appears where a workflow was imported. `examples/task-runner/`
is the native adaptation of an upstream workflow that had parameters; its
README records that "No new global parameter expansion ... was added", and the
adaptation shows what replaced them — the task's paths are written literally
into every `tool_command`, and the one value a caller varies rides on an
`ATTRACTOR_TASK_MAX_ITERATIONS` environment variable the workflow never
declares. An input the graph cannot see is an input `validate` cannot check.

Two mechanisms exist and neither closes the gap. Sub-pipelines are already
parameterized: `composition.lg` seeds a child run's context from `input_map`.
Top-level runs are not: the hub builds an empty context and no CLI path
supplies values. Separately, `$goal` is substituted into node prompts by a
transform. That convention reaches one attribute, from one source, with a
syntax that would corrupt shell variables if generalized.

The gap has a hard edge. `model_stylesheet` and `timeout` are consumed
before any node runs — the stylesheet by a transform during prepare, the
timeout by the tool handler reading the parsed node — so no runtime context
value can ever reach them. Anything that parameterizes a workflow must act
on the graph before the run starts.

This document specifies that mechanism: a declaration, a reference syntax, a
resolution order, and the trust rules that apply when the launcher is not
the author.

## Terminology

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD",
"SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this
document are to be interpreted as described in BCP 14 (RFC 2119, RFC 8174)
when, and only when, they appear in all capitals, as shown here.

- **parameter** — a named, typed value a workflow declares and a launch supplies.
- **declaration** — the record in the `params` graph attribute that names a parameter and fixes its type.
- **reference** — the token `{{name}}` appearing in an attribute value.
- **resolution** — producing the value of every parameter for one launch, from defaults and supplied values.
- **substitution** — replacing every reference with its resolved value, before validation.
- **launch** — one request to run a workflow, carrying supplied values and a trust level.
- **trust level** — whether a launch may set every parameter or only delegable ones.
- **delegable** — a declaration's permission for a DELEGATED launch to supply that parameter.

## Specification

This document defines workflow input parameters: their declaration, the
reference syntax, resolution order, substitution, the run context and
environment they reach, and the trust rules bounding a delegated launch. It
does NOT define how a launch acquires its trust level on any particular
channel; that belongs to the transport exposing the launch, and the
pinned-bundle case is named in Out of Scope.

**Substitution precedes interpretation.** Parameter substitution produces an
ordinary graph. No component downstream of substitution knows that
parameters exist — not validation, not the stylesheet transform, not the
tool handler, not workflow capture.

**A declaration is the complete picture.** Everything a launch can set, every
value a tool node can read from its environment, and everything a delegated
caller can reach is visible in the `params` attribute. Nothing is implicit.

**Trust does not increase.** A launch MAY lower its own trust level and MUST
NOT raise it.

### Evidence conventions

Evidence conventions are governed by draft-ndn-authoring-rfcs-00, section
"Evidence conventions". For this RFC: transcripts run from a directory
containing the workflow file named in the command, with no checkpoint
present unless the transcript creates one. This RFC is spec-first; its
corpus is red until the implementation lands.

### Data model

```
RECORD ParameterDeclaration:
    name        : ParamName            -- the reference token and env-var stem
    type        : ParameterType        -- fixes coercion and validation
    default     : Value | None         -- None means the launch MUST supply it
    doc         : String = ""          -- one line, shown by `attractor graph`
    export      : Boolean = false      -- reaches tool nodes as an env var
    delegable   : Boolean = false      -- a DELEGATED launch may supply it

RECORD ResolvedParameter:
    name        : ParamName
    value       : Value                -- coerced to the declared type
    source      : ValueSource          -- for the event log and diagnostics

ENUM ParameterType:
    STRING      -- any text; carries no closed value set; written :string
    INT         -- a decimal integer; written :int
    ENUM_OF     -- one of a fixed list of strings; written [:enum "a" "b"]

ENUM ValueSource:
    DEFAULT     -- the declaration's default
    FILE        -- the params file
    FLAG        -- a --param occurrence

ENUM TrustLevel:
    TRUSTED     -- the launcher could equally have edited the workflow
    DELEGATED   -- the launcher may parameterize but is not the author
```

| Trust level | Meaning                                                                    |
|-------------|----------------------------------------------------------------------------|
| `TRUSTED`   | Accepts a value for any declared parameter.                                 |
| `DELEGATED` | Accepts a value only for a parameter declared `:delegable true`; rejects the rest before any node runs. |

**Field constraints:** `name` conforms to `param-name` in the Formal Grammar.
A declaration whose `default` is present MUST carry a value of its declared
type. A declaration list MUST NOT contain two declarations with the same
`name`.

### Declaration

A workflow declares its parameters in the `params` graph attribute, whose
value is an EDN vector of declarations. [R-param-declaration] A workflow
without the attribute declares no parameters.

```
digraph Example {
    graph [
        params="[{:name :editable :type :string :default \"solve.lg\"
                  :doc \"files the researcher may edit\" :export true}
                 {:name :run_cmd :type :string :doc \"how the experiment runs\"
                  :export true}
                 {:name :direction :type [:enum \"min\" \"max\"] :default \"min\"
                  :doc \"which way is better\" :export true :delegable true}
                 {:name :max_iterations :type :int :default 0 :export true}]"
    ]
}
```

Parameter names are lowercase so that the environment variable a declaration
maps to is unambiguous. [R-param-name-charset]

<!-- evidence: @R-param-name-charset -->
| name             | valid |
|------------------|-------|
| `editable`       | yes   |
| `run_cmd`        | yes   |
| `max_iterations` | yes   |
| `a1`             | yes   |
| `Editable`       | no    |
| `run-cmd`        | no    |
| `1st`            | no    |
| `_leading`       | no    |
| (empty)          | no    |

A malformed `params` value, a duplicate name, an unknown type, or a default
whose value does not match its declared type is a validation error reported
by `attractor validate`. [R-param-declaration]

```transcript @R-param-declaration
$ attractor validate bad-params.dot
parameter_declaration: duplicate parameter name 'editable'
parameter_declaration: parameter 'max_iterations' default "many" is not an :int
? 1
```

The upstream engine this workflow family comes from spells the same attribute
as a bare comma-separated name list. A `params` value of that shape MUST be
rejected with a diagnostic naming the declaration form, so an imported
workflow fails with a migration hint rather than an EDN parse error.
[R-legacy-params-rejected]

```transcript @R-legacy-params-rejected
$ attractor validate examples/upstream/amplifier/task-runner.dot
parameter_declaration: 'params' is a comma-separated name list; this runtime expects a vector of declarations, e.g. [{:name :task_file :type :string}]
? 1
```

### Reference syntax

A reference is `{{name}}`, as given by `reference` in the Formal Grammar.
The sequence `{{{{` is an escape yielding a literal `{{`, so a prompt can
carry brace pairs it wants a model to read. [R-substitution-syntax]

<!-- evidence: @R-substitution-syntax -->
| attribute value             | with `editable` = `solve.lg`    |
|-----------------------------|---------------------------------|
| `edit {{editable}}`         | `edit solve.lg`                 |
| `{{editable}}{{editable}}`  | `solve.lgsolve.lg`              |
| `{{{{editable}}`            | `{{editable}}`                  |
| `"${LG:-lg}" bench.lg`      | `"${LG:-lg}" bench.lg`          |
| `$goal`                     | `$goal`                         |
| `cost is {50}`              | `cost is {50}`                  |

Shell variables and Graphviz record-label braces pass through untouched.
That is why references are doubled braces rather than RFC 6570's `{name}`
or an extension of the existing `$goal` convention: the lg-primes demo
target's run command is literally `"${LG:-lg}" -source-paths . bench.lg`,
and a `$`-based or single-brace syntax would corrupt it.

A reference naming an undeclared parameter is a validation error.
[R-undeclared-reference] Without this rule a typo substitutes nothing and
the workflow runs with a corrupted command.

```transcript @R-undeclared-reference
$ attractor validate typo.dot
parameter_reference: node 'guard' attribute 'tool_command' references undeclared parameter 'editble'
? 1
```

### Substitution

Substitution is a graph transform. It MUST run before every other transform
and before validation. [R-substitution-order] Running first is what lets the
stylesheet transform see a resolved `model_stylesheet`, the tool handler see
a resolved `tool_command` and `timeout`, and workflow capture pin a resolved
`subpipeline.dotfile`. Each is observable: the model a node resolves to, the
budget a tool node enforces, and the child a capture pins all follow the
supplied value.

```transcript @R-substitution-order
$ attractor graph ordered.dot --param model=openrouter/anthropic/claude-haiku-4.5 --param budget=30s
node propose: llm_model=openrouter/anthropic/claude-haiku-4.5
node run: timeout=30s
node child: subpipeline.dotfile=targets/lg-primes/inner.dot
```

Substitution MUST apply to every attribute string value on the graph, on
every node, and on every edge, except the `params` attribute itself, which
is read before substitution and MUST NOT be substituted into.
[R-substitution-scope]

<!-- evidence: @R-substitution-scope -->
| attribute                | substituted |
|--------------------------|-------------|
| `tool_command` (node)    | yes         |
| `prompt` (node)          | yes         |
| `timeout` (node)         | yes         |
| `class` (node)           | yes         |
| `condition` (edge)       | yes         |
| `label` (edge)           | yes         |
| `goal` (graph)           | yes         |
| `model_stylesheet` (graph) | yes       |
| `subpipeline.dotfile` (node) | yes     |
| `params` (graph)         | no          |

`$goal` expansion is unchanged and continues to run after substitution.

### Configuration

| Key                    | Type   | Default   | Description                          |
|------------------------|--------|-----------|--------------------------------------|
| `--param k=v`          | String | absent    | One parameter value; repeatable      |
| `--params-file <path>` | Path   | absent    | EDN map of parameter names to values |
| `--trust <level>`      | Enum   | `TRUSTED` | The launch's trust level             |

`run`, `validate` and `graph` MUST all accept these options, so a launch can
be checked without being executed.

The trust default is `TRUSTED` because the only channels that exist at the
time of writing (September 2026) accept a whole workflow source from the
caller, so they already grant what any parameter could.

**Resolution precedence** (highest first; the last entry is the terminal
default):

1. A `--param` occurrence
2. An entry in the `--params-file` map
3. The declaration's `:default`
4. Failure: the parameter is REQUIRED and unsupplied

[R-value-precedence]

```transcript @R-value-precedence
$ cat params.edn
{:direction "max" :max_iterations 7}
$ attractor run wf.dot --params-file params.edn --param direction=min
parameters: direction=min (flag) max_iterations=7 (file) editable=solve.lg (default)
```

A `--param` naming an undeclared parameter is an error, so a misspelled flag
never passes silently. A parameter with no default and no supplied value is
an error raised before any node runs. [R-missing-value]

```transcript @R-missing-value
$ attractor run wf.dot
parameter_missing: 'run_cmd' is required and was not supplied
? 1
$ attractor run wf.dot --param editble=solve.lg
parameter_undeclared: '--param editble' names no declared parameter
? 1
```

### Types and coercion

Values from `--param` arrive as text and MUST be coerced to the declared
type. A value that does not coerce is an error naming the parameter, and for
`ENUM_OF` the allowed values. [R-type-coercion]

<!-- evidence: @R-type-coercion -->
| declared type          | supplied | outcome                                |
|------------------------|----------|----------------------------------------|
| `:string`              | `min`    | `"min"`                                |
| `:int`                 | `7`      | `7`                                    |
| `:int`                 | `-1`     | `-1`                                   |
| `:int`                 | `7.5`    | error                                  |
| `:int`                 | `many`   | error                                  |
| `[:enum "min" "max"]`  | `max`    | `"max"`                                |
| `[:enum "min" "max"]`  | `Max`    | error, names `min` and `max`           |
| `[:enum "min" "max"]`  | `middle` | error, names `min` and `max`           |

A substituted value is rendered as text: an `INT` renders in decimal, an
`ENUM_OF` and a `STRING` render verbatim.

### Run context and environment

Every resolved parameter MUST be seeded into the run context under the key
`param.<name>` before the first node runs. [R-context-mirror] This makes a
parameter readable by an edge condition and forwardable to a sub-pipeline
through the existing `input_map`, rather than adding a second way to move
values.

```transcript @R-context-mirror
$ attractor run wf.dot --param direction=max
stage route: condition "param.direction = max" matched -> maximize
```

A parameter declared `:export true` MUST be present in the environment of
every tool node as `ATTRACTOR_PARAM_<NAME>`, where `<NAME>` is the
parameter's name uppercased. A parameter not so declared MUST NOT be.
[R-export-env]

The probe node's command is `env | grep '^ATTRACTOR_PARAM_' | sort`, so a
parameter that is not exported is absent rather than empty.

```transcript @R-export-env
$ attractor run env-probe.dot --param editable=solve.lg --param secret_note=hidden
ATTRACTOR_PARAM_EDITABLE=solve.lg
```

Export is per declaration rather than blanket so that the declaration stays
the complete picture of what a tool node can see.

### Trust

A launch carries a trust level. A launch that itself originates from a run
MUST NOT carry a level higher than the run that spawned it; a sub-pipeline of
a DELEGATED run is DELEGATED. [R-trust-monotonic]

<!-- evidence: @R-trust-monotonic -->
| launching run | requested for child | effective |
|---------------|---------------------|-----------|
| `TRUSTED`     | `TRUSTED`           | `TRUSTED` |
| `TRUSTED`     | `DELEGATED`         | `DELEGATED` |
| `DELEGATED`   | `DELEGATED`         | `DELEGATED` |
| `DELEGATED`   | `TRUSTED`           | `DELEGATED` |

Under a DELEGATED launch, supplying a value for a parameter not declared
`:delegable true` MUST fail before any node runs.
[R-delegated-rejects-nondelegable]

```transcript @R-delegated-rejects-nondelegable
$ attractor run wf.dot --trust delegated --param run_cmd='sh evil.sh'
parameter_not_delegable: 'run_cmd' may not be supplied by a delegated launch
? 1
```

As defence in depth, a parameter declared `:delegable true` whose reference
appears in `tool_command`, `subpipeline.dotfile` or `model_stylesheet` MUST
have a closed type — `:int` or `[:enum ...]`, never `:string`.
[R-delegable-closed-type] Reference sites are static, so this is checked by
`attractor validate` rather than at launch. A closed type cannot carry shell
metacharacters, a path, or a provider name the author did not enumerate.

<!-- evidence: @R-delegable-closed-type -->
| type                  | delegable | referenced from        | valid |
|-----------------------|-----------|------------------------|-------|
| `:string`             | no        | `tool_command`         | yes   |
| `:string`             | yes       | `prompt`               | yes   |
| `:string`             | yes       | `tool_command`         | no    |
| `:string`             | yes       | `subpipeline.dotfile`  | no    |
| `:string`             | yes       | `model_stylesheet`     | no    |
| `:int`                | yes       | `tool_command`         | yes   |
| `[:enum "min" "max"]` | yes       | `tool_command`         | yes   |

### Checkpoint and resume

The resolved parameters of a run MUST be recorded in its checkpoint.
[R-checkpoint-capture] A resume MUST use the recorded values.

```transcript @R-checkpoint-capture
$ attractor run wf.dot --param direction=max --param run_cmd='sh bench.sh'
stage failed: run
$ grep -o ':parameters {[^}]*}' run/checkpoint.edn
:parameters {"direction" "max" "run_cmd" "sh bench.sh" "editable" "solve.lg" "max_iterations" "0"}
$ attractor resume --checkpoint run/checkpoint.edn
parameters: direction=max run_cmd=sh bench.sh (from checkpoint)
```

Supplying `--param` or `--params-file` to a resume MUST raise
`workflow_configuration_error`. [R-resume-rejects-params] The resume path
admits a fixed set of runtime options and discards the rest silently, so
without this rule a caller's parameters would be accepted and ignored — the
dishonest outcome.

```transcript @R-resume-rejects-params
$ attractor resume --checkpoint run/checkpoint.edn --param direction=max
workflow_configuration_error: option --param is not permitted on resume
? 1
```

### Errors

| Error                       | Example                                              | Recovery                                                   |
|-----------------------------|------------------------------------------------------|------------------------------------------------------------|
| `parameter_declaration`     | duplicate name; default of the wrong type            | Reject at validate; the graph never runs                   |
| `parameter_reference`       | `{{editble}}` with no such declaration               | Reject at validate; name the node and attribute            |
| `parameter_reference_coerced` | `goal_gate="{{gate}}"`                             | Reject at validate; the attribute is coerced before substitution, so move the reference to an uncoerced attribute |
| `parameter_undeclared`      | `--param editble=x`                                  | Reject before the run; list declared names                 |
| `parameter_missing`         | `run_cmd` has no default and no value                | Reject before the run; name the parameter                  |
| `parameter_type`            | `--param max_iterations=many`                        | Reject before the run; name the type and allowed values    |
| `parameter_not_delegable`   | DELEGATED launch supplying `run_cmd`                 | Reject before the run; name the parameter                  |
| `parameter_delegable_open`  | `:delegable :string` referenced from `tool_command`  | Reject at validate; require a closed type                  |
| `workflow_configuration_error` | `--param` passed to resume                        | Reject; the checkpoint's values are authoritative          |

## Formal Grammar

```abnf
param-arg      = param-name "=" param-value
param-name     = LOWER *( LOWER / DIGIT / "_" )
param-value    = *VCHAR

reference      = "{{" param-name "}}"
escape         = "{{{{"

env-var-name   = %s"ATTRACTOR_PARAM_" UPPER *( UPPER / DIGIT / "_" )

LOWER          = %x61-7A
UPPER          = %x41-5A
```

The `params` attribute value is EDN (see References); its shape is given by
`ParameterDeclaration` in the Data model rather than restated here.

## Out of Scope

**Launching a pinned workflow bundle by identity.** An operation that runs an
already-captured workflow by its fingerprint, supplying only parameters, is
where DELEGATED becomes load-bearing: the caller parameterizes something it
cannot author. It is excluded because no such operation exists — every launch
channel at the time of writing accepts a whole workflow source, so a trust
distinction would have nothing to bite on. Extension point: the trust rules
in Specification, which a transport RFC binds to a channel.

**How a channel establishes a trust level.** Whether a request is TRUSTED is a
property of the transport that accepted it, not of the parameter mechanism.
Extension point: `TrustLevel` in the Data model, and the `--trust` flag,
which any transport may set on the launch it constructs.

**Secret material in parameters.** Resolved values are written to checkpoints
and event logs, so parameters are the wrong carrier for credentials. No
redaction is specified. Extension point: `ValueSource`, which a later RFC
could extend with a source that resolves at use and is never recorded.

**Parameter types beyond the three.** Durations, paths and booleans are
expressible as `:string` or `[:enum ...]` today. Extension point:
`ParameterType`.

**Implicit parameter inheritance into sub-pipelines.** A child run does not
see its parent's parameters unless the parent maps them. `input_map` already
owns moving values across that boundary, and implicit inheritance would make
a child's inputs depend on which parent invoked it. Extension point:
`input_map` in `composition.lg`.

## Alternatives Considered

**Why not seed the run context and add no substitution?** Values would be
readable by edge conditions and tool nodes but could never reach
`model_stylesheet` or `timeout`, which are consumed by transforms and by the
tool handler before any node runs. That excludes the two settings the
motivating example's README tells readers to hand-edit.

**Why not environment variables only?** Same reach problem, and the effective
values become invisible in the launch and in the event log, so two machines
can run the same command and get different workflows.

**Why not RFC 6570 URI Templates?** Its single-brace `{name}` collides with
Graphviz record-label syntax, and its expansion operators for lists,
fragments and reserved characters solve a URI problem this is not.

**Why not extend `$goal` to `$name`?** `tool_command` values carry shell
variables — the lg-primes target's run command contains `"${LG:-lg}"` — and a
`$`-based syntax would capture them.

**Why not export every parameter to tool nodes?** It needs no extra field,
but the declaration would stop being the complete picture of what a tool node
can read, and every node would see every value whether it needs it or not.

**Why not an allow-list of substitutable attributes?** It is a list to
maintain and explain, and it would have to grow with every new attribute.
Running the transform first makes it unnecessary: the graph is ordinary by
the time anything else reads it.

**Why not upstream amplifier's `$name` references and comma-separated `params`?**
That design exists and is pinned in this repo at
`examples/upstream/amplifier/task-runner.dot`: `params="a, b, c"`, a `--param`
flag, and substitution of `$name`/`${name}` over a shared context-and-parameter
namespace. Its own header warns why the reference syntax lost: "Shell variables
here (VF, n, rc, sig, B, N, prev, ok, sc) are safe ONLY because no param shares
their name. Never add a param named like a shell var." A workflow author must
then know every shell variable in every `tool_command` before naming a
parameter, and the native `examples/task-runner/` files are dense with
`${n:-0}`, `${B:-6}` and `${VF%.md}`. Doubled braces remove the hazard rather
than documenting it. The comma-separated list also has nowhere to carry a
type, a default, an export flag or a delegability flag.

**Why not per-parameter declarations as qualified attributes (`param.editable=...`)?**
One line per parameter reads well and matches the `subpipeline.*` convention,
but the name then lives in the key while the type lives in an EDN value,
splitting one record across two syntaxes. A single `params` vector keeps
declarations ordered for `attractor graph` output and matches the shape of
lgx task arguments.

## Security Considerations

Parameter values are substituted into `tool_command`, which is executed by a
shell. Under a TRUSTED launch this is injection by design and grants nothing
new: that launcher can edit the workflow file, including its commands. Under
a DELEGATED launch two rules bound it — the author marks which parameters may
be supplied at all, and any delegable parameter reaching `tool_command`,
`subpipeline.dotfile` or `model_stylesheet` must have a closed type, so a
delegated caller can select among values the author enumerated but cannot
introduce text of its own into a command, a path, or a provider selection.

At the time of writing (September 2026) every launch channel is
TRUSTED-equivalent, because the hub's run operation accepts the whole
workflow source from its caller. Parameters therefore widen no existing
surface. The trust rules exist so that the first channel to accept a pinned
workflow plus parameters has a model to enforce rather than a retrofit.

Resolved values are recorded in checkpoints and appear in event logs and in
the run context. Credentials MUST NOT be passed as parameters; no redaction
is specified and none should be assumed.

A params file is read from a caller-supplied path with the launching user's
privileges. It is data, not code: the file is EDN read for values only, and
a value never becomes a declaration.

Substitution cannot alter graph topology beyond what the author wrote:
references expand inside attribute values, and a value cannot introduce a
node, an edge, or a new attribute.

## Compatibility

No workflow in this repository contains `{{`, so substitution is a no-op for
every workflow written before this document. `$goal` is unchanged and
continues to expand after substitution.

One file declares a `params` attribute: `examples/upstream/amplifier/task-runner.dot`,
a pinned unmodified copy of an upstream workflow, which its README describes as
"provenance/reference source, not the native runnable variant" — this runtime
does not run it, and the adapted variant beside it declares no parameters.
Under this document that file becomes a validation error rather than an
ignored attribute, which is the intended outcome: its parameters were never
honored here, and the diagnostic says so instead of letting the file look
supported.

One behavior changes for existing users: passing parameter options to a
resume raises an error where the current resume path silently discards
unrecognized options. Resumes that pass no such options are unaffected.

Checkpoints written before this document carry no recorded parameters. A
resume from one of them is a resume of a workflow that declared none, so the
recorded set is empty and the run proceeds unchanged.

`examples/autoresearch` migrates by declaring its `research.env` settings as
exported parameters; `ar.sh` reads them from its environment instead of
sourcing a file. That migration is a separate change and is not required by
this document.

## References

- BCP 14 — RFC 2119, RFC 8174: normative keywords.
- RFC 5234, RFC 7405: ABNF, including case-sensitive string notation.
- RFC 6570: URI Template — prior art for reference syntax, not adopted here.
- Graphviz DOT language: <https://graphviz.org/doc/info/lang.html> — the host syntax, and the source of the record-label brace collision.
- EDN: <https://github.com/edn-format/edn> — the format of the `params` attribute and the params file.
- `docs/specs/attractor-spec.md` §2.5 (graph attributes), §9.2 (built-in transforms), Appendix A (attribute reference) — the sections this document extends.
- lgx: <https://github.com/abogoyavlensky/lgx> — task `:args` declarations, the shape the `params` vector follows, and `{{name}}` interpolation in task strings.
- `microsoft/amplifier-bundle-attractor`, pinned at commit `2d8c781fd4290e035c6fc7b64ff36f46a7332045` and vendored at `examples/upstream/amplifier/task-runner.dot` — the upstream parameter design, and the source of its own shell-collision warning.
- `examples/task-runner/README.md` — the native adaptation that records parameter expansion was not carried over.
- `nnunley/strange-lettractor` issue #2 — the autoresearch report whose fix motivates parameterizing that workflow.
