# The layout

The layout the architect chose for the three workstations, as it stands after the vllm-layout
task: per host its purposes, models, rows, context, sequences, fractions and load targets, each
figure citing its finding under `docs/findings/`. The spike decides nothing; the architect chose
each placement, and the findings are its evidence. Then what the layout needs from routing and
model management (spike-model-gateway), what it needs from the host descriptors (the intake), and
what was not pursued. The measured arrangements that led here follow, in "How the layout was
reached".

## The layout

Each host serves vLLM v0.33.0 in containers, one model an instance, from spike-model-engines'
`host/vllm-rows` at 8f981ee ([vllm-layout](findings/vllm-layout.md), "Stack, engine and network
path", B). Every row is `--restart unless-stopped` and comes back by itself after a reboot (I).
llama.cpp is gone from all three hosts (H). Each purpose has one host, and there is no failover:
the architect's choice, which dropped the Framework's staged vision and audio failover rows
(vllm-layout, M), so a down host fails its purpose visibly until it returns.

| Host | Purpose | Model | Row (container, port) | Fraction | Sequences (max-num-seqs) | Context a sequence | Load target | Measured, alone on its host | Measured, the standing cell (all three hosts at once) | Pool idle / lowest in the standing cell (floor) | Finding |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-1 | agent | OpenAI's gpt-oss-120b, native MXFP4; FP8 (e4m3) KV, uncalibrated | `gpt-oss-120b-agent-fp8` (`vllm`, 8000) | 0.80, the KV cache sized at 32,993,476,982 bytes: 1,733,910 tokens | 12 | 131,072 tokens | 4 sessions | 4: ITL 49.13 ms; 12: 99.07 ms, meets | 4: ITL 48.13 ms, meets | 15.07 / 14.87 GiB (12.2) | [vllm-layout](findings/vllm-layout.md): C, D, J, K |
| gb10-2 | vision | Gemma 4 26B-A4B, NVIDIA's NVFP4; BF16 KV | `gemma-4-26B-A4B-NVFP4-vision-gb10` (`vllm-vision`, 8000) | 0.40: 165,213 tokens of KV | 16 | 8,192 tokens | 4 requests | 4: 4.68 s; 16: 9.64 s, meets | 4: 4.49 s, meets | 66.73 / 65.21 GiB (12.2) | [vllm-layout](findings/vllm-layout.md): E.2, E.5, E.7, J, K |
| framework | audio | Gemma 4 E4B, BF16; BF16 KV; the audio image | `gemma-4-E4B-it-audio-framework` (`vllm-audio`, 8001) | 0.18: 106,065 tokens of KV | 4 | 8,192 tokens | 4 requests | 4: RTFx 6.54; beside embedding at 34 req/s 5.84, meets; 8 beside it 4.94, misses | 4: RTFx 5.78, meets | GTT 90.78 / 90.24 GiB (11.2); system 89.44 / 87.27 GiB (12.5) | [vllm-layout](findings/vllm-layout.md): F.4, F.5, F.6, J, K |
| framework | embedding | IBM's granite-embedding-english-r2, BF16 | `granite-embedding-english-r2-framework` (`vllm-embed`, 8002) | 0.03; pooling, no KV pool | 128, with 65,536 batched tokens a step | 8,192 tokens | 16 streams; admitted at ≤34 requests a second | knee at 16 streams, 98,325 prompt tok/s; holds to 128 | 34 req/s: 17,442 prompt tok/s, meets | as audio | [vllm-layout](findings/vllm-layout.md): F.2, F.4, J |

The floors: agent ITL median ≤100 ms; vision request latency median ≤10 s an image question;
audio RTFx median ≥5; embedding ≥4,300 prompt tok/s. Every figure is a LAN figure: production
clients sit on the same direct network as the GPUs, and every vllm-layout run went direct
(vllm-layout, "Stack, engine and network path").

**Capacity against the targets.** The agent row holds 12 sessions at its floor, 3 times its
target; vision 16 requests, 4 times; audio exactly its target of 4, beside embedding at the
gateway's rate; embedding at that rate runs 4.06 times its floor (c), and alone it reaches about
23 times (vllm-layout, D, E.5, F.2, F.5). On each host the rows hold what their cells met the
floors at, so a request past a row's cap queues in vLLM rather than slowing the running ones.

**Why each purpose is where it is.** Every miss measured in this spike was two purposes sharing
one GPU's compute and bandwidth, never memory ([capability-vllm](findings/capability-vllm.md),
N.1; vllm-layout, E.6, F.3). So the layout gives each heavy purpose a GPU of its own:

