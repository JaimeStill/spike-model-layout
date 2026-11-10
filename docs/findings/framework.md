# Finding: the Framework as a second capability host beside gb10-2

Measured 2026-11-10, task `framework`. This finding is dated: every figure holds for the versions,
stack, preset and network path below, on that day, and nothing after it.

**What it establishes.** The finding measures what the Framework holds per purpose as a capability
host, serving set A's capped Gemma 4 26B-A4B (vision) and E4B (audio) at 4 slots of 8,192 tokens
and granite (embedding) at 16, one purpose at a time: **vision 1 request, audio 2, embedding 16
streams** (section F). It then sets the split plus the Framework, each capability purpose's
streams spread evenly over gb10-2 and the Framework, against this session's baseline, the split
alone, at the load targets and at role-split's held levels, with the memory each host leaves
(section J). That answers evidence 5 in the role the framework plan round chose, adds the
Framework's rows to evidence 3 (section I) and its capped capacity rows, measured (section K), and
closes footprint's open items on the Framework's prompt cache, its system-memory floor, and the
26B-A4B on Vulkan past 4 slots (K.4). It also found that:

- neither arrangement held vision or audio at the load target of 4, and neither held the one
  vision and one audio stream per host that role-split's held levels set; embedding met its floor
  in every cell, and the agent on gb10-1 met its floor in every cell (J);
- on the Framework, vision alone at 1 stream met its floor (6.82 s) and missed beside its audio and
  embedding (11.94 s); audio did the same (RTFx 8.81 alone, 4.03 beside them), with 82 GiB of GTT
  free throughout (L.1);
- with the prompt cache capped, the 26B-A4B's RSS on the Framework grew by 1,252 MiB at most,
  against footprint's uncapped 239 → 9,867 MiB, and the system memory the new floor watches never
  fell under 84.25 GiB (K.2, K.4);
- gb10-1's agent-only host ran 0.30 to 0.36 GiB above its floor at its lowest in the last three
  cells (H, L.5).

It decides nothing. The architect's walkthrough (slice 4) is still to run.

**Which figures size the layout.** Production clients sit on the same direct network as the GPUs,
so the layout is sized on LAN figures (role-split's decision). Every run here went direct on the
LAN, 0 to 2 ms to each host ("Stack, engine and network path"), so client-side and server-side
figures both stand as LAN figures.

| Host | Serves at the end of the session |
| --- | --- |
| gb10-1 | `gpt-oss-120b-MXFP4-agent-only` (c 1,179,648, 16 slots, unified), reloaded fresh for the baseline (D): 12.52 GiB available, read 22:10:34Z |
| gb10-2 | `gemma-4-26B-A4B-it-qat-Q4_0-16-slots`, `gemma-4-E4B-it-Q8_0-16-slots` and granite, reloaded fresh for the baseline (D): 69.59 GiB available, read 22:10:34Z |
| framework | set A's capped `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` and `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` (4 × 8,192 each) and granite (16 × 8,192), gpt-oss unloaded (E): 82.27 GiB GTT and 84.80 GiB system memory available, read 22:10:35Z |

All three hosts' spike-model-engines clones are on `main` at 21b5e8c (A), and no section other
than these loaded on any host after section E.

## Stack, engine and network path

Read by the session over SSH, read-only, at 2026-11-10T16:25:16-05:00 (21:25:16Z), after the
architect's root updates (`.state/framework/stack-2026-11-10.txt`):

| Host | Pending updates | OS | Kernel | GPU stack | Docker | Engine | Clone |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-1 | 3, phased (apt; A) | DGX OS 7.6.0 (`DGX_OTA_VERSION`), Ubuntu 24.04.5 LTS | 7.0.0-1025-nvidia | driver 580.178.04, CUDA 13.0, NVIDIA Container Toolkit 1.20.1 | 29.6.2 | llama.cpp `server-cuda13-b12098`, up 10 hours (healthy) | `main` at 21b5e8c |
| gb10-2 | 3, phased (apt; A) | as gb10-1 | 7.0.0-1025-nvidia | as gb10-1 | 29.6.2 | as gb10-1 | `main` at 21b5e8c |
| framework | 0 (`checkupdates`) | Omarchy | 7.2.15-1-omarchy | mesa and vulkan-radeon 1:26.2.5-1, linux-firmware 20260916-1 | 1:29.9.2-1 | llama.cpp `server-vulkan-b12098`, up 29 hours (healthy) | `main` at 3260dd0, moved to 21b5e8c in A |

The GB10s' stack is role-split's in every column but the clone, now on `main` at 21b5e8c
([role-split](role-split.md), "Stack, engine and network path"); the Framework's kernel, Mesa and
Docker are footprint's ([footprint](footprint.md), "Stack, engine and network path"). The root
updates moved no kernel, driver or Mesa: no container restarted with them.

**Network path.** `tailscale ping -c 1` from the laptop at the stack read: each host via its LAN
address in 1 ms. A ping
before every run, each with its date, is in `.state/framework/ping-2026-11-10.txt` (the baseline,
B-target, B-held, the Framework's arrangement, X-vision, X-audio, X-embed, P-target and P-held)
and in the anchors' step output (`.state/framework/fw-anchors.out`). Every one answered via the
host's LAN address, 0 to 2 ms, "direct". **Every run in this finding went direct on the LAN.**
Had the laptop been off the LAN, the relay's trip would have landed on the client-side timing
figures only (TTFT, request latency, RTFx, requests and prompt tokens a second); the server-side
figures (ITL, memory, buffers) don't carry the path ([role-split](role-split.md), L.7).

**Engine and preset.** llama.cpp b12098 on all three hosts, each router serving spike-model-engines'
shared preset (`host/llama-preset/models.ini`) from `main` at 21b5e8c, the merge of role-split's
preset change (2d7ae32). The sections this task loaded, with their arguments as `load` printed them
from the router's `/models`:

| Host | Section id | Model, role | c | Slots | Loaded arguments (`load`) |
| --- | --- | --- | --- | --- | --- |
| framework | `gpt-oss-120b-MXFP4-set-a` | gpt-oss-120b MXFP4, anchors only | 131072 | 4, unified | `--no-cache-idle-slots --ctx-size 131072 --checkpoint-min-step 4096 --cache-ram 0 --kv-unified --parallel 4` |
| framework | `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` | Gemma 4 26B-A4B QAT Q4_0, vision | 32768 | 4 (8192 each) | `--no-cache-idle-slots --ctx-size 32768 --cache-ram 0 --swa-checkpoints 2 --parallel 4` |
| framework | `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` | Gemma 4 E4B Q8_0, audio | 32768 | 4 (8192 each) | `--no-cache-idle-slots --ctx-size 32768 --cache-ram 0 --swa-checkpoints 2 --parallel 4` |
| framework | `mrutkows/granite-embedding-english-r2-GGUF:BF16` | granite-embedding-english-r2 BF16, embedding | 131072 | 16 (8192 each) | `--ctx-size 131072 --parallel 16` |
| gb10-1 | `gpt-oss-120b-MXFP4-agent-only` | gpt-oss-120b MXFP4, agent | 1179648 | 16, unified | `--no-cache-idle-slots --ctx-size 1179648 --checkpoint-min-step 4096 --cache-ram 0 --kv-unified --parallel 16` |
| gb10-2 | `gemma-4-26B-A4B-it-qat-Q4_0-16-slots` | vision | 131072 | 16 (8192 each) | `--no-cache-idle-slots --ctx-size 131072 --cache-ram 0 --swa-checkpoints 2 --parallel 16` |
| gb10-2 | `gemma-4-E4B-it-Q8_0-16-slots` | audio | 131072 | 16 (8192 each) | `--no-cache-idle-slots --ctx-size 131072 --cache-ram 0 --swa-checkpoints 2 --parallel 16` |
| gb10-2 | `mrutkows/granite-embedding-english-r2-GGUF:BF16` | embedding | 131072 | 16 (8192 each) | `--ctx-size 131072 --parallel 16` |

On the Framework the router's `/models` gave each loaded section's full arguments at 21:48:47Z
(section E's step; `.state/framework/fw-x-arrange.out`); the 26B-A4B's carries the vision keys
`--image-min-tokens 560 --mtmd-batch-max-tokens 512 --ubatch-size 1120`, and granite's
`--embeddings --batch-size 8192 --ubatch-size 8192`:

```
google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: /app/llama-server --no-cache-idle-slots --host 127.0.0.1 --image-min-tokens 560 --log-colors off --metrics --min-p 0 --mtmd-batch-max-tokens 512 --offline --port 49235 --temperature 1 --top-k 64 --top-p 0.95 --alias google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 --ctx-size 32768 --cache-ram 0 --swa-checkpoints 2 --hf-repo google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 --log-verbosity 4 --n-gpu-layers all --parallel 4 --ubatch-size 1120
ggml-org/gemma-4-E4B-it-GGUF:Q8_0: /app/llama-server --no-cache-idle-slots --host 127.0.0.1 --log-colors off --metrics --min-p 0 --offline --port 33505 --temperature 1 --top-k 64 --top-p 0.95 --alias ggml-org/gemma-4-E4B-it-GGUF:Q8_0 --ctx-size 32768 --cache-ram 0 --swa-checkpoints 2 --hf-repo ggml-org/gemma-4-E4B-it-GGUF:Q8_0 --log-verbosity 4 --n-gpu-layers all --parallel 4
mrutkows/granite-embedding-english-r2-GGUF:BF16: /app/llama-server --embeddings --host 127.0.0.1 --log-colors off --metrics --offline --port 43145 --alias mrutkows/granite-embedding-english-r2-GGUF:BF16 --batch-size 8192 --ctx-size 131072 --hf-repo mrutkows/granite-embedding-english-r2-GGUF:BF16 --log-verbosity 4 --n-gpu-layers all --parallel 16 --ubatch-size 8192
```

No step loaded the 16-slot 26B-A4B, the 16-slot E4B or the agent-only section on the Framework,
and gpt-oss loaded there only for the anchors (C). No pull request to `host/`.

**Tools.** The step helpers in `scripts/measure-lib.sh` (`load`, `unload`, `loaded`, `memory`,
`footprint`, `cell`, `watch`, `summarize`, `readout`), with this task's change to read both of the
Framework's pools (B). Every cell is GuideLLM 0.8.1 from the laptop (`mise.bench.toml`), run by
`cell` under `watch`: the pool sampled every 10 s into `<cell>.watch.tsv` (both pools on the
Framework), the cell stopped under a floor, capped at 10 min. Each cell's GuideLLM JSON,
`.watch.tsv`, `.exit` and `.log` are under `.state/measure/<host>/`, named `framework-*`. Every
measured cell's `.exit` reads 0: none was stopped (B's two helper tests that stop by design read
143). The scenarios are role-split's, unchanged, listed in `bench/README.md`, "The framework
task's cells". The steps ran from step files in the session's scratch directory, each run through `step.sh <host> <file>`, which sources the helpers for the host
and exports its floors; copies of every step file are in `.state/framework/step-files/`, and the
step log traces every command inside them (section M).

**Per-level figures.** The step log holds each cell's summary line per level. Request latency (its
median, p90 and minimum, and for vision the count at ≤10 s), the floors, RTFx and the knee come from
each cell's JSON through [`bench/levels.jq`](../../bench/levels.jq), which this task extended with
the latency minimum and vision's count (M, "Commands not in a step log"); medians and percentiles
interpolate linearly between the two nearest ranks. It judges agent by ITL median ≤100 ms, vision
by the median request latency ≤10 s, audio by the median of each request's RTFx (its clip's
seconds over its request time) ≥5, and embedding by mean prompt tok/s ≥4,300; a level with no
successful request misses. "Holds" is role-split's rule: the highest level meeting the floor at
or below GuideLLM's knee, or, where it found none, the highest level meeting it.

