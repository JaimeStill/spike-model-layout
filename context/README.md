# spike-model-layout

spike-model-layout is where the workstations' three memory pools get their layout: which models
gb10-1, gb10-2 and the Framework each serve, at what context, and for how many concurrent
sessions. It measures each placement with GuideLLM in capped runs on all three hosts, weighs a
full set on one GB10 against splitting the roles across both GB10s, compares vLLM with llama.cpp,
and tunes the layout the architect chose: vLLM instances, one model each, across gb10-1 and
gb10-2, with the Framework as backup compute. It gives the layout v1.ai.hosting specifies as
evidence. The spike decides nothing itself.

The spike is the sub-goal `experiment.hosting.spike-model-layout` in the coordinator's roadmap,
`standards-lab/context/roadmap.toml`, where its tasks live. Its question is framed in
`standards-lab/context/ai-hosting.md`, under "Experiment: experiment.hosting", which holds the
experiment's rules and the answers of spike-model-hosting, spike-model-engines and
spike-hosting-upgrades.

## The question

How are models placed across the three workstations' memory pools to make the best use of memory,
and what context and how many concurrent sessions does each placed model hold?

## The evidence

1. Host parity: gb10-1 and gb10-2, on one stack, build and preset, serve anchors A and B within
   run noise of each other in one session, so cells across the two GB10s compare.
2. Memory per model per host class: weights, KV per 1,000 tokens of context, and compute
   buffers, loaded idle and at the warmed peak, on a GB10 and on the Framework; the capacity
   table each placement is computed from.
3. Context × sessions per placed model: the concurrent multi-turn sessions (agent) or requests
   (vision, audio, embedding) each placed model holds at its context, up to its knee or speed
   floor, by output tok/s, TTFT and inter-token latency, on llama.cpp, and on vLLM in containers
   with each model in its own process.
4. Full set against role split: set A on one GB10, against the roles split across both GB10s
   (one serves the agent model alone; the other serves vision, audio and embedding, with no
   agent), requests directed to a host by capability; the sessions and requests each holds, the
   speed per stream, and the memory each arrangement leaves.
5. The Framework's role: a second capability host beside gb10-2, chosen from item 4's findings
   over overflow for the full set or for the agent, serving vision, audio and embedding (set A's
   capped 4-slot 26B-A4B and E4B, and granite); what it holds per purpose, and what the split
   plus the Framework holds against the split alone, on llama.cpp, and on vLLM (ROCm) in
   containers with each model in its own process.
6. The agent model alone on vLLM v0.33.0, in a container, in two rows (BF16 KV at
   gpu-memory-utilization 0.80; FP8 KV at fixed bytes sized for 1,179,648 tokens), against
   llama.cpp's agent-only section on one GB10, in one session, at the agent's load target: speed,
   TTFT under multi-turn load, memory, and cold start.
7. The vLLM layout tuned: the agent row's KV dtype settled by an FP8-against-BF16 accuracy check;
   the capability pool's concurrency tuned across vision, audio and embedding together, with a
   strategy that keeps them from competing for compute; a lighter Gemma 4 vision model for the
   Framework's vLLM ROCm engine; v0.34 against v0.33.0; and the standing layout at the load
   targets.
8. Not pursued: two-node serving over QSFP. One model per instance across the GB10s replaces
   pooling them (the architect, 2026-11-12).
9. The layout: per host, its purposes, models, context, slots and load targets; what it needs from
   routing (session stickiness, overflow) and model management as requirements for
   spike-model-gateway; the host descriptors' purposes and load targets as requirements for the
   intake; and the items not pursued, on-demand loading and two-node serving, with their reasons.
   Our own agents and role sets under our own sessions stay with model-evaluation.

## Rules

The experiment's rules, in `ai-hosting.md`, govern every session. In short:

- **One new tool per task**, explained in its brief and walkthrough; at most four slices, the last
  a walkthrough the architect runs before the next task is planned.
- **Guided sessions.** Routine host steps that need no root the session runs itself over Tailscale
  SSH and records; root, a new tool's first walk, and the last slice's walkthrough are the
  architect's.
- **Benchmarks.** GuideLLM 0.8.1 from the laptop (`mise.bench.toml`), its multi-turn datasets
  standing in for agent sessions. Each run is agreed in its task's plan round and takes at most 10
  minutes unless the brief decides otherwise. Every run records the engine version, the host
  stack, and `tailscale ping`.
- **Comparisons.** Only cells run in the same session on the same versions are compared, with
  anchors A and B (`bench/`) rerun before any comparison across sessions or hosts.
- **Engines and presets.** Each host serves from spike-model-engines' engines suite and shared
  preset; this spike changes them only through pull requests to its `host/`. Native features come
  first, and vLLM runs in containers.
- **Routing** stays on paper: each workload targets its host directly, and what the layout needs
  from routing goes to spike-model-gateway as requirements.
- **Quantization floor** and **model origin**, as the experiment's rules state them.
- **Hosts.** gb10-1, gb10-2 and the Framework, each brought current at a session's start. Either
  GB10 may take either role, and the workstations change as the layout needs.

## Capabilities

- **Host bring-up:** all three hosts serve from spike-model-engines' engines suite and shared
  preset, and cells on gb10-1 and gb10-2 compare, [`docs/findings/hosts.md`](../docs/findings/hosts.md).
- **The footprint table:** each set A model's memory on a GB10 and on the Framework, and the
  capacity table placements are computed from, [`docs/findings/footprint.md`](../docs/findings/footprint.md).
- **Measured sessions and requests** per placed model, at its context,
  [`docs/findings/role-split.md`](../docs/findings/role-split.md), with the Framework's in
  [`docs/findings/framework.md`](../docs/findings/framework.md).