- **gb10-1, the agent alone.** The FP8 KV row met the agent's floor through 12 sessions, against
  BF16's 8 ([agent-vllm](findings/agent-vllm.md), F), and the accuracy check found no significant
  loss against BF16 at 95% on GPQA diamond or RULER's needle at 32,768 and 65,536 tokens
  (vllm-layout, C.4), so FP8 is the row. The test can't exclude a loss of up to about 10 points
  on GPQA (C.5).
- **gb10-2, vision alone.** Beside vision, audio missed its floor at every pair level from 2 + 2
  to 8 + 8 streams (RTFx 2.86 to 3.36) while vision met its own at every pair but 8 + 8; alone,
  vision holds 16 (vllm-layout, E.3 to E.6). NVIDIA's NVFP4 checkpoint showed no significant loss
  against Google's BF16 on mmmu_val (0.6111 against 0.6178, p 0.68), CUDA against ROCm a limit
  (G).
- **The Framework, audio and embedding.** Audio missed beside embedding run flat out at 16
  streams (RTFx 2.44) and held beside it at a steady 8.4 and 34 requests a second (6.43, 5.84), so
  the gateway rate-limits embedding to 34; at 8 streams beside that rate audio missed by 0.06, so
  its cap is 4 (vllm-layout, F.3 to F.5). The two rows take 0.21 of the 112 GiB GTT ceiling (c),
  where capability-vllm's three rows took 0.81 and left the system pool 0.76 GiB above its floor
  ([capability-vllm](findings/capability-vllm.md), K).

**Starts and reboots.** After one reboot each: gb10-2's vision row served 193.2 s after its
container started, gb10-1's agent row 502.5 s, the Framework's granite 22.8 s and audio 68.7 s
(c) (vllm-layout, I.3). The GB10s return unattended. The Framework's root is LUKS-encrypted, so
it returns only after a person enters the passphrase at its console, and can't be rebooted
remotely (I.4). A row that compiles afresh starts slower, and the agent row's compiling start
dipped 0.81 GiB under gb10-1's floor (C.7, N.4).

### Hosts

| Host | Stack | Engine | Serves | Clone | Finding |
| --- | --- | --- | --- | --- | --- |
| gb10-1 | DGX OS 7.6.0, kernel 7.0.0-1025-nvidia, driver 580.178.04, CUDA 13.0, Docker 29.6.2 | vLLM v0.33.0, `vllm/vllm-openai:v0.33.0` | the agent row; the store holds `openai/gpt-oss-120b` alone | spike-model-engines on a local `hosts` branch at 8f981ee, before merge | [vllm-layout](findings/vllm-layout.md): stack, B, H, I |
| gb10-2 | as gb10-1 | as gb10-1 | the vision row; the store holds `nvidia/Gemma-4-26B-A4B-NVFP4` alone | as gb10-1 | [vllm-layout](findings/vllm-layout.md): stack, B, H, I |
| framework | Omarchy, kernel 7.2.15-1-omarchy, Mesa 26.2.5, linux-firmware 20260916, Docker 29.9.2; GTT 112 GiB through `ttm.pages_limit` alone, the deprecated gttsize option removed | vLLM v0.33.0, ROCm 10.0, `vllm/vllm-openai-rocm:v0.33.0`; the audio row on the built audio image | the audio and embedding rows; the store holds E4B and granite | as gb10-1 | [vllm-layout](findings/vllm-layout.md): stack, B, H, I |

gb10-1 and gb10-2 run anchors A and B within run noise of each other, so cells compare across the
two GB10s ([hosts](findings/hosts.md), D; [role-split](findings/role-split.md), A). vLLM v0.34.0
was not released at the task's start, so every host stays on v0.33.0 (vllm-layout, A.2).

## Requirements for spike-model-gateway

