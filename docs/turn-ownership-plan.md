# Current-turn ownership — CAL-OWN-01

Status: paired scope, spec and quality reviews approved; permanent RED reproduced.
Focused and standalone bundle: 5 tests / 85 assertions. Impacted: 198/1405.
Final default suite: 644/5970. All zero failures; CLI build/help pass.
Paired three-tier component audit is clean; ready for the public checkpoint.
Fresh default baseline on `1bdc933`: 639 tests / 5,885 assertions / zero failures.

Source obligations: coding-agent specification §2.3 session lifecycle, §2.8 stop
conditions, and graceful shutdown. See `turn-ownership-gap.md` for the independently
verified baseline reproduction on `f38af57` and `1bdc933`'s hook candidate.

## Root cause and boundary

The session becomes idle before processing-end callback delivery finishes. A new
input may correctly be admitted, while the prior backend monitor and catch block
still retain an `:owned` admission token. That token proves historic admission,
not current authority to abort, clean up, or evict the shared session. Preserve
completion-callback reentry; do not fix this by withholding idle or rejecting
otherwise valid new inputs.

## Required contract

- Every successfully admitted root input establishes a fresh current ownership
  identity, including public direct-session input, not just backend calls.
  Queued follow-ups stay within their owning processing invocation.
- Pending/rejected inputs never acquire authority. Existing hook-context refresh
  and cancellation-before-admission behavior remain intact.
- Backend cancellation or failure may seal/close a session only if that invocation
  is still its current owner. Make ownership check and close/abort state claim one
  atomic lifecycle-lock operation; a check followed by an unfenced close is unsafe.
  Run blocking provider/environment/subagent cleanup outside that lock.
- A stale caller still receives its own result/error/cancellation, but cannot abort
  the successor's controller, close its resources, alter its hooks/history, or evict
  its cache entry. Preserve the existing identity check against replacement cache
  entries. Newly created but never-admitted sessions may be cleaned up only if no
  other invocation has taken ownership.
- Public explicit session abort/close remains session-wide. Do not weaken the host
  application's shutdown authority or general graceful cleanup.
- Do not infer an old invocation's cancellation merely from a successor's mutable
  session-wide abort flag; retain invocation-local disposition where necessary.

## Evidence and work sequence

1. Permanent test-only RED for A's gated processing-end callback, B's admitted
   provider, and A cancellation. Observe a completed cancellation decision rather
   than only predicate evaluation; bound and release every worker in `finally`.
2. Paired scope review, then minimal let-go-only production fix through TDD.
3. Prove B remains live before gate release, its controller is not aborted, history
   and hook context are unchanged, cache identity is retained, and B succeeds.
   Cover stale failure cleanup, a direct-session successor, pending cancellation,
   genuine current-owner cancellation/cleanup, and queued follow-ups. Also gate
   completed A's callback while B is aborted: A must retain its own successful
   result instead of inheriting B's abort flag.
4. Paired spec then quality reviews. Run impacted agent/hook/error/engine contracts,
   frozen full sentinel suite, standalone bundle and CLI build/help. Bundle/build
   success is not native-Go AOT conformance.
5. Update CAL-OWN-01/scenario/corpus/roadmap/progress/evidence, audit this component,
   commit and push a verified public checkpoint. Keep broader lifecycle and full
   Attractor requirements open where their separate proof remains incomplete.

No local let-go changes, new concurrency framework, provider implementation work,
private-note access, or destructive worktree cleanup belongs in this repair.
