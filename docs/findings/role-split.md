# Finding: set A on one GB10 against the roles split across both

Measured 2026-11-10, task `role-split`. This finding is dated: every figure holds for the versions,
stack, preset and network path below, on that day, and nothing after it.

**What it establishes.** How many sessions or requests each placed model holds at its context
before its knee or its speed floor, in two arrangements: the full set (set A, its Gemma prompt
cache capped, on one GB10) and the split (one GB10 serving the agent alone, the other vision,
audio and embedding). It answers evidence 3 (section I) and evidence 4 (section J), adds the
capacity rows it measured beside the [footprint finding](footprint.md)'s table (section K), and
closes three of footprint's six open items, two of them in part (section K.4). On the way it found that the capped Gemma
sections still grow their RSS under load, that vision answers about 0.23 requests a second however
many streams send them, in both arrangements, because the server encodes one image at a time
(L.1), and that the agent-only GB10 sits 1.39 GiB above its
floor idle. It decides nothing.

| Host | Serves at the end of the session |
| --- | --- |
| gb10-1 | `gpt-oss-120b-MXFP4-agent-only` (c 1,179,648, 16 slots, unified), 12.47 GiB available |
| gb10-2 | `gemma-4-26B-A4B-it-qat-Q4_0-16-slots`, `gemma-4-E4B-it-Q8_0-16-slots` and granite, 68.94 GiB available |
| framework | set A from main, untouched: no read, load, request or clone change this task |

Both GB10s' spike-model-engines clones are on the local `hosts` branch at 2d7ae32 (section A).

## Stack, engine and network path

Read by the session over SSH, read-only, at 2026-11-10T06:22:39-05:00 (11:22:39Z), before the root
updates (`.state/role-split/stack-pre-2026-11-10.txt`), and again at 11:33:53Z, after them
(`.state/role-split/stack-2026-11-10.txt`):

| Host | Pending updates before → after | OS | Kernel | GPU stack | Docker | Engine |
| --- | --- | --- | --- | --- | --- | --- |
| gb10-1 | 10 → 0 (apt) | DGX OS 7.6.0 (`DGX_OTA_VERSION`), Ubuntu 24.04.5 LTS | 7.0.0-1025-nvidia | driver 580.178.04, CUDA 13.0, NVIDIA Container Toolkit 1.20.1 | 29.6.2 | llama.cpp `server-cuda13-b12098`, up 19 hours (healthy) |
| gb10-2 | 10 → 0 (apt) | as gb10-1 | 7.0.0-1025-nvidia | as gb10-1 | 29.6.2 | as gb10-1 |

The stack is the footprint finding's in every column ([footprint](footprint.md), "Stack, engine
and network path"). The root updates (section A) moved no kernel, driver, CUDA or toolkit.

**Network path.** `tailscale ping -c 1` from the laptop, before and after the updates: gb10-1 via
192.168.1.216, 2 ms both times; gb10-2 via 192.168.1.138, 0 s then 1 ms. Both direct on the LAN for
the whole session.

**Engine and preset.** llama.cpp b12098 on both GB10s, each router serving spike-model-engines'
shared preset (`host/llama-preset/models.ini`) from the `role-split` branch at 2d7ae32 (section A).
The sections loaded, with their arguments as `load` printed them from the router's `/models`:

| Section id | Model | c | Slots | KV | Loaded arguments (`load`) |
| --- | --- | --- | --- | --- | --- |
| `gpt-oss-120b-MXFP4-set-a` | gpt-oss-120b MXFP4 (agent, full set, and the anchors) | 131072 | 4 | unified | `--no-cache-idle-slots --ctx-size 131072 --checkpoint-min-step 4096 --cache-ram 0 --kv-unified --parallel 4` |
| `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` | Gemma 4 26B-A4B QAT Q4_0 (vision, full set) | 32768 | 4 | per slot (8192 each) | `--no-cache-idle-slots --ctx-size 32768 --cache-ram 0 --swa-checkpoints 2 --parallel 4` |
| `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` | Gemma 4 E4B Q8_0 (audio, full set) | 32768 | 4 | per slot (8192 each) | `--no-cache-idle-slots --ctx-size 32768 --cache-ram 0 --swa-checkpoints 2 --parallel 4` |
| `mrutkows/granite-embedding-english-r2-GGUF:BF16` | granite-embedding-english-r2 BF16 (embedding, both arms) | 131072 | 16 | none logged | `--ctx-size 131072 --parallel 16` |
| `gpt-oss-120b-MXFP4-agent-only` | gpt-oss-120b MXFP4 (agent, split) | 1179648 | 16 | unified | `--no-cache-idle-slots --ctx-size 1179648 --checkpoint-min-step 4096 --cache-ram 0 --kv-unified --parallel 16` |
| `gemma-4-26B-A4B-it-qat-Q4_0-16-slots` | Gemma 4 26B-A4B QAT Q4_0 (vision, split) | 131072 | 16 | per slot (8192 each) | `--no-cache-idle-slots --ctx-size 131072 --cache-ram 0 --swa-checkpoints 2 --parallel 16` |
| `gemma-4-E4B-it-Q8_0-16-slots` | Gemma 4 E4B Q8_0 (audio, split) | 131072 | 16 | per slot (8192 each) | `--no-cache-idle-slots --ctx-size 131072 --cache-ram 0 --swa-checkpoints 2 --parallel 16` |

The preset key `ctx-checkpoints = 2` reaches the server as `--swa-checkpoints 2`, as `load` printed
it. The Gemma sections' vision keys (`ub`, `image-min-tokens`, `mtmd-batch-max-tokens`) are not in
`load`'s filter, so they aren't printed; the 16-slot 26B-A4B section carries them in 2d7ae32.

**Tools.** The step helpers in `scripts/measure-lib.sh`, as the footprint finding used them
(`load`, `unload`, `loaded`, `memory`, `footprint`, `cell`, `watch`, `readout`). Every cell is
GuideLLM 0.8.1 from the laptop (`mise.bench.toml`), run by `cell` under `watch`: the pool sampled
every 10 s into `<cell>.watch.tsv`, the cell stopped under the floor, capped at 10 min. Each cell's
GuideLLM JSON, `.watch.tsv`, `.exit` and `.log` are under `.state/measure/<host>/`, named
`role-split-*`. Every `.exit` reads 0: no cell was stopped. The scenarios are `bench/`'s, listed in
`bench/README.md`, "Role-split's cells". The steps ran from step files in the session's scratch
directory (untracked), sourced into a shell that sourced the helpers; the step log traces every
command inside them (section M).

**Per-level figures.** The step log holds each cell's summary line per level (requests, output
tok/s, TTFT and ITL medians). Request latency, the vision and audio floors, and the knee estimate
come from each cell's JSON through the session's per-level script, `levels.py` (untracked; its
command is under "Commands not in a step log"). It judges agent by ITL median ≤100 ms, vision by
the median request latency ≤10 s, audio by the median of each request's RTFx (its clip's seconds
over its request time) ≥5, and embedding by mean prompt tok/s ≥4,300; a level with no successful
request misses.

**Reading the figures.** The pool is MemAvailable, read just after dropping the page cache
(`ssh <host> sudo -n /usr/sbin/sysctl vm.drop_caches=3`), against the floor of 12.2 GiB on both
GB10s. `watch`'s samples during a cell are not taken after a drop. The logs give buffers in MiB;
pools are in GiB (1 GiB = 1024 MiB). The command lists show the step logs' local times (UTC−5);
the prose gives UTC. Figures marked **(m)** are measured; **(c)** are computed from measured
figures, with the arithmetic shown.

## A. Hosts brought current, and the preset change (Behaviors 1, 2)

From `.state/role-split/root-updates.md`, the architect's root update, pasted in full in the
session. On both GB10s the architect ran:

```
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && cat /var/run/reboot-required 2>/dev/null; echo "exit $?"
```

The architect's record: 10 packages upgraded on each (apache2-bin 2.4.58-1ubuntu8.18,
google-chrome-stable 157.0.8103.50-1, libgphoto2-6t64 / -l10n / -port12t64 2.5.31-2.1ubuntu1.2,
libperl5.38t64 / perl / perl-base / perl-modules-5.38 5.38.2-3.2ubuntu0.7, nvidia-redfish-config
26.10-1); "Running kernel seems to be up-to-date." "No containers need to be restarted."
nvidia-redfish-config printed "Redfish IP address is incorrect. Redfish Host Interface not
configured." on both; autoremove removed nothing; `exit 1`, no reboot. The session's read
afterwards found 0 pending on both and the kernel unchanged.

**The preset change.** spike-model-engines commit 2d7ae32 on its `role-split` branch, "host/llama-preset:
cap the Gemma prompt cache; add role-split's agent-only and 16-slot sections", citing footprint's
sections G, I.4 and K:

- set A's `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` and `ggml-org/gemma-4-E4B-it-GGUF:Q8_0`
  take `cache-ram = 0`, `cache-idle-slots = false` and `ctx-checkpoints = 2`;
- `gpt-oss-120b-MXFP4-agent-only`: c 1179648, 16 slots, `kv-unified = true`, with set-a's
  `checkpoint-min-step = 4096`, `cache-ram = 0`, `cache-idle-slots = false` and its sampling;
- `gemma-4-26B-A4B-it-qat-Q4_0-16-slots`: c 131072, 16 slots, set A's 26B-A4B vision keys and the
  three cap keys;
- `gemma-4-E4B-it-Q8_0-16-slots`: c 131072, 16 slots, the three cap keys.

It reached both GB10s before merge by a push to each host's `hosts-next` and a local `hosts`
branch, and each router restarted to read it (`.state/role-split/push-restart-2026-11-10.txt`: on
each host `role-split -> hosts-next`, "Switched to a new branch 'hosts'", `2d7ae32`, health
`{"status":"ok"}`, and the preset's 12 sections listed, every one unloaded, the three new ones
among them). The Framework's clone was not touched.

## B. Anchors, parity between the GB10s (Behavior 3)