What the layout needs from routing and model management. Each requirement cites the figure behind
it.

1. **Admission on the engines' live signals, per purpose floor.** The gateway admits a request to
   a row on that row's live latency and queue (vLLM's `/metrics`: requests running and waiting,
   time to first token, inter-token latency, end-to-end latency), judged against the purpose's
   floor, not on free memory. gb10-2 missed vision with about 19 GiB free above its floor, and
   missed audio beside vision with 23 GiB free ([capability-vllm](findings/capability-vllm.md),
   H, accept decision; [vllm-layout](findings/vllm-layout.md), E.6).
2. **Queueing past each row's cap.** Each row serves at most the sequences it met its floor at:
   agent 12, vision 16, audio 4, embedding 128 (vllm-layout, D, E.5, F.5, F.2). The gateway queues
   what a row can't take, and holds a session's turns on the agent row's host (session stickiness,
   one host serves the agent).
3. **Embedding rate-limited to ≤34 requests a second** (512-token inputs, about 17,442 prompt
   tok/s, 4.06 times the floor, c), so audio keeps its floor on the shared Framework: at 34 audio
   held RTFx 5.84 at 4 streams, and beside granite unlimited at 16 streams it fell to 2.44
   (vllm-layout, F.3, F.4). Requests past the rate queue or overflow; a burst is not admitted at
   once.
4. **Overflow to cloud models.** Past a purpose's queue limit, or while its host is down, the
   gateway sends the request to the production cloud models (Azure AI Foundry), since no
   workstation purpose has a second host. Audio has no headroom above its target of 4 (vllm-layout,
   N.2).
5. **Model management only through the gateway, never a serving API.** A client that can change
   a workstation's models through the serving API is a vulnerability (the architect, 2026-11-12);
   the rows start from `host/engines` on the host, and the gateway is the single secure point that
   manages them (spike-model-engines' answer in the coordinator's `ai-hosting.md`, its requirement
   "Model management separated from inference and held by an admin").
6. **No failover.** Each purpose has one host, by the architect's choice, so a down host fails its
   purpose visibly: the gateway reports it and overflows, and never routes vision or audio to a
   host without that row (vllm-layout, M).
7. **The Framework needs a person at its console after any reboot.** It returns only after its
   LUKS passphrase is entered there; the gateway treats it as down until its rows answer
   `/health` (vllm-layout, I.4). The GB10s return unattended in 3 min 49 s (gb10-2) and 8 min
   58 s (gb10-1) from the reboot (c) (I.3).

## Requirements for the intake: the host descriptors

spike-hosting-upgrades' host descriptors (`docs/hosts/gb10-1.md`, `docs/hosts/framework.md`) list
each host's purposes and load targets from llama.cpp's set A, each host serving all four
purposes. The layout changes them; as requirements for the intake:

- **gb10-1** serves the agent alone: 4 concurrent sessions of up to 131,072 tokens each, on
  `gpt-oss-120b-agent-fp8` (12 at most), in place of set A's 4 sessions sharing one 131,072-token
  pool. Vision, audio and embedding leave its descriptor.
- **gb10-2** has no descriptor; it needs one: vision alone, 4 concurrent requests of 8,192 tokens
  (16 at most), on `gemma-4-26B-A4B-NVFP4-vision-gb10`, with this spike's run noise as its first
  figure (goal record, pending edits).
- **The Framework** serves audio and embedding: audio 4 concurrent requests of 8,192 tokens (4 at
  most); embedding 16 concurrent requests of 8,192 tokens, admitted at up to 34 requests a second.
  The agent and vision leave its descriptor. Its OS and configuration: GTT 112 GiB through
  `ttm.pages_limit`, the gttsize option removed, a 512 MiB VRAM carve-out, Omarchy kept, and a
  LUKS root that needs its console after a reboot (vllm-layout, I.2, I.4).
- Each descriptor names vLLM v0.33.0 and its rows in place of llama.cpp b12098 and set A's
  sections; llama.cpp is no longer on any workstation (vllm-layout, H).

## Not pursued

