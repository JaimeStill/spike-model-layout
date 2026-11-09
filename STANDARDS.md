# Standards

The judgement calls the check can't enforce, one line each, for the standards-reviewer. What
`mise run check` enforces is never restated here.

The architecture pages that apply, in the architecture repository:

- `principles/minimal-footprint.md`
- `principles/rolling-currency.md`
- `principles/validation-first.md`

## Tools

- A native feature comes first: on-demand loading uses llama.cpp's router; llama-swap only ever
  fronts a vLLM server, which loads no other model itself.
- vLLM runs in a container, never on bare metal.
- No Python is authored, and a mise task runs one script or one command.

## Scripts

- Only a step that must be idempotent is scripted, beside step helpers (`scripts/measure-lib.sh`)
  a session sources and calls one step at a time in the architect's view, each command logged
  with its time so the findings quote the log; a helper never runs a benchmark on its own.
- A host's engine or preset changes only through spike-model-engines' `host/`, by pull request.

## Docs

- A finding, `docs/findings/<task>.md`, says what was measured, when, on which engine version,
  host stack, and network path (`tailscale ping`), and stays dated.
- `docs/layout.md` is the one living layout document, updated in place as findings land; the
  answer task finalizes it, and every figure in it cites its finding.
- Raw run output stays untracked under `.state/`.
- Every command a session or the architect runs appears in its finding exactly as run.
- No tailnet or LAN identifier is committed: hosts go by short name, such as `gb10-2`.