**Decision it informs:** whether cells on gb10-1 and gb10-2 compare, which the split's mixed cells
need. **Configuration.** Anchors A and B (`bench/anchor-a.yaml`, `bench/anchor-b.yaml`), each on a
freshly loaded `gpt-oss-120b-MXFP4-set-a` alone (nothing else loaded), gb10-1 then gb10-2, judged
against the hosts finding's run noise (A 2.37%, B 2.2%) on output tok/s and ITL.

| Run | gb10-1: ok / output tok/s / TTFT / ITL | gb10-2: ok / output tok/s / TTFT / ITL | gb10-2 against gb10-1 (c): output tok/s, ITL | Verdict |
| --- | --- | --- | --- | --- |
| A, 11:35Z / 11:40Z | 8 of 8 / 49.14 / 396 ms / 18.73 ms | 8 of 8 / 48.72 / 399 ms / 18.86 ms | −0.85%, +0.69% | within 2.37% |
| B, 11:37Z / 11:42Z | 31 ok, 1 errored / 78.58 / 1315 ms / 44.08 ms | 32 of 32 / 80.71 / 1373 ms / 43.83 ms | +2.71%, −0.57% | **missed** (2.71% over 2.2%) |
| B repeat, 11:45Z / 11:48Z | 32 of 32 / 81.34 / 1308 ms / 43.87 ms | 32 of 32 / 80.39 / 1380 ms / 44.66 ms | −1.17%, +1.80% | within 2.2% |

B's first run on gb10-1 had one errored request, GuideLLM's
`JSONDecodeError('Unterminated string starting at: line 1 column 64 (char 63)')` (section L.5), and
counted 31 of 32. B was repeated once on both hosts, as the brief states; the repeat held, so
**parity holds and cells compare across the two GB10s.** Pool after each run: 51.82 to 52.00 GiB
on both hosts, set-a alone.

## C. The full-set arm: capped set A on gb10-2 (Behavior 4)

**Decision it informs:** whether the Gemma cap holds set A above a GB10's floor under vision load,
the condition every computed placement assumed.

**Configuration.** gb10-2: `unload --all`, cache dropped (117.80 GiB available), set A's four
sections loaded in turn (45.3, 15.1, 9.1, 3.1 s; last at 11:52:15Z), idle 30 s, cache dropped and
read at 11:52:46Z. Then F-L2: footprint's L2 unchanged (`bench/footprint-l2.yaml`, vision-b at
1440p: 4 streams × 32 requests, one 1440p JPEG beside 200 text tokens, 64 out), 112 s.

**Set A idle, capped (m):** 21.57 GiB available, 9.37 GiB above the floor (footprint's gb10-1:
21.45). Each process read footprint's set A figures within 4 MiB: gpt-oss set-a 64911 / 1261 MiB
(GPU / RSS), 26B-A4B 18015 / 1214, E4B 6530 / 4141, granite 863 / 827; router 170 / 340. Every
logged buffer line matched footprint's section C line for line: the cap keys change no logged
buffer.

**F-L2 (m):** 31 of 32 requests ok, 1 errored; 20.68 output tok/s; TTFT median 10,244 ms; ITL
median 26.45 ms. The pool's lowest during the cell was **17.80 GiB** (11:53:47Z), 5.60 GiB above
the floor; 18.08 GiB after it. The `readout` counted 0 idle-slot saves, 0 prompt saves and 96
context checkpoints.

| | Footprint L2, gb10-1, cache at default (2026-11-09) | F-L2, gb10-2, capped |
| --- | --- | --- |
| Outcome | stopped by `watch` at 61 s, 12 of 32 complete | ran to its end, 31 ok, 1 errored |
| Pool lowest | 10.39 GiB (under the floor) | 17.80 GiB |
| 26B-A4B GPU, idle → after | 18015 → 18828 MiB | 18015 → 18828 MiB |
| 26B-A4B RSS, idle → after | 1217 → 10397 MiB (+9180) | 1214 → 3526 MiB (+2312) |
| Idle-slot / prompt saves | 30 / 40 | 0 / 0 |

So **the cap holds set A above the floor under L2**, and the 26B-A4B's RSS still grew by 2312 MiB,
a quarter of footprint's growth, with no save counted (section L.2). The errored request was
llama.cpp's Gemma 4 output parser, not memory (section L.4). By the architect's decision F-L2 was
not rerun: 31 of 32 meets Behavior 4 on memory.

## D. Knee sweeps (Behavior 5)

Every sweep is GuideLLM's knee profile with adaptive refinement off and no ramp-up (granite's is a
concurrent sweep), one purpose at a time, nothing reloaded within the arm after its fresh load. The
full set's sweeps ran on gb10-2 with the rest of set A loaded and idle; the split's ran on the
split's hosts, S-agent on gb10-1 alone, S-vision and S-audio on gb10-2 beside the other two
sections, idle. Levels are concurrent streams; for the agent, a stream is a session and a request
is one turn.

**The agent's session** (`bench/role-split-agent-full.yaml`, `-agent-split.yaml`): GuideLLM's
multi-turn synthetic conversation, 4 turns, the first 8,192 prompt tokens and the next three 512
each, exactly 512 out a turn, no think time; its last turn reads 11,264 tokens of history before its
own 512 out. At 110 s a level, a session reaching its fourth turn is counted incomplete at the cut.

### D.1 Agent