**Reading the figures.** On a GB10 the pool is MemAvailable, read just after dropping the page
cache (`ssh <host> sudo -n /usr/sbin/sysctl vm.drop_caches=3`), against the floor of 12.2 GiB. On
the Framework there are two pools, each read with no cache drop (it has no drop-caches sudoers
rule): GTT available, against 11.2 GiB (10% of the 112 GiB GTT), and system MemAvailable, against
12.5 GiB (10% of 128,075 MiB). `watch`'s samples during a cell are not taken after a drop. The logs
give buffers in MiB; pools are in GiB (1 GiB = 1024 MiB). The command lists show the step logs'
local times (UTC−5); the prose gives UTC. Every figure is measured, read from a cell's JSON, the
step log or a saved file, unless marked **(c)**: computed from measured figures, with the
arithmetic shown where it isn't a plain difference. **(m)** marks a measured figure where computed
ones sit beside it.

## A. Hosts brought current, the clone moved, the store cleared (Behaviors 1, 2, 3)

**Root updates.** The architect applied the Framework's 4 pending pacman updates and the GB10s'
apt updates before the session's first read; the session holds no list of the Framework's
packages. The stack read then found 0 pending on the Framework and 3 listed on each GB10. Those
three (distro-info and python3-distro-info 1.7ubuntu0.1, snapd 2.78+ubuntu24.04) are Ubuntu
phased updates at 10%, which `apt upgrade` defers; a simulated upgrade on each GB10 printed "The
following upgrades have been deferred due to phasing: distro-info python3-distro-info snapd" and
"0 upgraded, 0 newly installed, 0 to remove and 3 not upgraded", and each GB10's dpkg log held 15
`upgrade` lines from the architect's run at 16:2x local (`.state/framework/phased-2026-11-10.txt`).
By the session's decision the phased three count as no pending updates (goal record, Decisions).
Kernels, driver, CUDA and Mesa are unchanged from the previous tasks (Stack).

**The clone move (Behavior 2).** On the Framework, 21:26:10Z: `git fetch origin && git merge
--ff-only origin/main` moved spike-model-engines from 3260dd0 to 21b5e8c, "Fast-forward" with one
file changed, `host/llama-preset/models.ini` (102 insertions, 10 deletions); `git branch -vv`
listed `main 21b5e8c [origin/main]` and the local `screen` branch untouched at 31b00eb. Then
`docker restart llama`; health `{"status":"ok"}` within 4 s, and `/models` listed **12 sections**,
every one unloaded, role-split's three new ones among them. Set A, from main at 3260dd0, was loaded
before the move, and the restart unloaded it. Its two Gemma sections,
loaded in E, print `--cache-ram 0`, `--no-cache-idle-slots` and `--swa-checkpoints 2`.

**The store clear (Behavior 3).** The Framework's store held the same extras as gb10-1 before the
hosts task cleared them. A dry run of `hf cache rm` (21:26:51Z) named four repositories, 32.5G,
with `/srv/models` at 120,363,420,735 bytes; the run itself (21:27:03Z,
`.state/framework/framework-store-clear.log`) printed "Deleted 4 repo(s) and 4 revision(s); freed
32.5G": `google/gemma-4-12B-it-qat-q4_0-gguf`, `google/gemma-4-31B-it-qat-q4_0-gguf`,
`google/gemma-4-E4B-it-qat-q4_0-gguf` and `ibm-granite/granite-embedding-english-r2`. Left: set
A's four, `ggml-org/gemma-4-E4B-it-GGUF` 8.6G, `ggml-org/gpt-oss-120b-GGUF` 63.4G,
`google/gemma-4-26B-A4B-it-qat-q4_0-gguf` 15.6G, `mrutkows/granite-embedding-english-r2-GGUF`
299.9M; `/srv/models` at 87,912,535,355 bytes, 32,450,885,380 less (c). The first `mise exec -- hf`
on the Framework installed the engines suite's huggingface_hub 2.4.0 at user level. The removed
sections stay listed in `/models`, and one doesn't load: `load
google/gemma-4-12B-it-qat-q4_0-gguf:Q4_0` (21:27:15Z) printed `FAILED in 3.1 s`, and `/srv/models`
read 87,912,535,355 bytes after it, nothing downloaded (the preset's `offline = true`), as on the
GB10s.

## B. The step helpers read both of the Framework's pools (Behavior 4)

**Decision it informs:** whether a Framework cell can be stopped by the memory the GTT watch
can't see, footprint's open item (K.4). Commit 91c20fa, "measure-lib: read and floor the Framework's
system memory beside GTT", in `scripts/measure-lib.sh`: on an amdgpu host each `watch` sample
carries system MemAvailable as a last column beside GTT; `memory` prints both pools with their
floors; `footprint`'s pool line reads `GTT used … ; system MemAvailable …`; `watch` stops a cell
under `MEASURE_FLOOR_GIB` (GTT) or `MEASURE_SYSTEM_FLOOR_GIB` (system memory) and refuses to start
on an amdgpu host when the second is unset; `summarize` gives the lowest of each. A GB10 reads
and stops as before. The check passed.

Tested with no load (21:28:55-21:29:44Z), each a `sleep` under `watch`:

| Test | Host | Result (step log) |
| --- | --- | --- |
| system floor unset | framework | refused: `watch: framework reads system memory beside GTT; set MEASURE_SYSTEM_FLOOR_GIB first`, rc 2 |
| both pools sampled | framework | 3 samples every 5 s; `lowest available 111.72 GiB (GTT) at 21:29:00; lowest system 116.25 GiB (MemAvailable) at 21:29:10` |
| system floor 200 GiB | framework | stopped: `system floor: 119058 MiB available (MemAvailable) under 200 GiB at 21:29:39`, exit 143 |
| GTT floor 200 GiB | framework | stopped: `memory floor: 114400 MiB available (GTT) under 200 GiB at 21:29:44`, exit 143 |
| a GB10 unchanged | gb10-2 | 3 samples, one pool: `lowest available 76.74 GiB (MemAvailable) at 21:29:16` |

Every Framework cell after that ran with both floors set (11.2 and 12.5 GiB). A Framework watch
file carries the system pool as its last column; P-held's vision process, its first two samples
(`.state/measure/framework/framework-p-held-vision.watch.tsv`):

```
time	available MiB	read	gpu	system MiB
22:05:57	84241	GTT	sclk 600Mhz, busy 0%, edge 44 C, power 6 W	86848
22:06:07	84241	GTT	sclk 2873Mhz, busy 100%, edge 75 C, power 138 W	86950
```

## C. Anchors FA and FB against R3 and R4 (Behavior 5)

**Decision it informs:** whether the Framework's speed held since the hosts task, as a record:
read against the hosts finding's R3 and R4 (b12098, 2026-11-09) within the Framework's across-days
run noise of 2.8% (the brief), and never compared with the GB10s' figures as host parity.
**Configuration.** Anchors A and B (`bench/anchor-a.yaml`, `bench/anchor-b.yaml`), each on a
freshly loaded `gpt-oss-120b-MXFP4-set-a` alone after `unload --all` (111.72 GiB GTT, 116.28 GiB
system available before the load), loaded in 21.2 s each; then unloaded.

| Run | Requests | Output tok/s (R) | Change (c) | ITL median (R) | Change (c) | TTFT median (R) | Lowest GTT / system |
| --- | --- | --- | --- | --- | --- | --- | --- |
| FA, 21:30:22Z | 8 of 8 | 44.37 (R3 43.90) | +1.07% | 19.98 ms (19.67) | +1.58% | 629 ms (680) | 47.76 / 52.04 GiB |
| FB, 21:31:47Z | 32 of 32 | 72.46 (R4 70.72) | +2.46% | 46.13 ms (46.64) | −1.09% | 2345 ms (2370) | 47.76 / 52.17 GiB |

**Both within 2.8%** on output tok/s and ITL: the Framework's speed held. The process read
65,500 MiB GTT and 272 MiB RSS after FB (the hosts task's set-a alone: 65,459 / 219, footprint C),
its buffers line for line footprint's Framework set-a buffers. After the unload the Framework read
111.72 GiB GTT and 116.64 GiB system available, nothing loaded, until section E.

## D. The baseline: the split reloaded, B-target and B-held (Behaviors 6, 9)

**Decision it informs:** what one capability host (gb10-2) gives beside the agent-only GB10 in
this session, the baseline the Framework arm is set against. Role-split's figures are cited, not
compared.

**The reload.** Both GB10s at once, 21:34:12Z. gb10-1: `unload --all`, cache dropped (117.68 GiB
available), the agent-only section loaded in 48.3 s, idle 30 s, cache dropped and read at
21:35:35Z: **13.59 GiB (m), 1.39 GiB above the floor (c)**; process 102,925 MiB GPU, 2,419 MiB
RSS; router 170 / 356. gb10-2: `unload --all`, cache dropped (117.52 GiB), the 16-slot 26B-A4B
(15.1 s), the 16-slot E4B (9.1 s) and granite (3.1 s) loaded, idle 30 s, cache dropped and read at
21:35:20Z: **77.34 GiB (m), 65.14 above the floor (c)**; processes (GPU / RSS, MiB) 26B-A4B 25,335 /
1,231, E4B 8,546 / 4,157, granite 863 / 827; router 170 / 622. Every buffer line on both hosts is
role-split's section G line for line (`.state/framework/base-gb10-{1,2}.out`). Nothing on either
GB10 reloaded after this in the session.

**The cells.** Each starts four GuideLLM processes together, 240 s each: the agent's on gb10-1 and
the other three on gb10-2, from each host's own step file (`bench/role-split-mixed-*.yaml`, streams
from `GUIDELLM__SPEC__PROFILE__STREAMS`). The Framework had nothing loaded and took no request.

| Purpose | B-target, 21:35:41Z: agent 4, vision 4, audio 4, embedding 16 | B-held, 21:40:20Z: agent 4, vision 1, audio 1, embedding 16 |
| --- | --- | --- |
| Agent, gb10-1 | 24 ok, 1 errored, 4 incomplete; 51.20 tok/s; TTFT 1788 ms; ITL 55.55 ms (p95 74.02); latency 30.02 s: **meets** | 32 ok, 0 errored, 4 incomplete; 68.27 tok/s; TTFT 2604 ms; ITL 50.79 ms (p95 51.65); latency 28.61 s: **meets** |
| Vision, gb10-2 | 23 ok, 1 errored, 4 incomplete; 9.58 tok/s; TTFT 27,172 ms; ITL 101.05 ms; latency 37.04 s (p90 37.77, min 36.92), 0 of 23 ≤10 s: **misses** | 17 ok, 0, 1; 7.08 tok/s; TTFT 7110 ms; ITL 74.04 ms; latency 14.43 s (p90 14.59, min 7.98), 1 of 17 ≤10 s: **misses** |
| Audio, gb10-2 | 148 ok, 0, 4; 11.40 tok/s; TTFT 1840 ms; ITL 249.32 ms; RTFx median 0.98 (min 0.46), 0 of 148 ≥5: **misses** | 96 ok, 0, 1; 7.94 tok/s; TTFT 503 ms; ITL 95.21 ms; RTFx 2.68 (min 1.17), 3 of 96 ≥5: **misses** |
| Embedding, gb10-2 | 5775 ok, 0, 5; 12,321 prompt tok/s; latency 0.68 s: **meets** | 6916 ok, 0, 10; 14,770 prompt tok/s; latency 0.51 s: **meets** |
| Pool lowest | gb10-1 12.72 GiB (21:39:45Z); gb10-2 69.11 GiB (21:39:35Z) | gb10-1 12.56 GiB (21:44:35Z); gb10-2 69.21 GiB (21:44:24Z) |
| Idle-slot saves, gb10-2 (granite) | 62,655 | 78,203 |

The errors are GuideLLM's `JSONDecodeError('Unterminated string starting at: line 1 column 64
(char 63)')` on the agent (role-split L.5) and the Gemma 4 output parser on vision (L.4). The
baseline holds the agent at its target and embedding at 16, and **misses vision and audio at the
target and at the held level of 1 stream each**, as role-split's S-mixed and S-knee did (cited:
S-knee vision 10.14 s, audio RTFx 2.26, run over a relay).

