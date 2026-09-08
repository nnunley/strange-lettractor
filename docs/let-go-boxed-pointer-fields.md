# Boxed pointer field lookup does not dereference the receiver

Upstream: https://github.com/nooga/let-go/issues/814

Observed 2026-09-07 with the local let-go binary; user-owned checkout HEAD was
`bdd8268c9cb3acf369f0854bada47af79d1d673d`, potentially with uncommitted changes.

## Reproducer (does not launch a process)

```clojure
(get (os/exec "/bin/true") "Process")
```

Expected: nil, because the unstarted Go `exec.Cmd` has a nil `Process` field.
Actual: `reflect: call of reflect.Value.FieldByName on ptr Value`.

## Cause and impact

`pkg/vm/boxed.go`, `Boxed.ValueAtOr`, invokes
`reflect.ValueOf(n.value).FieldByName(name)` without dereferencing a pointer to
the containing struct. `os/exec` returns boxed `*exec.Cmd`, so field access fails
before conversion of the field value. This also prevents accessing the exact
owned process handle for `.Kill` when implementing bounded subprocess shutdown.

Potential repair: safely dereference non-nil pointers before looking up exported
struct fields. Handle nil pointers, missing fields, non-struct receivers and
unexported fields without reflection panics. Add tests for the intended lookup
default and actual started-process handle; do not broaden this into new host
field syntax unless separately intended.

No let-go source was modified. The basic stdin/stdout duplex probe remains
valid; it proved only graceful close and wait. Attractor must not claim bounded
forced shutdown until a tested exact-process termination path exists. Avoid
process-name matching or killing unrelated Codex instances as a workaround.