- **The full-set and role-split comparison** across the two GB10s,
  [`docs/findings/role-split.md`](../docs/findings/role-split.md).
- **The Framework's placement** in the layout, as a second capability host beside gb10-2 serving
  vision, audio and embedding, [`docs/findings/framework.md`](../docs/findings/framework.md).
- **The vLLM agent comparison** against llama.cpp on gb10-1,
  [`docs/findings/agent-vllm.md`](../docs/findings/agent-vllm.md).
- **The vLLM capability comparison** against llama.cpp on gb10-2 and the Framework: vision, audio
  and embedding, each in its own process,
  [`docs/findings/capability-vllm.md`](../docs/findings/capability-vllm.md).
- **On-demand serving** through llama.cpp's router: not pursued, since GPU compute, not memory, is
  the bottleneck (the architect, 2026-11-12).
- **Two-node serving** over QSFP with vLLM and Ray: not pursued, since one model per vLLM instance
  across the GB10s replaces pooling them (the architect, 2026-11-12).
- **The layout document:** [`docs/layout.md`](../docs/layout.md), living, finalized by the answer.
- **The step helpers:** `scripts/measure-lib.sh`, adapted from spike-hosting-upgrades' without its
  tier and conform helpers, sourced and called one step at a time, logging every command to this
  spike's `.state/measure/<host>/`. The read-only `footprint` helper prints each llama-server
  process's memory, the pool, and the router's buffer lines. Sourced for port 8000, 8001 or 8002,
  `footprint` and `readout` read the vLLM container that publishes that port instead
  (`MEASURE_ENGINE` and `MEASURE_CONTAINER` override the choice): `footprint` prints its
  processes' memory, the pool, and the start log's sizing lines, and `readout` prints vLLM's
  `/metrics` and counts the server log's errors. On an amdgpu host vLLM's `footprint` prints each
  process's GTT and RSS, the helpers read system memory beside GTT, and `watch` refuses to start
  without the system-memory floor (`MEASURE_SYSTEM_FLOOR_GIB`) and stops a cell under either floor.
- **The result readers:** `bench/levels.jq` turns GuideLLM's result JSON into per-level tables
  judged against each purpose's floor, `bench/srvtimes.awk` with `bench/stats.awk` reads each
  request's server timings from the router log, and `bench/capacity.jq` with `bench/readouts.awk`
  reads the vLLM capacity cell, [`bench/README.md`](../bench/README.md).

## Path

The tasks, in the order they run; each cites the evidence it proves. Each benchmark's cells, caps
and load targets are agreed in its task's own plan round.

1. `hosts`: gb10-2 onto spike-model-engines' engines suite and shared preset (spike-ai-pipeline's
   vision keys carried in by pull request), all three hosts current, and anchors A and B on both
   GB10s in one session (evidence 1).
2. `footprint`: memory per model on a GB10 and on the Framework, and the capacity table
   (evidence 2).
3. `role-split`: set A on one GB10, then the roles split across both GB10s, compared in one
   session (evidence 3, 4). A pull request to spike-model-engines' `host/` first caps llama.cpp's
   host prompt cache (`cache-ram`) on set A's two Gemma sections, whose 8192 MiB default took
   gb10-1 under its floor under vision load (the footprint finding, section K).
4. `framework`: the Framework as a second capability host beside gb10-2, serving set A's capped
   26B-A4B and E4B and granite, against the split alone in one session (evidence 3, 5).
5. `agent-vllm`: gpt-oss-120b on vLLM v0.33.0 in a container, in two rows (BF16 KV at 0.80; FP8
   KV at fixed bytes sized for 1,179,648 tokens), against llama.cpp's agent-only section on
   gb10-1, in one session (evidence 6).
6. `capability-vllm`: vision (Gemma 4 26B-A4B), audio (E4B) and embedding (granite) on vLLM
   v0.33.0 in containers, each in its own process, alone and together, on gb10-2 and on the
   Framework (vLLM ROCm), against llama.cpp's sections rerun in the same session; a pull request
   to spike-model-engines' `host/` first gives each row its own container, port and memory fraction
   (evidence 3, 5, beside 6).
7. `vllm-layout`: vLLM instances, one model each, across gb10-1 and gb10-2, with the Framework as
   backup compute, tuned and measured at the load targets, with the FP8-against-BF16 accuracy
   check as the task's one new tool; the hosts end on that layout, with llama.cpp removed from the
   workstations. Then the answer: `docs/layout.md` finalized, the routing and model-management
   requirements for spike-model-gateway, README "The answer", and the answer section in
   `ai-hosting.md` (evidence 7, 9). It may take up to five slices, the last a walkthrough: the
   one exception to the rules' four.

## References

The spike reads these repositories and never writes to them, with one exception:
experiment.hosting owns spike-model-engines while the experiment runs, so this spike lists it in
its repos and changes its `host/` (scripts and presets) through pull requests, each citing the
finding behind it. Each is a key in the coordinator's `references.toml`, with its local checkout
in `references.local.toml`:

- `spike-model-engines`: the `engines` suite, the shared preset, the engine guides, and anchors A
  and B with their last readings.
- `spike-model-hosting`: the memory budget, the slot sweep, the pool document, and the footprint
  and model-card methods.
- `spike-hosting-upgrades`: the host descriptors and their load targets, the dated reports and
  screens, the blocker register, and the step helpers.
- `personal-agents`: the context-sizing and memory-footprint references.
- `dotfiles`: the GB10 host-stack setup and the QSFP record.
- `spike-ai-pipeline`: gb10-2's former preset and `llama.env`, read only.