- **On-demand loading.** The capabilities are designated and their memory layouts essentially
  settled; GPU compute, not memory, is the bottleneck, and loading and unloading add compute on top
  of inference (the architect, 2026-11-12; goal record, the plan's decisions). Every row stands
  loaded.
- **Two-node serving** over QSFP with vLLM and Ray. vLLM instances, one model each, spread across
  gb10-1 and gb10-2 replace pooling the GB10s for the agent (the architect, 2026-11-12). The agent
  holds 12 sessions of 131,072 tokens on gb10-1 alone (vllm-layout, D).
- **Redundancy and failover.** The Framework's staged vision (Gemma 4 12B QAT w4a16) and audio
  failover rows were dropped when audio moved to the Framework and gb10-2 took vision alone
  (vllm-layout, M); the 12B was never measured (G.3).
- **CUDA MPS and other concurrency tools.** Placement and vLLM's own per-row limits keep the
  purposes apart (goal record, the plan's decisions).

## How the layout was reached

The sections below are the arrangements the earlier tasks measured, kept as the evidence the
layout rests on. Each describes its own task's hosts and engines, not the standing layout above.

### Hosts as the capability-vllm task left them

| Host | Stack | Engine and preset | Served then | Parity | Finding |
| --- | --- | --- | --- | --- | --- |
| gb10-1 | DGX OS 7.6.0, kernel 7.0.0-1025-nvidia, driver 580.178.04, CUDA 13.0, Docker 29.6.2 | llama.cpp `server-cuda13-b12098`, spike-model-engines' shared preset (role-split's change, 2d7ae32, merged); its clone on `main` at a294e4e, agent-vllm's `host/` change merged: vLLM v0.33.0 (`vllm/vllm-openai:v0.33.0`) and the rows `gpt-oss-120b-agent` and `gpt-oss-120b-agent-fp8`, the `vllm` container stopped on the FP8 row | `gpt-oss-120b-MXFP4-agent-only` (c 1,179,648 over 16 slots, unified): the agent | the reference GB10 | [hosts](findings/hosts.md): stack, sections A, B, D, E; [role-split](findings/role-split.md): stack, A, G; [framework](findings/framework.md): stack, D; [agent-vllm](findings/agent-vllm.md): stack, A, C; [capability-vllm](findings/capability-vllm.md): stack |
| gb10-2 | as gb10-1 | llama.cpp `server-cuda13-b12098`, the shared preset; its clone on a local `hosts` branch at bb68cbd, capability-vllm's `host/` change before merge (measured at 4ad76e6; bb68cbd adds a comment): vLLM v0.33.0 (`vllm/vllm-openai:v0.33.0`) and three capability rows, each its own container and port (`vllm-vision` 8000, `vllm-audio` 8001, `vllm-embed` 8002), the containers stopped | `gemma-4-26B-A4B-it-qat-Q4_0-16-slots`, `gemma-4-E4B-it-Q8_0-16-slots` (16 slots of 8,192 each, prompt cache capped), granite-embedding: vision, audio and embedding | within run noise of gb10-1 on anchors A and B (means: A −1.37%, B −0.99% output tok/s); rechecked in role-split: A −0.85%, B −1.17% on B's repeat; cells compare across the two GB10s | [hosts](findings/hosts.md): stack, sections A, B, D, E; [role-split](findings/role-split.md): stack, A, B, G; [framework](findings/framework.md): stack, D; [capability-vllm](findings/capability-vllm.md): stack, A, D |
| framework | Omarchy, kernel 7.2.15-1-omarchy, Mesa and vulkan-radeon 26.2.5, linux-firmware 20260916, Docker 29.9.2 | llama.cpp `server-vulkan-b12098` (moved from b11960, no regression), the shared preset; its clone on a local `hosts` branch at bb68cbd, as gb10-2's: vLLM v0.33.0's ROCm 10.0 image (`vllm/vllm-openai-rocm:v0.33.0`, `-rocm72` staged as the fallback), the rebuilt audio image, and three capability rows on 8000, 8001 and 8002, the containers stopped | set A's `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` and `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` (4 slots of 8,192 each, prompt cache capped) and granite-embedding (16 slots of 8,192): a second capability host beside gb10-2, serving vision, audio and embedding; gpt-oss unloaded | not compared with the GB10s; anchors against its own R3 and R4: A +1.07%, B +2.46% output tok/s, within its across-days 2.8% | [hosts](findings/hosts.md): stack, sections A, B, C; [footprint](findings/footprint.md): C, G, I; [framework](findings/framework.md): stack, A, C, E; [capability-vllm](findings/capability-vllm.md): stack, A, D, M |

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

The [framework finding](findings/framework.md) measured the Framework in the role chosen from
role-split's findings: a second capability host beside gb10-2, serving vision, audio and
embedding, so each capability purpose has two hosts (sections F, G and J). It reran the split as
the baseline in the same session. Every run was direct on the LAN, so these are LAN figures.

| Arrangement | Host | Role | Holds, each purpose alone | At the load targets, all at once (combined) | At the held levels, all at once (combined) | Lowest under load (floors) |
| --- | --- | --- | --- | --- | --- | --- |
| Split (baseline) | gb10-1 | agent only | (role-split: 4 sessions) | agent 4 of 4 (ITL 55.55 ms) | agent 4 of 4 (ITL 50.79 ms) | 12.72 GiB at the targets, 12.56 at the held levels (12.2) |
| Split (baseline) | gb10-2 | vision, audio, embedding | (role-split: vision 1, audio 1) | vision 0 of 4 (37.04 s); audio 0 of 4 (RTFx 0.98); embedding 16 of 16 (12,321 tok/s) | vision 0 of 1 (14.43 s); audio 0 of 1 (RTFx 2.68); embedding 16 (14,770 tok/s) | 69.11 GiB (12.2) |
| Split plus the Framework | gb10-1 | agent only | – | agent 4 of 4 (ITL 49.82 ms) | agent 4 of 4 (ITL 50.71 ms) | 12.51 GiB at the targets, 12.50 at the held levels (12.2) |
| Split plus the Framework | gb10-2 and framework | vision, audio, embedding, streams split evenly | framework: vision 1, audio 2, embedding 16 streams | vision 0 of 4 (2 + 2: 21.54 and 19.37 s); audio 0 of 4 (RTFx 1.65 and 1.68); embedding 16 of 16 (25,644 tok/s) | vision 0 of 2 (13.89 and 11.94 s); audio 0 of 2 (RTFx 2.82 and 4.03); embedding 16 (27,711 tok/s) | gb10-2 69.12 GiB (12.2); framework 82.27 GiB GTT (11.2), 84.25 GiB system (12.5) |

The second capability host about doubles embedding's throughput, and the two hosts together hold
neither vision nor audio at the target or at 1 stream a host. On the Framework, vision alone at 1 stream met its floor
(6.82 s) and audio alone did (RTFx 8.81); beside each other and embedding they missed (11.94 s,
RTFx 4.03), with over 80 GiB free on both of the Framework's pools (framework finding, J and
L.1). Two capability hosts hold at most 2 vision requests with nothing else running, against a
load target of 4.