## E. The Framework's arrangement, loaded (Behavior 7)

**Decision it informs:** what the capability arrangement takes of the Framework's two pools,
against the computation, before any request.

**Configuration.** 21:48:04Z: `unload --all` (111.72 GiB GTT, 116.20 GiB system available), set
A's 26B-A4B (6.1 s), E4B (3.1 s) and granite (3.1 s) loaded, nothing else; idle 30 s; read at
21:48:47Z with no cache drop.

| | Measured (m) | Computed in the plan round |
| --- | --- | --- |
| GTT available | **83.00 GiB**; GTT used 29.00 of 112.00 GiB | ~83.0 GiB |
| System memory available | **87.13 GiB** | ~87 GiB |
| Taken by the load (c) | GTT 28.72 GiB (111.72 − 83.00); system 29.07 GiB (116.20 − 87.13) | |
| Above the floors (c) | GTT 71.80 GiB; system 74.63 GiB | |

Processes (GTT / RSS, MiB): 26B-A4B **18,380 / 237**, E4B **9,929 / 248**, granite **1,102 /
122**, router 2 / 108. Their GTT sums to 29,413 MiB, 28.72 GiB (c), the GTT taken. Each figure
is footprint's Framework idle-alone figure to the MiB on GTT and within 3 MiB on RSS (footprint C:
18,380 / 240, 9,929 / 247, 1,102 / 123).

**Every logged buffer** (m, MiB; `.state/framework/fw-x-arrange.out`), the same as footprint's
Framework lines for set A's sections: the cap keys change no logged buffer on Vulkan, as role-split
found on CUDA.

| Buffer | 26B-A4B, 4 × 8,192 | E4B, 4 × 8,192 | granite, 16 × 8,192 |
| --- | --- | --- | --- |
| Weights Vulkan0 / Vulkan_Host | 13755.36 / 577.50 | 4788.10 / 3536.00 | 210.51 / 73.78 |
| Full-attention KV | 640.00 (8192 cells, 5 layers, 4/4 seqs) | 512.00 (8192 cells, 4 layers, 4/4 seqs) | none logged |
| Sliding-window KV | 1800.00 (2304 cells, 25 layers, 4/4 seqs) | 160.00 (1024 cells, 20 layers, 4/4 seqs) | none logged |
| Compute Vulkan0 / Vulkan_Host | 239.04 / 70.64 | 137.02 / 50.04 | 460.13 / 352.19 |
| Projector | gemma4v 1139.46 | gemma4v 533.83, gemma4a 533.83 | – |
| Projector compute Vulkan0 / CPU | 150.63 / 6.77 | 101.27 / 6.77 (v); 101.19 / 1.58 (a) | – |
| Output (Vulkan_Host) | 4.00 | 4.00 | 3.12 |
| mmproj worst case (estimate) | 1296.85 | 746.89 | – |
| Slots | `n_slots = 4, n_ctx_slot = 8192, kv_unified = 'false'` | the same | `n_slots = 16, n_ctx_slot = 8192` |

## F. The Framework per purpose: X-vision, X-audio, X-embed (Behavior 8)

**Decision it informs:** what the Framework holds per purpose as a capability host, at each
purpose's floor. Each sweep is role-split's full-set sweep, unchanged, on the Framework, one
purpose at a time with the other two sections loaded and idle, nothing reloaded between them:
GuideLLM's knee profile, adaptive refinement off, no ramp-up (granite's a concurrent sweep).

### F.1 Vision

X-vision, the 26B-A4B (c 32768, 4 slots), `bench/role-split-vision-full.yaml`: one synthetic 1440p
JPEG beside 200 text tokens, exactly 100 out; levels [1, 2, 3, 4, 8], 60 s each,
21:48:51-21:54:34Z. **No knee** ("No breakpoint satisfied the saturation thresholds").

| Streams | Ok / errored / incomplete | Output tok/s | Requests/s | TTFT median | ITL median | Latency median / p90 / min | ≤10 s | Floor (≤10 s) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 8 / 0 / 1 | 13.33 | 0.133 | 5252 ms | 15.71 ms | 6.82 / 6.85 / 6.74 s | 8 of 8 | meets |
| 2 | 8 / 0 / 2 | 13.33 | 0.133 | 10,434 ms | 20.43 ms | 13.09 / 13.81 / 12.38 s | 0 of 8 | **misses** |
| 3 | 9 / 0 / 3 | 15.00 | 0.150 | 15,611 ms | 38.12 ms | 19.39 / 19.48 / 18.01 s | 0 of 9 | **misses** |
| 4 | 7 / 1 / 4 | 11.67 | 0.117 | 20,622 ms | 29.41 ms | 23.54 / 23.56 / 23.50 s | 0 of 7 | **misses** |
| 8 | 8 / 0 / 8 | 13.33 | 0.133 | 20,844 ms | 30.08 ms | 35.47 / 47.12 / 23.82 s | 0 of 8 | **misses** |

**Holds 1 request.** Requests a second stay between 0.117 and 0.150 at every level, and TTFT grows
by 5.0 to 5.2 s (c) with each stream added to 4: the pattern role-split L.1 read as one image encode
at a time, here on Vulkan. The Framework's router log wasn't read in this task, so the encode itself
isn't timed here. The 4-stream error is the Gemma 4 output parser (L.4).

### F.2 Audio

