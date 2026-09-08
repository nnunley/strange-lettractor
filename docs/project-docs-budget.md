# Project instruction byte budget

The coding-agent-loop spec §6.5 requires a total 32 KB project-document budget
and a visible truncation marker. Discovery previously counted characters in
document bodies only, leaving headers, separators and the marker outside the
budget. Multibyte content could exceed the limit substantially.

The implementation now counts the complete rendered block in UTF-8 bytes using
native let-go `bytes`. A rune-boundary prefix search preserves complete
characters. Truncation reserves space for the marker, including when an earlier
document exactly filled the budget. Discovery stops reading later documents
once truncation occurs. Provider selection and root-first ordering are unchanged.

## Verification (2026-09-07)

- Against main's prior implementation, the original five regression tests
  produced ten assertion failures and zero errors.
- Final focused contracts: six tests, 30 assertions, zero failures/errors.
  Covers provider filtering, multibyte content, exact size and one-byte overflow,
  combined headers/separators, later-document marker space, cutoff reads, and
  the project-instruction block in an actual session request.
- A standalone bundled test entrypoint explicitly requiring the agent and
  contract namespace passed the same six tests / 30 assertions outside the
  repository. This is packaged bytecode evidence, not native Go AOT lowering.
- The worktree suite passed 570 tests / 4,723 assertions, zero failures.
  An earlier run while the test file was still being extended reported one
  failure; its detailed failure was not retained, so its cause is unverified.
  The final suite was rerun after edits stopped. `lgx build` also exited zero.
- After integration onto main (`a38e37a`), the fresh suite passed 573 tests /
  4,740 assertions with zero failures. The application build and its `help`
  command exited zero. The CLI uses `help`; `--help` was rejected as an unknown
  command during verification and is not being counted as a passing check.

## Backlog reconciliation (2026-09-08)

The requirement table and roadmap still called this budget work pending despite
the committed implementation and evidence above. Rechecked source and all six
contract tests against the snapshot's section 6.5; reran natively and from a
standalone bundle outside the checkout: 6 tests / 30 assertions / zero failures
or errors in each, exit 0. The persistent focused runner is now:

`/Users/ndn/development/let-go/lg -source-paths src:test dev/project_docs_tests.lg run`

Only the evidence index and runner changed; no production behavior or test
assertions changed in this reconciliation. Complete environment/git metadata and
provider-base system prompt evidence still needs its own closure audit.

This closes the byte-budget defect, not the entire system-prompt requirement or
the full Attractor implementation. No let-go runtime changes or model calls
were required.
