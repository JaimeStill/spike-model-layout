# spike-model-layout

spike-model-layout is where the workstations' three memory pools get their layout: which models
gb10-1, gb10-2 and the Framework each serve, at what context, for how many concurrent sessions,
and which load on demand rather than stay resident. It measures each placement with GuideLLM in
capped runs on all three hosts, weighs a full set on one GB10 against splitting the roles across
both GB10s, measures one model served across both GB10s over QSFP, and gives the layout
v1.ai.hosting specifies as evidence. The spike decides nothing itself.

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
   floor, by output tok/s, TTFT and inter-token latency.
4. Full set against role split: set A on one GB10, against the roles split across both GB10s
   (one serves the agent model alone; the other serves vision, audio and embedding, with no
   agent), requests directed to a host by capability; the sessions and requests each holds, the
   speed per stream, and the memory each arrangement leaves.
5. The Framework's role: where it relieves the most pressure, chosen from item 4's findings
   (overflow for the full set, overflow for the agent, or capability host, noting Gemma 4
   26B-A4B's Vulkan abort with several slots), measured in that role.
6. The agent model alone on vLLM, in a container, against llama.cpp on one GB10, in one session,
   at the agent's load target: speed, TTFT under multi-turn load, memory, and cold start.
7. On demand against resident: each model's cold load and first-request latency through
   llama.cpp's router, against the memory it frees, and which purposes can load on demand.
8. Two-node serving over QSFP: gpt-oss-120b across both GB10s (vLLM with Ray, in containers)
   against one node, in one session; it weighs the candidate layout of both GB10s pooled for the
   agent with the Framework serving the capability models.
9. The layout: per host, its purposes, models, context, slots and load targets; what it needs from
   routing (session stickiness, overflow) as requirements for spike-model-gateway; and the host
   descriptors' purposes and load targets as requirements for the intake. Our own agents and role
   sets under our own sessions stay with model-evaluation.

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
  [`docs/findings/role-split.md`](../docs/findings/role-split.md).
- **The full-set and role-split comparison** across the two GB10s,
  [`docs/findings/role-split.md`](../docs/findings/role-split.md).
- **The Framework's placement** in the layout.
- **The vLLM agent comparison** against llama.cpp.
- **On-demand serving** through llama.cpp's router.
- **Two-node serving** over QSFP with vLLM and Ray.
- **The layout document:** [`docs/layout.md`](../docs/layout.md), living, finalized by the answer.
- **The step helpers:** `scripts/measure-lib.sh`, adapted from spike-hosting-upgrades' without its
  tier and conform helpers, sourced and called one step at a time, logging every command to this
  spike's `.state/measure/<host>/`. The read-only `footprint` helper prints each llama-server
  process's memory, the pool, and the router's buffer lines.
- **The result readers:** `bench/levels.jq` turns GuideLLM's result JSON into per-level tables
  judged against each purpose's floor, and `bench/srvtimes.awk` with `bench/stats.awk` reads each
  request's server timings from the router log, [`bench/README.md`](../bench/README.md).

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
4. `framework`: the Framework in the role the role-split findings point to (evidence 3, 5).
5. `agent-vllm`: gpt-oss-120b on vLLM v0.33.0 in a container against llama.cpp on the agent GB10,
   in one session (evidence 6).
6. `on-demand`: llama.cpp's router loading models on demand against keeping them resident, on
   each host (evidence 7).
7. `two-node`: gpt-oss-120b across both GB10s over QSFP with vLLM and Ray, against one node; Ray
   is the task's one new tool (evidence 8).
8. `answer`: `docs/layout.md` finalized, the routing requirements for spike-model-gateway, README
   "The answer", and the answer section in `ai-hosting.md` (evidence 9).

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
