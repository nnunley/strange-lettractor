# Node Timeout and Tool Execution Design

## Purpose

Strange Lettractor parses the Attractor `timeout` node attribute but does not
currently enforce it. Its built-in ToolHandler also tokenizes commands on
whitespace, which changes shell semantics and provides no timeout or process
group cleanup. This design makes `timeout` a real per-attempt execution bound
while preserving the handler interface and using the existing execution
environment for killable commands.

## Semantics

A node timeout is optional. A numeric value is milliseconds, matching the
parser's existing duration representation; a duration string accepts the DOT
units already supported by `parse-duration-ms` (`ms`, `s`, `m`, `h`, `d`). An
invalid or non-positive timeout fails the attempt as an invalid node
configuration rather than silently choosing a default.

The timeout applies independently to every attempt made by
`execute-with-retry`. When a deadline expires, the attempt produces a
retryable `:timeout_error`. Existing retry policy therefore decides whether to
run another attempt. A retryable timeout emits `:stage.failed` with
`:will_retry true` before `:stage.retrying`; an exhausted timeout emits
`:stage.failed` with `:will_retry false`.

## Cancellation Boundary

The engine creates a cancellation controller for each attempt. Its state is
`:running`, `:deadline`, or `:pipeline_cancelled`, with pipeline cancellation
taking precedence. The handler receives `:cancelled?` and
`:cancellation_reason` functions on an execution-node copy. This is additive
and keeps existing custom handlers source compatible.

The handler runs in a future while the engine polls at a short bounded
interval, observing both the deadline and the pipeline cancellation predicate.
The controller transition is atomic and pipeline cancellation wins a race
with deadline expiry. At
timeout, the engine signals the attempt controller, then waits for the handler
future to quiesce before retrying or advancing. This prevents late writes to
shared Context, logs, or fidelity state. Built-in handlers must honor the
signal and release owned resources promptly. A custom handler that ignores
cooperative cancellation cannot be forcefully stopped safely, so its timeout
is advisory until it returns. Hard wall-clock termination is guaranteed only
for subprocess-backed and cooperative handlers. Pipeline cancellation yields
a terminal cancelled outcome; deadline expiry yields a retryable timeout.
Invalid timeout configuration is terminal with `:retryable false`.

After signalling a deadline, the engine joins the handler and captures its
terminal value. If the handler returns or throws structured timeout details,
the engine-owned timeout outcome copies its `context_updates`, including
partial stdout/stderr, while retaining deadline classification. Unstructured
late values are discarded. Retry handling therefore preserves diagnostic
output without accepting a late success after the deadline.

## ToolHandler

With an explicit timeout, ToolHandler delegates the complete command string to
a fresh, attempt-owned `LocalExecutionEnvironment`. A cancellation watcher
calls environment cleanup when the attempt is signalled, and ToolHandler joins
owned work before returning. This preserves shell syntax and reuses the
existing process-group TERM/KILL watchdog.

When the node has a timeout, ToolHandler passes that duration to
`exec_command`. When unset, ToolHandler preserves its unbounded behavior and
executes the complete string through the platform shell; the coding-agent
shell tool's separate 10-second default does not apply. A timed-out result becomes a retryable timeout error;
a cancelled result becomes a cancelled outcome; other nonzero exits remain
ordinary failures.

## Codergen

The engine-level cancellation predicate is passed through the prepared node.
The agent-backed codergen backend watches it while a turn is active. When it
fires, the backend calls `abort-session!`, which closes the provider request,
terminates active execution-environment commands, and cleans up subagents. The
engine remains the authority that classifies the attempt as timed out.

Full-fidelity sessions that time out are evicted from their thread cache; a
later retry starts a fresh session rather than reusing an aborted one.

## Other Built-ins and Custom Handlers

Fast synchronous handlers need no special work. Parallel explicitly checks
the attempt predicate before scheduling and collecting branch work. Manager
combines its runtime predicate with the attempt predicate, stops an owned
child, and joins it before returning. Active parallel branches receive the
combined predicate through the engine callback and are joined before return.

Human-interviewer timeout behavior remains governed by the separate
Interviewer protocol. Until a later non-blocking-input slice, a blocking
interviewer is non-cooperative and its node timeout is advisory until `ask`
returns; this slice does not claim a hard human deadline.

Custom handlers may periodically call `(:cancelled? node)` and return
`:cancelled`. Existing handlers that do not inspect it continue to work.

## Evidence

Tests will prove:

- inherited and explicit node durations are parsed and enforced per attempt;
- timeout errors enter the existing retry policy;
- a cooperative custom handler observes cancellation;
- ToolHandler preserves quoting, pipes, and redirects;
- ToolHandler terminates a process group and exposes partial output on timeout;
- agent-backed codergen aborts and evicts a timed-out session;
- nodes without an explicit timeout retain existing behavior;
- invalid and non-positive timeout configuration is terminal and never retried;
- the full test suite and local let-go AOT build remain green.

No recursive deletion is required by the implementation or its tests. Tests
use unique temporary paths and leave cleanup to the operating system.
