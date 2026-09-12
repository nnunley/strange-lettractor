# Hub workflow inspection for HTTP adaptation

Retain the actual running context, chosen logs root and submitted DOT in a
hub-owned workflow entry. On publication, verify the manifest before recording
the graph, diagnostics and fingerprint. Expose these as data through
`:workflow/inspect`, alongside the existing completion snapshot. Do not expose
atoms, promises or handler registries.

Prove inspection while a real handler is blocked after updating context, then
after completion. Preserve existing workflow run/resume behavior. Resume now
supplies a wrapper-owned observer after verification and creation of the actual
checkpoint context; the hub retains that context and captured graph. The observer
does not replace context through runtime options. This is prerequisite work, not a migrated
HTTP adapter or a replacement for HTTP publication/timeout acceptance tests.

Implemented and verified. Ten assertions failed before implementation; the new
test passes 1/12/0. Existing hub workflow/evaluation tests pass 13/85/0, including
resume; CLI tests pass 6/57/0. `make build` succeeds. The compiled host probe reads
the waiting workflow's graph and current node over nREPL, then shuts it down.
Publication verification remains separate from future HTTP timeout admission;
that race contract is not claimed by this increment.

Resume follow-up: four live inspection assertions failed before adding the
observer. Both inspection tests now pass 2/21/0; workflow-recovery-contract passes
52/481/0, engine passes 46/209/0, and hub-console-ops passes 13/85/0. The logs-root
assertion uses the canonical directory, matching the existing resume path resolver.
No new compiled-wire resume test was run; the resume evidence here is public hub
and engine integration, while the earlier compiled probe covers fresh runs.
