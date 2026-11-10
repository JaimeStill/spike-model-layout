# The layout

The living layout document: per host, its purposes, models, context, slots and load targets, each
figure citing its finding under `docs/findings/`. The answer task finalizes it.

## Hosts

What each host runs and serves. No placement is decided yet: "Serves now" is what the last task
left loaded, not a layout decision.

| Host | Stack | Engine and preset | Serves now | Parity | Finding |
| --- | --- | --- | --- | --- | --- |
| gb10-1 | DGX OS 7.6.0, kernel 7.0.0-1025-nvidia, driver 580.178.04, CUDA 13.0, Docker 29.6.2 | llama.cpp `server-cuda13-b12098`, spike-model-engines' shared preset on `main` at 21b5e8c (role-split's change, 2d7ae32, merged) | `gpt-oss-120b-MXFP4-agent-only` (c 1,179,648 over 16 slots, unified): the agent | the reference GB10 | [hosts](findings/hosts.md): stack, sections A, B, D, E; [role-split](findings/role-split.md): stack, A, G; [framework](findings/framework.md): stack, D |
| gb10-2 | as gb10-1 | as gb10-1 | `gemma-4-26B-A4B-it-qat-Q4_0-16-slots`, `gemma-4-E4B-it-Q8_0-16-slots` (16 slots of 8,192 each, prompt cache capped), granite-embedding: vision, audio and embedding | within run noise of gb10-1 on anchors A and B (means: A −1.37%, B −0.99% output tok/s); rechecked in role-split: A −0.85%, B −1.17% on B's repeat; cells compare across the two GB10s | [hosts](findings/hosts.md): stack, sections A, B, D, E; [role-split](findings/role-split.md): stack, A, B, G; [framework](findings/framework.md): stack, D |
| framework | Omarchy, kernel 7.2.15-1-omarchy, Mesa and vulkan-radeon 26.2.5, linux-firmware 20260916, Docker 29.9.2 | llama.cpp `server-vulkan-b12098` (moved from b11960, no regression), the shared preset on `main` at 21b5e8c | set A's `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` and `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` (4 slots of 8,192 each, prompt cache capped) and granite-embedding (16 slots of 8,192): a second capability host beside gb10-2, serving vision, audio and embedding; gpt-oss unloaded | not compared with the GB10s; anchors against its own R3 and R4: A +1.07%, B +2.46% output tok/s, within its across-days 2.8% | [hosts](findings/hosts.md): stack, sections A, B, C; [footprint](findings/footprint.md): C, G, I; [framework](findings/framework.md): stack, A, C, E |

### Roles measured on the GB10s

The table gives the two arrangements the [role-split finding](findings/role-split.md) compared
(sections I, J and K.3). "Holds" is the most sessions or requests meeting the purpose's floor
(agent ITL ≤100 ms, vision ≤10 s an image question, audio RTFx ≥5, embedding ≥4,300 prompt tok/s)
at or below its knee, with one purpose loaded at a time.

| Arrangement | Host | Role | Holds, each purpose alone | At the load targets, all at once | Pool idle / lowest under load (floor 12.2 GiB) |
| --- | --- | --- | --- | --- | --- |
| Full set | one GB10 (measured on gb10-2) | set A, Gemma capped: agent, vision, audio, embedding | agent 3 sessions, vision 2, audio 3, embedding 16 streams | embedding only meets (agent ITL 237.67 ms) | 21.57 / 15.86 GiB |
| Split | gb10-1 | agent only | agent 4 sessions (8 miss at ITL 109.63 ms) | agent meets (ITL 50.76 ms) | 13.59 / 12.47 GiB |
| Split | gb10-2 | vision, audio, embedding | vision 1, audio 1; embedding meets at 16 in every mixed cell | embedding meets; vision (38.90 s) and audio (RTFx 0.98) miss | 77.40 / 68.69 GiB |

Agent sessions are the 4-turn shape, at most 11,776 tokens; 131,072-token sessions stay computed.