F-agent, gb10-2, `gpt-oss-120b-MXFP4-set-a` (c 131072, 4 slots, unified), levels [1, 2, 3, 4, 8],
110 s each, 11:57:33-12:07:22Z. **Knee 3.13** (breakpoint 3, saturation 4: "A rising segment
followed by a substantially flatter tail was detected").

| Streams | Turns ok / errored / incomplete | Output tok/s | TTFT median | ITL median | ITL p95 | Floor (ITL ≤100 ms) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 8 / 1 / 1 | 37.24 | 769 ms | 19.78 ms | 20.17 ms | meets |
| 2 | 10 / 0 / 2 | 46.55 | 1505 ms | 30.30 ms | 30.85 ms | meets |
| 3 | 12 / 0 / 3 | 55.85 | 2058 ms | 41.31 ms | 46.84 ms | meets |
| 4 | 12 / 0 / 4 | 55.85 | 1876 ms | 54.42 ms | 62.58 ms | meets |
| 8 | 8 / 0 / 8 | 37.24 | 18137 ms | 68.66 ms | 78.20 ms | meets |

**Holds 3 sessions** (the highest level meeting the floor at or below the knee). Every level met
the floor; 8 streams exceed set-a's 4 slots. The 1-stream error is GuideLLM's `JSONDecodeError`
(section L.5).

S-agent, gb10-1, `gpt-oss-120b-MXFP4-agent-only` (c 1,179,648, 16 slots, unified), levels
[1, 4, 8, 12, 16], 110 s each, 14:12:17-14:22:12Z. **No knee** ("No breakpoint satisfied the
saturation thresholds").

| Streams | Turns ok / errored / incomplete | Output tok/s | TTFT median | ITL median | ITL p95 | Floor (ITL ≤100 ms) |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | 8 / 0 / 1 | 37.24 | 963 ms | 19.57 ms | 20.15 ms | meets |
| 4 | 12 / 0 / 4 | 55.85 | 2906 ms | 50.97 ms | 66.42 ms | meets |
| 8 | 8 / 0 / 8 | 37.24 | 25279 ms | 109.63 ms | 140.45 ms | **misses** |
| 12 | 0 / 2 / 12 | 0 | – | – | – | **misses**: no turn completed |
| 16 | 0 / 0 / 16 | 0 | – | – | – | **misses**: no turn completed |

**Holds 4 sessions** (no knee: the highest level meeting the floor, by the session's decision). At
12 and 16 streams no session finished its first turn in 110 s; tokens were still generated (the
step log's every-token rate: 41.68 and 30.8 tok/s). The two errors at 12 are GuideLLM's
`JSONDecodeError`. The pool's lowest was 12.53 GiB (14:20:36Z), above the floor.

### D.2 Vision

Each request is one synthetic 1440p JPEG beside 200 text tokens, exactly 100 out
(`bench/role-split-vision-full.yaml`, `-vision-split.yaml`).

F-vision, gb10-2, set A's 26B-A4B (c 32768, 4 slots), levels [1, 2, 3, 4, 8], 60 s each,
12:07:23-12:13:09Z. **No knee.**

| Streams | Ok / errored / incomplete | Output tok/s | Requests/s | TTFT median | ITL median | Latency median / p90 | Floor (≤10 s) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 14 / 0 / 1 | 23.33 | 0.233 | 2686 ms | 13.17 ms | 3.99 / 4.02 s | meets |
| 2 | 14 / 0 / 2 | 23.33 | 0.233 | 5295 ms | 27.59 ms | 8.03 / 8.14 s | meets |
| 3 | 14 / 1 / 3 | 23.33 | 0.233 | 7861 ms | 32.57 ms | 11.06 / 11.22 s | **misses** |
| 4 | 14 / 2 / 4 | 23.33 | 0.233 | 10419 ms | 26.56 ms | 13.03 / 13.22 s | **misses** |
| 8 | 16 / 0 / 8 | 26.67 | 0.267 | 23108 ms | 27.13 ms | 25.82 / 25.94 s | **misses** |

**Holds 2 requests.** The 3 errors are the Gemma 4 output parser (section L.4).

S-vision, gb10-2, the 16-slot 26B-A4B (c 131072, 16 slots of 8192), levels [1, 4, 8, 12, 16],
90 s each, 14:22:20-14:30:41Z. **Knee 11.56** (breakpoint 12, saturation 12).

| Streams | Ok / errored / incomplete | Output tok/s | Requests/s | TTFT median | ITL median | Latency median / p90 | Floor (≤10 s) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 20 / 0 / 1 | 22.22 | 0.222 | 2951 ms | 13.86 ms | 4.32 / 4.41 s | meets |
| 4 | 22 / 2 / 4 | 24.44 | 0.244 | 10653 ms | 26.50 ms | 13.26 / 14.69 s | **misses** |
| 8 | 24 / 0 / 8 | 26.67 | 0.267 | 20588 ms | 42.51 ms | 24.78 / 26.02 s | **misses** |
| 12 | 23 / 1 / 12 | 25.56 | 0.256 | 30786 ms | 51.23 ms | 36.02 / 37.82 s | **misses** |
| 16 | 16 / 0 / 16 | 17.78 | 0.178 | 46479 ms | 63.80 ms | 52.79 / 52.86 s | **misses** |

**Holds 1 request.** The 3 errors are the Gemma 4 output parser. In both arms the requests answered
a second stay near 0.23 whatever the streams, and TTFT grows with each stream added (section L.1).

### D.3 Audio

Each request is one of the 73 LibriSpeech clips with the card's transcription prompt, up to 256 out;
each level stops at 30 s or 64 requests (`bench/role-split-audio-full.yaml`, `-audio-split.yaml`).

F-audio, gb10-2, set A's E4B (c 32768, 4 slots), levels [1, 2, 3, 4, 8], 12:13:10-12:15:52Z.
**Knee 4.08** (breakpoint 4, saturation 8).

| Streams | Ok / errored / incomplete | Output tok/s | TTFT median | ITL median | Latency median / p90 | RTFx median / min | Requests at RTFx ≥5 | Level duration | Floor (RTFx ≥5) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 49 / 0 / 1 | 31.97 | 161 ms | 21.65 ms | 0.50 / 0.96 s | 11.11 / 6.28 | 49 of 49 | 30 s | meets |
| 2 | 64 / 0 / 0 | 40.82 | 272 ms | 31.80 ms | 0.76 / 1.44 s | 6.95 / 4.01 | 60 of 64 | 30 s | meets |
| 3 | 64 / 0 / 0 | 47.91 | 366 ms | 41.68 ms | 0.99 / 1.99 s | 5.40 / 2.55 | 38 of 64 | 25 s | meets |
| 4 | 64 / 0 / 0 | 58.39 | 379 ms | 45.22 ms | 1.02 / 1.90 s | 4.97 / 2.13 | 32 of 64 | 20 s | **misses** |
| 8 | 64 / 0 / 0 | 61.02 | 1473 ms | 44.64 ms | 2.25 / 3.16 s | 2.43 / 0.98 | 4 of 64 | 20 s | **misses** |

**Holds 3 requests.** Level 4's median RTFx, 4.97, is under the floor by 0.03; half its requests
met it.

S-audio, gb10-2, the 16-slot E4B (c 131072, 16 slots of 8192), levels [1, 4, 8, 12, 16],
14:30:48-14:33:25Z. **No knee.**

| Streams | Ok / errored / incomplete | Output tok/s | TTFT median | ITL median | Latency median / p90 | RTFx median / min | Requests at RTFx ≥5 | Level duration | Floor (RTFx ≥5) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 22 / 0 / 0 | 18.27 | 675 ms | 22.17 ms | 1.14 / 1.82 s | 6.12 / 3.24 | 19 of 22 | 30 s | meets |
| 4 | 64 / 0 / 0 | 41.36 | 763 ms | 47.41 ms | 1.43 / 2.51 s | 3.84 / 1.95 | 8 of 64 | 29 s | **misses** |
| 8 | 64 / 0 / 0 | 49.70 | 1089 ms | 89.43 ms | 2.42 / 4.57 s | 2.22 / 1.30 | 0 of 64 | 24 s | **misses** |
| 12 | 64 / 0 / 0 | 49.64 | 1412 ms | 104.29 ms | 3.73 / 7.04 s | 1.48 / 0.80 | 0 of 64 | 24 s | **misses** |
| 16 | 64 / 0 / 0 | 59.86 | 1627 ms | 129.16 ms | 3.30 / 7.95 s | 1.46 / 0.71 | 0 of 64 | 20 s | **misses** |

**Holds 1 request.** At 1 stream the split's E4B ran slower than the full set's: RTFx median 6.12
against 11.11, TTFT 675 against 161 ms, 22 requests in 30 s against 49, with ITL alike (22.17
against 21.65 ms). Section L.6.

### D.4 Embedding

F-embed, gb10-2, granite (16 slots of 8192), `bench/role-split-embed.yaml`: 512-token inputs to
`/v1/embeddings`, concurrent [1, 2, 4, 8, 16], 30 s each, 12:15:53-12:19:17Z. Judged at ≥4,300
prompt tok/s. The full-set arm only; granite is the same section in the split.

| Streams | Ok / incomplete | Requests/s | Latency median | Prompt tok/s | Floor |
| --- | --- | --- | --- | --- | --- |
| 1 | 1554 / 0 | 51.77 | 0.02 s | 26,556 | meets |
| 2 | 3504 / 2 | 116.80 | 0.01 s | 59,918 | meets |
| 4 | 3470 / 2 | 115.60 | 0.03 s | 59,303 | meets |
| 8 | 2642 / 3 | 87.90 | 0.09 s | 45,093 | meets |
| 16 | 1601 / 16 | 53.37 | 0.30 s | 27,377 | meets |

**Holds 16 streams**, every level met. The `readout` counted 177,657 idle-slot saves in the run
(section L.3); granite's RSS grew 827 → 965 MiB.

## E. The 10-minute WAV probe (Behavior 6)

**Decision it informs:** what an 8,192-token E4B slot does with a 10-minute recording, against
footprint's 15,028 tokens (I.6). **Configuration.** The first 10 minutes of AMI ES2002a, 16 kHz
mono WAV (600.000 s, cut on the laptop; `bench/README.md`, "The audio probe, F-probe"), sent once
by curl to gb10-2's `/v1/audio/transcriptions` with `model=ggml-org/gemma-4-E4B-it-GGUF:Q8_0` (set
A's E4B, 4 slots of 8192), under `watch`, 12:19:20Z.

curl printed `400 0.715784s`. The response body, as returned
(`.state/measure/gb10-2/role-split-f-probe.response.json`):

```
{"error":{"code":400,"message":"request (15023 tokens) exceeds the available context size (8192 tokens), try increasing it","type":"exceed_context_size_error","n_prompt_tokens":15023,"n_ctx":8192}}
```

**The 10-minute WAV is 15,023 prompt tokens on this E4B, and an 8,192-token slot refuses it** with
HTTP 400 in 0.72 s. That is 25.04 tokens a second of audio (c: 15,023 / 600), against footprint's
15,028 and 25.05. No section changed on the result, as the brief states.

## F. Mixed cells (Behavior 7)

Each mixed cell starts four GuideLLM processes together, one a purpose, each at a constant
concurrency for 240 s (`bench/role-split-mixed-*.yaml`, streams from
`GUIDELLM__SPEC__PROFILE__STREAMS`). F-mixed ran on gb10-2 alone; S-mixed and S-knee ran the
agent's process on gb10-1 and the other three on gb10-2, both hosts' steps launched together.

**Decision it informs:** what each arrangement holds with every purpose loaded at once, at the
load targets (F-mixed, S-mixed: agent 4 sessions, vision 4, audio 4, embedding 16) and at the
split's knees (S-knee: agent 4, vision 1, audio 1, embedding 16, from D).

| Purpose | F-mixed (12:21:41Z) | S-mixed (14:34:23Z) | S-knee (14:40:24Z) |
| --- | --- | --- | --- |
| Agent | 4 sessions: 4 turns ok, 4 incomplete; 8.53 tok/s; TTFT 58,882 ms; ITL 237.67 ms (p95 285.20): **misses** | 4 sessions: 28 ok, 4 incomplete; 59.73 tok/s; TTFT 2972 ms; ITL 50.76 ms (p95 60.58): **meets** | 4 sessions: 32 ok, 4 incomplete; 68.27 tok/s; TTFT 2850 ms; ITL 50.76 ms (p95 52.13): **meets** |
| Vision | 4 streams: 16 ok, 4 incomplete; 6.67 tok/s; TTFT 37,533 ms; ITL 143.38 ms; latency 51.77 s (p90 54.20): **misses** | 4 streams: 24 ok, 4 incomplete; 10.00 tok/s; TTFT 25,735 ms; ITL 119.01 ms; latency 38.90 s (p90 41.46): **misses** | 1 stream: 23 ok, 1 incomplete; 9.58 tok/s; TTFT 6301 ms; ITL 37.82 ms; latency 10.14 s (p90 11.73): **misses** by 0.14 s |
| Audio | 4 streams: 124 ok, 4 incomplete; TTFT 2583 ms; ITL 285.00 ms; RTFx median 0.80, 7 of 124 at ≥5: **misses** | 4 streams: 143 ok, 4 incomplete; TTFT 2192 ms; ITL 241.43 ms; RTFx median 0.98, 0 of 143: **misses** | 1 stream: 79 ok, 1 incomplete; TTFT 1181 ms; ITL 82.66 ms; RTFx median 2.26, 0 of 79: **misses** |
| Embedding | 16 streams: 4179 ok; 8,933 prompt tok/s; latency 0.93 s: **meets** | 16 streams: 6474 ok; 13,838 prompt tok/s; latency 0.48 s: **meets** | 16 streams: 7000 ok; 14,962 prompt tok/s; latency 0.40 s: **meets** |
| Pool lowest | gb10-2 15.86 GiB (12:23:43Z) | gb10-1 12.51 GiB; gb10-2 68.69 GiB | gb10-1 12.47 GiB; gb10-2 68.85 GiB |
| Idle-slot saves (granite) | 43,743 | 82,541 | 92,480 |

Each process after the cell is in section H. The vision and audio processes on gb10-2 ran slower
in S-knee, at 1 stream each beside the other purposes, than alone in their sweeps at 1 stream:
vision 10.14 against 4.32 s, audio RTFx 2.26 against 6.12 (section L.6).

## G. The split loaded (Behavior 8)

**Decision it informs:** whether the agent-only section loads above a GB10's floor, against the
computation, and what the capability GB10 leaves free.

**gb10-1: the agent-only section alone.** `unload --all`, cache dropped (117.70 GiB available),
`gpt-oss-120b-MXFP4-agent-only` loaded in 51.3 s (14:10:20-14:11:11Z), idle 30 s, cache dropped and
read at 14:11:42Z: **13.59 GiB available (m), 1.39 GiB above the floor**; 104.11 GiB taken (c:
117.70 − 13.59). Process 102925 MiB GPU, 2419 MiB RSS; router 170 / 346. Cached after the drop
2.45 GiB.

Its buffers (m), as `footprint` printed them (14:11:44Z):

| Buffer | Agent-only, c 1,179,648 × 16, unified | set-a, c 131,072 × 4, unified (footprint C) | Change (c) |
| --- | --- | --- | --- |
| Weights GPU / host | 59851.68 / 586.82 | 59851.68 / 586.82 | 0 |
| Full-attention KV | 41472.00 (1179648 cells, 18 layers, 16/1 seqs) | 4608.00 (131072 cells, 4/1 seqs) | +36864.00, exactly 36,864 B/token × c |
| Sliding-window KV | 90.00 (2560 cells, 16/1 seqs) | 36.00 (1024 cells, 4/1 seqs) | +54.00 |
| Compute GPU (CUDA0) | 1316.68 | 221.04 | +1095.64 |
| Compute host (CUDA_Host) | 1249.18 | 153.54 | +1095.64 |
| Output (host) | 12.27 | 3.07 | +9.20 |

The GPU figure is the logged GPU buffers plus a CUDA context of 194.64 MiB (c: 102925 −
(59851.68 + 41472 + 90 + 1316.68)), inside footprint's 192.36 to 196.57.

**Against the computation.** The brief computed 4.1 GiB above the floor if compute stayed at its
c 131,072 figure, about 1.9 GiB if the attention mask grew it. The unified compute grew by 1095.64
MiB on the GPU and as much on the host, 2.14 GiB together (c), so the mask grew, and the load
landed at 1.39 GiB, about 0.5 GiB under the second figure. Against set-a on gb10-1 (65.33 GiB
taken, footprint C) the section took 38.78 GiB more (c); the process figures grew 38014 MiB GPU and
1154 MiB RSS, 38.25 GiB (c), and the other 0.53 GiB is not attributed by these reads.

Footprint's worked placement (I.7) computed 9 sessions of 131,072 tokens on 9 per-slot slots,
leaving 4.14 GiB above the floor without its reserve and 0.82 GiB with it. The loaded section is
the same 1,179,648 tokens as one unified pool over 16 slots.

**gb10-2: the capability host.** `unload --all`, cache dropped (117.60 GiB available), the 16-slot
26B-A4B (13.2 s), the 16-slot E4B (10.0 s) and granite (3.8 s) loaded, 14:10:34-14:11:01Z, idle
30 s, cache dropped and read at 14:11:33Z: **77.40 GiB available (m), 65.20 GiB above the floor**;
40.20 GiB taken (c). Processes (GPU / RSS, MiB): 26B-A4B 16-slot 25335 / 1231, E4B 16-slot 8546 /
4157, granite 863 / 827; router 170 / 561.

The 16-slot Gemma sections' buffers (m) and their 4-slot counterparts (footprint C, and this
session's F arm):

| Buffer | 26B-A4B, 16 slots | 26B-A4B, 4 slots | E4B, 16 slots | E4B, 4 slots |
| --- | --- | --- | --- | --- |
| Weights GPU / host | 13755.42 / 577.50 | the same | 4788.12 / 3536.00 | the same |
| Projector | 1139.46 | the same | 533.83 | the same |
| Full-attention KV | 2560.00 (8192 cells, 5 layers, 16/16 seqs) | 640.00 (4/4 seqs) | 2048.00 (8192 cells, 4 layers, 16/16 seqs) | 512.00 (4/4 seqs) |
| Sliding-window KV | 7200.00 (2304 cells, 25 layers, 16/16 seqs): 450 a slot | 1800.00: 450 a slot | 640.00 (1024 cells, 20 layers, 16/16 seqs): 40 a slot | 160.00: 40 a slot |
| Compute GPU / host | **335.29 / 70.61** | 335.29 / 70.61 | **137.02 / 50.03** | 137.02 / 50.03 |
| Projector compute GPU / CPU | **150.63 / 6.77** | 150.63 / 6.77 | **101.27 + 101.19 / 6.77 + 1.58** | the same |
| Output (host) | 16.00 | 4.00 | 16.00 | 4.00 |
| Projector worst case (estimate) | 1296.85 | 1296.85 | 746.89 | 746.89 |

**The Gemma compute buffers at 16 slots equal their 4-slot figures**, model and projector, on both
sections; KV scales with slots (20,480 and 16,384 B/token × 131,072, exactly). The GPU figures are
the logged GPU buffers plus 194.20 MiB (26B-A4B: 25335 − 25140.80) and 196.57 MiB (E4B: 8546 −
8349.43) (c), the contexts footprint measured.

## H. Memory through each arm (Behaviors 4, 7, 9)

Each read is after the cell: cache dropped, `memory`, then `footprint` (the `after` step, section
M). "Lowest" is `watch`'s during the cell. Processes in MiB, GPU / RSS. No cell went under the
floor, and nothing reloaded within an arm after its fresh load.

**Full set, gb10-2** (floor 12.2 GiB):

| After | Pool (GiB) | Lowest during | gpt-oss set-a | 26B-A4B | E4B | granite |
| --- | --- | --- | --- | --- | --- | --- |
| idle, 30 s | 21.57 | – | 64911 / 1261 | 18015 / 1214 | 6530 / 4141 | 863 / 827 |
| F-L2 | 18.08 | 17.80 | 64911 / 1261 | 18828 / 3526 | 6530 / 4141 | 863 / 827 |
| F-agent | 17.86 | 17.84 | 65017 / 1807 | 18828 / 3526 | 6530 / 4141 | 863 / 827 |
| F-vision | 17.99 | 17.10 | 65017 / 1807 | 18830 / 3215 | 6530 / 4141 | 863 / 827 |
| F-audio | 17.18 | 17.17 | 65017 / 1807 | 18830 / 3215 | 6760 / 4831 | 863 / 827 |
| F-embed | 16.91 | 16.89 | 65017 / 1807 | 18830 / 3215 | 6760 / 4831 | 975 / 965 |
| F-probe | 16.73 | 16.72 (one sample) | 65017 / 1807 | 18830 / 3215 | 6760 / 4923 | 975 / 965 |
| F-mixed | 16.24 | **15.86** | 65017 / 1807 | 18830 / 3723 | 6760 / 4913 | 975 / 966 |

**Split, gb10-1:**

| After | Pool (GiB) | Lowest during | gpt-oss agent-only |
| --- | --- | --- | --- |
| idle, 30 s | 13.59 | – | 102925 / 2419 |
| S-agent | 12.54 | 12.53 | 103029 / 3329 |
| S-mixed | 12.52 | 12.51 | 103029 / 3376 |
| S-knee | 12.47 | **12.47** | 103033 / 3413 |

**Split, gb10-2:**

| After | Pool (GiB) | Lowest during | 26B-A4B 16-slot | E4B 16-slot | granite |
| --- | --- | --- | --- | --- | --- |
| idle, 30 s | 77.40 | – | 25335 / 1231 | 8546 / 4157 | 863 / 827 |
| S-vision | 71.29 | 69.53 | 26150 / 6602 | 8546 / 4157 | 863 / 827 |
| S-audio | 70.21 | 70.18 | 26150 / 6602 | 8776 / 5096 | 863 / 827 |
| S-mixed | 69.60 | **68.69** | 26150 / 6710 | 8776 / 5319 | 975 / 965 |
| S-knee | 68.94 | 68.85 | 26150 / 7369 | 8778 / 5331 | 975 / 965 |

## I. Evidence 3: what each placed model holds, at its context

"Holds" is the highest level that meets the purpose's floor at or below the sweep's knee, or, where
GuideLLM found no knee, the highest level that meets it. Figures are at that level (D). Granite has
no TTFT or ITL; its figure is prompt tok/s.

| Arrangement | Model, section | Context | Knee | Holds | Output tok/s | TTFT median | ITL median | Purpose figure |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| Full set (gb10-2) | gpt-oss-120b, set-a | c 131,072 over 4 slots, unified | 3.13 | **3 sessions** | 55.85 | 2058 ms | 41.31 ms | ITL ≤100 ms at every level to 8 |
| Full set | 26B-A4B, capped, 4 slots | 8,192 a slot | none | **2 requests** | 23.33 | 5295 ms | 27.59 ms | latency 8.03 s |
| Full set | E4B, capped, 4 slots | 8,192 a slot | 4.08 | **3 requests** | 47.91 | 366 ms | 41.68 ms | RTFx 5.40 |
| Full set | granite | 8,192 a slot, 16 slots | (concurrent sweep) | **16 streams** | – | – | – | 27,377 prompt tok/s (26,556 to 59,918 across levels) |
| Split (gb10-1) | gpt-oss-120b, agent-only | c 1,179,648 over 16 slots, unified | none | **4 sessions** | 55.85 | 2906 ms | 50.97 ms | 8 sessions miss at 109.63 ms |
| Split (gb10-2) | 26B-A4B, 16 slots | 8,192 a slot | 11.56 | **1 request** | 22.22 | 2951 ms | 13.86 ms | latency 4.32 s; 4 streams 13.26 s |
| Split (gb10-2) | E4B, 16 slots | 8,192 a slot | none | **1 request** | 18.27 | 675 ms | 22.17 ms | RTFx 6.12; 4 streams 3.84 |
| Split (gb10-2) | granite | as the full set | not swept | 16 streams in S-mixed and S-knee | – | – | – | 13,838 and 14,962 prompt tok/s |

The agent's sessions are the 4-turn shape (D), at most 11,776 tokens each; sessions of 131,072
tokens stay computed (footprint I.4, I.7). The E4B's slot does not take a 10-minute recording
(section E).

## J. Evidence 4: the full set against the split

| | Full set: set A on gb10-2 | Split: agent on gb10-1; vision, audio, embedding on gb10-2 |
| --- | --- | --- |
| **Each purpose alone, held (D)** | agent 3, vision 2, audio 3, embedding 16 | agent 4, vision 1, audio 1, embedding not swept |
| **At the load targets** (agent 4, vision 4, audio 4, embedding 16, all at once) | F-mixed: **embedding only meets**. Agent ITL 237.67 ms; vision 51.77 s an image; audio RTFx 0.80; embedding 8,933 tok/s | S-mixed: **agent and embedding meet**. Agent ITL 50.76 ms; vision 38.90 s; audio RTFx 0.98; embedding 13,838 tok/s |
| **At the knees** | sweeps only, one purpose at a time with the rest idle: agent 3 at ITL 41.31 ms; vision 2 at 8.03 s; audio 3 at RTFx 5.40 | S-knee (agent 4, vision 1, audio 1, embedding 16 at once): **agent and embedding meet**; vision 10.14 s (misses by 0.14 s); audio RTFx 2.26 |
| **Per-stream speed, agent** | 1 session ITL 19.78 ms; 4 sessions 54.42 ms alone, 237.67 ms mixed | 1 session 19.57 ms; 4 sessions 50.97 ms alone, 50.76 ms mixed |
| **Per-stream speed, vision** | 1 stream 3.99 s; 4 streams 13.03 s alone, 51.77 s mixed | 1 stream 4.32 s alone, 10.14 s mixed; 4 streams 13.26 s alone, 38.90 s mixed |
| **Per-stream speed, audio** | 1 stream RTFx 11.11; 4 streams 4.97 alone, 0.80 mixed | 1 stream 6.12 alone, 2.26 mixed; 4 streams 3.84 alone, 0.98 mixed |
| **Memory left, idle** | gb10-2 21.57 GiB (9.37 above the floor); gb10-1 free for another role | gb10-1 13.59 GiB (1.39 above); gb10-2 77.40 GiB (65.20 above) |
| **Memory left, lowest under load** | gb10-2 15.86 GiB (F-mixed; 3.66 above) | gb10-1 12.47 GiB (S-knee; 0.27 above); gb10-2 68.69 GiB (S-mixed; 56.49 above) |
| **Errors** | 1 parser error in F-L2, 3 in F-vision; 1 JSON decode in F-agent | 3 parser errors in S-vision; 2 JSON decode in S-agent |

So, at the load targets, the split held the agent where the full set did not (ITL 50.76 against
237.67 ms) and gave embedding 1.55 times the throughput (c: 13,838 / 8,933); neither held vision or
audio at 4 streams. At its knees the split held the agent and embedding with all four running, and
missed vision and audio at 1 stream each. Memory moved the other way on the agent's host: the
full set leaves 3.66 GiB above gb10-2's floor at its lowest; the split leaves 0.27 GiB above
gb10-1's, and 56.49 GiB above gb10-2's.

## K. Capacity rows, measured (Behavior 11)

Rows to read beside footprint's capacity table ([footprint](footprint.md), section I), every one
measured **(m)** on a GB10 on 2026-11-10. Footprint's table stays as written; where a row here
replaces one of its computed assumptions, K.4 says so.

### K.1 Buffers (m, MiB, logged at load)

| Section | Weights GPU / host | Full-attention KV | Per 1,000 tokens | Sliding-window KV | Compute GPU / host | Projector compute GPU / CPU | Output |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gpt-oss-120b agent-only (c 1,179,648 × 16, unified) | 59851.68 / 586.82 | 41472.00 | 35.16 (36,864 B/token) | 90.00 for the unified pool at 16 slots | **1316.68 / 1249.18** | – | 12.27 |
| 26B-A4B 16 slots (c 131,072, 8,192 a slot) | 13755.42 / 577.50 | 2560.00 | 19.53 (20,480 B/token) | 450 a slot | **335.29 / 70.61** | 150.63 / 6.77 | 16.00 |
| E4B 16 slots (c 131,072, 8,192 a slot) | 4788.12 / 3536.00 | 2048.00 | 15.63 (16,384 B/token) | 40 a slot | **137.02 / 50.03** | 202.46 / 8.35 | 16.00 |
| 26B-A4B and E4B 4 slots, capped | footprint's I.1 rows, unchanged by the cap keys | | | | | | |

### K.2 Process and pool (m)

Process figures GPU / RSS in MiB. "Warmed" is the process after its first cell in the arm (no
P-cell warm-up ran in this task); "under load" is the highest after any cell in the arm.

| Section | Arm, host | Idle in the arm (m) | Warmed: after its first cell (m) | Under load: highest after a cell (m) | RSS growth, idle → highest |
| --- | --- | --- | --- | --- | --- |
| 26B-A4B 4 slots, capped | full set, gb10-2 | 18015 / 1214 | 18828 / 3526 (F-L2) | 18830 / 3723 (F-mixed) | +2509 |
| E4B 4 slots, capped | full set, gb10-2 | 6530 / 4141 | 6760 / 4831 (F-audio) | 6760 / 4923 (F-probe) | +782 |
| gpt-oss set-a | full set, gb10-2 | 64911 / 1261 | 65017 / 1807 (F-agent) | 65017 / 1807 | +546 |
| granite | full set, gb10-2 | 863 / 827 | 975 / 965 (F-embed) | 975 / 966 (F-mixed) | +139 |
| gpt-oss agent-only | split, gb10-1 | 102925 / 2419 | 103029 / 3329 (S-agent) | 103033 / 3413 (S-knee) | +994 |
| 26B-A4B 16 slots, capped | split, gb10-2 | 25335 / 1231 | 26150 / 6602 (S-vision) | 26150 / 7369 (S-knee) | +6138 |
| E4B 16 slots, capped | split, gb10-2 | 8546 / 4157 | 8776 / 5096 (S-audio) | 8778 / 5331 (S-knee) | +1174 |
| granite | split, gb10-2 | 863 / 827 | 975 / 965 (S-mixed) | 975 / 965 | +138 |

### K.3 Per host and arrangement (m)

| Arrangement | Host | Before load | Idle, 30 s | Taken (c) | Lowest under load | Above the floor, idle / lowest |
| --- | --- | --- | --- | --- | --- | --- |
| Set A, Gemma capped | gb10-2 | 117.80 GiB | 21.57 GiB | 96.23 GiB | 15.86 GiB (F-mixed) | 9.37 / 3.66 GiB |
| Agent-only, c 1,179,648 × 16 | gb10-1 | 117.70 GiB | 13.59 GiB | 104.11 GiB | 12.47 GiB (S-knee) | 1.39 / 0.27 GiB |
| 26B-A4B 16 slots, E4B 16 slots, granite | gb10-2 | 117.60 GiB | 77.40 GiB | 40.20 GiB | 68.69 GiB (S-mixed) | 65.20 / 56.49 GiB |

### K.4 Footprint's open items (section K): what this finding closes

| Footprint's item | Here |
| --- | --- |
| The Gemma sections' prompt cache | **Closed on the GB10s:** capped in 2d7ae32; set A held L2 at 17.80 GiB lowest (C). The Framework still serves the uncapped sections from main, its side the framework task's. The capped sections' RSS still grows (L.2), a new open item. |
| The Framework's system memory has no floor | Open: no Framework step in this task. |
| The Framework's L2 parser error (`peg-gemma4`) | Open, and wider: the same error on CUDA on gb10-2, 7 requests (F-L2 1, F-vision 3, S-vision 3) (L.4). |
| Unmeasured in the computed columns | **Closed for two of three:** Gemma compute at 16 slots equals its 4-slot figure (G, K.1); gpt-oss's unified compute at c 1,179,648 is 1316.68 / 1249.18 MiB (G, K.1). Open: the Gemma models' trained contexts. |
| The E4B's 8,192-token slot against a 15,028-token request | **Closed:** the 10-minute WAV is 15,023 tokens and the slot refuses it with HTTP 400 (E). |
| The 26B-A4B on Vulkan past 4 slots or c 32768 | Open: the framework task's. |

## L. What else was found

### L.1 Vision answers about 0.23 requests a second, whatever the streams: one image encode at a time

In both arms the 26B-A4B's requests a second stayed between 0.222 and 0.267 from 1 stream to 12,
and output tok/s between 22.22 and 26.67 (D.2). TTFT grew by about 2.5 to 2.6 s for each stream
added: F-vision 2686, 5295, 7861, 10,419 ms at 1 to 4 streams; S-vision 2951 ms at 1, 10,653
at 4, 20,588 at 8, 30,786 at 12.

**The request timelines.** Each successful or errored request's start and end in S-vision's JSON,
in seconds from its level's start, are saved in `.state/role-split/s-vision-timelines-2026-11-10.txt`
(read from `.state/measure/gb10-2/role-split-s-vision.json` with `jq`, below). At 1 stream each
request took 4.27 to 4.52 s, one after another. At 4 streams the first wave's four requests all
started at 0 s and all ended together:

```
# streams start end duration ttft_ms
4 0 13.28 13.28 10671
4 0 13.25 13.25 10642
4 0 13.29 13.29 10694
4 0 13.31 13.3 10692
```

At 16 streams the first wave's sixteen requests started between 0 and 0.77 s and all ended
between 52.79 and 52.86 s, TTFT 45,782 to 46,547 ms. So a wave of n requests takes about n times
3.3 s (c: 13.3 / 4, 52.8 / 16), and its requests finish together: no request gets its first token
until every image in the wave is in. F-vision's 4-slot section shows the same at its 4 slots: its
first four requests at 4 streams ended at 12.98 to 13.04 s, and at 8 streams four ended at 12.88 s
and the next at 25.8 s.

**The router log.** gb10-2's router log for process `[45453]`, the 16-slot 26B-A4B, read
read-only at 14:59:52Z with the command below and saved in
`.state/role-split/vision-encode-gb10-2-2026-11-10.log` (its timestamps are minutes, seconds,
milliseconds and microseconds since the process started, during the 14:10:34Z load). The
projector loads on the GPU, with the section's minimum image size:

```
[45453] 0.11.604.962 I clip_ctx: CLIP using CUDA0 backend
[45453] 0.11.605.113 I load_hparams: image_min_pixels:   1290240 (custom value)
```

S-vision's first 4-stream wave, as logged: each slot logs `encoding mtmd batch`, then
`decoding image batch` about 2 s later, then the LLM's `image decoded` in under 90 ms, and only then
does the next slot's encode begin; the four prompt evals end within 54 ms of each other:

```
[45453] 13.33.890.299 I slot encode_mtmd_: id  5 | task 2108 | encoding mtmd batch from idx = 212, n_chunks = 1
[45453] 13.35.977.067 I decoding image batch 1/1, n_tokens_batch = 1100
[45453] 13.36.062.858 I image decoded (batch 1/1) in 86 ms
[45453] 13.36.448.094 I slot encode_mtmd_: id  6 | task 2110 | encoding mtmd batch from idx = 212, n_chunks = 1
[45453] 13.38.501.171 I decoding image batch 1/1, n_tokens_batch = 1100
[45453] 13.38.588.025 I image decoded (batch 1/1) in 87 ms
[45453] 13.38.934.010 I slot encode_mtmd_: id  7 | task 2112 | encoding mtmd batch from idx = 212, n_chunks = 1
[45453] 13.40.982.857 I decoding image batch 1/1, n_tokens_batch = 1100
[45453] 13.41.065.725 I image decoded (batch 1/1) in 83 ms
[45453] 13.41.067.729 I slot encode_mtmd_: id  8 | task 2113 | encoding mtmd batch from idx = 212, n_chunks = 1
[45453] 13.43.324.748 I decoding image batch 1/1, n_tokens_batch = 1100
[45453] 13.43.411.470 I image decoded (batch 1/1) in 86 ms
[45453] 13.46.472.576 I slot print_timing: id  5 | task 2108 | prompt eval time =    5275.45 ms /  1318 tokens (    4.00 ms per token,   249.84 tokens per second)
[45453] 13.46.500.307 I slot print_timing: id  6 | task 2110 | prompt eval time =   10029.02 ms /  1318 tokens (    7.61 ms per token,   131.42 tokens per second)
[45453] 13.46.522.442 I slot print_timing: id  7 | task 2112 | prompt eval time =   10073.65 ms /  1318 tokens (    7.64 ms per token,   130.84 tokens per second)
[45453] 13.46.525.949 I slot print_timing: id  8 | task 2113 | prompt eval time =   10064.14 ms /  1318 tokens (    7.64 ms per token,   130.96 tokens per second)
```

Over the whole extract (201 encodes, S-vision, S-mixed and S-knee), no two encodes overlap: every
`encoding mtmd batch` line is followed by its own `decoding image batch` before the next one. The
gap between them ran 2.05 to 6.03 s, median 2.27 s (c, from the extract); the `image decoded` step
82 to 253 ms, median 85 ms. A single request's prompt eval, 1318 tokens, logged 2537.64 to 2761.42
ms alone (the first five at 1 stream), and the first slot of a 4-stream wave 5275.45 ms
(another, later, 5272.11 ms); the slots behind it about 10 s.

**The mechanism, as this build shows it.** On llama-server b12098, with the 26B-A4B's image
encoder on CUDA0, the server encodes each slot's image in turn, one slot at a time, in its slot
processing (the `slot encode_mtmd_` lines), while the LLM's own image-token decode takes under
0.3 s and the output decode is batched across slots (D.2: ITL 13.86 ms at 1 stream, 26.50 at 4).
So added slots and streams add waiting, not throughput: vision throughput stays near one request
per wave-time per image, about 0.23 to 0.30 a second (c: 1 / 3.3 s), whatever the slot count.
This is the behavior observed on this build and these sections, not a claim about llama.cpp in
general. The 4-slot section's own log lines were not read; its timelines (above) match.

**Audio, for contrast.** The 16-slot E4B's log, process `[44615]`, read the same way and saved in
`.state/role-split/audio-encode-gb10-2-2026-11-10.log`: 458 `audio decoded (batch 1/1)` lines, 10
to 118 ms, median 15 ms (c, from the extract), its encoder also on CUDA0 (`clip_ctx: CLIP using
CUDA0 backend`).

### L.2 The capped Gemma sections still grow their RSS

With `cache-ram 0` and `cache-idle-slots false`, the readouts counted 0 idle-slot saves and 0 prompt
saves on every Gemma cell, yet the 26B-A4B's RSS grew 1214 → 3723 MiB in the full set and 1231 →
7369 MiB in the split (16 slots), and the E4B's 4141 → 4923 and 4157 → 5331 MiB (K.2). GPU memory
grew by at most 815 MiB a process. The readouts counted context checkpoints (96 in F-L2, 421 in
S-vision); what holds the RSS growth is not read here. The F-vision read (3215 MiB) came after
F-L2's (3526 MiB), so it does not only grow.

### L.3 Granite's idle-slot saves

Granite's section sets no cache keys. The readouts counted its idle-slot saves: 177,657 in F-embed
(five 30 s levels, the step log's `readout`), 43,743 in F-mixed, 82,541 in S-mixed and 92,480 in S-knee (the
gb10-2 readouts for each mixed cell; one S-knee readout read 92,479, and F-mixed's audio process,
which ended 10 s before the others, 43,689). Its RSS grew 827 → 965 MiB in each arm. By the
architect's decision granite stayed unchanged in both arms, and capping it is an intake note.

### L.4 The Gemma 4 output-parser error, on CUDA

Seven requests, every one on the 26B-A4B, errored with GuideLLM's
`ValueError('Streaming response returned an error: The model produced output that does not match
the expected peg-gemma4 format')`: F-L2 1 (4 streams), F-vision 3 (1 at 3 streams, 2 at 4),
S-vision 3 (2 at 4 streams, 1 at 12). Footprint recorded the same error once on the Framework's
Vulkan L2; here it is on CUDA too. By the architect's decision F-L2 was not rerun; no cell was
rerun for it.

### L.5 GuideLLM's JSON decode errors

Four agent requests errored in GuideLLM with
`JSONDecodeError('Unterminated string starting at: line 1 column 64 (char 63)')`, raised as it
decoded a streamed reply, on the laptop: anchor B's first run on gb10-1 1, F-agent 1 (1 stream),
S-agent 2 (12 streams). Anchor B's one is what put its first run outside parity (B).

### L.6 Speed the arms don't explain

- **Audio, single stream.** The split's 16-slot E4B ran at RTFx 6.12 alone against the full set's
  4-slot E4B at 11.11, its TTFT 675 against 161 ms, with ITL alike (D.3). The sections differ in
  slots and c; the hosts' other residents differ too. Not isolated.
- **Agent at 8 sessions.** S-agent's 8 sessions missed at ITL 109.63 ms and TTFT 25,279 ms, where
  F-agent's 8 met at 68.66 ms and 18,137 ms. set-a has 4 slots, so F-agent's 8 streams exceed its
  slots; the agent-only section serves 16. At 4 sessions the two were within 3.5 ms of ITL apart
  (54.42 and 50.97 ms) and at 1 session within 0.21 ms.
- **The capability host under its own mix.** In S-knee, 1 vision stream took 10.14 s against
  4.32 s alone, and 1 audio stream ran at RTFx 2.26 against 6.12 alone, with granite at 16 streams
  beside them (F). No cell ran them in pairs.

## M. Every run

| Run | Host | Tool and configuration | Load | Duration | Decision it informs |
| --- | --- | --- | --- | --- | --- |
| Stack reads and pings | gb10-1, gb10-2 | SSH read-only; `tailscale ping -c 1` | none | two reads | Behavior 1's record (Stack) |
| Root updates | gb10-1, gb10-2 | the architect's apt command | none | – | hosts current (A) |
| Push and restart | gb10-1, gb10-2 | `git push` to `hosts-next`, local `hosts` branch, router restart | none | – | the preset change on both hosts (A) |
| AA | gb10-1, then gb10-2 | GuideLLM 0.8.1, `cell`, `bench/anchor-a.yaml`, fresh set-a alone | 1 stream × 8 | 61 s each | parity (B) |
| AB, AB repeat | gb10-1, then gb10-2 | `bench/anchor-b.yaml`, fresh set-a alone | 4 streams × 32, 512 in, 256 out | 122 s each | parity (B) |
| Full-set load | gb10-2 | set A's four sections after `unload --all` and a cache drop; 30 s idle | none | 73 s (load to last) | set A capped, idle (C) |
| F-L2 | gb10-2 | `bench/footprint-l2.yaml`, 26B-A4B capped | 4 streams × 32, 1440p image, 64 out | 112 s | the cap under vision load (C) |
| F-agent | gb10-2 | `bench/role-split-agent-full.yaml`, set-a, knee [1,2,3,4,8] | 4-turn sessions | 110 s a level, 589 s | the agent's sessions beside set A (D.1) |
| F-vision | gb10-2 | `bench/role-split-vision-full.yaml`, 26B-A4B, knee [1,2,3,4,8] | 1440p image + 200 tokens, 100 out | 60 s a level, 346 s | vision requests in the full set (D.2) |
| F-audio | gb10-2 | `bench/role-split-audio-full.yaml`, E4B, knee [1,2,3,4,8] | LibriSpeech clips, ≤64 a level | ≤30 s a level, 162 s | audio requests in the full set (D.3) |
| F-embed | gb10-2 | `bench/role-split-embed.yaml`, granite, concurrent [1,2,4,8,16] | 512-token inputs | 30 s a level, 204 s | embedding against its floor (D.4) |
| F-probe | gb10-2 | curl under `watch`, `/v1/audio/transcriptions`, E4B | one 600 s WAV | 0.72 s (10 s under `watch`) | the 8,192-token slot against 15,028 tokens (E) |
| F-mixed | gb10-2 | four `cell`s at once, `bench/role-split-mixed-*.yaml`, set A | agent 4, vision 4, audio 4, embedding 16 | 240 s each, 264 s | the full set at its load targets (F) |
| Split loads | gb10-1; gb10-2 | agent-only alone; 16-slot 26B-A4B, 16-slot E4B, granite; each after `unload --all` and a cache drop, 30 s idle | none | 51 s; 27 s | the split against the computation (G) |
| S-agent | gb10-1 | `bench/role-split-agent-split.yaml`, agent-only, knee [1,4,8,12,16] | 4-turn sessions | 110 s a level, 595 s | the agent's sessions alone on a GB10 (D.1) |
| S-vision | gb10-2 | `bench/role-split-vision-split.yaml`, 16-slot 26B-A4B, knee [1,4,8,12,16] | as F-vision | 90 s a level, 501 s | vision requests in the split (D.2) |
| S-audio | gb10-2 | `bench/role-split-audio-split.yaml`, 16-slot E4B, knee [1,4,8,12,16] | as F-audio | ≤30 s a level, 157 s | audio requests in the split (D.3) |
| S-mixed | gb10-1 and gb10-2 at once | `bench/role-split-mixed-*.yaml`, the split's sections | agent 4, vision 4, audio 4, embedding 16 | 240 s each, about 4.5 min | the split at the full set's targets (F) |
| S-knee | gb10-1 and gb10-2 at once | as S-mixed | agent 4, vision 1, audio 1, embedding 16 | 240 s each, about 4.5 min | what the split holds at its knees (F) |

Every cell ran under `watch`, memory sampled every 10 s, capped at 10 min, the floor
`MEASURE_FLOOR_GIB` 12.2 on both GB10s.

### Commands as run (gb10-1)

From `.state/measure/gb10-1/2026-11-10.log`, every command at the step level, in log order. As in
the footprint finding, every line inside a helper and the log's header lines stay in the log, and
the `export MEASURE_FLOOR_GIB=12.2` each step began with is left out. `<scratchpad>` stands for the
session's scratch directory,
`/tmp/claude-1000/-home-jaime-experiments-spike-model-layout/1077e790-19b7-4c69-bebf-53d1c193a7e3/scratchpad`;
the `source` lines are the step files, and the commands traced after each are what they ran.
`after` (from `after.sh`) drops the cache, runs `memory` and `footprint`, and stops the arm if the
pool reads under 12,492 MiB (the step file's text; the log traces its commands inside `after`).

```
06:34:20  loaded
06:34:20  load gpt-oss-120b-MXFP4-set-a
06:35:08  cell role-split-anchor-gb10-1-a anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
06:36:21  source <scratchpad>/g1b.sh
06:36:21  unload gpt-oss-120b-MXFP4-set-a
06:36:24  load gpt-oss-120b-MXFP4-set-a
06:37:09  cell role-split-anchor-gb10-1-b anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
06:39:12  unload gpt-oss-120b-MXFP4-set-a
06:39:15  loaded
06:44:23  source <scratchpad>/b2-gb10-1.sh
06:44:23  : 'anchor B missed parity (gb10-1 78.58 with 1 errored vs gb10-2 80.71 tok/s, 2.71% over 2.2%): repeated once on both hosts'
06:44:23  loaded
06:44:23  load gpt-oss-120b-MXFP4-set-a
06:45:11  cell role-split-anchor-gb10-1-b-r2 anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
06:47:14  unload gpt-oss-120b-MXFP4-set-a
06:47:17  loaded
09:10:18  source <scratchpad>/s1-gb10-1.sh
09:10:18  : 'role-split split arm on gb10-1: drop the page cache, load the agent-only section alone'
09:10:18  loaded
09:10:18  unload --all
09:10:18  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
09:10:19  memory
09:10:20  t0=2026-11-10T14:10:20Z
09:10:20  load gpt-oss-120b-MXFP4-agent-only
09:11:11  date -u +%FT%TZ
09:11:11  sleep 30
09:11:41  : 'agent-only loaded since 2026-11-10T14:10:20Z, idle 30 s'
09:11:41  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
09:11:42  memory
09:11:43  footprint 2026-11-10T14:10:20Z
09:11:44  loaded
09:12:16  source <scratchpad>/s2-gb10-1.sh
09:12:16  : 'S-agent: gpt-oss-120b agent-only alone on gb10-1, knee [1,4,8,12,16], 110 s a level'
09:12:16  source <scratchpad>/after.sh
09:12:16  loaded
09:12:16  memory
09:12:17  cell role-split-s-agent role-split-agent-split gpt-oss-120b-MXFP4-agent-only openai/gpt-oss-120b
09:22:15  after s-agent
09:22:18  loaded
09:34:23  source <scratchpad>/mixed-gb10-1.sh
09:34:23  : 'role-split-s-mixed: the split'\''s agent process on gb10-1, 4 sessions, 240 s, started with gb10-2'\''s three'
09:34:23  source <scratchpad>/after.sh
09:34:23  loaded
09:34:23  GUIDELLM__SPEC__PROFILE__STREAMS=4
09:34:23  cell role-split-s-mixed-agent role-split-mixed-agent gpt-oss-120b-MXFP4-agent-only openai/gpt-oss-120b
09:38:46  after s-mixed-agent
09:38:50  loaded
09:40:23  source <scratchpad>/mixed-gb10-1.sh
09:40:23  : 'role-split-s-knee: the split'\''s agent process on gb10-1, 4 sessions, 240 s, started with gb10-2'\''s three'
09:40:23  source <scratchpad>/after.sh
09:40:23  loaded
09:40:24  GUIDELLM__SPEC__PROFILE__STREAMS=4
09:40:24  cell role-split-s-knee-agent role-split-mixed-agent gpt-oss-120b-MXFP4-agent-only openai/gpt-oss-120b
09:44:49  after s-knee-agent
09:44:52  loaded
```

The trace prints a command's environment assignment (`GUIDELLM__SPEC__PROFILE__STREAMS=4`) on its
own line before the command it prefixes.

### Commands as run (gb10-2)

From `.state/measure/gb10-2/2026-11-10.log`, left out as above. In `f2.sh` the `after` function is
defined in the step file itself, with the same steps. The mixed cells' processes ran in the
background (`&`) and `wait`, so the trace prints their assignments, `wait` and the `cell` lines in
the order the shell reached them.

```
06:39:25  source <scratchpad>/g2ab.sh
06:39:25  loaded
06:39:25  load gpt-oss-120b-MXFP4-set-a
06:40:11  cell role-split-anchor-gb10-2-a anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
06:41:12  unload gpt-oss-120b-MXFP4-set-a
06:41:15  load gpt-oss-120b-MXFP4-set-a
06:42:03  cell role-split-anchor-gb10-2-b anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
06:44:05  unload gpt-oss-120b-MXFP4-set-a
06:44:08  loaded
06:47:17  source <scratchpad>/b2-gb10-2.sh
06:47:17  : 'anchor B missed parity (gb10-1 78.58 with 1 errored vs gb10-2 80.71 tok/s, 2.71% over 2.2%): repeated once on both hosts'
06:47:17  loaded
06:47:17  load gpt-oss-120b-MXFP4-set-a
06:48:02  cell role-split-anchor-gb10-2-b-r2 anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
06:50:04  unload gpt-oss-120b-MXFP4-set-a
06:50:07  loaded
06:51:01  source <scratchpad>/f1.sh
06:51:01  : 'role-split full-set arm on gb10-2: unload all, drop the page cache, load capped set A'
06:51:01  loaded
06:51:01  unload --all
06:51:01  ssh gb10-2 sudo -n /usr/sbin/sysctl vm.drop_caches=3
06:51:02  memory
06:51:02  t0=2026-11-10T11:51:02Z
06:51:02  for s in gpt-oss-120b-MXFP4-set-a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16
06:51:02  load gpt-oss-120b-MXFP4-set-a
06:51:48  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
06:52:03  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
06:52:12  load mrutkows/granite-embedding-english-r2-GGUF:BF16
06:52:15  date -u +%FT%TZ
06:52:15  sleep 30
06:52:45  : 'capped set A loaded since 2026-11-10T11:51:02Z, idle 30 s'
06:52:45  ssh gb10-2 sudo -n /usr/sbin/sysctl vm.drop_caches=3
06:52:46  memory
06:52:46  footprint 2026-11-10T11:51:02Z
06:52:46  cell role-split-f-l2 footprint-l2 google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
06:54:38  ssh gb10-2 sudo -n /usr/sbin/sysctl vm.drop_caches=3
06:54:38  memory
06:54:38  footprint 2026-11-10T11:51:02Z
06:57:33  source <scratchpad>/f2.sh
06:57:33  loaded
06:57:33  cell role-split-f-agent role-split-agent-full gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
07:07:22  after f-agent
07:07:23  cell role-split-f-vision role-split-vision-full google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
07:13:09  after f-vision
07:13:10  cell role-split-f-audio role-split-audio-full ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
07:15:53  after f-audio
07:15:53  cell role-split-f-embed role-split-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
07:19:19  after f-embed
07:19:20  watch role-split-f-probe curl -sS -o /home/jaime/experiments/spike-model-layout/.state/measure/gb10-2/role-split-f-probe.response.json -w '%{http_code} %{time_total}s\n' http://gb10-2:8080/v1/audio/transcriptions -F model=ggml-org/gemma-4-E4B-it-GGUF:Q8_0 -F file=@.state/role-split/ami-es2002a-first10min.wav
07:19:31  cat /home/jaime/experiments/spike-model-layout/.state/measure/gb10-2/role-split-f-probe.log
07:19:31  after f-probe
07:19:33  loaded
07:21:41  source <scratchpad>/f3.sh
07:21:41  : 'F-mixed: four cell processes started together at the load targets, agent 4, vision 4, audio 4, embedding 16, 240 s each'
07:21:41  loaded
07:21:41  memory
07:21:41  GUIDELLM__SPEC__PROFILE__STREAMS=4
07:21:41  wait
07:21:41  GUIDELLM__SPEC__PROFILE__STREAMS=4
07:21:41  GUIDELLM__SPEC__PROFILE__STREAMS=4
07:21:41  GUIDELLM__SPEC__PROFILE__STREAMS=16
07:21:41  cell role-split-f-mixed-agent role-split-mixed-agent gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
07:21:41  cell role-split-f-mixed-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
07:21:41  cell role-split-f-mixed-audio role-split-mixed-audio ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
07:21:41  cell role-split-f-mixed-vision role-split-mixed-vision google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
07:26:06  ssh gb10-2 sudo -n /usr/sbin/sysctl vm.drop_caches=3
07:26:07  memory
07:26:07  date -u +%FT%TZ
07:26:07  footprint 2026-11-10T12:26:07Z
07:26:08  loaded
09:10:18  source <scratchpad>/s1-gb10-2.sh
09:10:18  : 'role-split split arm on gb10-2: unload all, drop the page cache, load the 16-slot 26B-A4B, the 16-slot E4B and granite'
09:10:18  loaded
09:10:18  unload --all
09:10:32  ssh gb10-2 sudo -n /usr/sbin/sysctl vm.drop_caches=3
09:10:33  memory
09:10:34  t0=2026-11-10T14:10:34Z
09:10:34  for s in gemma-4-26B-A4B-it-qat-Q4_0-16-slots gemma-4-E4B-it-Q8_0-16-slots mrutkows/granite-embedding-english-r2-GGUF:BF16
09:10:34  load gemma-4-26B-A4B-it-qat-Q4_0-16-slots
09:10:47  load gemma-4-E4B-it-Q8_0-16-slots
09:10:57  load mrutkows/granite-embedding-english-r2-GGUF:BF16
09:11:01  date -u +%FT%TZ
09:11:01  sleep 30
09:11:31  : 'split set loaded since 2026-11-10T14:10:34Z, idle 30 s'
09:11:31  ssh gb10-2 sudo -n /usr/sbin/sysctl vm.drop_caches=3
09:11:33  memory
09:11:33  footprint 2026-11-10T14:10:34Z
09:11:35  loaded
09:22:19  source <scratchpad>/s2-gb10-2.sh
09:22:19  : 'S-vision and S-audio on gb10-2, knee [1,4,8,12,16]: vision 90 s a level, audio 30 s or 64 requests a level'
09:22:19  source <scratchpad>/after.sh
09:22:19  loaded
09:22:19  memory
09:22:20  cell role-split-s-vision role-split-vision-split gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
09:30:44  after s-vision
09:30:48  cell role-split-s-audio role-split-audio-split gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
09:33:30  after s-audio
09:33:34  loaded
09:34:23  source <scratchpad>/mixed-gb10-2.sh
09:34:23  : 'role-split-s-mixed: the split'\''s vision 4, audio 4 and embedding 16 processes on gb10-2, 240 s each, started together with gb10-1'\''s agent'
09:34:23  source <scratchpad>/after.sh
09:34:23  loaded
09:34:23  GUIDELLM__SPEC__PROFILE__STREAMS=4
09:34:23  GUIDELLM__SPEC__PROFILE__STREAMS=16
09:34:23  GUIDELLM__SPEC__PROFILE__STREAMS=4
09:34:23  wait
09:34:23  cell role-split-s-mixed-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
09:34:23  cell role-split-s-mixed-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
09:34:23  cell role-split-s-mixed-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
09:39:52  after s-mixed
09:39:57  loaded
09:40:23  source <scratchpad>/mixed-gb10-2.sh
09:40:23  : 'role-split-s-knee: the split'\''s vision 1, audio 1 and embedding 16 processes on gb10-2, 240 s each, started together with gb10-1'\''s agent'
09:40:23  source <scratchpad>/after.sh
09:40:23  loaded
09:40:24  GUIDELLM__SPEC__PROFILE__STREAMS=1
09:40:24  GUIDELLM__SPEC__PROFILE__STREAMS=16
09:40:24  GUIDELLM__SPEC__PROFILE__STREAMS=1
09:40:24  wait
09:40:24  cell role-split-s-knee-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
09:40:24  cell role-split-s-knee-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
09:40:24  cell role-split-s-knee-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
09:46:11  after s-knee
09:46:15  loaded
```

Each `cell` printed its summary lines, for example S-agent's (09:22:15):

```
1 stream(s): requests ok 8, errored 0, incomplete 1 of 9; output tok/s completed 37.24, every-token 41.41; TTFT median 963 ms; ITL median 19.57 ms
4 stream(s): requests ok 12, errored 0, incomplete 4 of 16; output tok/s completed 55.85, every-token 59.09; TTFT median 2906 ms; ITL median 50.97 ms
8 stream(s): requests ok 8, errored 0, incomplete 8 of 16; output tok/s completed 37.24, every-token 52.96; TTFT median 25279 ms; ITL median 109.63 ms
12 stream(s): requests ok 0, errored 2, incomplete 12 of 14; output tok/s completed 0, every-token 41.68; TTFT median 0 ms; ITL median 0 ms
16 stream(s): requests ok 0, errored 0, incomplete 16 of 16; output tok/s completed 0, every-token 30.8; TTFT median 0 ms; ITL median 0 ms
```

and the probe's `watch` printed curl's `400 0.715784s`.

### Commands not in a step log

The stack reads, the push and router restart, and the launch of the split's mixed cells ran from
the laptop outside the step helpers. Their outputs are saved
(`.state/role-split/stack-pre-2026-11-10.txt`, `stack-2026-11-10.txt`,
`push-restart-2026-11-10.txt`), but the commands themselves are not in a step log or a saved file,
so they are not quoted here. The split's mixed cells were launched by the scratch file
`<scratchpad>/mixed.sh`, which runs each host's step file (`mixed-gb10-1.sh`, `mixed-gb10-2.sh`)
through `<scratchpad>/step.sh <host> <file>` in the background on both hosts at once, with `MIX`,
`AGENT`, `VISION`, `AUDIO` and `EMBED` exported; the values each run took show in the step logs'
`:` and `GUIDELLM__SPEC__PROFILE__STREAMS` lines above.

The per-level tables in D, F, I and J and the errors in L.4 and L.5 were read from the cells' JSON,
from the project's root:

```sh
python3 -I <scratchpad>/levels.py <agent|vision|audio|embed> .state/measure/<host>/role-split-<cell>.json
jq -r '.benchmarks[] | (.config.strategy.streams|tostring) as $s | .requests.errored[]? | "s=\($s): \(.info.error)"' .state/measure/<host>/role-split-<cell>.json
```

Section L.1's timelines and router-log extracts, from the project's root, at 14:59:52Z for the log
reads (read-only: `docker logs` on gb10-2, nothing loaded, unloaded or requested). Each saved file
starts with the command that made it:

```sh
jq -r '.benchmarks[] | .config.strategy.streams as $s | .start_time as $t0 | [.requests.successful[], .requests.errored[]] | sort_by(.request_start_time)[] | "\($s) \((.request_start_time-$t0)*100|round/100) \((.request_end_time-$t0)*100|round/100) \((.request_end_time-.request_start_time)*100|round/100) \(.time_to_first_token_ms // "-" | if type=="number" then round else . end)"' .state/measure/gb10-2/role-split-s-vision.json
ssh gb10-2 'docker logs llama 2>&1 | grep -E "^\[45453\]" | grep -E "encode_mtmd_|decoding image batch|image decoded|prompt eval time|CLIP using|image_min_pixels"'
ssh gb10-2 'docker logs llama 2>&1 | grep -E "^\[44615\]" | grep -E "audio decoded|CLIP using"'
```

## N. Open items for later tasks

None of these is decided here.

- **Vision serializes at the image encode.** About 0.23 requests a second at every stream count in
  both arms; on b12098 the server encodes one slot's image at a time (L.1). Vision held 2 requests
  in the full set and 1 in the split against a load target of 4.
- **The capped Gemma sections' RSS growth** with no save counted (L.2): 26B-A4B +6138 MiB at 16
  slots by the end of the split arm, not attributed.
- **Granite's idle-slot saves** (L.3): capping granite is an intake note, by the architect's
  decision; it stayed unchanged in both arms.
- **gb10-1's thin margin.** The agent-only section left 1.39 GiB above the floor idle and 0.27 GiB
  at its lowest under load (G, H), against the brief's computed ~1.9 GiB; its unified compute
  buffers grew 2.14 GiB over set-a's.
- **The agent held 4 sessions on the agent-only GB10, not 9** (I): the 9 is footprint's memory count
  for 131,072-token sessions; the measured 4 is the ITL floor's count for the 4-turn shape, missed at
  8. Sessions of 131,072 tokens stay computed.
- **Audio slower in the split** at 1 stream (RTFx 6.12 against 11.11), and **the capability
  host's purposes slower beside each other** in S-knee (L.6): not isolated.
- **Neither arrangement held vision or audio at the load target of 4** (F, J).
- **The 10-minute WAV** is 15,023 tokens, refused by an 8,192-token slot (E); the E4B keeps its
  slot size in this task, and audio past 30 s goes windowed, by the session's decision.
- **The Gemma 4 output-parser error** on CUDA, 7 requests (L.4), and **GuideLLM's JSON decode
  errors**, 4 requests (L.5).
- **Hypotheses the spike hasn't measured:**
  - several vision processes (sections) in place of more slots in one, so that images encode in
    parallel;
  - vLLM, which batches the vision encoder across requests, for the vision and audio models;
  - the GPU's compute and memory bandwidth shared between vision and audio (and embedding) as the
    cause of the capability host's mixed-cell misses: memory capacity was never the limit there,
    gb10-2's lowest in any split cell being 68.69 GiB (H);
  - the split's single-stream audio slowdown (RTFx 6.12 against 11.11, L.6), still unexplained.
- From footprint's section K, still open (K.4): the Framework's system memory floor and its side of
  the prompt cache, the Gemma models' trained contexts, and the 26B-A4B on Vulkan past 4 slots.
