# Runtime SKIPPED outcomes

Scope: original Attractor specification §5.2 defines SKIPPED as proceeding
without recording an outcome. The runtime currently reuses the four-state
Appendix C status-file validator and rejects this handler result.

Decisions from independent scope review:

- Keep the Appendix C file codec strict. Introduce runtime Outcome normalization
  that additionally accepts skipped, while validating the same optional fields.
  Valid files still take precedence; invalid files still fail; no-file skipped
  handler outcomes take precedence over auto-status synthesis.
- A skipped visit advances completed_nodes and execution/checkpoint position.
  It does not write status.json, add a node_outcomes entry, or replace a prior
  recorded outcome. An earlier failed goal gate remains failed after a skipped
  revisit; a gate with only skipped visits has no recorded outcome (§3.4).
- Apply explicit context_updates and set context.outcome to skipped (§5.1).
  Route with the transient Outcome, including label/suggested IDs/next override.
  Keep an observable completion event. Manager collectors must not record the
  skipped outcome or accumulate its artifacts.
- Persist the selected transition for checkpoint recovery without persisting
  a skipped node Outcome. This avoids replaying a handler, losing suggested
  destinations, or routing from an earlier visit's saved outcome. Resume must
  preserve incoming edge/fidelity, loop_restart and a no-next-edge completion.
  Older checkpoints continue to use the existing fallback recovery path.
  The context checkpoint serializer/loader must retain the transition data;
  public pinned resume must validate it before events or handlers. If the
  engine-only next_node_id override is supported on skipped outcomes, retain
  enough transition history to validate that non-edge jump after later nodes
  checkpoint too; a cursor for only the latest visit would lose that evidence.
- Apply the same no-status/no-outcome behavior to branch execution. Preserve
  the last recorded branch result through trailing skipped stages. An entirely
  skipped branch remains neutral: it cannot win first_success or supply a
  successful fan-in candidate. This is an explicit choice for an aggregation
  case the specification leaves underspecified. Human AnswerValue.SKIPPED
  continues to mean a failed human gate and is unrelated to this runtime status.

Implementation will be delegated to gpt-6-sol (multi-file runtime integration),
after the current cheaper implementer's bounded test repair. Required evidence:
handler normalization/file precedence/auto-status; main graph routing and goal
gates; skipped revisits; checkpoint/resume with suggested IDs and no edge;
parallel branch and manager paths; unchanged status-file rejection and human
skip behavior. Paired review, impacted tests, full suite and CLI build follow.
