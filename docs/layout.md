# The layout

The living layout document: per host, its purposes, models, context, slots and load targets, each
figure citing its finding under `docs/findings/`. The answer task finalizes it.

## Hosts

What each host runs and serves. No placement is decided yet: "Serves now" is what the last task
left loaded, not a layout decision.

| Host | Stack | Engine and preset | Serves now | Parity | Finding |
| --- | --- | --- | --- | --- | --- |
| gb10-1 | DGX OS 7.6.0, kernel 7.0.0-1025-nvidia, driver 580.178.04, CUDA 13.0, Docker 29.6.2 | llama.cpp `server-cuda13-b12098`, spike-model-engines' shared preset at 2d7ae32 (its `role-split` branch, on the host's local `hosts` branch until it merges) | `gpt-oss-120b-MXFP4-agent-only` (c 1,179,648 over 16 slots, unified) | the reference GB10 | [hosts](findings/hosts.md): stack, sections A, B, D, E; [role-split](findings/role-split.md): stack, A, G |
| gb10-2 | as gb10-1 | as gb10-1 | `gemma-4-26B-A4B-it-qat-Q4_0-16-slots`, `gemma-4-E4B-it-Q8_0-16-slots` (16 slots of 8,192 each, prompt cache capped), granite-embedding | within run noise of gb10-1 on anchors A and B (means: A −1.37%, B −0.99% output tok/s); rechecked in role-split: A −0.85%, B −1.17% on B's repeat; cells compare across the two GB10s | [hosts](findings/hosts.md): stack, sections A, B, D, E; [role-split](findings/role-split.md): stack, A, B, G |
| framework | Omarchy, kernel 7.2.15-1-omarchy, Mesa 26.2.5, Docker 29.9.2 | llama.cpp `server-vulkan-b12098` (moved from b11960, no regression), the shared preset at 3b60fa4 (main) | set A, its Gemma prompt cache at the default | not compared with the GB10s | [hosts](findings/hosts.md): stack, sections A, B, C |

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
figures; and each arrangement's pool (K.1-K.3). The footprint table's computed figures assume the
Gemma sections' `cache-ram` capped at 0; the cap is in the GB10s' preset (2d7ae32), where set A
then held its floor under vision load (role-split, section C), and not yet in the Framework's.

| Host class | Set A idle | Set A warmed peak | Floor | Worked placement | Finding |
| --- | --- | --- | --- | --- | --- |
| GB10 | 21.45 GiB available (21.57 with the Gemma cap) | 17.23 GiB (with the cap, lowest under the full set's mixed load: 15.86 GiB) | 12.2 GiB | agent-only: 9 sessions of 131,072 tokens computed; loaded as c 1,179,648 over 16 slots, 1.39 GiB above the floor idle, 0.27 GiB at its lowest, holding 4 sessions of the 4-turn shape | [footprint](findings/footprint.md): I.3, I.7; [role-split](findings/role-split.md): G, I, K |
| Framework | 19.08 GiB available (GTT) | 18.08 GiB | 11.2 GiB | none yet | [footprint](findings/footprint.md): I.3 |