Production clients sit on the same direct network as the GPUs, so the layout is sized on LAN
figures. The full set ran with its client on the LAN. The split ran from the laptop over a
Tailscale relay: its client-side figures (vision latency, audio RTFx, TTFT) are pessimistic, and its
server-side figures (ITL, memory) are unaffected ([role-split](findings/role-split.md), "Stack,
engine and network path" and L.7).

### The Framework as a second capability host

The [framework finding](findings/framework.md) measured the Framework in the role the framework
plan round chose from role-split's findings: a second capability host beside gb10-2, serving
vision, audio and embedding, so each capability purpose has two hosts (sections F, G and J). It
reran the split as the baseline in the same session. Every run was direct on the LAN, so these are
LAN figures.

| Arrangement | Host | Role | Holds, each purpose alone | At the load targets, all at once (combined) | At the held levels, all at once (combined) | Lowest under load (floors) |
| --- | --- | --- | --- | --- | --- | --- |
| Split (baseline) | gb10-1 | agent only | (role-split: 4 sessions) | agent 4 of 4 (ITL 55.55 ms) | agent 4 of 4 (ITL 50.79 ms) | 12.72 GiB at the targets, 12.56 at the held levels (12.2) |
| Split (baseline) | gb10-2 | vision, audio, embedding | (role-split: vision 1, audio 1) | vision 0 of 4 (37.04 s); audio 0 of 4 (RTFx 0.98); embedding 16 of 16 (12,321 tok/s) | vision 0 of 1 (14.43 s); audio 0 of 1 (RTFx 2.68); embedding 16 (14,770 tok/s) | 69.11 GiB (12.2) |
| Split plus the Framework | gb10-1 | agent only | – | agent 4 of 4 (ITL 49.82 ms) | agent 4 of 4 (ITL 50.71 ms) | 12.51 GiB at the targets, 12.50 at the held levels (12.2) |
| Split plus the Framework | gb10-2 and framework | vision, audio, embedding, streams split evenly | framework: vision 1, audio 2, embedding 16 streams | vision 0 of 4 (2 + 2: 21.54 and 19.37 s); audio 0 of 4 (RTFx 1.65 and 1.68); embedding 16 of 16 (25,644 tok/s) | vision 0 of 2 (13.89 and 11.94 s); audio 0 of 2 (RTFx 2.82 and 4.03); embedding 16 (27,711 tok/s) | gb10-2 69.12 GiB (12.2); framework 82.27 GiB GTT (11.2), 84.25 GiB system (12.5) |

The second capability host about doubles embedding's throughput and holds neither vision nor audio
at the target or at 1 stream a host. On the Framework, vision alone at 1 stream met its floor
(6.82 s) and audio alone did (RTFx 8.81); beside each other and embedding they missed (11.94 s,
RTFx 4.03), with over 80 GiB free on both of the Framework's pools (framework finding, J and
L.1). Two capability hosts hold at most 2 vision requests with nothing else running, against a
load target of 4.

## Sizing

Every placement is sized from the capacity table in the
[footprint finding](findings/footprint.md), section I: each set A model's buffers, KV per
1,000 tokens and per slot, and its idle, warmed-peak and under-load figures on each host class
(I.1, I.2); each host's ceiling, floor and base use (I.3); the computed largest c and
131,072-token sessions above the floor, alone and beside set A (I.4); the 26B-A4B's Vulkan
constraint (I.5); and input token costs (I.6). Beside it, the
[role-split finding](findings/role-split.md), section K, adds measured rows: the agent-only
section's unified compute (1316.68 / 1249.18 MiB) and pool at c 1,179,648; the Gemma compute at
16 slots, equal to its 4-slot figures; the capped Gemma sections' idle, warmed and under-load
figures; and each arrangement's pool (K.1-K.3). The [framework finding](findings/framework.md),
section K, adds the Framework's measured rows with the Gemma cap: its buffers unchanged by the cap
keys, the capped sections' idle, warmed and highest figures on Vulkan (the 26B-A4B's RSS grew
1,252 MiB at most, against footprint's uncapped 239 → 9,867), and the capability arrangement's
GTT and system-memory pools. The footprint table's computed figures assume the Gemma sections'
`cache-ram` capped at 0; the cap is in the shared preset on all three hosts (21b5e8c), where set A
held a GB10's floor under vision load (role-split, section C) and the Framework's system memory
stayed above its own floor (framework, K.4). The Framework's 26B-A4B stays at 4 slots: past 4 on
Vulkan it is untested, since the fix (#25584) is in no build and more slots add no vision
throughput (framework, K.4).

| Host class | Set A idle | Set A warmed peak | Floor | Worked placement | Finding |
| --- | --- | --- | --- | --- | --- |
| GB10 | 21.45 GiB available (21.57 with the Gemma cap) | 17.23 GiB (with the cap, lowest under the full set's mixed load: 15.86 GiB) | 12.2 GiB | agent-only: 9 sessions of 131,072 tokens computed; loaded as c 1,179,648 over 16 slots, 1.39 GiB above the floor idle, 0.27 GiB at its lowest in role-split and 0.30 GiB in the framework task, holding 4 sessions of the 4-turn shape | [footprint](findings/footprint.md): I.3, I.7; [role-split](findings/role-split.md): G, I, K; [framework](findings/framework.md): D, H |
| Framework | 19.08 GiB available (GTT) | 18.08 GiB | 11.2 GiB GTT; 12.5 GiB system memory | capability host, measured: capped 26B-A4B and E4B (4 × 8,192) and granite (16 × 8,192), 83.00 GiB GTT and 87.13 GiB system memory available idle, 82.27 and 84.25 GiB at their lowest; holds vision 1, audio 2, embedding 16 alone | [footprint](findings/footprint.md): I.3; [framework](findings/framework.md): E, F, K |