X-audio, the E4B (c 32768, 4 slots), `bench/role-split-audio-full.yaml`: one of the 73 LibriSpeech
clips with the card's transcription prompt, up to 256 out; levels [1, 2, 3, 4, 8], each 30 s or 64
requests, 21:54:43-21:57:34Z. **Knee 4.11** (breakpoint 4, saturation 8: "A rising segment
followed by a substantially flatter tail was detected").

| Streams | Ok / errored / incomplete | Output tok/s | TTFT median | ITL median | Latency median / p90 | RTFx median / min | RTFx ≥5 | Level duration | Floor (RTFx ≥5) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 40 / 0 / 1 | 27.03 | 224 ms | 24.48 ms | 0.62 / 1.13 s | 8.81 / 5.15 | 40 of 40 | 30 s | meets |
| 2 | 47 / 0 / 2 | 31.27 | 336 ms | 48.77 ms | 1.00 / 2.31 s | 5.45 / 3.12 | 31 of 47 | 30 s | meets |
| 3 | 62 / 0 / 2 | 38.17 | 472 ms | 50.45 ms | 1.17 / 2.31 s | 4.32 / 2.00 | 17 of 62 | 30 s | **misses** |
| 4 | 64 / 0 / 0 | 45.44 | 486 ms | 56.93 ms | 1.42 / 2.50 s | 3.76 / 1.72 | 13 of 64 | 26 s | **misses** |
| 8 | 64 / 0 / 0 | 46.64 | 2003 ms | 58.90 ms | 2.93 / 4.16 s | 1.93 / 0.71 | 0 of 64 | 26 s | **misses** |

**Holds 2 requests.** At 2 streams the median met the floor and about a third of the requests
(16 of 47, c) missed it.

### F.3 Embedding

X-embed, granite (16 slots of 8,192), `bench/role-split-embed.yaml`: 512-token inputs to
`/v1/embeddings`, concurrent [1, 2, 4, 8, 16], 30 s each, 21:57:46-22:00:57Z. Judged at ≥4,300
prompt tok/s.

| Streams | Ok / incomplete | Requests/s | Latency median | Prompt tok/s | Floor |
| --- | --- | --- | --- | --- | --- |
| 1 | 760 / 0 | 25.300 | 0.04 s | 12,979 | meets |
| 2 | 997 / 1 | 33.200 | 0.06 s | 17,032 | meets |
| 4 | 1296 / 1 | 43.100 | 0.09 s | 22,110 | meets |
| 8 | 1192 / 8 | 39.733 | 0.20 s | 20,383 | meets |
| 16 | 1184 / 16 | 39.467 | 0.40 s | 20,246 | meets |

**Holds 16 streams**, every level met; throughput peaked at 4 streams. The `readout` counted 73,253
idle-slot saves (L.3); granite's RSS grew 123 → 136 MiB and its GTT 1,102 → 1,149 MiB.

## G. The Framework arm: P-target and P-held (Behavior 9)

**Decision it informs:** whether a second capability host reaches the load targets, and whether it
doubles what one held. Each cell starts seven GuideLLM processes together, 240 s each, launched
from each host's own step file: the agent's on gb10-1, and each capability purpose's streams split
evenly, half on gb10-2's 16-slot sections and granite, half on the Framework's (vision and audio
read `bench/role-split-mixed-vision.yaml` and `-audio.yaml` with the Framework's set A sections).

| Purpose | P-target, 22:01:05Z: agent 4; vision 2 + 2; audio 2 + 2; embedding 8 + 8 | P-held, 22:05:47Z: agent 4; vision 1 + 1; audio 1 + 1; embedding 8 + 8 |
| --- | --- | --- |
| Agent, gb10-1 | 32 ok, 0, 4 incomplete; 68.27 tok/s; TTFT 2813 ms; ITL 49.82 ms (p95 51.44): **meets** | 32 ok, 0, 4; 68.27 tok/s; TTFT 2658 ms; ITL 50.71 ms (p95 52.26): **meets** |
| Vision, gb10-2 | 22 ok, 0, 2; 9.17 tok/s; TTFT 13,364 ms; ITL 82.52 ms; latency 21.54 s (p90 21.89, min 15.74), 0 of 22 ≤10 s: **misses** | 18 ok, 0, 1; 7.50 tok/s; TTFT 6773 ms; ITL 72.59 ms; latency 13.89 s (p90 14.04, min 4.86), 1 of 18: **misses** |
| Vision, framework | 24 ok, 0, 2; 10.00 tok/s; TTFT 13,749 ms; ITL 56.10 ms; latency 19.37 s (p90 19.86, min 18.78), 0 of 24: **misses** | 20 ok, 0, 1; 8.33 tok/s; TTFT 6762 ms; ITL 52.30 ms; latency 11.94 s (p90 13.05, min 8.87), 1 of 20: **misses** |
| Audio, gb10-2 | 127 ok, 0, 2; TTFT 990 ms; ITL 147.43 ms; latency 3.26 s (p90 6.06); RTFx 1.65 (min 0.76), 5 of 127 ≥5: **misses** | 103 ok, 0, 1; TTFT 476 ms; ITL 89.31 ms; latency 1.99 s (p90 3.85); RTFx 2.82 (min 1.46), 4 of 103: **misses** |
| Audio, framework | 114 ok, 0, 2; TTFT 1051 ms; ITL 107.84 ms; latency 3.04 s (p90 8.26); RTFx 1.68 (min 0.53), 1 of 114: **misses** | 115 ok, 0, 1; TTFT 539 ms; ITL 46.96 ms; latency 1.44 s (p90 4.10); RTFx 4.03 (min 0.78), 33 of 115: **misses** |
| Embedding, gb10-2 | 8586 ok, 0, 3; 18,342 prompt tok/s; latency 0.22 s (p90 0.27): **meets** | 9235 ok, 0, 8; 19,740; 0.19 s (0.25): **meets** |
| Embedding, framework | 3416 ok, 0, 8; 7,302 prompt tok/s; latency 0.46 s (p90 0.92): **meets** | 3729 ok, 0, 8; 7,971; 0.42 s (0.87): **meets** |
| Pool lowest | gb10-1 12.51 GiB (22:05:29Z); gb10-2 69.12 GiB (22:04:39Z); framework GTT 82.27 (22:01:16Z), system 84.25 GiB (22:01:56Z) | gb10-1 12.50 GiB (22:09:51Z); gb10-2 69.31 GiB (22:09:41Z); framework GTT 82.27 (22:05:57Z), system 84.41 GiB (22:07:18Z) |
| Idle-slot saves (granite) | gb10-2 114,728; framework 43,702 | gb10-2 124,178; framework 48,830 |

No request errored in either cell. **Combined**, against the load targets: agent 4 of 4 sessions;
vision 0 of 4 streams; audio 0 of 4; embedding 16 of 16 streams at 25,644 prompt tok/s (c: 18,342 +
7,302). At the held levels: agent 4; vision 0 of 2; audio 0 of 2; embedding 16 at 27,711 (c).

## H. Memory through the session (Behaviors 7, 9, 10)

Each read is after the cell: on a GB10 the cache dropped, `memory`, then `footprint` (the step
file's `after`); on the Framework `memory` and `footprint` with no drop (`after_fw`). "Lowest" is
`watch`'s during the cell. Processes in MiB, GPU / RSS on a GB10, GTT / RSS on the Framework. No
cell went under a floor, and nothing reloaded on any host after its load in D or E.

**gb10-1** (floor 12.2 GiB):

| After | Pool (GiB) | Lowest during | Above the floor at the lowest (c) | gpt-oss agent-only |
| --- | --- | --- | --- | --- |
| idle, 30 s | 13.59 | – | 1.39 (idle) | 102925 / 2419 |
| B-target | 12.73 | 12.72 | 0.52 | 103029 / 3140 |
| B-held | 12.56 | 12.56 | 0.36 | 103029 / 3317 |
| P-target | 12.52 | 12.51 | 0.31 | 103033 / 3342 |
| P-held | 12.52 | **12.50** | **0.30** | 103033 / 3355 |

**gb10-2** (floor 12.2 GiB):

| After | Pool (GiB) | Lowest during | 26B-A4B 16-slot | E4B 16-slot | granite |
| --- | --- | --- | --- | --- | --- |
| idle, 30 s | 77.34 | – | 25335 / 1231 | 8546 / 4157 | 863 / 827 |
| B-target | 69.68 | **69.11** | 26148 / 6951 | 8776 / 5004 | 973 / 958 |
| B-held | 69.58 | 69.21 | 26148 / 6926 | 8776 / 5047 | 973 / 963 |
| P-target | 69.39 | 69.12 | 26148 / 7072 | 8776 / 5085 | 973 / 963 |
| P-held | 69.50 | 69.31 | 26148 / 6951 | 8776 / 5077 | 973 / 963 |

**framework** (floors GTT 11.2, system 12.5 GiB):

| After | GTT / system (GiB) | Lowest during, GTT / system | 26B-A4B | E4B | granite | router RSS |
| --- | --- | --- | --- | --- | --- | --- |
| idle, 30 s | 83.00 / 87.13 | – | 18380 / 237 | 9929 / 248 | 1102 / 122 | 108 |
| X-vision | 82.37 / 85.61 | 82.37 / 84.56 | 19028 / 1355 | 9929 / 249 | 1102 / 123 | 134 |
| X-audio | 82.31 / 85.29 | 82.31 / 85.07 | 19028 / 888 | 9987 / 572 | 1102 / 123 | 281 |
| X-embed | 82.27 / 85.16 | 82.27 / 85.15 | 19028 / 888 | 9987 / 572 | 1149 / 136 | 282 |
| P-target | 82.27 / 84.83 | 82.27 / **84.25** | 19028 / 1481 | 9987 / 584 | 1149 / 136 | 299 |
| P-held | 82.27 / 84.85 | **82.27** / 84.41 | 19028 / **1489** | 9987 / **627** | 1149 / 136 | 315 |

On a GB10 the `footprint` read a few seconds after `memory` gave the pool within 0.02 GiB of it
(for example 12.54 against B-held's 12.56 on gb10-1); the tables give `memory`'s.

## I. Evidence 3: the Framework's rows

Rows to read beside role-split's section I, which this task's figures don't replace. Figures are
at the held level (F). Granite has no TTFT or ITL; its figure is prompt tok/s.

| Arrangement | Model, section | Context | Knee | Holds | Output tok/s | TTFT median | ITL median | Purpose figure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Capability host (framework), the other two idle | 26B-A4B, capped, 4 slots, Vulkan | 8,192 a slot | none | **1 request** | 13.33 | 5252 ms | 15.71 ms | latency 6.82 s; 2 streams 13.09 s |
| Capability host (framework) | E4B, capped, 4 slots, Vulkan | 8,192 a slot | 4.11 | **2 requests** | 31.27 | 336 ms | 48.77 ms | RTFx 5.45; 3 streams 4.32 |
| Capability host (framework) | granite, 16 slots, Vulkan | 8,192 a slot | (concurrent sweep) | **16 streams** | – | – | – | 20,246 prompt tok/s (12,979 to 22,110 across levels) |
| Split plus the Framework, all at once (G) | the above, beside gb10-2's | as above | – | vision 0 and audio 0 at 1 + 1; embedding 8 + 8 | – | – | – | vision 11.94 s, audio RTFx 4.03 on the Framework in P-held |

## J. Evidence 5: the split plus the Framework against the baseline

The Framework's role is the capability host, chosen in the plan round from role-split's findings
(goal record, Decisions): it serves vision, audio and embedding beside gb10-2, each capability
purpose with two hosts. **The comparison**, every figure from D and G, "holds" counted as the
streams on hosts whose figure met the floor:

| | B-target: the split | P-target: the split plus the Framework | B-held: the split | P-held: the split plus the Framework |
| --- | --- | --- | --- | --- |
| **Agent** (gb10-1, 4 sessions; target 4) | ITL 55.55 ms: **4 of 4** | ITL 49.82 ms: **4 of 4** | ITL 50.79 ms: **4 of 4** | ITL 50.71 ms: **4 of 4** |
| **Vision** (target 4; held 1 a host) | 4 on gb10-2: 37.04 s. **0 of 4** | 2 on gb10-2: 21.54 s; 2 on the Framework: 19.37 s. **0 of 4** | 1 on gb10-2: 14.43 s. **0 of 1** | 1 on gb10-2: 13.89 s; 1 on the Framework: 11.94 s. **0 of 2** |
| **Audio** (target 4; held 1 a host) | 4 on gb10-2: RTFx 0.98. **0 of 4** | 2 + 2: RTFx 1.65 and 1.68. **0 of 4** | 1 on gb10-2: RTFx 2.68. **0 of 1** | 1 + 1: RTFx 2.82 and 4.03. **0 of 2** |
| **Embedding** (target 16) | 16 on gb10-2: 12,321 tok/s. **16 of 16** | 8 + 8: 18,342 + 7,302 = 25,644 tok/s (c). **16 of 16** | 16 on gb10-2: 14,770 tok/s. **16 of 16** | 8 + 8: 19,740 + 7,971 = 27,711 tok/s (c). **16 of 16** |
| **Memory left, lowest** (above the floor, c) | gb10-1 12.72 (0.52); gb10-2 69.11 (56.91); framework idle, nothing loaded: 111.72 GTT / 116.64 system | gb10-1 12.51 (0.31); gb10-2 69.12 (56.92); framework 82.27 GTT (71.07) / 84.25 system (71.75) | gb10-1 12.56 (0.36); gb10-2 69.21 (57.01); framework as B-target | gb10-1 12.50 (0.30); gb10-2 69.31 (57.11); framework 82.27 (71.07) / 84.41 (71.91) |
| **Errors** | agent 1 JSON decode; vision 1 parser | none | none | none |

**What the figures show.** The agent met its floor in all four cells, and embedding held 16 streams
in all four, at about twice the baseline's throughput with the second host (c: 25,644 / 12,321 =
2.08; 27,711 / 14,770 = 1.88). **Vision and audio held nothing in any cell.** Combined vision at the
target of 4 was 0 of 4 in the baseline and 0 of 4 with the Framework: spread 2 + 2, each host's
streams waited 19 to 22 s an image question against the 10 s floor, closer than the baseline's
37 s but not under it. At the held levels the second host gave each purpose a second stream and
neither stream met the floor, so the second host did not double what one held: one host held 0
streams of vision and audio here, and so did two. Each host kept at least 56.91 GiB above its
floor on gb10-2 and 71.07 GiB (GTT) on the Framework throughout, while gb10-1 ran 0.30 to 0.36 GiB
above its own in the last three cells. **The limit these cells met is speed, not memory**: L.1
sets out the reading, which this task did not isolate.

**One placement, read from the table: combined vision against the target of 4.** Alone, the
Framework's 26B-A4B holds 1 request (F.1) and gb10-2's 16-slot section held 1 in role-split's
S-vision (cited). Two capability hosts therefore hold at most 2 vision requests with nothing else
running, half the target, and with audio and embedding beside them they held none (P-target 0 of
4, P-held 0 of 2). On these sections and this build, adding the Framework as a second capability
host does not bring vision to its load target of 4; the spike records it and decides nothing.

## K. Capacity rows, measured (Behavior 11)

Rows to read beside footprint's capacity table ([footprint](footprint.md), section I) and
role-split's (role-split K), every one measured **(m)** on the Framework on 2026-11-10 with the
Gemma prompt cache capped. Footprint's table stays as written; K.4 says which of its open items
these rows close.

### K.1 Buffers (m, MiB, logged at load)

Set A's capped 26B-A4B and E4B and granite on the Framework log every buffer footprint's I.1
Framework rows give, line for line (E): the cap keys change no logged buffer. No new row.

### K.2 Process and pool (m)

GTT / RSS in MiB. "Idle" is E's read; "warmed" the process after its first cell in the arm (X-vision
for the 26B-A4B, X-audio for the E4B, X-embed for granite); "highest" the most after any cell (H).
Footprint's uncapped Framework rows (footprint I.2, 2026-11-09, `cache-ram` at its default) beside
them.

| Section | Idle (m) | Warmed: after its first cell (m) | Highest after a cell (m) | RSS growth, idle → highest (c) | Footprint, uncapped: idle → under load (m) |
| --- | --- | --- | --- | --- | --- |
| 26B-A4B 4 slots, capped | 18380 / 237 | 19028 / 1355 (X-vision) | 19028 / 1489 (P-held) | **+1252** | RSS 239 (fresh before L1-L4) → **9867** (after L2), footprint G: +9628 (c) |
| E4B 4 slots, capped | 9929 / 248 | 9987 / 572 (X-audio) | 9987 / 627 (P-held) | +379 | 9929 / 246 → 9983 / 1049 (L3): +803 (c) |
| granite | 1102 / 122 | 1149 / 136 (X-embed) | 1149 / 136 | +14 | 1102 / 122 → 1129 / 129 (L4) |
| router | 2 / 108 | – | 2 / 315 (P-held) | +207 | – |

The 26B-A4B's GTT rose 648 MiB (c) with the first vision cell and stayed flat after it. Its RSS
rose and fell between cells (1355 after X-vision, 888 after X-audio), as role-split L.2 found on
CUDA; the readouts counted 0 prompt saves on every cell.

### K.3 Per host and arrangement (m)

| Arrangement | Host | Before load | Idle, 30 s | Taken (c) | Lowest under load | Above the floor, idle / lowest (c) |
| --- | --- | --- | --- | --- | --- | --- |
| Capability host: 26B-A4B and E4B capped (4 × 8,192), granite (16 × 8,192) | framework, GTT | 111.72 GiB | 83.00 GiB | 28.72 GiB | 82.27 GiB (X-embed on) | 71.80 / 71.07 GiB |
| as above | framework, system memory | 116.20 GiB | 87.13 GiB | 29.07 GiB | 84.25 GiB (P-target) | 74.63 / 71.75 GiB |
| Agent-only, c 1,179,648 × 16 (baseline reload) | gb10-1 | 117.68 GiB | 13.59 GiB | 104.09 GiB | 12.50 GiB (P-held) | 1.39 / 0.30 GiB |
| 26B-A4B 16 slots, E4B 16 slots, granite (baseline reload) | gb10-2 | 117.52 GiB | 77.34 GiB | 40.18 GiB | 69.11 GiB (B-target) | 65.14 / 56.91 GiB |

Footprint's set A on the Framework, uncapped, sat at 19.08 GiB GTT idle and 18.31 GiB at its
lowest, with system memory down to 12,658 MiB (12.36 GiB, c) after L4 (footprint I.3, G): under
the 12.5 GiB floor this task set, had it been watched. The capability arrangement here leaves the
Framework's gpt-oss section out, which is most of the difference.

### K.4 Footprint's open items (section K): what this finding closes

| Footprint's item | Here |
| --- | --- |
| The Gemma sections' prompt cache | **Closed on the Framework:** its clone carries the cap (21b5e8c, A), its Gemma sections print `--cache-ram 0` (E), the readouts counted 0 prompt saves, and the 26B-A4B's RSS grew 1,252 MiB at most (237 → 1,489), against footprint's uncapped 239 → 9,867 MiB (K.2). The capped sections' RSS growth itself stays role-split's open item (L.2 there), now seen on Vulkan too. |
| The Framework's system memory has no floor | **Closed:** `watch` samples system MemAvailable beside GTT on an amdgpu host and stops a cell under 12.5 GiB (B). In every Framework cell the system pool's lowest was 84.25 GiB (P-target), 71.75 GiB above that floor (c). |
| The Framework's L2 parser error (`peg-gemma4`) | Open, as role-split widened it: one more on the Framework's capped 26B-A4B (X-vision, 4 streams) and one on gb10-2 (B-target) (L.4). |
| Unmeasured in the computed columns | Open as role-split left it: the Gemma models' trained contexts. Nothing here reads them. |
| The E4B's 8,192-token slot against a 15,028-token request | Closed by role-split (E there). |
| The 26B-A4B on Vulkan past 4 slots or c 32768 | **Closed as untested**, by the session's decision: the fix ([#25584](https://github.com/ggml-org/llama.cpp/pull/25584)) is in no build, and more slots add no vision throughput on b12098, since the server encodes one image at a time (role-split L.1; F.1 here shows the same pattern on Vulkan at 4 slots). The Framework serves it at 4 slots of 8,192; footprint's I.5 constraint row stands. |

## L. What else was found

### L.1 Vision and audio miss beside each other on one GPU, with memory to spare

On the Framework, each purpose alone at 1 stream met its floor, and beside the other two it
missed:

| Framework, 1 stream | Alone (F; the other two loaded, idle) | In P-held (beside 1 audio or vision stream and 8 embedding streams) |
| --- | --- | --- |
| Vision latency median | 6.82 s (8 of 8 ≤10 s): meets | 11.94 s (1 of 20): misses |
| Vision TTFT / ITL | 5252 ms / 15.71 ms | 6762 ms / 52.30 ms |
| Audio RTFx median | 8.81 (40 of 40 ≥5): meets | 4.03 (33 of 115): misses |
| Audio TTFT / ITL | 224 ms / 24.48 ms | 539 ms / 46.96 ms |

The Framework had 82.27 GiB of GTT and at least 84.41 GiB of system memory available through
P-held, and nothing was stopped or swapped. Splitting the streams over two hosts left both missing
at 1 stream on each: gb10-2's vision at 13.89 s and audio at RTFx 2.82, the Framework's at 11.94 s
and 4.03 (G). Role-split saw the same on gb10-2 alone (S-knee, cited). These figures point to the
purposes sharing one GPU's compute and bandwidth, not memory capacity, as what holds vision and
audio under their floors; no cell here ran purposes in pairs or read GPU utilization per process,
so the reading is not isolated. ITL, a server-side figure, rose 3.3 times for vision (c: 52.30 /
15.71) and 1.9 times for audio (46.96 / 24.48), on a LAN path.

### L.2 The capped 26B-A4B on Vulkan

Its process GTT moved once, 18,380 → 19,028 MiB with the first image requests, as footprint's
warmed growth did (19,062 then), and its RSS stayed under 1,500 MiB (K.2). The system pool fell
from 87.13 GiB idle to 84.25 GiB at its lowest, 2.88 GiB (c), against footprint's fall of about 10
GiB (23,639 → 13,660 MiB) through its uncapped L2.

### L.3 Granite's idle-slot saves, on both capability hosts

Granite's section still sets no cache keys (an intake note, role-split L.3). The readouts counted
73,253 idle-slot saves in X-embed on the Framework, and in the mixed cells 62,655 (B-target),
78,203 (B-held), 114,728 (P-target) and 124,178 (P-held) on gb10-2 and 43,702 and 48,830 on the
Framework. Granite's RSS on the Framework grew 122 → 136 MiB.

### L.4 The Gemma 4 output-parser error

Two requests, each on a 26B-A4B, errored with GuideLLM's `ValueError('Streaming response returned
an error: The model produced output that does not match the expected peg-gemma4 format')`:
X-vision at 4 streams (the Framework, Vulkan, capped) and B-target's vision (gb10-2, CUDA). No
cell was rerun for them.

### L.5 gb10-1's margin

The agent-only section reloaded fresh reads 13.59 GiB idle, role-split's figure, and sits 0.52 GiB
above the floor at its lowest in B-target, then 0.36, 0.31 and 0.30 GiB in B-held, P-target and
P-held (H). Its RSS grew 2,419 → 3,355 MiB over the four cells and its GPU memory 102,925 →
103,033 MiB. The floor wasn't reached; the margin shrank with each cell, as role-split's 0.27 GiB
at S-knee did.

## M. Every run

| Run | Host | Tool and configuration | Load | Duration | Path | Decision it informs |
| --- | --- | --- | --- | --- | --- | --- |
| Stack read and pings | all three | SSH read-only; `tailscale ping -c 1` | none | one read | direct, 1 ms each | Behavior 1's record (Stack) |
| Phased-update read | gb10-1, gb10-2 | SSH, `apt-get -s upgrade` (simulated) | none | one read | direct | whether the 3 listed updates are pending (A) |
| Clone move and restart | framework | `git merge --ff-only origin/main`, `docker restart llama` | none | 4 s to health | direct, 2 ms | the cap keys on the Framework (A) |
| Store dry run, clear, probe | framework | `hf cache rm --dry-run`, `hf cache rm --yes`, `load` of a removed section | none | 3.1 s probe | direct | the store holds set A only (A) |
| Helper tests | framework, gb10-2 | `watch` over `sleep`, floors unset, 200 GiB, and as set | none | 1 to 16 s each | direct | `watch` reads and stops on both pools (B) |
| FA | framework | GuideLLM 0.8.1, `cell`, `bench/anchor-a.yaml`, fresh set-a alone | 1 stream × 8, 512 in, 256 out | 46 s (60 s under `watch`) | direct, 0 s | the Framework's speed against R3 (C) |
| FB | framework | `bench/anchor-b.yaml`, fresh set-a alone | 4 streams × 32 | 113 s (131 s under `watch`) | direct, 1 ms | against R4 (C) |
| Baseline reload | gb10-1, gb10-2 | agent-only; 16-slot 26B-A4B, 16-slot E4B, granite; each after `unload --all` and a cache drop; 30 s idle | none | 48.3 s; 27.3 s | direct, 2 ms | the split as it serves (D) |
| B-target | gb10-1 and gb10-2 at once | `bench/role-split-mixed-*.yaml`, the split's sections | agent 4, vision 4, audio 4, embedding 16 | 240 s each, about 4.5 min | direct, 1 ms | one capability host at the targets (D) |
| B-held | gb10-1 and gb10-2 at once | as B-target | agent 4, vision 1, audio 1, embedding 16 | 240 s each, about 4.5 min | direct, 1-2 ms | the baseline at the held levels (D) |
| Framework arrangement | framework | set A's capped 26B-A4B, E4B and granite after `unload --all`; 30 s idle | none | 12.3 s load, 30 s idle | direct, 2 ms | both pools against the computation (E) |
| X-vision | framework | `bench/role-split-vision-full.yaml`, 26B-A4B, knee [1,2,3,4,8] | 1440p image + 200 tokens, 100 out | 60 s a level, 343 s | direct, 2 ms | vision requests the Framework holds (F.1) |
| X-audio | framework | `bench/role-split-audio-full.yaml`, E4B, knee [1,2,3,4,8] | LibriSpeech clips, ≤64 a level | ≤30 s a level, 171 s | direct, 1 ms | audio requests the Framework holds (F.2) |
| X-embed | framework | `bench/role-split-embed.yaml`, granite, concurrent [1,2,4,8,16] | 512-token inputs | 30 s a level, 191 s | direct, 2 ms | embedding against its floor (F.3) |
| P-target | gb10-1, gb10-2 and framework at once | `bench/role-split-mixed-*.yaml`, each host's sections | agent 4; vision 2 + 2; audio 2 + 2; embedding 8 + 8 | 240 s each, about 4.5 min | direct, 1-2 ms | whether two capability hosts reach the targets (G) |
| P-held | all three at once | as P-target | agent 4; vision 1 + 1; audio 1 + 1; embedding 8 + 8 | 240 s each, about 4.5 min | direct, 1-2 ms | whether a second host doubles what one held (G) |
| End state | all three | `/models`, the clone's commit, `memory` | none | one read | direct | Behavior 12's state |

Every cell ran under `watch`, memory sampled every 10 s, capped at 10 min: floors 12.2 GiB on the
GB10s (`MEASURE_FLOOR_GIB`), 11.2 GiB GTT and 12.5 GiB system memory on the Framework
(`MEASURE_FLOOR_GIB`, `MEASURE_SYSTEM_FLOOR_GIB`), set by `step.sh` for each host.

### Commands as run (framework)

From `.state/measure/framework/2026-11-10.log`, every command at the step level that a figure
rests on or that changed the host, in log order, by role-split's rule: every line inside a helper,
the log's header lines and the floors `step.sh` exported stay in the log, and so do the reads no
figure rests on, the `loaded` reads that end a step or come just before an `unload --all`, and
the `memory` reads just before a cell. A step's opening `loaded` stays, and so does the last
step's. `<scratchpad>` stands for the session's scratch directory,
`/tmp/claude-1000/-home-jaime-experiments-spike-model-layout/9e244662-9c8e-41d0-aebb-1002503f2438/scratchpad`;
the `source` lines are the step files (copies in `.state/framework/step-files/`), and the commands
traced after each are what they ran. A step file's `{ date -u +%FT%TZ; tailscale ping -c 1 <host>;
} 2>&1 | tee -a .../ping-2026-11-10.txt` is one line, which the trace prints as three, in the order
the shell started them. The trace prints each `for s in ...` line again before every pass of its
loop; it is shown once. The mixed cells' processes ran in the background (`&`) and `wait`, so the
trace prints their assignments, `wait` and the `cell` lines in the order the shell reached them.
`after_fw` (from `after-fw.sh`) runs `memory` and `footprint`, then stops the arm if GTT reads under
11,468 MiB or system memory under 12,800 MiB.

```
16:26:10  source <scratchpad>/fw-clone.sh
16:26:10  : 'framework: move the spike-model-engines clone from 3260dd0 to main at 21b5e8c and restart the router to read it'
16:26:10  tailscale ping -c 1 framework
16:26:10  loaded
16:26:10  ssh framework 'cd ~/repos/spike-model-engines && git fetch origin && git merge --ff-only origin/main && git log --oneline -1 && git status -sb | head -1 && git branch -vv'
16:26:10  ssh framework 'docker restart llama'
16:26:14  curl -s http://framework:8080/health
16:26:14  curl -s http://framework:8080/models
16:26:14  jq -r '.data[] | "\(.id)\t\(.status.value)"'
16:26:14  curl -s http://framework:8080/models
16:26:14  jq '.data | length'
16:26:51  source <scratchpad>/fw-store-dry.sh
16:26:51  : 'framework: the store extras, a dry run of hf cache rm (12B, 31B, E4B QAT GGUFs; granite safetensors)'
16:26:51  ssh framework 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache ls --format json; mise exec -- hf cache rm --dry-run model/google/gemma-4-12B-it-qat-q4_0-gguf model/google/gemma-4-31B-it-qat-q4_0-gguf model/google/gemma-4-E4B-it-qat-q4_0-gguf model/ibm-granite/granite-embedding-english-r2 2>&1 | grep -v Hint; du -sb /srv/models; df -B1 /srv/models | tail -1'
16:27:03  source <scratchpad>/fw-store-rm.sh
16:27:03  : 'framework: remove the store extras (12B, 31B, E4B QAT GGUFs; granite safetensors); set A keeps its four'
16:27:03  ssh framework 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --yes model/google/gemma-4-12B-it-qat-q4_0-gguf model/google/gemma-4-31B-it-qat-q4_0-gguf model/google/gemma-4-E4B-it-qat-q4_0-gguf model/ibm-granite/granite-embedding-english-r2 2>&1 | grep -v Hint; mise exec -- hf cache ls 2>&1 | grep -v Hint; ls /srv/models; find /srv/models/blobs -type f -size +1M -printf "%s\t%p\n"; du -sb /srv/models; df -B1 /srv/models | tail -1'
16:27:03  curl -s http://framework:8080/models
16:27:03  jq -r '.data[] | "\(.id)\t\(.status.value)"'
16:27:15  source <scratchpad>/fw-store-probe.sh
16:27:15  : 'framework: a removed section does not load (offline = true in [*]), as on the GB10s'
16:27:15  MEASURE_LOAD_WAIT=60
16:27:15  load google/gemma-4-12B-it-qat-q4_0-gguf:Q4_0
16:27:19  ssh framework 'du -sb /srv/models; ls /srv/models'
16:28:55  source <scratchpad>/helper-test.sh
16:28:55  : 'step helpers: watch on the amdgpu host refuses without the system floor, then samples both pools (a 25 s sleep, no load)'
16:28:55  unset MEASURE_SYSTEM_FLOOR_GIB
16:28:55  watch framework-helper-refuse sleep 1
16:28:55  echo 'refuse rc 2'
16:28:55  MEASURE_SAMPLE_EVERY=5
16:28:55  watch framework-helper-test sleep 12
16:29:11  summarize framework-helper-test
16:29:11  cat /home/jaime/experiments/spike-model-layout/.state/measure/framework/framework-helper-test.watch.tsv
16:29:11  memory
16:29:33  source <scratchpad>/helper-test-stop.sh
16:29:33  : 'step helpers: each floor stops a run (floors set above the idle pools; a 60 s sleep, no load)'
16:29:33  MEASURE_SAMPLE_EVERY=5
16:29:33  watch framework-helper-stop-system sleep 60
16:29:39  summarize framework-helper-stop-system
16:29:39  MEASURE_SAMPLE_EVERY=5
16:29:39  watch framework-helper-stop-gtt sleep 60
16:29:44  summarize framework-helper-stop-gtt
16:30:00  source <scratchpad>/fw-anchors.sh
16:30:00  : 'FA/FB: anchors A and B on the Framework, each on a freshly loaded gpt-oss-120b set-a section alone, under watch with both floors'
16:30:00  unload --all
16:30:00  memory
16:30:01  tailscale ping -c 1 framework
16:30:01  load gpt-oss-120b-MXFP4-set-a
16:30:22  cell framework-fa anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
16:31:22  memory
16:31:23  unload gpt-oss-120b-MXFP4-set-a
16:31:26  tailscale ping -c 1 framework
16:31:26  load gpt-oss-120b-MXFP4-set-a
16:31:47  cell framework-fb anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
16:33:58  memory
16:33:58  footprint 2026-11-10T21:29:58Z
16:33:58  unload gpt-oss-120b-MXFP4-set-a
16:34:01  memory
16:48:04  source <scratchpad>/fw-x-arrange.sh
16:48:04  : 'framework arm on the Framework: unload all, load set A capped 26B-A4B and E4B (4 x 8,192) and granite (16 x 8,192), nothing else, idle 30 s, read both pools and each process'
16:48:04  date -u +%FT%TZ
16:48:04  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:48:04  tailscale ping -c 1 framework
16:48:04  unload --all
16:48:04  memory
16:48:04  t0=2026-11-10T21:48:04Z
16:48:04  for s in google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16
16:48:04  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
16:48:11  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
16:48:14  load mrutkows/granite-embedding-english-r2-GGUF:BF16
16:48:17  date -u +%FT%TZ
16:48:17  sleep 30
16:48:47  : 'framework arm loaded since 2026-11-10T21:48:04Z, idle 30 s'
16:48:47  memory
16:48:47  footprint 2026-11-10T21:48:04Z
16:48:47  curl -s http://framework:8080/models
16:48:47  jq -r '.data[] | select(.status.value == "loaded") | "\(.id): \(.status.args | join(" "))"'
16:48:51  source <scratchpad>/fw-x-sweep.sh
16:48:51  : 'framework-x-vision: the Framework'\''s vision sweep, role-split-vision-full, the other two sections loaded and idle, under watch with both floors'
16:48:51  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:48:51  date -u +%FT%TZ
16:48:51  tailscale ping -c 1 framework
16:48:51  loaded
16:48:51  t0=2026-11-10T21:48:51Z
16:48:51  cell framework-x-vision role-split-vision-full google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:54:34  memory
16:54:34  footprint 2026-11-10T21:48:51Z
16:54:42  source <scratchpad>/fw-x-sweep.sh
16:54:42  : 'framework-x-audio: the Framework'\''s audio sweep, role-split-audio-full, the other two sections loaded and idle, under watch with both floors'
16:54:42  date -u +%FT%TZ
16:54:42  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:54:42  tailscale ping -c 1 framework
16:54:43  loaded
16:54:43  t0=2026-11-10T21:54:43Z
16:54:43  cell framework-x-audio role-split-audio-full ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:57:34  memory
16:57:34  footprint 2026-11-10T21:54:43Z
16:57:45  source <scratchpad>/fw-x-sweep.sh
16:57:45  : 'framework-x-embed: the Framework'\''s embed sweep, role-split-embed, the other two sections loaded and idle, under watch with both floors'
16:57:45  date -u +%FT%TZ
16:57:45  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:57:45  tailscale ping -c 1 framework
16:57:45  loaded
16:57:46  t0=2026-11-10T21:57:46Z
16:57:46  cell framework-x-embed role-split-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
17:00:57  memory
17:00:57  footprint 2026-11-10T21:57:46Z
17:01:05  source <scratchpad>/mixed-fw.sh
17:01:05  : 'framework-p-target: the Framework'\''s vision 2, audio 2 and embedding 8 processes, 240 s each, started together with gb10-1'\''s agent and gb10-2'\''s three'
17:01:05  source <scratchpad>/after-fw.sh
17:01:05  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
17:01:05  date -u +%FT%TZ
17:01:05  tailscale ping -c 1 framework
17:01:05  loaded
17:01:05  GUIDELLM__SPEC__PROFILE__STREAMS=2
17:01:05  GUIDELLM__SPEC__PROFILE__STREAMS=2
17:01:05  wait
17:01:05  GUIDELLM__SPEC__PROFILE__STREAMS=8
17:01:05  cell framework-p-target-audio role-split-mixed-audio ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
17:01:05  cell framework-p-target-vision role-split-mixed-vision google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
17:01:05  cell framework-p-target-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
17:05:28  after_fw framework-p-target
17:05:47  source <scratchpad>/mixed-fw.sh
17:05:47  : 'framework-p-held: the Framework'\''s vision 1, audio 1 and embedding 8 processes, 240 s each, started together with gb10-1'\''s agent and gb10-2'\''s three'
17:05:47  source <scratchpad>/after-fw.sh
17:05:47  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
17:05:47  date -u +%FT%TZ
17:05:47  tailscale ping -c 1 framework
17:05:47  loaded
17:05:47  GUIDELLM__SPEC__PROFILE__STREAMS=1
17:05:47  wait
17:05:47  GUIDELLM__SPEC__PROFILE__STREAMS=1
17:05:47  GUIDELLM__SPEC__PROFILE__STREAMS=8
17:05:47  cell framework-p-held-audio role-split-mixed-audio ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
17:05:47  cell framework-p-held-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
17:05:47  cell framework-p-held-vision role-split-mixed-vision google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
17:10:19  after_fw framework-p-held
17:10:35  source <scratchpad>/end-state.sh
17:10:35  : 'framework slice 2 end state on framework (Behavior 12): its loaded sections by /models, its clone'\''s commit, both pools'
17:10:35  loaded
17:10:35  curl -s http://framework:8080/models
17:10:35  jq -r '.data[] | "\(.id)\t\(.status.value)"'
17:10:35  ssh framework 'cd ~/repos/spike-model-engines && git log --oneline -1'
17:10:35  memory
```

The helper test's `(unset MEASURE_SYSTEM_FLOOR_GIB; watch framework-helper-refuse sleep 1); echo
"refuse rc $?"` is one line of the step file, and the trace prints the `echo` with `$?` expanded.

### Commands as run (gb10-1)

From `.state/measure/gb10-1/2026-11-10.log`, from 16:34, left out as above. `after` (from
`after.sh`) drops the cache, runs `memory` and `footprint`, and stops the arm if the pool reads
under 12,492 MiB.

```
16:34:12  source <scratchpad>/base-gb10-1.sh
16:34:12  : 'framework baseline on gb10-1: drop the page cache, reload the agent-only section alone, idle 30 s, read'
16:34:12  date -u +%FT%TZ
16:34:12  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:34:12  tailscale ping -c 1 gb10-1
16:34:12  unload --all
16:34:16  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:34:16  memory
16:34:16  t0=2026-11-10T21:34:16Z
16:34:16  load gpt-oss-120b-MXFP4-agent-only
16:35:04  date -u +%FT%TZ
16:35:04  sleep 30
16:35:34  : 'agent-only loaded since 2026-11-10T21:34:16Z, idle 30 s'
16:35:34  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:35:35  memory
16:35:35  footprint 2026-11-10T21:34:16Z
16:35:41  source <scratchpad>/mixed-gb10-1.sh
16:35:41  : 'framework-b-target: the baseline'\''s agent process on gb10-1, 4 sessions, 240 s, started with gb10-2'\''s three'
16:35:41  source <scratchpad>/after.sh
16:35:41  date -u +%FT%TZ
16:35:41  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:35:41  tailscale ping -c 1 gb10-1
16:35:41  loaded
16:35:41  GUIDELLM__SPEC__PROFILE__STREAMS=4
16:35:41  cell framework-b-target-agent role-split-mixed-agent gpt-oss-120b-MXFP4-agent-only openai/gpt-oss-120b
16:40:06  after framework-b-target-agent
16:40:20  source <scratchpad>/mixed-gb10-1.sh
16:40:20  : 'framework-b-held: the baseline'\''s agent process on gb10-1, 4 sessions, 240 s, started with gb10-2'\''s three'
16:40:20  source <scratchpad>/after.sh
16:40:20  date -u +%FT%TZ
16:40:20  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:40:20  tailscale ping -c 1 gb10-1
16:40:20  loaded
16:40:20  GUIDELLM__SPEC__PROFILE__STREAMS=4
16:40:20  cell framework-b-held-agent role-split-mixed-agent gpt-oss-120b-MXFP4-agent-only openai/gpt-oss-120b
16:44:45  after framework-b-held-agent
17:01:05  source <scratchpad>/mixed-p-gb10-1.sh
17:01:05  : 'framework-p-target: the Framework arm'\''s agent process on gb10-1, 4 sessions, 240 s, started with gb10-2'\''s three and the Framework'\''s three'
17:01:05  source <scratchpad>/after.sh
17:01:05  date -u +%FT%TZ
17:01:05  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
17:01:05  tailscale ping -c 1 gb10-1
17:01:05  loaded
17:01:05  GUIDELLM__SPEC__PROFILE__STREAMS=4
17:01:05  cell framework-p-target-agent role-split-mixed-agent gpt-oss-120b-MXFP4-agent-only openai/gpt-oss-120b
17:05:30  after framework-p-target-agent
17:05:47  source <scratchpad>/mixed-p-gb10-1.sh
17:05:47  : 'framework-p-held: the Framework arm'\''s agent process on gb10-1, 4 sessions, 240 s, started with gb10-2'\''s three and the Framework'\''s three'
17:05:47  source <scratchpad>/after.sh
17:05:47  date -u +%FT%TZ
17:05:47  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
17:05:47  tailscale ping -c 1 gb10-1
17:05:47  loaded
17:05:47  GUIDELLM__SPEC__PROFILE__STREAMS=4
17:05:47  cell framework-p-held-agent role-split-mixed-agent gpt-oss-120b-MXFP4-agent-only openai/gpt-oss-120b
17:10:12  after framework-p-held-agent
17:10:34  source <scratchpad>/end-state.sh
17:10:34  : 'framework slice 2 end state on gb10-1 (Behavior 12): its loaded sections by /models, its clone'\''s commit, both pools'
17:10:34  loaded
17:10:34  curl -s http://gb10-1:8080/models
17:10:34  jq -r '.data[] | "\(.id)\t\(.status.value)"'
17:10:34  ssh gb10-1 'cd ~/repos/spike-model-engines && git log --oneline -1'
17:10:34  memory
```

### Commands as run (gb10-2)

From `.state/measure/gb10-2/2026-11-10.log`, from 16:29, left out as above.

```
16:29:11  source <scratchpad>/helper-test-gb.sh
16:29:11  : 'step helpers: watch on a GB10 reads as before (MemAvailable, one pool; a 12 s sleep, no load)'
16:29:11  MEASURE_SAMPLE_EVERY=5
16:29:11  watch gb10-2-helper-test sleep 12
16:29:28  summarize gb10-2-helper-test
16:29:28  cat /home/jaime/experiments/spike-model-layout/.state/measure/gb10-2/gb10-2-helper-test.watch.tsv
16:29:28  memory
16:34:12  source <scratchpad>/base-gb10-2.sh
16:34:12  : 'framework baseline on gb10-2: unload all, drop the page cache, load the 16-slot 26B-A4B, the 16-slot E4B and granite, idle 30 s, read'
16:34:12  date -u +%FT%TZ
16:34:12  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:34:12  tailscale ping -c 1 gb10-2
16:34:12  unload --all
16:34:22  ssh gb10-2 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:34:22  memory
16:34:22  t0=2026-11-10T21:34:22Z
16:34:22  for s in gemma-4-26B-A4B-it-qat-Q4_0-16-slots gemma-4-E4B-it-Q8_0-16-slots mrutkows/granite-embedding-english-r2-GGUF:BF16
16:34:22  load gemma-4-26B-A4B-it-qat-Q4_0-16-slots
16:34:37  load gemma-4-E4B-it-Q8_0-16-slots
16:34:46  load mrutkows/granite-embedding-english-r2-GGUF:BF16
16:34:49  date -u +%FT%TZ
16:34:49  sleep 30
16:35:19  : 'split set loaded since 2026-11-10T21:34:22Z, idle 30 s'
16:35:19  ssh gb10-2 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:35:20  memory
16:35:20  footprint 2026-11-10T21:34:22Z
16:35:41  source <scratchpad>/mixed-gb10-2.sh
16:35:41  : 'framework-b-target: the baseline'\''s vision 4, audio 4 and embedding 16 processes on gb10-2, 240 s each, started together with gb10-1'\''s agent'
16:35:41  source <scratchpad>/after.sh
16:35:41  date -u +%FT%TZ
16:35:41  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:35:41  tailscale ping -c 1 gb10-2
16:35:41  loaded
16:35:41  GUIDELLM__SPEC__PROFILE__STREAMS=4
16:35:41  GUIDELLM__SPEC__PROFILE__STREAMS=4
16:35:41  GUIDELLM__SPEC__PROFILE__STREAMS=16
16:35:41  wait
16:35:41  cell framework-b-target-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
16:35:41  cell framework-b-target-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:35:41  cell framework-b-target-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
16:40:07  after framework-b-target
16:40:20  source <scratchpad>/mixed-gb10-2.sh
16:40:20  : 'framework-b-held: the baseline'\''s vision 1, audio 1 and embedding 16 processes on gb10-2, 240 s each, started together with gb10-1'\''s agent'
16:40:20  source <scratchpad>/after.sh
16:40:20  date -u +%FT%TZ
16:40:20  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
16:40:20  tailscale ping -c 1 gb10-2
16:40:20  loaded
16:40:20  GUIDELLM__SPEC__PROFILE__STREAMS=16
16:40:20  wait
16:40:20  GUIDELLM__SPEC__PROFILE__STREAMS=1
16:40:20  GUIDELLM__SPEC__PROFILE__STREAMS=1
16:40:20  cell framework-b-held-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:40:20  cell framework-b-held-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
16:40:20  cell framework-b-held-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
16:44:48  after framework-b-held
17:01:05  source <scratchpad>/mixed-p-gb10-2.sh
17:01:05  : 'framework-p-target: the Framework arm'\''s vision 2, audio 2 and embedding 8 processes on gb10-2, 240 s each, started together with gb10-1'\''s agent and the Framework'\''s three'
17:01:05  source <scratchpad>/after.sh
17:01:05  date -u +%FT%TZ
17:01:05  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
17:01:05  tailscale ping -c 1 gb10-2
17:01:05  loaded
17:01:05  GUIDELLM__SPEC__PROFILE__STREAMS=2
17:01:05  wait
17:01:05  GUIDELLM__SPEC__PROFILE__STREAMS=2
17:01:05  GUIDELLM__SPEC__PROFILE__STREAMS=8
17:01:05  cell framework-p-target-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
17:01:05  cell framework-p-target-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
17:01:05  cell framework-p-target-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
17:05:34  after framework-p-target
17:05:47  source <scratchpad>/mixed-p-gb10-2.sh
17:05:47  : 'framework-p-held: the Framework arm'\''s vision 1, audio 1 and embedding 8 processes on gb10-2, 240 s each, started together with gb10-1'\''s agent and the Framework'\''s three'
17:05:47  source <scratchpad>/after.sh
17:05:47  date -u +%FT%TZ
17:05:47  tee -a /home/jaime/experiments/spike-model-layout/.state/framework/ping-2026-11-10.txt
17:05:47  tailscale ping -c 1 gb10-2
17:05:47  loaded
17:05:47  GUIDELLM__SPEC__PROFILE__STREAMS=1
17:05:47  GUIDELLM__SPEC__PROFILE__STREAMS=1
17:05:47  GUIDELLM__SPEC__PROFILE__STREAMS=8
17:05:47  wait
17:05:47  cell framework-p-held-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
17:05:47  cell framework-p-held-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
17:05:47  cell framework-p-held-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
17:10:16  after framework-p-held
17:10:34  source <scratchpad>/end-state.sh
17:10:34  : 'framework slice 2 end state on gb10-2 (Behavior 12): its loaded sections by /models, its clone'\''s commit, both pools'
17:10:34  loaded
17:10:34  curl -s http://gb10-2:8080/models
17:10:34  jq -r '.data[] | "\(.id)\t\(.status.value)"'
17:10:34  ssh gb10-2 'cd ~/repos/spike-model-engines && git log --oneline -1'
17:10:34  memory
```

Each `cell` printed its summary lines, for example X-audio's (16:57:34):

```
1 stream(s): requests ok 40, errored 0, incomplete 1 of 41, full NO (64 wanted); output tok/s completed 27.03, every-token 27.03; TTFT median 224 ms; ITL median 24.48 ms; audio s/s 9.64
2 stream(s): requests ok 47, errored 0, incomplete 2 of 49, full NO (64 wanted); output tok/s completed 31.27, every-token 31.37; TTFT median 336 ms; ITL median 48.77 ms; audio s/s 11.31
3 stream(s): requests ok 62, errored 0, incomplete 2 of 64, full NO (64 wanted); output tok/s completed 38.17, every-token 38.67; TTFT median 472 ms; ITL median 50.45 ms; audio s/s 14.1
4 stream(s): requests ok 64, errored 0, incomplete 0 of 64, full yes; output tok/s completed 45.44, every-token 45.44; TTFT median 486 ms; ITL median 56.93 ms; audio s/s 16.89
8 stream(s): requests ok 64, errored 0, incomplete 0 of 64, full yes; output tok/s completed 46.64, every-token 46.64; TTFT median 2003 ms; ITL median 58.9 ms; audio s/s 17.39
```

### Commands not in a step log

The stack and phased-update reads, each step file's launch, and the per-level tables ran from the
laptop outside the step helpers. They are quoted from the session's command history, each with its
time (UTC), from the project's root; `<scratchpad>` stands for the scratch directory as above.

The stack read (21:25:15Z) and the phased-update read (21:25:42Z):

```sh
mkdir -p .state/framework && { date -Is; for h in gb10-1 gb10-2; do echo "== $h"; timeout 90 ssh -o BatchMode=yes $h 'apt list --upgradable 2>/dev/null | grep -vc "^Listing"; uname -r; nvidia-smi --query-gpu=driver_version --format=csv,noheader; nvidia-smi | grep -o "CUDA Version: [0-9.]*"; docker --version; nvidia-ctk --version | head -1; . /etc/os-release; echo $PRETTY_NAME; cat /etc/dgx-release 2>/dev/null | grep -i version | head -2; docker ps --format "{{.Names}} {{.Image}} {{.Status}}"; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1'; done; echo "== framework"; timeout 120 ssh -o BatchMode=yes framework 'checkupdates 2>/dev/null | wc -l; uname -r; pacman -Q mesa vulkan-radeon docker linux-firmware 2>/dev/null; docker ps --format "{{.Names}} {{.Image}} {{.Status}}"; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1'; for h in gb10-1 gb10-2 framework; do tailscale ping -c 1 $h; done; } 2>&1 | tee .state/framework/stack-2026-11-10.txt
{ date -Is; for h in gb10-1 gb10-2; do echo "== $h: apt-get -s upgrade (simulated, no root)"; ssh -o BatchMode=yes $h 'apt-get -s upgrade 2>/dev/null | grep -A3 -iE "deferred|^[0-9]+ upgraded"; for p in snapd distro-info python3-distro-info; do apt-cache policy $p | grep -E "Candidate|phased" | tr -s " " | paste -sd" " | sed "s/^/$p: /"; done; zgrep -h "^Start-Date: 2026-11-10  16" -A2 /var/log/apt/history.log | grep -c "^Upgrade"; grep -c "2026-11-10 16:2.* upgrade " /var/log/dpkg.log'; done; } 2>&1 | tee .state/framework/phased-2026-11-10.txt
```

Each step file ran through `step.sh` (`.state/framework/step-files/step.sh`), which sources the
helpers for the host and exports its floors. The single-host steps, each with its output kept
(21:26:08Z to 21:30:00Z; the store clear's output into `.state/framework/framework-store-clear.log`,
the anchors' into `fw-anchors.out`):

```sh
D=<scratchpad>; bash $D/step.sh framework $D/fw-clone.sh 2>&1 | tail -30
D=<scratchpad>; bash $D/step.sh framework $D/fw-store-dry.sh 2>&1 | tail -40
D=<scratchpad>; bash $D/step.sh framework $D/fw-store-rm.sh 2>&1 | tail -40 | tee /home/jaime/experiments/spike-model-layout/.state/framework/framework-store-clear.log
D=<scratchpad>; bash $D/step.sh framework $D/fw-store-probe.sh 2>&1 | tail -15
D=<scratchpad>; bash $D/step.sh framework $D/helper-test.sh 2>&1 | tail -20
D=<scratchpad>; bash $D/step.sh gb10-2 $D/helper-test-gb.sh 2>&1 | tail -12
D=<scratchpad>; bash $D/step.sh framework $D/helper-test-stop.sh 2>&1 | grep -v "^  gpu\|readout"
D=<scratchpad>; bash $D/step.sh framework $D/fw-anchors.sh > $D/fw-anchors.out 2>&1; grep -v "^  gpu" $D/fw-anchors.out | tail -50
```

The baseline reload on both GB10s at once (21:34:12Z), and the baseline cells, B-target (21:35:41Z)
and B-held (21:40:19Z). `mixed.sh` runs `mixed-gb10-1.sh` and `mixed-gb10-2.sh` through `step.sh`
in the background on both hosts at once, with `MIX`, `AGENT`, `VISION`, `AUDIO` and `EMBED`
exported; what each step file ran is in the step logs above:

```sh
D=<scratchpad>; bash $D/step.sh gb10-1 $D/base-gb10-1.sh > $D/base-gb10-1.out 2>&1 </dev/null & bash $D/step.sh gb10-2 $D/base-gb10-2.sh > $D/base-gb10-2.out 2>&1 </dev/null & wait; for h in 1 2; do echo "##### gb10-$h"; cat $D/base-gb10-$h.out; done
D=<scratchpad>; cp $D/base-gb10-*.out /home/jaime/experiments/spike-model-layout/.state/framework/; date -u +%FT%TZ; MIX=b-target AGENT=4 VISION=4 AUDIO=4 EMBED=16 bash $D/mixed.sh; date -u +%FT%TZ; ls $D/b-target*
D=<scratchpad>; date -u +%FT%TZ; MIX=b-held AGENT=4 VISION=1 AUDIO=1 EMBED=16 nohup bash $D/mixed.sh >/dev/null 2>&1 </dev/null & sleep 5; for i in $(seq 1 55); do [ -f $D/b-held.done ] && break; sleep 10; done; date -u +%FT%TZ; for h in 1 2; do echo "##### gb10-$h"; grep -E "pong|stream\(s\)|^exit|^watch|STOPPED|floor:|^memory|^  [a-z].*: pid|^pool|^\[" $D/b-held-gb10-$h.out; done
```

The Framework's arrangement (21:48:03Z) and its sweeps, X-vision (21:48:51Z), X-audio (21:54:42Z)
and X-embed (21:57:45Z), `fw-x-sweep.sh` taking its purpose, scenario, section and tokenizer from
the environment:

```sh
D=<scratchpad>; bash $D/step.sh framework $D/fw-x-arrange.sh > $D/fw-x-arrange.out 2>&1; echo rc $?; cat $D/fw-x-arrange.out
D=<scratchpad>; PURPOSE=vision SCENARIO=role-split-vision-full SECTION=google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 TOKENIZER=google/gemma-4-26B-A4B-it bash $D/step.sh framework $D/fw-x-sweep.sh > $D/fw-x-vision.out 2>&1; echo rc $?
D=<scratchpad>; PURPOSE=audio SCENARIO=role-split-audio-full SECTION=ggml-org/gemma-4-E4B-it-GGUF:Q8_0 TOKENIZER=google/gemma-4-E4B-it timeout 590 bash $D/step.sh framework $D/fw-x-sweep.sh > $D/fw-x-audio.out 2>&1; echo rc $?; cat $D/fw-x-audio.out; cd /home/jaime/experiments/spike-model-layout && jq -r --arg purpose audio -f bench/levels.jq .state/measure/framework/framework-x-audio.json
D=<scratchpad>; PURPOSE=embed SCENARIO=role-split-embed SECTION=mrutkows/granite-embedding-english-r2-GGUF:BF16 TOKENIZER=ibm-granite/granite-embedding-english-r2 timeout 590 bash $D/step.sh framework $D/fw-x-sweep.sh > $D/fw-x-embed.out 2>&1; echo rc $?; cat $D/fw-x-embed.out; cd /home/jaime/experiments/spike-model-layout && jq -r --arg purpose embed -f bench/levels.jq .state/measure/framework/framework-x-embed.json
```

The Framework arm's cells, P-target (22:01:05Z) and P-held (22:05:47Z). `mixed-p.sh` runs
`mixed-p-gb10-1.sh`, `mixed-p-gb10-2.sh` (copies of the baseline's GB10 step files, commands
unchanged) and `mixed-fw.sh` through `step.sh` in the background on all three hosts at once;
`VISION`, `AUDIO` and `EMBED` are each capability host's share:

```sh
D=<scratchpad>; MIX=p-target AGENT=4 VISION=2 AUDIO=2 EMBED=8 bash $D/mixed-p.sh; echo rc $?; cat $D/p-target.done
D=<scratchpad>; MIX=p-held AGENT=4 VISION=1 AUDIO=1 EMBED=8 bash $D/mixed-p.sh; echo rc $?; cat $D/p-held.done
```

The end-state reads (22:10:34Z), after the step file was written:

```sh
for h in gb10-1 gb10-2 framework; do echo "#### $h"; bash $D/step.sh $h $D/end-state.sh 2>&1 | tee $D/end-state-$h.out; done
```

**The per-level tables** in C, D, F, G, I, J and L, and the errors in D and L.4, were read from
the cells' JSON with [`bench/levels.jq`](../../bench/levels.jq) at 22:16:53Z, into
`.state/framework/jq-figures-slice3.txt`. The session's tables after each slice (21:45:04Z and
22:11:04Z, `jq-figures-slice1.txt` and `-slice2.txt`) read the same figures with the program as it
stood; vision's minimum and the count at ≤10 s, which an inline `jq` gave then, come from the
extended program here:

```sh
M=.state/measure; { date -u +%FT%TZ; for f in $M/framework/framework-f[ab].json; do echo "# ${f#$M/}"; jq -r --arg purpose agent -f bench/levels.jq $f; done; for p in agent vision audio embed; do for f in $M/*/framework-*-$p.json; do echo "# ${f#$M/}"; jq -r --arg purpose $p -f bench/levels.jq $f; done; done; for f in $M/*/framework-f[ab].json $M/*/framework-[bpx]-*.json; do jq -r --arg f "${f#$M/}" '.benchmarks[] | (.config.strategy.streams|tostring) as $s | .requests.errored[]? | "\($f) s=\($s): \(.info.error // .error // "?" | tostring | .[0:220])"' $f; done; } > .state/framework/jq-figures-slice3.txt 2>&1
```

## N. Open items for later tasks

None of these is decided here.

- **Vision and audio miss their floors beside each other on one GPU** (L.1), on both capability
  hosts, at 1 stream each, with memory to spare. Neither arrangement held vision or audio at the
  load target of 4, or at 1 stream a host with the other purposes running (J). Not isolated: no
  cell ran purposes in pairs, and no per-process GPU reading was taken.
- **Vision is bounded by one image encode at a time** (role-split L.1), and the Framework's
  26B-A4B shows the same pattern on Vulkan (F.1): two capability hosts hold at most 2 vision
  requests alone, against a target of 4 (J). The inference path for vision, audio and embedding on
  vLLM, on gb10-2 and on the Framework, is agent-vllm's, as pending roadmap edits (goal record).
- **gb10-1's thin margin**: 0.30 GiB above the floor at its lowest (L.5), with the agent's
  4-session target met.
- **The capped Gemma sections' RSS growth** (role-split L.2), now seen on Vulkan, smaller there
  (+1,252 MiB on the 26B-A4B at 4 slots) (K.2).
- **Granite's idle-slot saves** on both capability hosts (L.3), an intake note.
- **The Gemma 4 output-parser error**, 2 more requests (L.4), and GuideLLM's JSON decode error, 1
  more (D).
- **The Gemma models' trained contexts**, still unread (K.4).