### The agent on vLLM beside llama.cpp

The [agent-vllm finding](findings/agent-vllm.md) measured gpt-oss-120b alone on gb10-1, on
llama.cpp's agent-only section and on two vLLM v0.33.0 rows in a container, each at 131,072 tokens
a sequence and 16 sequences, one engine at a time in one session (sections C, F, H and I). Every
measuring run went direct on the LAN, so these are LAN figures. "Meets the floor through" is the
highest level of role-split's S-agent sweep with ITL median ≤100 ms. Under role-split's rule for
"holds", llama.cpp holds 4, the BF16 row 4 (its knee is 6.71) and the FP8 row 12 (finding, F).

| Engine and row | At the target of 4: output tok/s, ITL, TTFT | Meets the floor through | 1 stream: tok/s, ITL | KV tokens; 131,072-token sessions (c) | 8 × 65,603-token requests at once | Pool idle / lowest under load (floor 12.2 GiB) | Cold start |
| --- | --- | --- | --- | --- | --- | --- | --- |
| llama.cpp `gpt-oss-120b-MXFP4-agent-only` (c 1,179,648 over 16 slots, f16 KV) | 55.85; 54.44 ms; 2,258 ms | 4 sessions | 37.24; 20.07 ms | 1,179,648; 9 | not run | 13.66 / 12.59 GiB | 48.4 s |
| vLLM `gpt-oss-120b-agent` (BF16 KV, gpu-memory-utilization 0.80) | 55.85; 50.03 ms; 574 ms | 8 sessions | 27.93; 29.65 ms | 846,411 (725,243 on a compiling start); 6 | held, no preemption, KV 57.1% | 15.88 / 15.46 GiB | 503.1 s |
| vLLM `gpt-oss-120b-agent-fp8` (fp8 e4m3 KV, 32,993,476,982 bytes, uncalibrated) | 65.16; 49.55 ms; 566 ms | 12 sessions | 32.58; 28.97 ms | 1,733,910; 13 | held, no preemption, KV 27.0% | 13.88 / 13.92 GiB (12.52 during its start) | 530.7 s |

