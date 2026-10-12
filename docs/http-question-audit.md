# HTTP human-question audit — 2026-09-12

Historical evidence for the legacy `server.lg` / `web_interviewer.lg` path.
The current CLI serves the hub HTTP/nREPL implementation; see [hub usage](hub.md)
and the [2026-10-07 audit](codebase-audit-2026-10-07.md). Both expose HTTP APIs,
not a bundled browser frontend.

The original-spec audit found that the HTTP interviewer ignored each question's
timeout and imposed a hardcoded 30-second limit. Millisecond-based question IDs
could also collide between parallel gates. `web_interviewer.lg` now uses unique
IDs, monotonic per-question deadlines, complete default answers, and cancellation
cleanup. Untimed questions wait for an answer or cancellation. The questions
endpoint exposes stage, metadata, default and timeout alongside text and options.

The parallel answer regression also exposed a runtime JSON defect: string map
keys were serialized with reader quotes. The configured runtime is fixed; the
historical source-patch evidence is recorded in
[runtime build audits](runtime-audits.md). The patch directory has since been removed;
the current release pin is in `lgx.edn`.

The native socket probe found that an empty lazy pipeline listing serialized as
`[null]`. The endpoint now constructs a vector and returns `[]`; a public-handler
regression failed before the change and passes afterward.

Evidence:

- `make run-server-question`: five tests, 20 assertions, zero failures. Covers
  timeout/default routing, parallel questions and answers, complete defaults,
  cancellation cleanup, and an empty JSON pipeline listing.
- The full suite passed with 1008 tests and 9297 assertions before the final
  empty-list endpoint regression/change; that total does not certify later edits.
- `make build` rebuilt the CLI after the endpoint change.
- The native let-go client exercised the compiled server over loopback, without
  model calls: question IDs, stage, answer routing, context keys, question cleanup,
  and timeout/default routing all passed. The owned process settled during
  cleanup. `evidence/http-question-wire-evidence.edn` (local output: `evidence/http-question-wire-evidence.edn`)
  records the result and temporary server artifact directory.

Reproduce from the repository root after building:

```sh
.worktrees/let-go-http-cancellation/build/lg -source-paths src test/probes/http_questions_check.lg run
```

The probe uses an isolated temporary working directory and a bounded owned
server process. It requires loopback socket access. This is HTTP human-gate
evidence, not proof of whole-spec completion or release-runtime compatibility.