On these figures vLLM is the stronger agent engine on gb10-1, and the FP8 row leads the BF16 row
if its output quality matches BF16's, which only the two probes and the error counts checked; an
accuracy check is the open item (finding, N). The architect accepts vLLM's longer cold start for a
resident agent in exchange for its concurrency (the architect's preference, finding summary).
v0.33.0 counts about 38,058 bytes of KV a token in BF16 and 19,028 in FP8 (c), against v0.32.0's
55,936 (c), so v0.32.0's 493,523-token BF16 cache and the 1,179,648 tokens computed for the FP8
row's bytes don't describe v0.33.0 (finding, I.2).

### The capability models on vLLM beside llama.cpp

The [capability-vllm finding](findings/capability-vllm.md) measured vision, audio and embedding on
both capability hosts on llama.cpp's sections and on vLLM v0.33.0, three rows a host, each in its
own container and port with its own fraction, 16 sequences of 8,192 tokens each, one engine at a
time in one session (sections C, E, G to K). Every measuring run went direct on the LAN, so these
are LAN figures. "Holds" is role-split's rule, each purpose alone with the other two loaded and
idle.

| Host, engine | Rows or sections | Holds alone: vision, audio, embedding | At the targets on one host (4 / 4 / 16): vision latency, audio RTFx, embedding prompt tok/s | Two-host cell, this host's share (2 / 2 / 8) | KV tokens: vision; audio | Pool idle / lowest under load (floors) | Cold start: vision; audio; embedding |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-2, llama.cpp | 16-slot 26B-A4B and E4B (8,192 a slot), granite | 1, 1, 16 | 44.68 s, 0.93, 11,897: vision and audio miss | 24.58 s, 1.68, 19,128 | 131,072; 131,072 | 77.26 / 68.48 GiB (12.2) | 15.1; 9.1; 3.1 s (load) |
| gb10-2, vLLM | NVFP4 26B-A4B 0.40, E4B BF16 0.20, granite 0.05 | **16, 16, 16** | 14.90 s, 2.15, 47,799: vision and audio miss | 10.89 s, 2.38, 42,671 | 164,570; 172,508 | 35.53 / 31.37 GiB (12.2) | 168.6; 162.2; 19.6 s |
| framework, llama.cpp | capped 26B-A4B and E4B (4 × 8,192), granite, Vulkan | 1, 2, 16 | 34.38 s, 0.93, 7,969: vision and audio miss | 18.37 s, 1.94, 7,441 | 32,768; 32,768 | GTT 82.97 / 82.27, system 88.29 / 85.30 GiB (11.2, 12.5) | 6.1; 6.1; 3.1 s (load) |
| framework, vLLM | BF16 26B-A4B 0.60, E4B BF16 0.18 (rebuilt audio image), granite 0.03, ROCm 10.0 | **4, 8, 16** | 30.11 s, 2.75, 36,331: vision and audio miss | 17.18 s, 3.25, 33,755 | 109,055 (13.31 of 8,192); 104,813 (12.79) | GTT 22.87 / 21.66, **system 16.52 / 13.26 GiB** (11.2, 12.5) | 100.9; 73.4; 20.5 s |

On these figures vLLM is the stronger capability engine for each purpose alone on both hosts, with
4.4 and 4.7 times llama.cpp's embedding throughput at 16 streams (c), and errored no request where
llama.cpp's Gemma 4 output parser errored 5 vision requests. With all three purposes at their
targets on one GPU, vision and audio miss on both engines, and two capability hosts held 0 of 4
vision and 0 of 4 audio streams on each (finding, H to J). vLLM's fractions leave gb10-2 23.33 GiB
above its floor idle against llama.cpp's 65.06 (c), and the Framework's system memory came to
0.76 GiB above its floor under the vision sweep (c), with the containers' host-side memory outside
the GTT the fractions size (finding, K). The Framework's vLLM rows start in 20 to 101 s on the
ROCm 10.0 image, from a dropped page cache with the compile cache warm (finding, C).

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
throughput (framework, K.4). The [agent-vllm finding](findings/agent-vllm.md), section I, adds
the agent's rows on vLLM v0.33.0: 66.14 GiB of weights; KV bytes a token, tokens per GiB and
131,072-token sessions for BF16 and FP8 KV beside llama.cpp's f16; each row's idle and lowest pool;
and the capacity cell's 8 concurrent 65,603-token requests, held on both rows. The
[capability-vllm finding](findings/capability-vllm.md), sections D, E and K, adds the capability
rows on vLLM v0.33.0 on both capability hosts: each row's weights, KV cache memory and tokens at
its fraction, each container's GPU or GTT and RSS idle and after every cell, and each host's pools
idle and at their lowest beside llama.cpp's sections in the same session. The
[vllm-layout finding](findings/vllm-layout.md), sections C.7, E.1, E.7, F.1, F.6, I.3 and K, adds
the standing rows: each row's KV tokens, weights and start, alone on its host and after a reboot,
and each host's pools idle and at their lowest through every cell, the standing cell's among them.

| Host class | Set A idle | Set A warmed peak | Floor | Worked placement | Finding |
| --- | --- | --- | --- | --- | --- |
| GB10 | 21.45 GiB available (21.57 with the Gemma cap) | 17.23 GiB (with the cap, lowest under the full set's mixed load: 15.86 GiB) | 12.2 GiB | agent-only: 9 sessions of 131,072 tokens computed; loaded as c 1,179,648 over 16 slots, 1.39 GiB above the floor idle, 0.27 GiB at its lowest in role-split and 0.30 GiB in the framework task, holding 4 sessions of the 4-turn shape; on vLLM v0.33.0 (agent-vllm), BF16 KV at 0.80: 846,411 tokens, 6 sessions computed, 3.68 GiB above the floor idle, 3.26 at its lowest, meeting the floor through 8 sessions; FP8 KV at 32,993,476,982 bytes: 1,733,910 tokens, 13 sessions computed, 1.68 GiB above the floor idle, 1.72 at its lowest under load and 0.32 during its start, meeting the floor through 12; capability host on vLLM v0.33.0 (capability-vllm), NVFP4 26B-A4B 0.40, E4B 0.20, granite 0.05: 35.53 GiB available idle, 31.37 at its lowest, holding vision 16, audio 16, embedding 16 alone, against the 16-slot llama.cpp sections' 77.26 and 68.48 GiB in the same session | [footprint](findings/footprint.md): I.3, I.7; [role-split](findings/role-split.md): G, I, K; [framework](findings/framework.md): D, H; [agent-vllm](findings/agent-vllm.md): C, F, I; [capability-vllm](findings/capability-vllm.md): D, G, K |
| Framework | 19.08 GiB available (GTT) | 18.08 GiB | 11.2 GiB GTT; 12.5 GiB system memory | capability host, measured: capped 26B-A4B and E4B (4 × 8,192) and granite (16 × 8,192), 83.00 GiB GTT and 87.13 GiB system memory available idle, 82.27 and 84.25 GiB at their lowest; holds vision 1, audio 2, embedding 16 alone; on vLLM v0.33.0's ROCm 10.0 image (capability-vllm), BF16 26B-A4B 0.60, E4B 0.18, granite 0.03: 22.87 GiB GTT and 16.52 GiB system memory available idle, 21.66 and 13.26 GiB at their lowest (system 0.76 GiB above its floor), holding vision 4, audio 8, embedding 16 alone | [footprint](findings/footprint.md): I.3; [framework](findings/framework.md): E, F, K; [capability-vllm](findings/capability-vllm.md): D, G, K |
