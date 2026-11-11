# Finding: the capability models on vLLM v0.33.0 against llama.cpp on gb10-2 and the Framework

Measured 2026-11-11, task `capability-vllm`. This finding is dated: every figure holds for the
versions, stack, rows, sections and network path below, on that day, and nothing after it.

**What it establishes.** The finding answers evidence 3 and 5 for the capability purposes (vision,
audio, embedding) on vLLM v0.33.0 against llama.cpp b12098, in one session, per host: gb10-2 (CUDA)
and the Framework (ROCm 10.0 for vLLM, Vulkan for llama.cpp). On llama.cpp each host serves the
sections role-split and framework left it (gb10-2's 16-slot 26B-A4B and E4B and granite; the
Framework's capped 4-slot 26B-A4B and E4B and granite). On vLLM each host serves three rows, each
in its own container on its own port with its own memory fraction, 16 sequences of 8,192 tokens
each: gb10-2 the NVFP4 26B-A4B (0.40), the E4B BF16 (0.20) and granite (0.05); the Framework the
BF16 26B-A4B (0.60), the E4B BF16 from the rebuilt audio image (0.18) and granite (0.03). It
measures each purpose alone at every level of the host's role-split sweep, one mixed cell per host
at the targets (vision 4, audio 4, embedding 16), and one two-host cell per engine (vision 2 + 2,
audio 2 + 2, embedding 8 + 8), with memory and the margin above each floor, the KV cache per row,
cold starts, backends, probes and errors, and the ROCm 10.0 outcome (sections A to M).

| Per host and engine | gb10-2 llama.cpp | gb10-2 vLLM | Framework llama.cpp | Framework vLLM |
| --- | --- | --- | --- | --- |
| Vision holds alone (role-split's rule; G) | 1 request | **16** | 1 | **4** |
| Vision at 4 streams alone: latency median | 12.92 s | **4.61 s** | 23.45 s | **9.98 s** |
| Audio holds alone (G) | 1 request | **16** | 2 | **8** |
| Audio at 4 streams alone: RTFx median | 4.34 | **6.17** | 3.97 | **6.38** |
| Embedding holds alone; prompt tok/s at 16 (G) | 16; 28,762 | 16; **126,643** | 16; 20,503 | 16; **96,803** |
| Mixed cell at the targets, 4 / 4 / 16 (H): vision latency; audio RTFx; embedding prompt tok/s | 44.68 s; 0.93; 11,897 | 14.90 s; 2.15; 47,799 | 34.38 s; 0.93; 7,969 | 30.11 s; 2.75; 36,331 |
| Two-host cell, this host's share 2 / 2 / 8 (I) | 24.58 s; 1.68; 19,128 | 10.89 s; 2.38; 42,671 | 18.37 s; 1.94; 7,441 | 17.18 s; 3.25; 33,755 |
| KV cache, tokens: vision; audio (E) | 131,072; 131,072 (16 × 8,192) | 164,570; 172,508 | 32,768; 32,768 (4 × 8,192) | 109,055; 104,813 |
| Pool idle / lowest under load (K) | 77.26 / 68.48 GiB | **35.53 / 31.37 GiB** | GTT 82.97 / 82.27; system 88.29 / 85.30 GiB | GTT 22.87 / 21.66; **system 16.52 / 13.26 GiB** |
| Above the floor, idle / lowest (c) | 65.06 / 56.28 GiB | 23.33 / 19.17 GiB | GTT 71.77 / 71.07; system 75.79 / 72.80 GiB | GTT 11.67 / 10.46; **system 4.02 / 0.76 GiB** |
| Cold start: vision; audio; embedding (C) | 15.1; 9.1; 3.1 s (load) | 168.6; 162.2; 19.6 s | 6.1; 6.1; 3.1 s (load) | 100.9; 73.4; 20.5 s |
| Errored requests, all cells (L) | 3, the Gemma 4 output parser | **0** | 2, the Gemma 4 output parser | **0** |

It also found that:

- **vLLM lifts the per-purpose ceiling on both hosts.** Alone, with the other two rows loaded and
  idle, gb10-2's vision row met the 10 s floor at every level to 16 streams (9.51 s at 16), where
  llama.cpp's 16-slot section met it at 1; audio met RTFx 5 at every level to 16, against 1. On
  the Framework vision held 4 (9.98 s, 0.02 s under the floor, c) and audio 8, against 1 and 2
  (G).
- **Beside each other at the targets, vision and audio still miss on both engines and both
  hosts**, and vLLM comes closer: gb10-2's vision at 14.90 s against 44.68, audio at RTFx 2.15
  against 0.93 (H). In the two-host cell **neither engine held vision or audio at the target**:
  0 of 4 each; vLLM's gb10-2 vision share ran 10.89 s, 0.89 s over the floor (c) (I, J).
- **vLLM's fractions take most of each pool.** gb10-2 read 35.53 GiB idle against llama.cpp's
  77.26; the Framework's system memory, which GTT doesn't count, fell to **13.26 GiB under the
  vLLM vision sweep, 0.76 GiB above its 12.5 GiB floor** (c), the narrowest margin of the task,
  with the GTT pool 10.46 GiB above its own (K). That reading bears on the Framework's fractions
  (0.60, 0.18 and 0.03, 0.81 in all).
- **The Framework's vLLM start is measured** (the roadmap's item): 100.8 s for the vision row,
  73.4 s for audio and 20.4 s for granite from the container's start, with the other two rows
  serving and the page cache dropped; the first starts, which compiled, took 168.3, 146.7 and
  33.4 s. v0.32.0's single-row starts on the same host (73.9, 97.6 and 21.2 s timed) stand beside
  them as a record across versions (C).
- On GB10 the start is **mostly weight reading** (117.14 s of the vision row's 168.6 s for 18.13
  GiB, c 0.15 GiB/s); the Framework read 48.6 GiB in 16.36 s (C).
- The Framework's two Gemma rows hold 13.31 and 12.79 sequences of 8,192 tokens in their caches,
  under their 16 sequences (E). gb10-2's audio row sized its cache at 231,342 tokens on its first
  start and 172,508 on its cold start beside the other two rows (E).
- **ROCm 10.0 runs on gfx1151**: v0.33.0's default ROCm image started and served all three rows,
  and no fallback ran. Its official image ships no audio decoder; the rebuilt audio image served
  every audio request, each logging torchcodec's fallback warning (M).
- llama.cpp's vision errored 5 requests in all with the Gemma 4 output parser's `peg-gemma4`
  error; vLLM's rows errored none, and their server logs held no error line in any cell (L).

It decides nothing.

**The conclusion, as evidence.** The spike records it and decides nothing.

- On this session's figures, **vLLM is the stronger capability engine on both hosts for each
  purpose alone**: it holds 16 vision and 16 audio requests on gb10-2 against llama.cpp's 1 and 1,
  and 4 and 8 on the Framework against 1 and 2, with 4.4 and 4.7 times llama.cpp's embedding
  throughput at 16 streams (c: 126,643 / 28,762; 96,803 / 20,503). The server-side batching lifts
  the one-image-at-a-time ceiling llama.cpp shows (F.1 in the framework finding; G here).
- **What vLLM does not change:** with vision, audio and embedding loaded at once on one GPU at
  their targets, vision and audio miss their floors on both engines. Two capability hosts on vLLM
  hold 0 of 4 vision and 0 of 4 audio streams at the target, as on llama.cpp. vLLM narrows the gap
  (gb10-2's vision share 10.89 s against llama.cpp's 24.58), but doesn't close it.
- **What vLLM costs:** memory and start time. Its fractions leave gb10-2 23.33 GiB above its
  floor idle against llama.cpp's 65.06, and the Framework's system memory 0.76 GiB above its floor
  at its lowest. Its cold starts take 20 to 169 s per row against llama.cpp's 3 to 15 s loads.
- llama.cpp leads at 1 audio stream on both hosts: RTFx 11.00 against 6.50 on gb10-2 and 8.67
  against 7.01 on the Framework (G).
- **Open items** (N): what holds vision and audio under their floors beside each other (GPU
  sharing is the reading, not isolated); the Framework's fractions against its system floor; the
  NVFP4 checkpoint's accuracy warning; the audio image's missing torchcodec; and the hub contact
  at every start.

"Holds" is role-split's rule: the highest level meeting the purpose's floor at or below GuideLLM's
knee, or, where it found none, the highest level meeting it ([role-split](role-split.md), I).

**Which figures size the layout.** Production clients sit on the same direct network as the GPUs,
so the layout is sized on LAN figures (role-split's decision). Every run with a recorded ping went
direct on the LAN, 0 to 2 ms ("Stack, engine and network path"), so client-side and server-side
figures both stand as LAN figures.

| Host | Serves at the end of the session (Behavior 13) |
| --- | --- |
| gb10-1 | as agent-vllm left it: `gpt-oss-120b-MXFP4-agent-only` on llama.cpp (`llama` up 2 hours at the stack read), the `vllm` container Exited (0); clone on `main` at a294e4e, agent-vllm's merge. Read only, for the stack |
| gb10-2 | llama.cpp's `gemma-4-26B-A4B-it-qat-Q4_0-16-slots`, `gemma-4-E4B-it-Q8_0-16-slots` and granite, reloaded fresh at 22:58:18Z: 77.51 GiB available. `vllm-vision`, `vllm-audio` and `vllm-embed` Exited (0), the image `vllm/vllm-openai:v0.33.0` (d825baf9ce4b), the compile cache (438M) and the three models' safetensors kept. spike-model-engines' clone on a local `hosts` branch at bb68cbd, the pull request's head, moved from 4ad76e6 after the reviews; every run measured at 4ad76e6 ("Commands not in a step log") |
| framework | llama.cpp's capped `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` and `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` and granite, reloaded fresh at 22:58:18Z: 82.97 GiB GTT and 89.02 GiB system memory available. The three vLLM containers Exited (0); `vllm/vllm-openai-rocm:v0.33.0` and `:v0.33.0-rocm72`, both audio images, the compile cache (982M) and the safetensors kept. Clone on a local `hosts` branch at bb68cbd, moved from 4ad76e6 as gb10-2's |

## Stack, engine and network path

Read by the session over SSH, read-only, at 2026-11-11T14:11:56-05:00 (19:11:56Z), after the
architect's root updates (`.state/capability-vllm/stack-2026-11-11.txt`, `phased-2026-11-11.txt`):

| Host | Pending updates | OS | Kernel | GPU stack | Docker | Tailscale | Engine | Clone |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-1 | 3, phased (A.1) | DGX OS 7.6.0 (`DGX_OTA_VERSION`), Ubuntu 24.04.5 LTS | 7.0.0-1025-nvidia | driver 580.178.04, CUDA 13.0, NVIDIA Container Toolkit 1.20.1 | 29.6.2 | 1.104.6 | llama.cpp `server-cuda13-b12098`, up 2 hours (healthy); `vllm` Exited (0) | `main` at a294e4e |
| gb10-2 | 3, phased (A.1) | as gb10-1 | 7.0.0-1025-nvidia | as gb10-1 | 29.6.2 | 1.104.6 | llama.cpp `server-cuda13-b12098`, up 32 hours (healthy) | `main` at 21b5e8c, moved to `hosts` at 4ad76e6 in A.2 |
| framework | 0 (`checkupdates` exit 2) | Omarchy | 7.2.15-1-omarchy | mesa and vulkan-radeon 1:26.2.5-1, linux-firmware 20260916-1; `/dev/kfd` and `/dev/dri/renderD128` present | 1:29.9.2-1 | 1.104.2 | llama.cpp `server-vulkan-b12098`, up 22 hours (healthy) | `main` at 21b5e8c, moved to `hosts` at 4ad76e6 in A.2 |

The stack is agent-vllm's in every column ([agent-vllm](agent-vllm.md), "Stack, engine and
network path"), but gb10-1's clone, now on `main` at agent-vllm's merge. The drop-caches rule read
`(root) NOPASSWD: /usr/sbin/sysctl vm.drop_caches\=3` on each GB10 and `/usr/bin/sysctl` on the
Framework (A.3). Nothing changed on gb10-1 after this read: no load, request or clone move.

**Network path.** `tailscale ping -c 1 <host>` from the laptop preceded every run, each dated in
`.state/capability-vllm/ping-2026-11-11.txt`, and every pong came via the host's LAN address:

| Run | Ping (UTC): host, pong |
| --- | --- |
| Stack read | 19:11:56 gb10-1, 2 ms; 19:11:58 gb10-2, 2 ms; 19:12:00 framework, 2 ms |
| Push and clone move (A.2) | 19:12:15 gb10-2, 2 ms; 19:12:16 framework, 2 ms |
| Staging (A.4) | 19:12:43 gb10-2, 2 ms; 19:12:48 framework, 2 ms |
| Staging checks; image checks (A.4) | 20:37:39 gb10-2, 2 ms; 20:37:40 framework, 2 ms; 20:37:48 framework, 1 ms |
| llama.cpp load, both hosts (D) | 20:38:08 gb10-2, 2 ms; framework, 1 ms |
| L-vision, L-audio, L-embed, L-mixed, gb10-2 | 20:39:27, 1 ms; 20:48:09, 2 ms; 20:50:40, 2 ms; 20:54:13, 2 ms |
| L-vision, L-audio, L-embed, L-mixed, framework | 20:58:58, 2 ms; 21:04:41, 1 ms; 21:07:34, 2 ms; 21:10:59, 2 ms |
| L-two, the reaped run (I) | 21:15:31 gb10-2, 2 ms; framework, 2 ms |
| L-two, the rerun (I) | 21:54:03 gb10-2, 1 ms; framework, 2 ms |
| vLLM installs, first starts (C) | 22:03:15 gb10-2, 2 ms; framework, 2 ms |
| Cold starts (C) | vision 22:11:01, both 1 ms; audio 22:12:47 framework, 0 s; 22:13:54 gb10-2, 0 s; embedding 22:14:07 framework, 0 s; 22:16:40 gb10-2, 1 ms |
| Probes, warm-up, idle read (D, L) | 22:17:16 gb10-2, 2 ms; framework, 1 ms |
| V-vision, V-audio, V-embed, V-mixed, gb10-2 | 22:18:52, 1 ms; 22:27:25, 1 ms; 22:29:10, 1 ms; 22:32:38, 1 ms |
| V-vision, V-audio, V-embed, V-mixed, framework | 22:37:22, 1 ms; 22:43:07, 0 s; 22:45:30, 0 s; 22:48:46, 0 s |
| V-two (I) | 22:53:23 gb10-2, 1 ms; framework, 1 ms |
| Restore (Behavior 13) | 22:58:12 gb10-2, 1 ms; framework, 1 ms |

The audio probe's rerun (22:18:10Z, L.1) recorded no ping of its own; it followed the probes'
22:17:16 pings by 54 s. **Every run with a recorded ping went direct on the LAN, 0 to 2 ms.** Had
the laptop been off the LAN, the relay's trip would have landed on the client-side figures only
(TTFT, request latency, RTFx); ITL and memory don't carry the path
([role-split](role-split.md), L.7).

**Engines.** llama.cpp b12098 on both capability hosts, serving spike-model-engines' shared
preset, as `load` printed the arguments (`.state/capability-vllm/l-load-<host>.out`):

| Host | Section | Purpose | Loaded arguments (`load`) |
| --- | --- | --- | --- |
| gb10-2 | `gemma-4-26B-A4B-it-qat-Q4_0-16-slots` | vision | `--no-cache-idle-slots --ctx-size 131072 --cache-ram 0 --swa-checkpoints 2 --parallel 16` |
| gb10-2 | `gemma-4-E4B-it-Q8_0-16-slots` | audio | the same |
| gb10-2 | `mrutkows/granite-embedding-english-r2-GGUF:BF16` | embedding | `--ctx-size 131072 --parallel 16` |
| framework | `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` | vision | `--no-cache-idle-slots --ctx-size 32768 --cache-ram 0 --swa-checkpoints 2 --parallel 4` |
| framework | `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` | audio | the same |
| framework | `mrutkows/granite-embedding-english-r2-GGUF:BF16` | embedding | `--ctx-size 131072 --parallel 16` |

Each router's `/models` gave the full arguments, as in the framework finding: the 26B-A4B sections
carry `--image-min-tokens 560 --mtmd-batch-max-tokens 512`, granite's `--embeddings --batch-size
8192 --ubatch-size 8192`.

vLLM v0.33.0 (`/version` read `{"version":"0.33.0"}` on all six rows), run by spike-model-engines'
`host/engines vllm install` from the PR branch (A.2), one container a row:

| Host | Image (digest) | Row | Container, port | Container command, as `docker inspect` printed it |
| --- | --- | --- | --- | --- |
| gb10-2 | `vllm/vllm-openai:v0.33.0` (`sha256:d825baf9…`, arm64) | `gemma-4-26B-A4B-NVFP4-vision-gb10` | `vllm-vision`, 8000 | `nvidia/Gemma-4-26B-A4B-NVFP4 --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 8192 --gpu-memory-utilization 0.40 --kv-cache-dtype bfloat16 --reasoning-parser gemma4 --enable-auto-tool-choice --tool-call-parser gemma4` |
| gb10-2 | as above | `gemma-4-E4B-it-audio-gb10` | `vllm-audio`, 8001 | `google/gemma-4-E4B-it --host 0.0.0.0 --port 8001 --max-num-seqs 16 --max-model-len 8192 --gpu-memory-utilization 0.20 --kv-cache-dtype bfloat16 --reasoning-parser gemma4 --enable-auto-tool-choice --tool-call-parser gemma4` |
| gb10-2 | as above | `granite-embedding-english-r2-gb10` | `vllm-embed`, 8002 | `ibm-granite/granite-embedding-english-r2 --host 0.0.0.0 --port 8002 --runner pooling --max-num-seqs 16 --max-model-len 8192 --gpu-memory-utilization 0.05` |
| framework | `vllm/vllm-openai-rocm:v0.33.0`, ROCm 10.0 (`sha256:4fcd39b7…`, amd64; `-rocm100`'s digest, "Commands not in a step log") | `gemma-4-26B-A4B-it-vision-framework` | `vllm-vision`, 8000 | `google/gemma-4-26B-A4B-it --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 8192 --gpu-memory-utilization 0.60 --kv-cache-dtype bfloat16 --reasoning-parser gemma4 --enable-auto-tool-choice --tool-call-parser gemma4` |
| framework | `spike-model-engines/vllm-openai-rocm-audio:v0.33.0` (298c73773c66), built on the image above | `gemma-4-E4B-it-audio-framework` | `vllm-audio`, 8001 | `google/gemma-4-E4B-it --host 0.0.0.0 --port 8001 --max-num-seqs 16 --max-model-len 8192 --gpu-memory-utilization 0.18 --kv-cache-dtype bfloat16 --reasoning-parser gemma4 --enable-auto-tool-choice --tool-call-parser gemma4` |
| framework | `vllm/vllm-openai-rocm:v0.33.0` | `granite-embedding-english-r2-framework` | `vllm-embed`, 8002 | `ibm-granite/granite-embedding-english-r2 --host 0.0.0.0 --port 8002 --runner pooling --max-num-seqs 16 --max-model-len 8192 --gpu-memory-utilization 0.03` |

No row names an attention or MoE backend; vLLM chose them (F). `/v1/models` read each row's
repository as its id, with `max_model_len` 8192.

**Tools.** The step helpers in `scripts/measure-lib.sh` (`load`, `unload`, `loaded`, `memory`,
`footprint`, `cell`, `watch`, `summarize`, `readout`), with this task's change to read the vLLM
container that publishes a port, with GTT on amdgpu (B). Every cell is GuideLLM 0.8.1 from the
laptop (`mise.bench.toml`), run by `cell` under `watch`: the pool sampled every 10 s into
`<cell>.watch.tsv` (both pools on the Framework), the cell stopped under a floor, capped at 10
min. Each cell's GuideLLM JSON, `.watch.tsv`, `.exit` and `.log` are under
`.state/measure/<host>/`, named `capability-vllm-l-*` (llama.cpp) and `capability-vllm-v-*`
(vLLM). Every cell's `.exit` reads 0: none was stopped. The scenarios are role-split's, unchanged:
on vLLM `cell` names the row's served model, with the tokenizer of the same model, and the helpers
sourced for the row's port set the target (`bench/README.md`). The steps ran from step files in
the session's scratch directory, each through `step.sh <host> <file>`, which sources the helpers
for the host and exports its floors; copies of every step file are in
`.state/capability-vllm/step-files/`, and the step log traces every command inside them (O). Each
vLLM start was timed by `vwait` (`v-common.sh`), agent-vllm's `vllm_wait` generalized to a port and
container: it polls `/health` every 2 s, samples MemAvailable (and GTT on the Framework) every 10 s
into `.state/capability-vllm/<host>-<label>.mem.tsv`, and prints the seconds from the start
command and from the container's StartedAt to the start log's "Application startup complete." on
the host's clock.

**Reading the figures.** On gb10-2 the pool is MemAvailable against its floor of 12.2 GiB. On the
Framework there are two pools: GTT available, against 11.2 GiB, and system MemAvailable, against
12.5 GiB. **Every idle and after-cell read on both hosts follows a page-cache drop** (`ssh gb10-2
sudo -n /usr/sbin/sysctl vm.drop_caches=3`; `ssh framework sudo -n /usr/bin/sysctl
vm.drop_caches=3`, the Framework's new rule, A.3), where the framework task read the Framework
without one; `watch`'s samples during a cell and `vwait`'s during a start are not taken after a
drop. The per-level tables come from each cell's JSON through
[`bench/levels.jq`](../../bench/levels.jq), judged by vision's median request latency ≤10 s,
audio's median RTFx ≥5 and embedding's mean prompt tok/s ≥4,300; all were re-read at 23:09:44Z
into `.state/capability-vllm/jq-figures-slice3.txt` by one quoted command (O, "Commands not in a
step log"), and match the session's reads after each slice (`jq-figures-slice1.txt`,
`jq-figures-slice2.txt`). Logs give buffers and processes in MiB and vLLM gives GiB; pools are in
GiB (1 GiB = 1024 MiB). The command lists show the step logs' local times (UTC−5); the prose gives
UTC. Every figure is measured, read from a cell's JSON, the step log or a saved file, unless
marked **(c)**: computed from measured figures, with the arithmetic shown where it isn't a plain
difference or ratio. **(m)** marks a measured figure where computed ones sit beside it.

## A. Hosts brought current, the pull request, root steps, staging (Behaviors 1 to 4)

### A.1 Root updates

The architect applied the root updates on all three hosts before the session's first read
(`.state/capability-vllm/root-steps.md`). The stack read found 0 pending on the Framework and 3
listed on each GB10, the same three Ubuntu phased updates earlier tasks found (distro-info and
python3-distro-info 1.7ubuntu0.1, snapd 2.78+ubuntu24.04, each "phased 10%"); a simulated upgrade
on each GB10 printed "The following upgrades have been deferred due to phasing: distro-info
python3-distro-info snapd" and "0 upgraded, 0 newly installed, 0 to remove and 3 not upgraded"
(`phased-2026-11-11.txt`). By the framework task's decision the phased three count as no pending
updates.

### A.2 The pull request reaches gb10-2 and the Framework (Behavior 2)

**Decision it informs:** whether each capability host can serve three vLLM rows at once before the
merge. The host/ change is commit 4ad76e6, "host: per-row vLLM containers, ports and images; the
capability rows on v0.33.0's ROCm 10.0", on spike-model-engines' `capability-vllm` branch:

- `vllm.sh`: a row may name its container (`container=`, default `vllm`), its port (`port=`,
  default 8000) and an image the host builds (`image=`); rows naming none run as before, so gb10-1's
  agent container compares equal unchanged. Install, update and uninstall act on the row's
  container alone; update's image cleanup keeps every official image any container was created
  from; uninstall removes the shared images and compile cache only once no row's container is left.
- llama's install and update, and the native installs and updates, refuse while any vLLM container
  runs; vLLM still refuses while llama runs.
- `vllm.env`: the rocm flavor stays on v0.33.0's default tag, its ROCm 10.0 build (the same
  digest as `-rocm100`, `sha256:4fcd39b7…`, read from Docker Hub in "Commands not in a step log"); `VLLM_ROCM_FALLBACK=rocm72` names the fallback, chosen
  for one run by `VLLM_ROCM_BUILD=rocm72`.
- `vllm-rocm-audio/Dockerfile`: rebuilt on the default ROCm image by digest, with av 19.0.2,
  soundfile 0.14.0 and soxr 1.1.0, and a rocm72 stage.
- `vllm-rows`: the six capability rows ("Engines" above) and the rewritten fraction comment;
  `llama.env`'s hold note reads "unrestored through b12282".

At 19:12:16Z the branch was pushed to each capability host as `hosts-next`, and each clone checked
out a local `hosts` branch at it (`push-gb10-2.out`, `push-framework.out`). Before the move the
step read the `llama` container's mounts (`host/llama-preset -> /etc/llama-preset ro`): the
preset's diff from the old HEAD was empty, and `models.ini`'s sha256 (`c0c631db…`) read the same
before and after the checkout. `git branch -vv` listed `* hosts 4ad76e6`, `hosts-next 4ad76e6` and
`main 21b5e8c [origin/main]` (and the Framework's `screen` branch at 31b00eb, untouched); each clone
listed the six rows, "unrestored through b12282", `VLLM_RELEASE=v0.33.0` and
`VLLM_ROCM_FALLBACK=rocm72`. `llama` answered `/health 200` with its three sections still loaded.
gb10-1's clone did not move.

### A.3 The Framework's root steps (Behavior 3)

The architect's, reported to the session (`root-steps.md`):

```
sudo ufw route allow in on tailscale0 proto tcp to any port 8001
sudo ufw route allow in on tailscale0 proto tcp to any port 8002
```

each printing "Rule added" and "Rule added (v6)"; and the drop-caches sudoers rule, as on the GB10s,
checked with `visudo -cf` ("parsed OK"). `sudo -n -l` and the stack read show `(root) NOPASSWD:
/usr/bin/sysctl vm.drop_caches\=3`; the GB10s' rule names `/usr/sbin/sysctl`, so the session drops
the Framework's cache with `sudo -n /usr/bin/sysctl vm.drop_caches=3`. From the laptop ports 8000,
8001 and 8002 answered on both hosts once a container published them: every `/health`, probe and
cell in C to I reached them. The session ran no root step other than that exact drop-caches
command with `sudo -n`.

### A.4 Staging and the image checks (Behavior 4)

**Decision it informs:** whether every vLLM start reads its weights and image from the host, so its
time is a load, not a download, and whether the ROCm 10.0 image fits gfx1151 and its audio row.
From 19:12:43Z (gb10-2) and 19:12:48Z (the Framework), in parallel and in the background, with
`llama` still serving, the weights by `hf download` into `/srv/models` (granite with
`--exclude pytorch_model.bin`) and the images by `docker pull`; on the Framework each ROCm image
was followed by its audio image's `docker build`. Each job's log exited 0 (`stage-result-<host>.out`,
read at 20:37:39Z), all bandwidth-bound at about 11 MB/s a host (the session's estimate):

| Host | Job | Finished (UTC) | Took (c) | Result |
| --- | --- | --- | --- | --- |
| gb10-2 | `vllm/vllm-openai:v0.33.0` | 20:10:46 | 58 min 3 s | `sha256:d825baf9ce4b…`, arm64, content 10,901,699,690 bytes, "Downloaded newer image": gb10-1's digest |
| gb10-2 | `nvidia/Gemma-4-26B-A4B-NVFP4` | 20:07:12 | 54 min 29 s | snapshot a19cfe00…: 12 files, 18,825,679,760 bytes (2 shards, `config.json`, `generation_config.json`, `hf_quant_config.json`, `model.safetensors.index.json`, `processor_config.json`, tokenizer files, `chat_template.jinja`) |
| gb10-2 | `google/gemma-4-E4B-it` | 19:59:16 | 46 min 33 s | 4ecc2ba6…: 9 files, 16,024,810,531 bytes |
| gb10-2 | `ibm-granite/granite-embedding-english-r2` | 19:26:11 | 13 min 28 s | 47ea694b…: 10 files, 301,662,285 bytes (with `1_Pooling/config.json`, `modules.json`, `sentence_bert_config.json`) |
| framework | `vllm/vllm-openai-rocm:v0.33.0`, then the audio image `:v0.33.0` | 20:37:07 | 1 h 24 min 19 s | `sha256:4fcd39b758b6…`, amd64, 53.4 GB, the pin's digest; audio image 298c73773c66, 53.7 GB, build exit 0 |
| framework | `vllm/vllm-openai-rocm:v0.33.0-rocm72`, then the audio image `:v0.33.0-rocm72` | 20:33:52 | 1 h 21 min 4 s | `sha256:4fe7bc121cbe…`, 46.4 GB, the pin's digest; audio image 628812adb713, 46.7 GB, build exit 0 |
| framework | `google/gemma-4-26B-A4B-it` | 20:26:05 | 1 h 13 min 17 s | 4d7ae498…: 12 files, 51,644,340,088 bytes |
| framework | `google/gemma-4-E4B-it` | 19:58:39 | 45 min 51 s | 4ecc2ba6…: 9 files, 16,024,810,531 bytes |
| framework | `ibm-granite/granite-embedding-english-r2` | 19:29:07 | 16 min 19 s | 47ea694b…: 10 files, 301,662,285 bytes |

No snapshot held a `*.incomplete` blob. Disk after: gb10-2 3.51 TB free, the Framework 611 GB.

**The image checks** (20:37:48Z, `image-checks.out`), each a throwaway container with no server:

| Image | `rocminfo` | torch, HIP | torchcodec | av | soundfile | soxr | ffmpeg |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `vllm/vllm-openai-rocm:v0.33.0` (ROCm 10.0) | `Name: gfx1151`, `Marketing Name: AMD Radeon 8060S Graphics`, Runtime Version 1.21 | 2.13.0+rocm10.0.0, HIP 7.15.26333 | missing | missing | missing | missing | none |
| `spike-model-engines/vllm-openai-rocm-audio:v0.33.0` | – | as above | missing | **19.0.2** | **0.14.0** | **1.1.0** | none |
| `vllm/vllm-openai-rocm:v0.33.0-rocm72` | `Name: gfx1151`, Runtime Version 1.18; `/opt/rocm/.info/version` 7.2.3 | 2.13.0+git733fca1, HIP 7.2.53211 | missing | missing | missing | missing | none |
| `spike-model-engines/vllm-openai-rocm-audio:v0.33.0-rocm72` | – | as above | missing | 19.0.2 | 0.14.0 | 1.1.0 | none |

Every image read vllm 0.33.0, scipy 1.18.1 and mistral_common 1.13.0. The ROCm 10.0 image has no
`/opt/rocm/.info/version` file. **The official ROCm 10.0 image lacks the audio decoders, and the
rebuilt image imports av, soundfile and soxr**; torchcodec is absent from both, outside the
Dockerfile's pins (M).

### A.5 What each start fetched

Each of the twelve start logs (`<host>-{first,cold}-<purpose>.log`) prints the hub's
unauthenticated-request warning and `Fetching N files: 100%` twice, at 884 to 3,339 files a second,
and no download-rate line: the files resolved against the staged snapshot. **No vLLM start
downloaded a model file; every start contacted the hub for metadata**, as agent-vllm found (A.3
there). The rows set no offline flag (N).

## B. The step helpers read several vLLM containers (Behavior 5)

**Decision it informs:** whether every vLLM read comes from a tracked helper. Commit b55d744,
"measure-lib: footprint and readout read the vLLM container by port, with GTT on amdgpu", in
`scripts/measure-lib.sh`:

- sourced for port 8000, 8001 or 8002, the engine is vLLM, and its container is the one whose port
  bindings publish that port (the running one, else the newest); with none, port 8000 falls back to
  `vllm`, any other port prints that no container publishes it. `MEASURE_CONTAINER` and
  `MEASURE_ENGINE` still override, and `readout`'s log line names the container it read;
- on an amdgpu host, vLLM's `footprint` reads `amdgpu_top -p` by host pid, printing each process's
  VRAM, GTT and RSS and the container's totals, and the pool as GTT used of total beside system
  MemAvailable (D, K show it);
- a llama.cpp host and `watch` read as before: `footprint` printed each llama-server row with GTT
  on the Framework (D).

Commit c881c29, "measure-lib: vLLM readout no longer counts "sparse" as a parser line", followed
the idle read at 22:17Z: on the ROCm 10.0 image every vLLM container logs `Op 'sparse_attn_indexer'
not present in model`, which the readout's `pars(e|er|ing)` matched, so the idle read counted one
"Harmony or parser" line per Framework container (`v-probe-framework.out`). The pattern now skips
"parse" inside "sparse"; every cell from 22:18:53Z read 0 (L.2). The check passed at each commit.

## C. Cold starts, the first starts apart (Behavior 7)

**Decision it informs:** what each row takes to come up, and the Framework's vLLM load time, the
roadmap's open item ("This spike hasn't measured the Framework's vLLM load time"). Each host
stopped `llama` (`docker stop llama`) and installed its three rows in order, vision, audio,
embedding, each after the previous one's `/health` 200: the **first starts**, which filled the
compile cache, recorded apart. Then each row's container was stopped, the page cache dropped, and
the container started alone while the other two served: the **cold starts**, each from the compile
cache ("Directly load AOT compilation"). Both hosts ran their starts at the same time (a decision
the brief didn't cover: no cell ran during them).

| Host, row | First start: from the command (from StartedAt) | Cold start: from the command (from StartedAt) | `/health` 200 after, laptop | Cold: model loading (weights read) | First: compile | Pool before the cold start | Lowest during the cold start |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-2, vision NVFP4 | 221.0 s (219.9) | **168.6 s** (168.5) | 169.0 s | 18.13 GiB in 120.33 s (117.14) | 6.75 s | 85.71 GiB | 32.73 GiB |
| gb10-2, audio E4B | 183.3 s (182.6) | **162.2 s** (162.1) | 162.7 s | 15.08 GiB in 100.75 s (98.00) | 8.38 s | 62.30 GiB | **27.00 GiB** (22:16:02Z) |
| gb10-2, granite | 36.0 s (35.1) | **19.6 s** (19.5) | 21.0 s | 0.29 GiB in 3.41 s (1.67) | 2.25 s | 37.68 GiB | 35.08 GiB |
| framework, vision BF16 | 169.1 s (168.3) | **100.9 s** (100.8) | 101.6 s | 48.6 GiB in 20.43 s (16.36) | 40.44 s | GTT 90.74, system 89.68 GiB | GTT 23.35, system 18.29 GiB |
| framework, audio E4B | 146.9 s (146.7) | **73.4 s** (73.4) | 74.6 s | 15.22 GiB in 6.44 s (3.00) | 46.21 s | GTT 43.23, system 42.37 GiB | GTT 23.01, system 16.77 GiB |
| framework, granite | 34.1 s (33.4) | **20.5 s** (20.4) | 20.8 s | 0.29 GiB in 2.45 s (0.07) | 3.11 s | GTT 23.74, system 19.51 GiB | GTT 23.01, system 16.18 GiB |

The `llama` loads, from a dropped page cache (D): gb10-2 15.1, 9.1 and 3.1 s; the Framework 6.1,
6.1 and 3.1 s. **vLLM's cold start is 11.2 times llama.cpp's load for gb10-2's vision row and 16.5
times for the Framework's (c: 168.6 / 15.1; 100.9 / 6.1).** The compile cache after: gb10-2 438M,
the Framework 365M after the first starts and 982M at the restore. The lowest pool during any
start was gb10-2's 27.00 GiB during the audio row's cold start, 14.80 GiB above its floor (c); on
the Framework the system pool's 15.77 GiB during granite's first start, 3.27 above its floor (c). A
start isn't run under `watch`, so a dip under a floor there would not have been stopped.

**Where the start goes.** On gb10-2 weight reading is most of each Gemma start: 117.14 s of the
vision row's 168.6 s, 18.13 GiB at about 0.15 GiB/s (c), and 98.00 s of the audio row's 162.2 s,
the same rate (c: 15.08 / 98.00). That is GB10's per-tensor mmap-copy cost agent-vllm traced to
vllm-project/vllm#58726, fixed by #58868 in v0.34.0 and not in v0.33.0 (cited,
[agent-vllm](agent-vllm.md), C). The Framework read 48.6 GiB in 16.36 s, about 2.97 GiB/s (c), and
15.22 GiB in 3.00 s: there the cold start is mostly engine start, compile loading, profiling and
graph capture (the vision row's two captures took 9 s and 2 s).

**The Framework's vLLM start against v0.32.0's** (spike-model-engines' `vllm-strix` finding,
2026-10-28, cited; a record across versions, not a comparison: there one row served alone at 0.80
in one `vllm` container, from StartedAt):

| Row | v0.33.0 here, first / cold (from StartedAt) | v0.32.0, first / timed (vllm-strix) | v0.33.0 weights here | v0.32.0 weights |
| --- | --- | --- | --- | --- |
| 26B-A4B BF16 | 168.3 / 100.8 s | 167.3 / 73.9 s | 48.6 GiB, 20.43 s | 48.54 GiB, 17.0 s |
| E4B BF16 | 146.7 / 73.4 s | 166.6 / 97.6 s | 15.22 GiB, 6.44 s | 15.08 GiB, 5.9 s |
| granite BF16 | 33.4 / 20.4 s | 32.8 / 21.2 s | 0.29 GiB, 2.45 s | 0.29 GiB, 2.3 s |

**This answers the roadmap's item:** on v0.33.0's ROCm 10.0 image the Framework's vLLM rows start
in 20 to 101 s from a dropped page cache with the compile cache warm, and 33 to 168 s compiling;
weight reading is 3 to 16 s of it.

## D. Idle reads and the gates (Behaviors 6, 7, 8)

**Decision it informs:** what each engine's arrangement leaves of each pool before any request,
and whether either host reads under a floor. llama.cpp (20:38:08Z, both hosts at once): `unload
--all`, a cache drop, the three sections loaded, 30 s idle, a cache drop, the read. vLLM (22:17:16Z,
both hosts): after the cold starts, the probes (L.1), one warm-up request a row ("Say hello in one
sentence." and one embedding input), 30 s idle, a cache drop, the read.

| | gb10-2 llama.cpp (m) | gb10-2 vLLM (m) | Framework llama.cpp (m) | Framework vLLM (m) |
| --- | --- | --- | --- | --- |
| Before the load | 117.42 GiB | 118.14 GiB (`docker stop llama`) | GTT 111.69, system 117.56 GiB | GTT 111.69, system 117.66 GiB |
| Idle | **77.26 GiB** | **35.53 GiB** | **GTT 82.97, system 88.29 GiB** | **GTT 22.87, system 16.52 GiB** |
| Above the floor (c) | 65.06 GiB | 23.33 GiB | GTT 71.77, system 75.79 GiB | GTT 11.67, system 4.02 GiB |
| Vision (MiB) | 25,335 GPU / 1,231 RSS | container 46,182 GPU / 7,475 RSS | 18,380 GTT / 233 RSS | container 69,486 GTT / 6,084 RSS |
| Audio | 8,546 / 4,157 | 22,450 / 6,729 | 9,929 / 242 | 20,710 / 6,675 |
| Embedding | 863 / 827 | 661 / 3,116 | 1,102 / 117 | 753 / 3,365 |
| Router | 170 / 657 | – | 2 / 153 | – |

Every llama.cpp buffer line is role-split's on gb10-2 (K there) and framework's on the Framework
(E there), line for line: gb10-2 full-attention KV
2,560.00 MiB (8,192 cells, 5 layers, 16/16 seqs) and sliding-window 7,200.00 MiB for the 26B-A4B,
2,048.00 and 640.00 for the E4B; the Framework 640.00 and 1,800.00, 512.00 and 160.00
(`l-load-<host>.out`). On the Framework `footprint` printed each llama-server process with its
VRAM, GTT and RSS (B).

**The vLLM arrangement takes 41.73 GiB more of gb10-2 than llama.cpp's (c: 77.26 − 35.53), and
60.10 GiB more GTT and 71.77 GiB more system memory of the Framework (c).** gb10-2's rows sum to
0.65 of 121.63 GiB, 79.06 GiB (c); the decision computed about 42 GiB left available idle, and the
read is 35.53, 6.47 GiB less (c). The Framework's sum to 0.81 of the 112 GiB GTT ceiling, 90.72 GiB
(c); GTT used read 89.13 GiB. The vLLM containers' RSS, 15.75 GiB on the Framework idle (c: 6,084 +
6,675 + 3,365 MiB), sits in system memory outside GTT, where llama.cpp's processes held 0.73 GiB
(c: 153 + 233 + 242 + 117 MiB).

**The gates (Behavior 8).**

- **Floors at the idle read:** `floorcheck` printed "floor held at the idle read: 36303 MiB
  available" on gb10-2 and "floors held at the idle read: GTT 23423 MiB, system 16880 MiB
  available" on the Framework. Neither host read under a floor, so neither phase stopped.
- **ROCM_ATTN on a Framework Gemma row:** each start's `startlog` counted `ROCM_ATTN lines: 0` on
  the vision and audio rows, first and cold. Granite's start logs name it (F); granite is not a
  Gemma row, so the gate (#62697) didn't apply, and the session recorded it and went on (a reading
  the brief's wording supports: "a Gemma row").
- **ROCm 10.0 fallback:** the `-rocm100` image started and served (M), so no `-rocm72` run.

## E. KV cache and sizing per row (Behavior 7)

From each start log, by `startlog` and `footprint` (`v-install-<host>.out`, `v-cold-<host>.out`;
the saved logs `<host>-{first,cold}-<purpose>.log`):

| Host, row | Fraction, of | Model loading | Available KV cache memory, cold (first) | KV cache tokens, cold (first) | Concurrency at 8,192 tokens, cold (first) | Free memory at startup, cold (first) | Weights + non-torch, cold (first) | CUDA graphs, cold |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-2, vision NVFP4 | 0.40 of 121.63 GiB (48.65) | 18.13 GiB | 26.25 GiB (26.33) | **164,570** (165,033) | 20.09x (20.15x) | 81.22 GiB (113.71) | 21.57 GiB (21.63) | 0.11 + 0.09 GiB |
| gb10-2, audio E4B | 0.20 (24.33 GiB) | 15.08 GiB | 6.36 GiB (8.53) | **172,508** (231,342) | 21.06x (28.24x) | 58.79 GiB (61.33) | 17.29 GiB (15.11) | 0.15 + 0.09 GiB |
| gb10-2, granite | 0.05 | 0.29 GiB | none logged | none: encoder-only pooling | – | – | – | 0.05 GiB |
| framework, vision BF16 | 0.60 of 112.0 GiB (67.2) | 48.6 GiB | 17.4 GiB (17.4) | **109,055** (109,059) | **13.31x** (13.31x) | 90.78 GiB (111.73) | 49.03 GiB (49.03) | 0.28 + 0.22 GiB |
| framework, audio E4B | 0.18 (20.16 GiB) | 15.22 GiB | 3.86 GiB (3.86) | **104,813** (104,827) | **12.79x** (12.80x) | 43.28 GiB (44.01) | 15.49 GiB (15.49) | 0.30 + 0.16 GiB |
| framework, granite | 0.03 | 0.29 GiB | none logged | none | – | – | – | 0.13 GiB |

llama.cpp's sections, for the same purposes (D; c from their arguments): gb10-2's 26B-A4B and E4B
hold 131,072 tokens each over 16 slots of 8,192; the Framework's 32,768 each over 4 slots; granite
131,072 over 16 on both, with no KV buffer logged.

- **The Framework's Gemma rows hold fewer full-length sequences than their 16.** The vision row's
  109,055 tokens are 13.31 sequences of 8,192 (c: 109,055 / 8,192) and the audio row's 104,813
  are 12.79 (c); at 16 sequences of 8,192 the rows would need 131,072 tokens each (c). The
  requests here are far shorter than 8,192 tokens (a vision request about 300 prompt tokens beside
  its image, an audio request 180, L.1), so no cell reached the cache: the highest KV use any
  readout saw was 5.4% (the Framework's vision row at the end of V-vision's 8-stream level, 8
  running), and every counter read 0
  preemptions (L.2).
- **gb10-2's audio row sized its cache by its start's surroundings.** Its first start, beside the
  vision row alone, logged 15.11 GiB of "weights + non-torch" and 8.53 GiB, 231,342 tokens; its
  cold start, beside both other rows serving, logged 17.29 GiB and 6.36 GiB, 172,508 tokens. The
  2.18 GiB more counted as non-torch (c) matches the 2.17 GiB less cache (c), on unified memory
  where the other processes' allocations are visible to the profile. The vision row's cache moved
  0.08 GiB between its starts, and the Framework's rows under 0.01 GiB.
- vLLM's log lines say each fraction counts CUDA-graph memory: 0.40 acts as 0.3989 without it on
  gb10-2's vision row, 0.60 as 0.5974 on the Framework's.

## F. Backends (Behavior 7)

Each start log names the backends vLLM chose; no row names one:

| Host, row | Attention | MoE | Other lines |
| --- | --- | --- | --- |
| gb10-2, vision | `TRITON_ATTN`: "Gemma4 model has heterogeneous head dimensions {'sliding_attention': 256, 'full_attention': 512}. FA4 not available, forcing TRITON_ATTN backend." | `Using 'FLASHINFER_CUTLASS' NvFp4 MoE backend out of potential backends: ['FLASHINFER_TRTLLM', 'FLASHINFER_CUTEDSL', 'FLASHINFER_CUTEDSL_BATCHED', 'FLASHINFER_CUTLASS', 'VLLM_CUTLASS', 'MARLIN', 'HUMMING', 'EMULATION']` | `WARNING [modelopt.py:1059] w1_weight_scale_2 must match w3_weight_scale_2. Accuracy may be affected.` at both starts (L.3) |
| gb10-2, audio | `TRITON_ATTN`, forced the same way | – | – |
| gb10-2, granite | `Using FLASH_ATTN attention backend out of potential backends: ['FLASH_ATTN', 'TRITON_ATTN', 'FLEX_ATTENTION']` | – | "Pooling models do not support full cudagraphs. Overriding cudagraph_mode to PIECEWISE." |
| framework, vision | `Using TRITON_ATTN backend (selected via --attention-backend).`, after the same "forcing TRITON_ATTN" line: vLLM's Gemma 4 config sets it, the row names none | `Using TRITON Unquantized MoE backend out of potential backends: ['ROCm AITER', 'TRITON', 'BATCHED_TRITON']`, then `Using TritonExperts MoE backend` | "Using default MoE config. Performance might be sub-optimal! Config file not found" for `E=128,N=704` |
| framework, audio | `TRITON_ATTN`, the same way | – | – |
| framework, granite | `Found incompatible backend(s) [TURBOQUANT, ROCM_OCTAVE, ULTRAQUANT] with AttentionType.ENCODER_ONLY. Overriding with ROCM_ATTN out of potential backends: ['ROCM_ATTN', 'TRITON_ATTN'].` | – | – |

**No Framework Gemma row named ROCM_ATTN** (#62697's case); **granite chose ROCM_ATTN on the
Framework**, for encoder-only attention, and it is not a Gemma row, so the gate didn't apply (D).
Every Framework container also logged ROCm's `GELU with tanh approximation is unstable with
torch.compile` and the `sparse_attn_indexer` and `rms_norm_gated` "not present in model"
compilation warnings, and both hosts' Gemma rows a "Triton kernel JIT compilation during
inference" warning at the probes.

## G. Evidence 3: each purpose alone, per level and engine (Behavior 9)

**Decision it informs:** what each engine holds per purpose on each capability host. Each sweep is
the host's role-split file, unchanged, one purpose at a time with the other two loaded and idle:
GuideLLM's knee profile, adaptive refinement off, no ramp-up (granite's a concurrent sweep). Each
cell gives requests ok / errored / incomplete; then the purpose's figures and the floor.

### G.1 gb10-2

**Vision**, `bench/role-split-vision-split.yaml` (a synthetic 1440p JPEG beside 200 text tokens,
exactly 100 out), [1, 4, 8, 12, 16], 90 s a level. L-vision 20:39:28-20:47:55Z, knee **11.80**
(breakpoint 12, saturation 12: "A rising segment followed by a substantially flatter tail was
detected"); V-vision 22:18:53-22:27:22Z, **no knee** ("No breakpoint satisfied the saturation
thresholds").

| Streams | llama.cpp, 16-slot 26B-A4B | vLLM, NVFP4 26B-A4B |
| --- | --- | --- |
| 1 | 21 / 0 / 1; 23.33 tok/s; TTFT 2,690 ms; ITL 14.36 ms; latency 4.12 / 4.14 / 4.01 s; 21 of 21 ≤10 s: meets | 25 / 0 / 1; 27.78 tok/s; TTFT 336 ms; ITL 32.40 ms; latency 3.54 / 3.56 / 3.53 s; 25 of 25 ≤10 s: meets |
| 4 | 23 / 1 / 4; 25.56 tok/s; TTFT 10,339 ms; ITL 26.83 ms; latency 12.92 / 14.14 / 12.79 s; 0 of 23 ≤10 s: **misses** | 76 / 0 / 4; 84.44 tok/s; TTFT 1,170 ms; ITL 34.93 ms; latency 4.61 / 4.65 / 4.55 s; 76 of 76 ≤10 s: meets |
| 8 | 23 / 1 / 8; 25.56 tok/s; TTFT 20,370 ms; ITL 43.28 ms; latency 24.66 / 25.94 / 24.37 s; 0 of 23 ≤10 s: **misses** | 112 / 0 / 8; 124.44 tok/s; TTFT 2,157 ms; ITL 42.76 ms; latency 6.39 / 6.42 / 6.22 s; 112 of 112 ≤10 s: meets |
| 12 | 23 / 1 / 12; 25.56 tok/s; TTFT 30,502 ms; ITL 69.96 ms; latency 37.26 / 38.71 / 37.05 s; 0 of 23 ≤10 s: **misses** | 120 / 0 / 12; 133.33 tok/s; TTFT 2,635 ms; ITL 61.60 ms; latency 8.74 / 8.76 / 7.54 s; 119 of 120 ≤10 s: meets |
| 16 | 16 / 0 / 16; 17.78 tok/s; TTFT 40,382 ms; ITL 65.84 ms; latency 47.04 / 47.08 / 46.40 s; 0 of 16 ≤10 s: **misses** | 144 / 0 / 16; 160.00 tok/s; TTFT 3,022 ms; ITL 65.61 ms; latency 9.51 / 9.88 / 8.32 s; 133 of 144 ≤10 s: meets |
| **Holds** | **1** (4 misses, at or below the knee of 11.80) | **16** (no knee) |

**Audio**, `bench/role-split-audio-split.yaml` (one of the 73 LibriSpeech clips with the card's
transcription prompt, up to 256 out), [1, 4, 8, 12, 16], 30 s or 64 requests a level. L-audio
20:48:09-20:50:35Z and V-audio 22:27:25-22:29:07Z, **no knee** on either. Each cell gives the
latency median / p90, RTFx median / minimum with the count at ≥5, and the level's duration.

| Streams | llama.cpp, 16-slot E4B | vLLM, E4B BF16 |
| --- | --- | --- |
| 1 | 49 / 0 / 1; 31.90 tok/s; TTFT 165 ms; ITL 21.66 ms; latency 0.51 / 0.97 s; RTFx 11.00 / 6.31, 49 of 49 ≥5; 30 s: meets | 22 / 0 / 1; 18.17 tok/s; TTFT 167 ms; ITL 47.80 ms; latency 0.99 / 2.00 s; RTFx 6.50 / 4.48, 17 of 22 ≥5; 30 s: meets |
| 4 | 64 / 0 / 0; 49.94 tok/s; TTFT 376 ms; ITL 58.86 ms; latency 1.22 / 2.60 s; RTFx 4.34 / 2.42, 21 of 64 ≥5; 24 s: **misses** | 64 / 0 / 0; 69.07 tok/s; TTFT 188 ms; ITL 42.47 ms; latency 0.85 / 1.78 s; RTFx 6.17 / 3.18, 50 of 64 ≥5; 17 s: meets |
| 8 | 64 / 0 / 0; 62.03 tok/s; TTFT 614 ms; ITL 94.58 ms; latency 2.01 / 3.54 s; RTFx 2.69 / 1.36, 0 of 64 ≥5; 19 s: **misses** | 64 / 0 / 0; 138.42 tok/s; TTFT 155 ms; ITL 44.47 ms; latency 0.86 / 1.67 s; RTFx 6.61 / 3.92, 57 of 64 ≥5; 9 s: meets |
| 12 | 64 / 0 / 0; 66.40 tok/s; TTFT 958 ms; ITL 127.45 ms; latency 2.62 / 5.19 s; RTFx 1.92 / 0.85, 0 of 64 ≥5; 18 s: **misses** | 64 / 0 / 0; 183.77 tok/s; TTFT 161 ms; ITL 47.52 ms; latency 0.92 / 1.81 s; RTFx 6.03 / 3.38, 56 of 64 ≥5; 7 s: meets |
| 16 | 64 / 0 / 0; 75.52 tok/s; TTFT 1,014 ms; ITL 147.40 ms; latency 3.07 / 6.00 s; RTFx 1.69 / 0.73, 0 of 64 ≥5; 16 s: **misses** | 64 / 0 / 0; 223.05 tok/s; TTFT 183 ms; ITL 50.11 ms; latency 1.00 / 1.93 s; RTFx 5.67 / 2.93, 44 of 64 ≥5; 5 s: meets |
| **Holds** | **1** | **16** |

**Embedding**, `bench/role-split-embed.yaml` (512-token inputs to `/v1/embeddings`), concurrent [1,
2, 4, 8, 16], 30 s each. L-embed 20:50:40-20:53:58Z; V-embed 22:29:10-22:32:35Z.

| Streams | llama.cpp, granite | vLLM, granite |
| --- | --- | --- |
| 1 | 1606 / 0 / 0; 53.500 req/s; latency 0.02 s; 27,445 prompt tok/s: meets | 2156 / 0 / 0; 71.833 req/s; latency 0.01 s; 36,850 prompt tok/s: meets |
| 2 | 3556 / 0 / 1; 118.500 req/s; latency 0.01 s; 60,790 prompt tok/s: meets | 4934 / 0 / 2; 164.467 req/s; latency 0.01 s; 84,371 prompt tok/s: meets |
| 4 | 3465 / 0 / 2; 115.433 req/s; latency 0.03 s; 59,217 prompt tok/s: meets | 7474 / 0 / 2; 249.133 req/s; latency 0.01 s; 127,805 prompt tok/s: meets |
| 8 | 2618 / 0 / 5; 87.167 req/s; latency 0.09 s; 44,716 prompt tok/s: meets | 9216 / 0 / 4; 307.067 req/s; latency 0.02 s; 157,525 prompt tok/s: meets |
| 16 | 1682 / 0 / 16; 56.067 req/s; latency 0.28 s; 28,762 prompt tok/s: meets | 7407 / 0 / 0; 246.867 req/s; latency 0.04 s; 126,643 prompt tok/s: meets |
| **Holds** | **16** | **16** |

### G.2 The Framework

**Vision**, `bench/role-split-vision-full.yaml`, [1, 2, 3, 4, 8], 60 s a level. L-vision
20:58:58-21:04:41Z and V-vision 22:37:22-22:43:05Z, **no knee** on either.

| Streams | llama.cpp, capped 26B-A4B, 4 slots, Vulkan | vLLM, BF16 26B-A4B, ROCm 10.0 |
| --- | --- | --- |
| 1 | 8 / 0 / 1; 13.33 tok/s; TTFT 5,267 ms; ITL 15.68 ms; latency 6.83 / 6.86 / 6.72 s; 8 of 8 ≤10 s: meets | 12 / 0 / 1; 20.00 tok/s; TTFT 542 ms; ITL 41.26 ms; latency 4.63 / 4.63 / 4.62 s; 12 of 12 ≤10 s: meets |
| 2 | 8 / 0 / 2; 13.33 tok/s; TTFT 10,422 ms; ITL 20.65 ms; latency 13.10 / 13.79 / 12.40 s; 0 of 8 ≤10 s: **misses** | 16 / 0 / 2; 26.67 tok/s; TTFT 1,020 ms; ITL 55.04 ms; latency 6.47 / 7.68 / 6.45 s; 16 of 16 ≤10 s: meets |
| 3 | 9 / 0 / 3; 15.00 tok/s; TTFT 15,606 ms; ITL 38.20 ms; latency 19.39 / 19.48 / 18.04 s; 0 of 9 ≤10 s: **misses** | 18 / 0 / 3; 30.00 tok/s; TTFT 1,481 ms; ITL 80.82 ms; latency 9.45 / 10.59 / 9.41 s; 15 of 18 ≤10 s: meets |
| 4 | 7 / 1 / 4; 11.67 tok/s; TTFT 20,547 ms; ITL 29.32 ms; latency 23.45 / 23.71 / 23.40 s; 0 of 7 ≤10 s: **misses** | 24 / 0 / 4; 40.00 tok/s; TTFT 1,921 ms; ITL 81.41 ms; latency 9.98 / 10.01 / 9.93 s; 21 of 24 ≤10 s: meets |
| 8 | 8 / 0 / 8; 13.33 tok/s; TTFT 20,924 ms; ITL 30.14 ms; latency 35.59 / 47.21 / 23.96 s; 0 of 8 ≤10 s: **misses** | 32 / 0 / 8; 53.33 tok/s; TTFT 3,355 ms; ITL 95.90 ms; latency 12.98 / 12.99 / 12.72 s; 0 of 32 ≤10 s: **misses** |
| **Holds** | **1** | **4** |

**Audio**, `bench/role-split-audio-full.yaml`, [1, 2, 3, 4, 8], 30 s or 64 requests. L-audio
21:04:41-21:07:33Z, knee **4.16** (breakpoint 4, saturation 8); V-audio 22:43:07-22:45:29Z, **no
knee**.

| Streams | llama.cpp, capped E4B, 4 slots | vLLM, E4B BF16, the audio image |
| --- | --- | --- |
| 1 | 40 / 0 / 0; 27.17 tok/s; TTFT 225 ms; ITL 24.54 ms; latency 0.63 / 1.26 s; RTFx 8.67 / 5.10, 40 of 40 ≥5; 30 s: meets | 26 / 0 / 1; 20.47 tok/s; TTFT 178 ms; ITL 40.94 ms; latency 0.89 / 1.70 s; RTFx 7.01 / 4.39, 24 of 26 ≥5; 30 s: meets |
| 2 | 48 / 0 / 2; 31.60 tok/s; TTFT 337 ms; ITL 43.94 ms; latency 0.95 / 2.26 s; RTFx 5.55 / 3.19, 32 of 48 ≥5; 30 s: meets | 55 / 0 / 1; 35.53 tok/s; TTFT 179 ms; ITL 43.29 ms; latency 0.84 / 1.73 s; RTFx 6.27 / 1.74, 47 of 55 ≥5; 30 s: meets |
| 3 | 61 / 0 / 3; 37.90 tok/s; TTFT 468 ms; ITL 50.82 ms; latency 1.26 / 2.30 s; RTFx 4.29 / 1.89, 15 of 61 ≥5; 30 s: **misses** | 64 / 0 / 0; 55.36 tok/s; TTFT 152 ms; ITL 44.33 ms; latency 0.87 / 1.66 s; RTFx 6.69 / 3.76, 55 of 64 ≥5; 22 s: meets |
| 4 | 64 / 0 / 0; 46.08 tok/s; TTFT 533 ms; ITL 56.91 ms; latency 1.39 / 2.53 s; RTFx 3.97 / 1.95, 16 of 64 ≥5; 26 s: **misses** | 64 / 0 / 0; 71.29 tok/s; TTFT 155 ms; ITL 45.51 ms; latency 0.87 / 1.70 s; RTFx 6.38 / 3.68, 54 of 64 ≥5; 17 s: meets |
| 8 | 64 / 0 / 0; 47.30 tok/s; TTFT 1,883 ms; ITL 57.42 ms; latency 2.92 / 4.12 s; RTFx 1.90 / 0.77, 0 of 64 ≥5; 25 s: **misses** | 64 / 0 / 0; 117.11 tok/s; TTFT 175 ms; ITL 52.86 ms; latency 1.09 / 2.04 s; RTFx 5.38 / 3.32, 41 of 64 ≥5; 10 s: meets |
| **Holds** | **2** | **8** |

**Embedding**, as gb10-2's. L-embed 21:07:35-21:10:46Z; V-embed 22:45:31-22:48:43Z.

| Streams | llama.cpp, granite | vLLM, granite |
| --- | --- | --- |
| 1 | 754 / 0 / 0; 25.100 req/s; latency 0.04 s; 12,876 prompt tok/s: meets | 2847 / 0 / 0; 94.867 req/s; latency 0.01 s; 48,667 prompt tok/s: meets |
| 2 | 991 / 0 / 1; 33.000 req/s; latency 0.06 s; 16,929 prompt tok/s: meets | 4705 / 0 / 1; 156.800 req/s; latency 0.01 s; 80,438 prompt tok/s: meets |
| 4 | 1297 / 0 / 3; 43.200 req/s; latency 0.09 s; 22,162 prompt tok/s: meets | 5161 / 0 / 2; 171.967 req/s; latency 0.02 s; 88,219 prompt tok/s: meets |
| 8 | 1288 / 0 / 4; 42.800 req/s; latency 0.18 s; 21,956 prompt tok/s: meets | 5552 / 0 / 4; 184.933 req/s; latency 0.04 s; 94,871 prompt tok/s: meets |
| 16 | 1200 / 0 / 7; 39.967 req/s; latency 0.40 s; 20,503 prompt tok/s: meets | 5666 / 0 / 1; 188.700 req/s; latency 0.08 s; 96,803 prompt tok/s: meets |
| **Holds** | **16** | **16** |

### G.3 What the sweeps show

| Host | Purpose | llama.cpp: knee; holds; figure there | vLLM: knee; holds; figure there |
| --- | --- | --- | --- |
| gb10-2 | vision | 11.80; **1**; 4.12 s | none; **16**; 9.51 s |
| gb10-2 | audio | none; **1**; RTFx 11.00 | none; **16**; RTFx 5.67 |
| gb10-2 | embedding | concurrent; **16**; 28,762 prompt tok/s | concurrent; **16**; 126,643 |
| framework | vision | none; **1**; 6.83 s | none; **4**; 9.98 s |
| framework | audio | 4.16; **2**; RTFx 5.55 | none; **8**; RTFx 5.38 |
| framework | embedding | concurrent; **16**; 20,503 | concurrent; **16**; 96,803 |

llama.cpp's holds repeat role-split's and framework's on the same sections (cited: gb10-2 vision 1,
audio 1; the Framework vision 1, audio 2, embedding 16), and its per-level figures lie within a few
percent of framework's F on the Framework (vision at 1: 6.83 against 6.82 s; audio at 1: RTFx 8.67
against 8.81).

- **llama.cpp's vision encodes one image at a time on both hosts**: requests a second stay at
  0.256 on gb10-2 from 4 to 12 streams and 0.117 to 0.150 on the Framework, and TTFT grows about
  10 s with each 4 streams on gb10-2 and 5 s with each stream to 4 on the Framework, as role-split
  L.1 read it. **vLLM batches
  them**: gb10-2's vision row served 0.278, 0.844, 1.244, 1.333 and 1.600 requests a second from 1
  to 16 streams, with TTFT 336 ms to 3,022 ms; the Framework's 0.200 to 0.533 to 8 streams.
- **vLLM's audio row met RTFx 5 at every level on both hosts**, its TTFT flat at 152 to 188 ms,
  where llama.cpp's grew to 1,014 ms (gb10-2) and 1,883 ms (the Framework).
- **At 1 audio stream llama.cpp leads**: RTFx 11.00 against 6.50 on gb10-2, ITL 21.66 against
  47.80 ms; 8.67 against 7.01 on the Framework, ITL 24.54 against 40.94 ms. At 1 vision stream vLLM
  leads (3.54 against 4.12 s; 4.63 against 6.83 s), on TTFT (336 against 2,690 ms), with a higher
  ITL (32.40 against 14.36 ms).
- **Embedding**: vLLM gave 1.34 to 4.40 times llama.cpp's prompt tok/s on gb10-2 across levels
  (c: 36,850 / 27,445 at 1; 126,643 / 28,762 at 16) and 3.78 to 4.75 times on the Framework (c),
  peaking at 8 streams on gb10-2 (157,525) and still rising at 16 on the Framework (96,803).

## H. The mixed cells at the targets (Behavior 9)

**Decision it informs:** what one capability host holds with all three purposes at their targets
at once. Each cell starts three GuideLLM processes together on one host, 240 s each
(`bench/role-split-mixed-{vision,audio,embed}.yaml`, streams from `GUIDELLM__SPEC__PROFILE__STREAMS`):
vision 4, audio 4, embedding 16.

| Purpose | gb10-2 llama.cpp, L-mixed 20:54:13Z | gb10-2 vLLM, V-mixed 22:32:39Z | Framework llama.cpp, L-mixed 21:10:59Z | Framework vLLM, V-mixed 22:48:46Z |
| --- | --- | --- | --- | --- |
| Vision, 4 | 20 / 0 / 4; 8.33 tok/s; TTFT 27,754 ms; ITL 171.13 ms; latency 44.68 / 51.10 / 37.55 s; 0 of 20 ≤10 s: **misses** | 64 / 0 / 4; 26.67 tok/s; TTFT 3,439 ms; ITL 115.86 ms; latency 14.90 / 15.01 / 13.85 s; 0 of 64: **misses** | 23 / 1 / 4; 9.58 tok/s; TTFT 27,212 ms; ITL 78.26 ms; latency 34.38 / 37.10 / 33.14 s; 0 of 23: **misses** | 32 / 0 / 4; 13.33 tok/s; TTFT 4,527 ms; ITL 256.86 ms; latency 30.11 / 30.40 / 28.36 s; 0 of 32: **misses** |
| Audio, 4 | 136 / 0 / 4; TTFT 1,738 ms; ITL 292.65 ms; latency 6.06 / 11.25 s; RTFx 0.93 / 0.47, 0 of 136 ≥5: **misses** | 318 / 0 / 4; TTFT 474 ms; ITL 138.07 ms; latency 2.67 / 4.98 s; RTFx 2.15 / 1.15, 7 of 318: **misses** | 122 / 0 / 4; TTFT 2,019 ms; ITL 225.37 ms; latency 6.24 / 13.71 s; RTFx 0.93 / 0.19, 0 of 122: **misses** | 404 / 0 / 4; TTFT 363 ms; ITL 108.75 ms; latency 2.10 / 3.94 s; RTFx 2.75 / 1.46, 5 of 404: **misses** |
| Embedding, 16 | 5571 / 0 / 11; 23.192 req/s; latency 0.70 s; 11,897 prompt tok/s: **meets** | 22362 / 0 / 10; 93.175 req/s; 0.17 s; 47,799: **meets** | 3728 / 0 / 16; 15.533 req/s; 0.92 s; 7,969: **meets** | 16997 / 0 / 16; 70.821 req/s; 0.22 s; 36,331: **meets** |
| Pool lowest (`watch`) | 68.59 GiB (20:55:04Z) | 31.46 GiB (22:33:40Z) | GTT 82.27 (21:11:19Z), system 85.50 GiB (21:13:30Z) | GTT 21.67 (22:51:57Z), system 13.58 GiB (22:50:26Z) |

**At the targets each host holds embedding and neither vision nor audio, on either engine.** vLLM
narrows the gap on gb10-2: vision at 14.90 s against 44.68 (3.0 times faster, c), audio at RTFx
2.15 against 0.93. On the Framework vLLM's vision barely moved (30.11 against 34.38 s), with its
ITL at 256.86 ms against 81.41 ms alone at 4 (G.2).

**Each purpose alone against beside the other two, at 4 streams, vLLM** (G and above): gb10-2's
vision 4.61 → 14.90 s and ITL 34.93 → 115.86 ms, audio RTFx 6.17 → 2.15; the Framework's vision
9.98 → 30.11 s, audio 6.38 → 2.75. Memory stayed far from the floor on gb10-2 (31.46 GiB at its
lowest) and on the Framework's GTT (21.67), so the cells met speed, not memory, as the framework
finding read on llama.cpp (L.1 there). vLLM's embedding row served 93 and 71 requests a second in
these cells, against llama.cpp's 23 and 16, the heavier neighbour of the two (N.1).

## I. The two-host cell (Behavior 10)

**Decision it informs:** whether two capability hosts reach the targets on each engine, read as
framework's P-target was. Each cell starts six GuideLLM processes together from the laptop, three
a host, 240 s each: vision 2 + 2, audio 2 + 2, embedding 8 + 8 (`two.sh` for llama.cpp, `v-two.sh`
for vLLM, each host's half its own step file).

**The llama.cpp cell ran twice.** Its first run started at 21:15:31Z and was killed about a minute
later, when Claude Code on the laptop reaped the background shell for low laptop memory (31.5 GiB
in all, 12 GiB of swap in use afterwards). No result JSON was written; each host's partial `.log`
and `.watch.tsv` (4 samples to 21:16:12Z) are in `.state/measure/<host>/reaped-two-2026-11-11/`,
with the step outputs. The hosts were untouched by it and still served their sections. The session
escalated; the architect closed applications on the laptop, the session deleted, at the
architect's word, stale temporary directories of finished sessions from the laptop's in-memory
`/tmp` (swap 10.3 → 2.2 GiB, available 15.7 → 18.3 GiB), and the architect answered **1 b**: free
memory with the reaper left on and rerun once, dropping the cell on both engines if reaped again.
The rerun, 21:54:03-21:58:34Z, ran to its end; its step outputs are
`.state/capability-vllm/two-rerun-<host>.out`, copied there from the scratch directory in this
finding's slice (`two-<host>.out` beside them is the reaped run's). The vLLM cell ran with
21,256 MiB available on the laptop (`v-two-laptop-free.txt`) and dipped to 9,713 MiB during it
(the session's read at 22:56:28Z); it was not reaped.

| Purpose | llama.cpp, L-two 21:54:03Z: gb10-2 | llama.cpp: framework | vLLM, V-two 22:53:23Z: gb10-2 | vLLM: framework |
| --- | --- | --- | --- | --- |
| Vision, 2 + 2 | 20 / 0 / 2; 8.33 tok/s; TTFT 13,453 ms; ITL 141.42 ms; latency 24.58 / 27.77 / 14.92 s; 0 of 20 ≤10 s: **misses** | 28 / 0 / 2; 11.67 tok/s; TTFT 13,466 ms; ITL 56.73 ms; latency 18.37 / 19.83 / 6.72 s; 4 of 28: **misses** | 44 / 0 / 2; 18.33 tok/s; TTFT 1,349 ms; ITL 96.36 ms; latency **10.89** / 10.94 / 8.36 s; 2 of 44: **misses** | 28 / 0 / 2; 11.67 tok/s; TTFT 1,878 ms; ITL 154.55 ms; latency 17.18 / 17.65 / 13.84 s; 0 of 28: **misses** |
| Audio, 2 + 2 | 126 / 0 / 2; TTFT 927 ms; ITL 154.50 ms; latency 3.10 / 6.62 s; RTFx 1.68 / 0.76, 4 of 126 ≥5: **misses** | 112 / 0 / 2; TTFT 1,007 ms; ITL 109.34 ms; latency 2.83 / 8.59 s; RTFx 1.94 / 0.51, 1 of 112: **misses** | 178 / 0 / 2; TTFT 451 ms; ITL 123.39 ms; latency 2.33 / 4.52 s; RTFx 2.38 / 1.27, 8 of 178: **misses** | 236 / 0 / 2; TTFT 310 ms; ITL 90.99 ms; latency 1.77 / 3.31 s; RTFx 3.25 / 1.72, 6 of 236: **misses** |
| Embedding, 8 + 8 | 8952 / 0 / 5; 37.287 req/s; latency 0.20 s; 19,128 prompt tok/s: **meets** | 3481 / 0 / 8; 14.504 req/s; 0.45 s; 7,441: **meets** | 19968 / 0 / 3; 83.179 req/s; 0.09 s; 42,671: **meets** | 15797 / 0 / 3; 65.800 req/s; 0.12 s; 33,755: **meets** |
| Pool lowest (`watch`) | 68.48 GiB (21:58:17Z) | GTT 82.27 (21:54:24Z), system 85.43 GiB (21:54:34Z) | 31.37 GiB (22:57:48Z) | GTT 21.66 (22:57:15Z), system 13.64 GiB (22:57:25Z) |

No request errored in either cell.

## J. Evidence 5: two capability hosts on each engine, against the targets

"Holds" counted as framework's J did: the streams on hosts whose figure met the floor.

| | llama.cpp, L-two | vLLM, V-two |
| --- | --- | --- |
| **Vision** (target 4) | 2 on gb10-2: 24.58 s; 2 on the Framework: 18.37 s. **0 of 4** | 2 on gb10-2: 10.89 s; 2 on the Framework: 17.18 s. **0 of 4** |
| **Audio** (target 4) | 2 + 2: RTFx 1.68 and 1.94. **0 of 4** | 2 + 2: RTFx 2.38 and 3.25. **0 of 4** |
| **Embedding** (target 16) | 8 + 8: 19,128 + 7,441 = 26,569 prompt tok/s (c). **16 of 16** | 8 + 8: 42,671 + 33,755 = 76,426 (c). **16 of 16** |
| **Memory left, lowest** (above the floor, c) | gb10-2 68.48 (56.28); framework GTT 82.27 (71.07), system 85.43 (72.93) | gb10-2 31.37 (19.17); framework GTT 21.66 (10.46), system 13.64 (1.14) |
| **Errors** | none | none |

The framework task's P-target, on the same llama.cpp sections beside gb10-1's agent (cited): vision
21.54 and 19.37 s, audio RTFx 1.65 and 1.68, embedding 25,644 prompt tok/s; this session's L-two
reads alike.

**One placement, read from the tables: combined vision against the target of 4.** On llama.cpp,
gb10-2 holds 1 vision request alone and the Framework 1 (G), so two hosts hold at most 2 with
nothing else running, and with audio and embedding at their shares they held 0 of 4. On vLLM each
host alone holds the target by itself, gb10-2 16 and the Framework 4 (G), so two hosts hold at least
20 vision requests (c: 16 + 4) with nothing else running; **with audio 2 and embedding 8 beside
each host's 2 vision streams they held 0 of 4**, gb10-2's share 0.89 s over the floor (c) and the
Framework's 7.18 s over. On these rows and this build, vLLM brings vision to its target only where
vision doesn't share the GPU with the other two purposes' load; the spike records it and decides
nothing.

## K. Memory through the session and the margin above each floor (Behavior 11)

Each read is after the cell, the cache dropped, then `memory` and `footprint` (`after` for
llama.cpp, `v_after` for vLLM, which reads every row's container). "Lowest" is `watch`'s during the
cell. No cell, start or read went under a floor; every `floorcheck` held.

**gb10-2** (floor 12.2 GiB). Processes or containers GPU / RSS, MiB:

| After | Pool | Lowest during | Above the floor at the lowest (c) | Vision | Audio | Embedding |
| --- | --- | --- | --- | --- | --- | --- |
| llama.cpp idle, 30 s | 77.26 | – | 65.06 (idle) | 25,335 / 1,231 | 8,546 / 4,157 | 863 / 827 |
| L-vision | 70.35 | 69.48 | 57.28 | 26,150 / 7,507 | 8,546 / 4,157 | 863 / 827 |
| L-audio | 69.17 | 69.16 | 56.96 | 26,150 / 7,507 | 8,776 / 5,165 | 863 / 827 |
| L-embed | 68.91 | 68.90 | 56.70 | 26,150 / 7,507 | 8,776 / 5,165 | 977 / 969 |
| L-mixed | 68.69 | 68.59 | 56.39 | 26,150 / 7,391 | 8,776 / 5,282 | 977 / 969 |
| L-two | 68.99 | **68.48** | **56.28** | 26,150 / 7,161 | 8,776 / 5,313 | 977 / 969 |
| vLLM idle, 30 s | 35.53 | 27.00 (cold audio start) | 23.33 (idle) | 46,182 / 7,475 | 22,450 / 6,729 | 661 / 3,116 |
| V-vision | 33.46 | 33.43 | 21.23 | 47,216 / 8,423 | 22,482 / 6,941 | 661 / 3,117 |
| V-audio | 31.69 | 31.68 | 19.48 | 47,216 / 8,425 | 24,306 / 6,876 | 661 / 3,117 |
| V-embed | 31.54 | 31.54 | 19.34 | 47,216 / 8,425 | 24,306 / 6,876 | 827 / 3,127 |
| V-mixed | 31.49 | 31.46 | 19.26 | 47,216 / 8,426 | 24,306 / 6,888 | 861 / 3,127 |
| V-two | 31.38 | **31.37** | **19.17** | 47,216 / 8,397 | 24,306 / 6,895 | 861 / 3,127 |
| llama.cpp restore, 30 s | 77.51 | – | 65.31 (idle) | 25,335 / 1,233 | 8,546 / 4,159 | 863 / 830 |

**framework** (floors GTT 11.2, system 12.5 GiB). Processes or containers GTT / RSS, MiB:

| After | GTT / system | Lowest during, GTT / system | Above the floors at the lowest (c) | Vision | Audio | Embedding |
| --- | --- | --- | --- | --- | --- | --- |
| llama.cpp idle, 30 s | 82.97 / 88.29 | – | 71.77 / 75.79 (idle) | 18,380 / 233 | 9,929 / 242 | 1,102 / 117 |
| L-vision | 82.35 / 86.63 | 82.35 / **85.30** | 71.15 / 72.80 | 19,016 / 1,334 | 9,929 / 243 | 1,102 / 119 |
| L-audio | 82.30 / 86.67 | 82.30 / 86.63 | 71.10 / 74.13 | 19,016 / 879 | 9,980 / 561 | 1,102 / 119 |
| L-embed | 82.28 / 86.68 | 82.28 / 86.58 | 71.08 / 74.08 | 19,016 / 900 | 9,980 / 561 | 1,126 / 130 |
| L-mixed | 82.27 / 85.96 | 82.27 / 85.50 | 71.07 / 73.00 | 19,016 / 1,683 | 9,980 / 618 | 1,134 / 131 |
| L-two | 82.27 / 86.38 | **82.27** / 85.43 | **71.07** / 72.93 | 19,016 / 1,228 | 9,981 / 650 | 1,134 / 131 |
| vLLM idle, 30 s | 22.87 / 16.52 | 23.01 / 15.77 (starts) | 11.67 / 4.02 (idle) | 69,486 / 6,084 | 20,710 / 6,675 | 753 / 3,365 |
| V-vision | 22.00 / 13.92 | 22.00 / **13.26** | 10.80 / **0.76** | 70,260 / 6,523 | 20,828 / 8,092 | 753 / 3,365 |
| V-audio | 21.95 / 14.02 | 21.85 / 13.84 | 10.65 / 1.34 | 70,260 / 6,500 | 20,880 / 8,067 | 753 / 3,365 |
| V-embed | 21.79 / 13.63 | 21.79 / 13.48 | 10.59 / 0.98 | 70,260 / 6,500 | 20,880 / 8,067 | 917 / 3,373 |
| V-mixed | 21.67 / 13.74 | 21.67 / 13.58 | 10.47 / 1.08 | 70,260 / 6,429 | 21,008 / 8,069 | 917 / 3,374 |
| V-two | 21.66 / 13.73 | **21.66** / 13.64 | **10.46** / 1.14 | 70,260 / 6,429 | 21,020 / 8,072 | 917 / 3,374 |
| llama.cpp restore, 30 s | 82.97 / 89.02 | – | 71.77 / 76.52 (idle) | 18,380 / 234 | 9,929 / 238 | 1,102 / 116 |

**The Framework's system memory came to 0.76 GiB above its 12.5 GiB floor during the vLLM vision
sweep** (13.26 GiB at 22:42:14Z, `capability-vllm-v-vision.watch.tsv`), with GTT 10.80 GiB above its
own floor at the same cell's lowest. The three containers' RSS, 17.56 GiB after that cell (c: 6,523
+ 8,092 + 3,365 MiB), is in system memory and outside the GTT the fractions size; the audio
container's grew 6,675 → 8,092 MiB between the idle read and that cell's end, a span in which it
served only the rerun audio probe (L.1). **So on
the Framework the system floor, not GTT, binds first under these fractions (0.60, 0.18, 0.03; 0.81
of GTT)**: the GTT pool kept 10.46 GiB above its floor at its lowest, the system pool 0.76. No
fraction was changed in the session, so how the system margin moves with a smaller one is
unmeasured (N).

On gb10-2 the vLLM arrangement kept 19.17 GiB above the floor at its lowest, against llama.cpp's
56.28; the vision container's GPU memory rose 1,034 MiB with its first cell (c: 47,216 − 46,182) and
the audio container's 1,824 MiB with its own (c: 24,306 − 22,482), and neither moved after. The restore reads
llama.cpp's idle within 0.25 GiB on gb10-2 (77.51 against 77.26) and 0.73 GiB of system memory on
the Framework (89.02 against 88.29), GTT the same.

## L. Probes and errors (Behaviors 7, 11)

### L.1 Probes

**Decision it informs:** whether each vLLM row answers its kind, once. By curl from the laptop
(`v-probe.sh`, `v-probe-audio.sh`), the inputs written by `mkprobes.py` into
`.state/capability-vllm/probes/` (a 640×360 PNG of a red circle, a blue square and the text "GB10
42"; the first clip of `hf-internal-testing/librispeech_asr_dummy`, LibriSpeech 1272-128104-0000,
5.86 s, as 16 kHz WAV), the replies in `probes/<host>-<kind>.json`:

| Probe | gb10-2 | framework |
| --- | --- | --- |
| Image, `/v1/chat/completions`, "Describe this image in one sentence: the shapes, their colors, and any text." | `stop`: "The image features a red circle on the left, a blue square on the right, and the text "GB10 42" centered above them." 296 prompt, 33 completion tokens | the same reply, the same tokens |
| Audio, `input_audio`, the card's transcription prompt | `stop`: "Mr Quilter is the apostle of the middle classes and we are glad to welcome his gospel." 180 prompt, 20 completion tokens | the same |
| Embeddings, "The cat sat on the mat." and "A cat was sitting on a rug." | 2 × 768 dimensions, cosine 0.9193, 19 prompt tokens | 2 × 768, cosine 0.9184, 19 |

The reference transcript reads "MISTER QUILTER IS THE APOSTLE OF THE MIDDLE CLASSES AND WE ARE GLAD
TO WELCOME HIS GOSPEL": both rows transcribed it word for word but "Mr" for "MISTER". **The first
audio attempt (22:17:16Z) sent no body**: `jq --arg wav "$(base64 …)"` exceeded the argument limit
(`/usr/bin/jq: Argument list too long`), and the row answered `400` "Field required" (the one
response ≥400 in each audio row's idle readout). It was rerun at 22:18:10Z with the payload built by
`jq --rawfile`, and `v-probe.sh` fixed the same way. **Every probe passes.**

### L.2 Errors in every cell

GuideLLM's errored count (G to I), and for vLLM the server log since each cell's start: `readout`'s
counts and `v_after`'s `ERROR`, `WARNING` and `Traceback` lines, saved as
`.state/capability-vllm/<host>-capability-vllm-v-<cell>-<container>.errors.log`:

| Cells | GuideLLM errored | Server log |
| --- | --- | --- |
| llama.cpp, gb10-2: L-vision; the rest | 3 (one each at 4, 8 and 12 streams); 0 | – |
| llama.cpp, framework: L-vision; L-mixed; the rest | 1 (at 4 streams); 1 (vision); 0 | – |
| llama.cpp, L-two | 0 | – |
| vLLM, all ten cells on both hosts | **0** | ERROR 0, Traceback 0, Harmony or parser 0, HarmonyError 0, responses ≥400 0, lines naming gemma4 0; preemptions 0 in all 56 counter reads |

**Every llama.cpp error is the Gemma 4 output parser's**: GuideLLM's `ValueError('Streaming
response returned an error: The model produced output that does not match the expected peg-gemma4
format')`, 5 requests in all, every one a vision request on a 26B-A4B (gb10-2's CUDA and the
Framework's Vulkan), as framework L.4 recorded. **vLLM's Gemma 4 parsers logged none** in any cell.
llama.cpp's granite counted 180,196 idle-slot saves in gb10-2's L-embed and 76,047 in the
Framework's (role-split L.3's intake note).

The vLLM WARNING lines in the cells' error logs: two on gb10-2's vision row in V-vision, FlashInfer's
autotuner falling back for the NVFP4 MoE GEMM ("No tuned config covers trtllm::fused_moe::gemm1 …
falling back to runner=MoERunner tactic=-1. This shape is outside the tuning bucket range"), and on
the Framework's audio row one per request (L.4).

### L.3 The NVFP4 checkpoint's warning

Both of gb10-2's vision starts logged:

```
WARNING 11-11 22:13:23 [modelopt.py:1059] w1_weight_scale_2 must match w3_weight_scale_2. Accuracy may be affected.
```

The row answered its probe correctly and errored nothing, and the brief's evals go no further than
the probes, so the warning's effect on output quality is unmeasured (N).

### L.4 The audio image's torchcodec fallback

The Framework's audio row logged, once per audio request, as its first came at the probe:

```
WARNING 11-11 22:18:12 [audio.py:480] torchcodec unavailable (ImportError('torchcodec audio backend is unavailable (requires the torchcodec package and a system ffmpeg installation)')); falling back to soundfile/PyAV.
```

275 such lines in V-audio, 408 in V-mixed and 238 in V-two, one per request sent (c: requests ok
plus incomplete, 273 + 2, 404 + 4, 236 + 2); every request succeeded. gb10-2's official CUDA image
logged none.

## M. The ROCm 10.0 outcome and the audio image (Behaviors 4, 8)

**v0.33.0's default ROCm image, ROCm 10.0, runs on the Framework's gfx1151.** Its `rocminfo` names
gfx1151 (A.4); all three rows started on it, first and cold, with no error line in any start log
(`error lines: 0`), answered their probes (L.1), and ran every cell with no errored request and no
server error (L.2). The fallback's conditions (a start error, `/health` never 200, probes or cells
erroring) never arose, so **no `-rocm72` run**: the `-rocm72` image and its audio image stay staged
and unused, and no `host/engines vllm update` ran on the Framework, which would have removed the
unused official image (`vllm_remove_images`). **The audio image check holds**: the official
`-rocm100` image imports none of torchcodec, av, soundfile or soxr, so its audio requests would
fail as v0.32.0's returned 500 (spike-model-engines' `vllm-strix`, cited); the rebuilt image
imports av 19.0.2, soundfile 0.14.0 and soxr 1.1.0, and completed 913 audio requests in the
cells with none errored (c: 273 + 404 + 236), each with torchcodec's fallback warning. It still
lacks torchcodec and ffmpeg (N).

## N. Open items and intake notes

None of these is decided here.

- **N.1 What holds vision and audio under their floors beside each other.** On vLLM each purpose
  alone holds the target on both hosts, and beside the other two at the targets it misses (H, I),
  with memory far from gb10-2's floor and the Framework's GTT floor. The figures point to the
  purposes sharing one GPU's compute and bandwidth, as the framework finding read on llama.cpp; on
  vLLM the embedding row's 70 to 93 requests a second at 16 streams is the heaviest neighbour. No
  cell ran purposes in pairs, at lower embedding streams, or read GPU use per process, so the
  reading is not isolated.
- **N.2 The Framework's fractions against its system floor.** 0.60 + 0.18 + 0.03 left the system
  pool 0.76 GiB above its floor under the vision sweep, the containers' 17.56 GiB of RSS outside
  GTT (K). A smaller vision fraction, or a cap on host-side memory, is untested.
- **N.3 The NVFP4 checkpoint's accuracy warning** (L.3) on gb10-2's vision row, against the
  publisher's evaluation within about 1% of BF16 (goal record, Decisions): unmeasured beyond the
  probe.
- **N.4 The audio image lacks torchcodec and ffmpeg** (A.4, L.4): every audio request falls back to
  soundfile/PyAV with a warning. Adding torchcodec is a change to spike-model-engines'
  `host/vllm-rocm-audio`, for a later pull request.
- **N.5 The Framework's Gemma rows hold 13.31 and 12.79 full-length sequences** under their 16 (E);
  no cell came near the cache, so what a row does with 16 long requests is unmeasured.
- **N.6 The hub is contacted at every start** (A.5), as agent-vllm found; the rows set no offline
  flag.
- **N.7 gb10-2's audio cache depends on its start's neighbours** (E): 231,342 tokens beside the
  vision row, 172,508 beside both.
- **N.8 The laptop as the load client.** Six GuideLLM processes at once took the laptop to 9,713
  MiB available on the vLLM run and got the first llama.cpp run reaped (I). A cell with more client
  processes than this needs the laptop's memory freed first, or another client.
- **N.9 Remeasure gb10-2's starts on v0.34.0**, which carries #58868, the GB10 weight-loading fix
  (C); the Framework's starts aren't weight-bound.
- **Intake note, spike-model-engines (vLLM docs):** `docs/engines/vllm/` still describes one
  container on port 8000 and lists none of the six capability rows; it is outside `host/`, so the
  edit is spike-model-engines' own (4ad76e6's message says so).

## O. Every run

| Run | Host | Tool and configuration | Load | Duration | Path | Decision it informs |
| --- | --- | --- | --- | --- | --- | --- |
| Stack read | all three | SSH read-only; `apt-get -s upgrade` on the GB10s | none | one read | direct, 2 ms each | Behavior 1's record (Stack, A.1) |
| Push and clone move | gb10-2, framework | `git push <host>:repos/spike-model-engines capability-vllm:hosts-next`; `git checkout -B hosts hosts-next` | none | one step | direct, 2 ms | the rows on both hosts before merge (A.2) |
| Staging | gb10-2, framework | `hf download` and `docker pull`, in parallel in the background; `docker build` of both audio images on the Framework | none | 13 min to 1 h 24 min a job | direct, 2 ms; the downloads ran on the hosts | starts that read, not download (A.4) |
| Staging checks; image checks | gb10-2, framework | SSH read-only; throwaway containers running `rocminfo` and `imports.py` | none | one read each | direct, 1-2 ms | the images and snapshots; ROCm 10.0 on gfx1151; the audio decoders (A.4) |
| llama.cpp load | gb10-2, framework at once | `unload --all`, cache drop, the three sections, 30 s idle, read | none | 27.3 s; 15.3 s of loads | direct, 1-2 ms | llama.cpp's idle pools (D) |
| L-vision | gb10-2; framework | GuideLLM 0.8.1, `cell`, `bench/role-split-vision-split.yaml`; `-full.yaml` | 1440p image + 200 tokens, 100 out | 90 s a level, 507 s; 60 s a level, 343 s | direct, 1-2 ms | vision on llama.cpp per level (G) |
| L-audio | gb10-2; framework | `bench/role-split-audio-split.yaml`; `-full.yaml` | LibriSpeech clips, ≤64 a level | 146 s; 172 s | direct, 1-2 ms | audio on llama.cpp per level (G) |
| L-embed | gb10-2; framework | `bench/role-split-embed.yaml`, concurrent [1,2,4,8,16] | 512-token inputs | 30 s a level, 198 s; 191 s | direct, 2 ms | embedding on llama.cpp (G) |
| L-mixed | gb10-2; framework, one at a time | `bench/role-split-mixed-*.yaml` | vision 4, audio 4, embedding 16 | 240 s each, about 4.5 min | direct, 2 ms | one host at the targets on llama.cpp (H) |
| L-two, reaped | gb10-2 and framework at once | as L-mixed, `two.sh` | vision 2 + 2, audio 2 + 2, embedding 8 + 8 | about 41 s, killed | direct, 2 ms | none: no result (I) |
| L-two | gb10-2 and framework at once | as above, the rerun (answer 1 b) | as above | 240 s each, about 4.5 min | direct, 1-2 ms | two hosts at the targets on llama.cpp (I, J) |
| vLLM installs, first starts | gb10-2, framework at once | `docker stop llama`; `VLLM_MODEL=<row> host/engines vllm install`, vision, audio, embedding | none | 7.4 min; 6 min | direct, 2 ms | the compile cache filled; recorded apart (C, E) |
| Cold starts | gb10-2, framework at once | per row: `docker stop`, cache drop, `docker start`, timed | none | 20 to 169 s a row | direct, 0-1 ms | each row's cold start, sizing and backends (C, E, F) |
| Probes, warm-up, idle read | gb10-2, framework at once | curl: `/version`, `/v1/models`, an image, a clip, two embeddings; one warm-up a row; 30 s idle; cache drop; read | 3 + 3 requests a host | about 40 s | direct, 1-2 ms | parsing and answers; idle pools; the gates (D, L.1) |
| Audio probe rerun | gb10-2, framework | `v-probe-audio.sh`, `jq --rawfile` | 1 request a host | 2 s each | no ping of its own | the audio probe (L.1) |
| V-vision | gb10-2; framework | as L-vision, each to the row's port and served name | as L-vision | 509 s; 343 s | direct, 1 ms | vision on vLLM per level (G) |
| V-audio | gb10-2; framework | as L-audio | as L-audio | 102 s; 142 s | direct, 0-1 ms | audio on vLLM per level (G) |
| V-embed | gb10-2; framework | as L-embed | as L-embed | 205 s; 192 s | direct, 0-1 ms | embedding on vLLM (G) |
| V-mixed | gb10-2; framework, one at a time | as L-mixed | as L-mixed | 240 s each, about 4.5 min | direct, 0-1 ms | one host at the targets on vLLM (H) |
| V-two | gb10-2 and framework at once | as L-two, `v-two.sh` | as L-two | 240 s each, about 4.5 min | direct, 1 ms | two hosts at the targets on vLLM (I, J) |
| Restore | gb10-2, framework at once | the run logs saved; `docker stop` of the three containers; `docker start llama`; `unload --all`, cache drop, the three sections, 30 s idle, read | none | 33.3 s; 15.3 s of loads | direct, 1 ms | Behavior 13's state |

Every cell ran under `watch`, memory sampled every 10 s, capped at 10 min: floor 12.2 GiB on gb10-2
(`MEASURE_FLOOR_GIB`), 11.2 GiB GTT and 12.5 GiB system memory on the Framework
(`MEASURE_FLOOR_GIB`, `MEASURE_SYSTEM_FLOOR_GIB`), set by `step.sh` for each host. The cells ran
one host at a time but the two-host cells; the starts, probes, loads and restore ran on both hosts
at once.

### Commands as run (gb10-2)

From `.state/measure/gb10-2/2026-11-11.log`, every command at the step level, in log order, from
the stack read at 14:11:58: the `source <scratchpad>/…` lines are the step files (copies in
`.state/capability-vllm/step-files/`), and the commands traced after each are what they ran.
`<scratchpad>` stands for the session's scratch directory,
`/tmp/claude-1000/-home-jaime-experiments-spike-model-layout/2e3d57aa-b8da-4d02-b02e-a7668095d1c1/scratchpad`.
Left in the log: every line inside a helper (`load`, `memory`, `footprint`, `cell`, `readout`,
`after`, `v_after`, `vwait`, `startlog`, `drop`, `ping_host`, `served`, `floorcheck` and the rest,
each traced with its name), the log's header lines and the floors `step.sh` exported, the lines
`source scripts/measure-lib.sh` traced as it set itself up (its variables and its export of
`GUIDELLM__SPEC__BACKEND__TARGET`), `v-common.sh`'s variable and array assignments, the `date -u`
and `tee -a … ping-2026-11-11.txt` halves of each `{ date -u +%FT%TZ; tailscale ping -c 1 <host>;
} 2>&1 | tee -a …` line (its `tailscale ping` is kept), each loop's `for … in` line, which the trace
prints before every pass, and `[[ … ]]` tests. A pipeline prints each of its commands, and
processes started with `&` print in the order the shell reached them. The probes' two `jq -n
--arg` lines carry the image and the clip as base64; `…` stands for each payload, which is
`base64 -w0` of `probes/probe-image.png` and of `probes/probe-clip.wav`.

```
14:11:58  : 'capability-vllm stack on gb10-2: pending updates, kernel, driver, CUDA, Docker, Tailscale, the engine containers and images, the clone (read only)'
14:11:58  tailscale ping -c 1 gb10-2
14:11:58  tee -a /home/jaime/experiments/spike-model-layout/.state/capability-vllm/stack-2026-11-11.txt
14:11:58  echo '== gb10-2'
14:11:58  ssh gb10-2 'apt list --upgradable 2>/dev/null | grep -c upgradable; apt list --upgradable 2>/dev/null | grep upgradable | cut -d/ -f1 | paste -sd" "; uname -r; nvidia-smi --query-gpu=driver_version --format=csv,noheader; nvidia-smi | grep -o "CUDA Version: [0-9.]*"; docker --version; nvidia-ctk --version | head -1; . /etc/os-release; echo "$PRETTY_NAME"; grep -h -E "^DGX_(SWBUILD|OTA)_VERSION" /etc/dgx-release | tail -2; tailscale version | head -1; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" | grep -E "vllm|llama"; sudo -n -l 2>/dev/null | grep -i drop_caches; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && git branch -vv; df -B1 /srv/models / | tail -2'
14:11:59  tee -a /home/jaime/experiments/spike-model-layout/.state/capability-vllm/phased-2026-11-11.txt
14:11:59  echo '== gb10-2: apt-get -s upgrade (simulated, no root)'
14:11:59  ssh gb10-2 'apt-get -s upgrade 2>/dev/null | grep -A1 -E "deferred due to phasing|upgraded,"; for p in snapd distro-info python3-distro-info; do echo "$p: $(apt-cache policy $p | grep -E "Candidate|phased" | tr -s " " | paste -sd" ")"; done'
14:12:15  source <scratchpad>/push.sh
14:12:15  : 'capability-vllm: the host/ branch to gb10-2 as hosts-next, then its clone onto a local hosts branch at it; the llama container'\''s preset mount and the preset'\''s diff checked first'
14:12:15  tailscale ping -c 1 gb10-2
14:12:15  git -C /home/jaime/experiments/spike-model-engines log --oneline -1 capability-vllm
14:12:15  ssh gb10-2 'docker inspect --format "{{range .Mounts}}{{.Source}} -> {{.Destination}} {{.Mode}}{{println}}{{end}}" llama; cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git log --oneline -1'
14:12:16  git -C /home/jaime/experiments/spike-model-engines push gb10-2:repos/spike-model-engines capability-vllm:hosts-next
14:12:16  ssh gb10-2 'cd ~/repos/spike-model-engines && git diff --stat HEAD hosts-next -- host/llama-preset && echo "llama-preset diff above (empty: unchanged)" && sha256sum host/llama-preset/models.ini && git checkout -B hosts hosts-next && sha256sum host/llama-preset/models.ini && git status -sb | head -1 && git log --oneline -1 && git branch -vv && grep -c "^\[.*-\(gb10\|framework\)\]" host/vllm-rows && grep -E "^\[.*-(gb10|framework)\]" host/vllm-rows && grep -o "unrestored through b12282" host/llama.env && grep -E "^VLLM_(RELEASE|ROCM_FALLBACK)=" host/vllm.env'
14:12:16  curl -s -o /dev/null -w 'llama /health %{http_code}\n' http://gb10-2:8080/health
14:12:16  loaded
14:12:43  source <scratchpad>/stage-gb.sh
14:12:43  : 'capability-vllm: stage on gb10-2, in parallel and in the background, without stopping llama: the cuda image host/vllm.sh names at the pin (vllm/vllm-openai:v0.33.0), and the NVFP4 26B-A4B, E4B BF16 and granite safetensors with every JSON file, into the store the rows mount (HF_HUB_CACHE=/srv/models); granite'\''s pytorch_model.bin excluded'
14:12:43  tailscale ping -c 1 gb10-2
14:12:43  ssh gb10-2 'cd ~/repos/spike-model-engines && source host/vllm.sh && VLLM_FLAVOR=cuda vllm_flavor && vllm_image "$VLLM_RELEASE"'
14:12:43  ssh gb10-2 'mkdir -p ~/prestage && ls -d ~/prestage && df -B1 /srv/models | tail -1'
14:12:43  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models HF_XET_HIGH_PERFORMANCE=1; for r in nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-E4B-it; do nohup bash -c "date -Is; mise exec -- hf download $r; echo \"exit \$?\"; date -Is" > ~/prestage/capability-vllm-${r//\//--}.log 2>&1 < /dev/null & done; nohup bash -c "date -Is; mise exec -- hf download ibm-granite/granite-embedding-english-r2 --exclude pytorch_model.bin; echo \"exit \$?\"; date -Is" > ~/prestage/capability-vllm-ibm-granite--granite-embedding-english-r2.log 2>&1 < /dev/null & nohup bash -c "date -Is; docker pull vllm/vllm-openai:v0.33.0; echo \"exit \$?\"; date -Is" > ~/prestage/capability-vllm-vllm-image.log 2>&1 < /dev/null & sleep 5; pgrep -af "hf download|^docker pull"; head -2 ~/prestage/capability-vllm-*.log'
15:37:39  source <scratchpad>/stage-check-gb.sh
15:37:39  : 'capability-vllm: the staging result on gb10-2: each log, the image and its digest, each snapshot with its files and size, no incomplete blob, the disk'
15:37:39  tailscale ping -c 1 gb10-2
15:37:40  ssh gb10-2 'for f in ~/prestage/capability-vllm-*.log; do echo "== $f"; head -1 "$f"; grep -aE "exit [0-9]|^Digest|^Status|rror" "$f"; tail -1 "$f"; done'
15:37:40  ssh gb10-2 'docker image inspect --format "{{index .RepoDigests 0}} {{.Id}} {{.Size}} {{.Architecture}}" vllm/vllm-openai:v0.33.0'
15:37:40  ssh gb10-2 'cd /srv/models && for m in nvidia--Gemma-4-26B-A4B-NVFP4 google--gemma-4-E4B-it ibm-granite--granite-embedding-english-r2; do echo "== $m"; cd /srv/models/models--$m && cat refs/main && echo && s=snapshots/$(cat refs/main) && find -L "$s" -type f -printf "%s\t%P\n" | sort -k2 && find -L "$s" -type f -printf "%s\n" | awk "{t+=\$1} END {printf \"%d files, %d bytes\n\", NR, t}" && find blobs -name "*.incomplete" | wc -l; done; du -sb /srv/models; df -B1 /srv/models | tail -1'
15:38:08  source <scratchpad>/l-load.sh
15:38:08  : 'capability-vllm llama.cpp phase on gb10-2 (Behavior 6): unload all, drop the page cache, load its capability sections fresh (gemma-4-26B-A4B-it-qat-Q4_0-16-slots gemma-4-E4B-it-Q8_0-16-slots mrutkows/granite-embedding-english-r2-GGUF:BF16), idle 30 s, drop the page cache, read the pools and each process'
15:38:08  tailscale ping -c 1 gb10-2
15:38:08  loaded
15:38:08  unload --all
15:38:17  drop
15:38:20  memory
15:38:20  t0=2026-11-11T20:38:20Z
15:38:20  load gemma-4-26B-A4B-it-qat-Q4_0-16-slots
15:38:35  load gemma-4-E4B-it-Q8_0-16-slots
15:38:44  load mrutkows/granite-embedding-english-r2-GGUF:BF16
15:38:47  sleep 30
15:39:17  : 'capability sections loaded since 2026-11-11T20:38:20Z, idle 30 s'
15:39:17  drop
15:39:18  memory
15:39:18  footprint 2026-11-11T20:38:20Z
15:39:21  loaded
15:39:21  curl -s http://gb10-2:8080/models
15:39:21  jq -r '.data[] | select(.status.value == "loaded") | "\(.id): \(.status.args | join(" "))"'
15:39:27  source <scratchpad>/l-sweep.sh
15:39:27  : 'capability-vllm-l-vision: gb10-2'\''s vision cell on llama.cpp, role-split-vision-split, unchanged, the other two sections loaded and idle, under watch with the host'\''s floors'
15:39:27  source <scratchpad>/after.sh
15:39:27  tailscale ping -c 1 gb10-2
15:39:27  loaded
15:39:27  memory
15:39:28  cell capability-vllm-l-vision role-split-vision-split gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
15:47:55  after capability-vllm-l-vision
15:47:58  loaded
15:48:09  source <scratchpad>/l-sweep.sh
15:48:09  : 'capability-vllm-l-audio: gb10-2'\''s audio cell on llama.cpp, role-split-audio-split, unchanged, the other two sections loaded and idle, under watch with the host'\''s floors'
15:48:09  source <scratchpad>/after.sh
15:48:09  tailscale ping -c 1 gb10-2
15:48:09  loaded
15:48:09  memory
15:48:09  cell capability-vllm-l-audio role-split-audio-split gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
15:50:35  after capability-vllm-l-audio
15:50:39  loaded
15:50:40  source <scratchpad>/l-sweep.sh
15:50:40  : 'capability-vllm-l-embed: gb10-2'\''s embed cell on llama.cpp, role-split-embed, unchanged, the other two sections loaded and idle, under watch with the host'\''s floors'
15:50:40  source <scratchpad>/after.sh
15:50:40  tailscale ping -c 1 gb10-2
15:50:40  loaded
15:50:40  memory
15:50:40  cell capability-vllm-l-embed role-split-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
15:53:58  after capability-vllm-l-embed
15:54:03  loaded
15:54:13  source <scratchpad>/l-mixed.sh
15:54:13  : 'capability-vllm-l-mixed: gb10-2'\''s vision 4, audio 4 and embedding 16 processes on llama.cpp, 240 s each, started together (this host alone)'
15:54:13  source <scratchpad>/after.sh
15:54:13  tailscale ping -c 1 gb10-2
15:54:13  loaded
15:54:13  wait
15:54:13  GUIDELLM__SPEC__PROFILE__STREAMS=4
15:54:13  GUIDELLM__SPEC__PROFILE__STREAMS=4
15:54:13  GUIDELLM__SPEC__PROFILE__STREAMS=16
15:54:13  cell capability-vllm-l-mixed-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
15:54:13  cell capability-vllm-l-mixed-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
15:54:13  cell capability-vllm-l-mixed-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
15:58:41  after capability-vllm-l-mixed
15:58:47  loaded
16:15:31  source <scratchpad>/l-mixed.sh
16:15:31  : 'capability-vllm-l-two: gb10-2'\''s vision 2, audio 2 and embedding 8 processes on llama.cpp, 240 s each, started together (with the Framework'\''s three)'
16:15:31  source <scratchpad>/after.sh
16:15:31  tailscale ping -c 1 gb10-2
16:15:31  loaded
16:15:31  GUIDELLM__SPEC__PROFILE__STREAMS=2
16:15:31  GUIDELLM__SPEC__PROFILE__STREAMS=8
16:15:31  GUIDELLM__SPEC__PROFILE__STREAMS=2
16:15:31  wait
16:15:31  cell capability-vllm-l-two-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
16:15:31  cell capability-vllm-l-two-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
16:15:31  cell capability-vllm-l-two-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:54:03  source <scratchpad>/l-mixed.sh
16:54:03  : 'capability-vllm-l-two: gb10-2'\''s vision 2, audio 2 and embedding 8 processes on llama.cpp, 240 s each, started together (with the Framework'\''s three)'
16:54:03  source <scratchpad>/after.sh
16:54:03  tailscale ping -c 1 gb10-2
16:54:03  loaded
16:54:03  wait
16:54:03  GUIDELLM__SPEC__PROFILE__STREAMS=8
16:54:03  GUIDELLM__SPEC__PROFILE__STREAMS=2
16:54:03  GUIDELLM__SPEC__PROFILE__STREAMS=2
16:54:03  cell capability-vllm-l-two-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:54:03  cell capability-vllm-l-two-vision role-split-mixed-vision gemma-4-26B-A4B-it-qat-Q4_0-16-slots google/gemma-4-26B-A4B-it
16:54:03  cell capability-vllm-l-two-audio role-split-mixed-audio gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
16:58:34  after capability-vllm-l-two
16:58:39  loaded
17:03:15  source <scratchpad>/v-install.sh
17:03:15  : 'capability-vllm vLLM phase on gb10-2 (Behavior 7): docker stop llama; install the vision, audio and embedding rows in that order (ROCm build default), each after the previous one'\''s /health 200; these first starts fill the compile cache and are recorded apart, each start log saved and read for fetches, sizing, backends, errors and ROCM_ATTN; a start past 15 min stops the phase'
17:03:15  source <scratchpad>/v-common.sh
17:03:15  ping_host
17:03:15  loaded
17:03:15  ssh gb10-2 docker stop llama
17:03:17  ssh gb10-2 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && ls -d ~/.cache/vllm 2>&1; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
17:03:17  memory
17:03:17  ssh gb10-2 date -u +%FT%T.%NZ
17:03:17  ht0=2026-11-11T22:03:17.379368505Z
17:03:17  ssh gb10-2 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-26B-A4B-NVFP4-vision-gb10 host/engines vllm install'
17:03:18  vwait first-vision 2026-11-11T22:03:17.379368505Z 900 vision
17:07:00  startlog vision /home/jaime/experiments/spike-model-layout/.state/capability-vllm/gb10-2-first-vision.log
17:07:00  memory
17:07:00  ssh gb10-2 date -u +%FT%T.%NZ
17:07:00  ht0=2026-11-11T22:07:00.374403527Z
17:07:00  ssh gb10-2 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-E4B-it-audio-gb10 host/engines vllm install'
17:07:01  vwait first-audio 2026-11-11T22:07:00.374403527Z 900 audio
17:10:05  startlog audio /home/jaime/experiments/spike-model-layout/.state/capability-vllm/gb10-2-first-audio.log
17:10:05  memory
17:10:05  ssh gb10-2 date -u +%FT%T.%NZ
17:10:05  ht0=2026-11-11T22:10:05.436265656Z
17:10:05  ssh gb10-2 'cd ~/repos/spike-model-engines && VLLM_MODEL=granite-embedding-english-r2-gb10 host/engines vllm install'
17:10:06  vwait first-embed 2026-11-11T22:10:05.436265656Z 900 embed
17:10:42  startlog embed /home/jaime/experiments/spike-model-layout/.state/capability-vllm/gb10-2-first-embed.log
17:10:42  memory
17:10:42  ssh gb10-2 'du -sh ~/.cache/vllm; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
17:11:01  source <scratchpad>/v-cold.sh
17:11:01  : 'capability-vllm cold starts on gb10-2 (Behavior 7): each row'\''s container restarted alone, the other two serving: docker stop, drop the page cache, docker start, timed to '\''Application startup complete.'\'' and /health 200 with MemAvailable sampled every 10 s; its start log saved and read; its footprint since the start'
17:11:01  source <scratchpad>/v-common.sh
17:11:01  ping_host
17:11:01  ssh gb10-2 docker stop vllm-vision
17:11:03  drop
17:11:03  memory
17:11:04  ssh gb10-2 date -u +%FT%T.%NZ
17:11:04  ht0=2026-11-11T22:11:04.063586447Z
17:11:04  ssh gb10-2 docker start vllm-vision
17:11:04  vwait cold-vision 2026-11-11T22:11:04.063586447Z 900 vision
17:13:53  startlog vision /home/jaime/experiments/spike-model-layout/.state/capability-vllm/gb10-2-cold-vision.log
17:13:53  source scripts/measure-lib.sh gb10-2 8000
17:13:53  footprint
17:13:54  ping_host
17:13:54  ssh gb10-2 docker stop vllm-audio
17:13:56  drop
17:13:56  memory
17:13:56  ssh gb10-2 date -u +%FT%T.%NZ
17:13:56  ht0=2026-11-11T22:13:56.888202999Z
17:13:56  ssh gb10-2 docker start vllm-audio
17:13:57  vwait cold-audio 2026-11-11T22:13:56.888202999Z 900 audio
17:16:40  startlog audio /home/jaime/experiments/spike-model-layout/.state/capability-vllm/gb10-2-cold-audio.log
17:16:40  source scripts/measure-lib.sh gb10-2 8001
17:16:40  footprint
17:16:40  ping_host
17:16:40  ssh gb10-2 docker stop vllm-embed
17:16:41  drop
17:16:41  memory
17:16:41  ssh gb10-2 date -u +%FT%T.%NZ
17:16:41  ht0=2026-11-11T22:16:41.712391637Z
17:16:41  ssh gb10-2 docker start vllm-embed
17:16:42  vwait cold-embed 2026-11-11T22:16:41.712391637Z 900 embed
17:17:03  startlog embed /home/jaime/experiments/spike-model-layout/.state/capability-vllm/gb10-2-cold-embed.log
17:17:03  source scripts/measure-lib.sh gb10-2 8002
17:17:03  footprint
17:17:16  source <scratchpad>/v-probe.sh
17:17:16  : 'capability-vllm on gb10-2 (Behavior 7): /version and /v1/models per port; one probe of each row'\''s kind (a 640x360 PNG of a red circle, a blue square and the text '\''GB10 42'\''; LibriSpeech 1272-128104-0000, 5.86 s; two embeddings), replies kept in probes/; one warm-up request a row; idle 30 s; drop the page cache; memory, each row'\''s footprint and readout since the cold starts; the idle floor check (Behavior 8)'
17:17:16  source <scratchpad>/v-common.sh
17:17:16  ping_host
17:17:16  curl -s http://gb10-2:8000/version
17:17:16  echo 'vision (8000): version {"version":"0.33.0"}'
17:17:16  curl -s http://gb10-2:8000/v1/models
17:17:16  jq -c '[.data[] | {id, max_model_len}]'
17:17:16  curl -s http://gb10-2:8001/version
17:17:16  echo 'audio (8001): version {"version":"0.33.0"}'
17:17:16  jq -c '[.data[] | {id, max_model_len}]'
17:17:16  curl -s http://gb10-2:8001/v1/models
17:17:16  curl -s http://gb10-2:8002/version
17:17:16  echo 'embed (8002): version {"version":"0.33.0"}'
17:17:16  curl -s http://gb10-2:8002/v1/models
17:17:16  jq -c '[.data[] | {id, max_model_len}]'
17:17:16  served 8000
17:17:16  VM=nvidia/Gemma-4-26B-A4B-NVFP4
17:17:16  served 8001
17:17:16  AM=google/gemma-4-E4B-it
17:17:16  served 8002
17:17:16  EM=ibm-granite/granite-embedding-english-r2
17:17:16  base64 -w0 /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-image.png
17:17:16  jq -n --arg m nvidia/Gemma-4-26B-A4B-NVFP4 --arg img 'data:image/png;base64,…' '{model: $m, max_tokens: 200, messages: [{role: "user", content: [{type: "image_url", image_url: {url: $img}}, {type: "text", text: "Describe this image in one sentence: the shapes, their colors, and any text."}]}]}'
17:17:16  base64 -w0 /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.wav
17:17:16  jq -n --arg m google/gemma-4-E4B-it --arg wav … '{model: $m, max_tokens: 256, messages: [{role: "user", content: [{type: "input_audio", input_audio: {data: $wav, format: "wav"}}, {type: "text", text: "Transcribe the following speech segment in English into English text. Only output the transcription, with no newlines."}]}]}'
17:17:16  curl -s http://gb10-2:8000/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/req-vision.json
17:17:18  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage, error}' /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/gb10-2-vision.json
17:17:18  curl -s http://gb10-2:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/req-audio.json
17:17:18  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage, error}' /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/gb10-2-audio.json
17:17:18  jq -r .text /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.json
17:17:18  echo 'reference: MISTER QUILTER IS THE APOSTLE OF THE MIDDLE CLASSES AND WE ARE GLAD TO WELCOME HIS GOSPEL'
17:17:18  jq -nc --arg m ibm-granite/granite-embedding-english-r2 '{model: $m, input: ["The cat sat on the mat.", "A cat was sitting on a rug."]}'
17:17:18  curl -s http://gb10-2:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":["The cat sat on the mat.","A cat was sitting on a rug."]}'
17:17:18  jq -c '{n: (.data | length), dims: [.data[].embedding | length], cosine: (if (.data | length) == 2 then ([.data[0].embedding, .data[1].embedding] | transpose | map(.[0] * .[1]) | add) / (([.data[0].embedding[] | . * .] | add | sqrt) * ([.data[1].embedding[] | . * .] | add | sqrt)) else null end), usage, error}' /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/gb10-2-embed.json
17:17:18  : 'one warm-up request a row'
17:17:18  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage}'
17:17:18  jq -nc --arg m nvidia/Gemma-4-26B-A4B-NVFP4 '{model: $m, messages: [{role: "user", content: "Say hello in one sentence."}], max_tokens: 64}'
17:17:18  curl -s http://gb10-2:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"nvidia/Gemma-4-26B-A4B-NVFP4","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
17:17:19  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage}'
17:17:19  jq -nc --arg m google/gemma-4-E4B-it '{model: $m, messages: [{role: "user", content: "Say hello in one sentence."}], max_tokens: 64}'
17:17:19  curl -s http://gb10-2:8001/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"google/gemma-4-E4B-it","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
17:17:20  jq -c '{n: (.data | length), usage}'
17:17:20  jq -nc --arg m ibm-granite/granite-embedding-english-r2 '{model: $m, input: "Say hello in one sentence."}'
17:17:20  curl -s http://gb10-2:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":"Say hello in one sentence."}'
17:17:20  sleep 30
17:17:50  : 'three rows warmed up, idle 30 s'
17:17:50  drop
17:17:50  memory
17:17:50  source scripts/measure-lib.sh gb10-2 8000
17:17:50  footprint
17:17:51  ssh gb10-2 'docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-vision'
17:17:51  readout 2026-11-11T22:11:04.178027387Z
17:17:51  source scripts/measure-lib.sh gb10-2 8001
17:17:51  footprint
17:17:51  ssh gb10-2 'docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-audio'
17:17:51  readout 2026-11-11T22:13:56.998709135Z
17:17:52  source scripts/measure-lib.sh gb10-2 8002
17:17:52  footprint
17:17:52  ssh gb10-2 'docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-embed'
17:17:52  readout 2026-11-11T22:16:41.831897256Z
17:17:52  floorcheck 'the idle read'
17:18:10  source <scratchpad>/v-probe-audio.sh
17:18:10  : 'capability-vllm on gb10-2: the audio probe again (LibriSpeech 1272-128104-0000, 5.86 s), its payload built with jq --rawfile; the first attempt'\''s jq --arg exceeded the argument limit and sent no body (400)'
17:18:10  source <scratchpad>/v-common.sh
17:18:10  served 8001
17:18:10  AM=google/gemma-4-E4B-it
17:18:10  base64 -w0 /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.wav
17:18:10  jq -n --arg m google/gemma-4-E4B-it --rawfile wav /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.b64 '{model: $m, max_tokens: 256, messages: [{role: "user", content: [{type: "input_audio", input_audio: {data: $wav, format: "wav"}}, {type: "text", text: "Transcribe the following speech segment in English into English text. Only output the transcription, with no newlines."}]}]}'
17:18:10  curl -s http://gb10-2:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/req-audio.json
17:18:12  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage, error}' /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/gb10-2-audio.json
17:18:12  jq -r .text /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.json
17:18:12  echo 'reference: MISTER QUILTER IS THE APOSTLE OF THE MIDDLE CLASSES AND WE ARE GLAD TO WELCOME HIS GOSPEL'
17:18:12  echo 'vllm-vision warnings since start:'
17:18:12  ssh gb10-2 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-vision) vllm-vision 2>&1'
17:18:12  grep -E ' (ERROR|WARNING) '
17:18:12  cut -c1-250
17:18:12  echo 'vllm-audio warnings since start:'
17:18:12  ssh gb10-2 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-audio) vllm-audio 2>&1'
17:18:12  grep -E ' (ERROR|WARNING) '
17:18:12  cut -c1-250
17:18:12  echo 'vllm-embed warnings since start:'
17:18:12  grep -E ' (ERROR|WARNING) '
17:18:12  cut -c1-250
17:18:12  ssh gb10-2 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-embed) vllm-embed 2>&1'
17:18:52  source <scratchpad>/v-sweep.sh
17:18:52  : 'capability-vllm-v-vision: gb10-2'\''s vision cell on vLLM, role-split-vision-split, unchanged but for the target (its row'\''s port) and model (its served name), the other two rows loaded and idle, under watch with the host'\''s floors'
17:18:52  source <scratchpad>/v-common.sh
17:18:52  source <scratchpad>/v-after.sh
17:18:52  ping_host
17:18:52  source scripts/measure-lib.sh gb10-2 8000
17:18:53  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
17:18:53  memory
17:18:53  t=2026-11-11T22:18:53Z
17:18:53  served 8000
17:18:53  cell capability-vllm-v-vision role-split-vision-split nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
17:27:22  v_after capability-vllm-v-vision 2026-11-11T22:18:53Z
17:27:25  source <scratchpad>/v-sweep.sh
17:27:25  : 'capability-vllm-v-audio: gb10-2'\''s audio cell on vLLM, role-split-audio-split, unchanged but for the target (its row'\''s port) and model (its served name), the other two rows loaded and idle, under watch with the host'\''s floors'
17:27:25  source <scratchpad>/v-common.sh
17:27:25  source <scratchpad>/v-after.sh
17:27:25  ping_host
17:27:25  source scripts/measure-lib.sh gb10-2 8001
17:27:25  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
17:27:25  memory
17:27:25  t=2026-11-11T22:27:25Z
17:27:25  served 8001
17:27:25  cell capability-vllm-v-audio role-split-audio-split google/gemma-4-E4B-it google/gemma-4-E4B-it
17:29:07  v_after capability-vllm-v-audio 2026-11-11T22:27:25Z
17:29:10  source <scratchpad>/v-sweep.sh
17:29:10  : 'capability-vllm-v-embed: gb10-2'\''s embed cell on vLLM, role-split-embed, unchanged but for the target (its row'\''s port) and model (its served name), the other two rows loaded and idle, under watch with the host'\''s floors'
17:29:10  source <scratchpad>/v-common.sh
17:29:10  source <scratchpad>/v-after.sh
17:29:10  ping_host
17:29:10  source scripts/measure-lib.sh gb10-2 8002
17:29:10  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
17:29:10  memory
17:29:10  t=2026-11-11T22:29:10Z
17:29:10  served 8002
17:29:10  cell capability-vllm-v-embed role-split-embed ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
17:32:35  v_after capability-vllm-v-embed 2026-11-11T22:29:10Z
17:32:38  source <scratchpad>/v-mixed.sh
17:32:38  : 'capability-vllm-v-mixed: gb10-2'\''s vision 4, audio 4 and embedding 16 processes on vLLM, each to its row'\''s port, 240 s each, started together (this host alone)'
17:32:38  source <scratchpad>/v-common.sh
17:32:38  source <scratchpad>/v-after.sh
17:32:38  ping_host
17:32:38  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
17:32:38  memory
17:32:38  served 8000
17:32:38  VM=nvidia/Gemma-4-26B-A4B-NVFP4
17:32:38  served 8001
17:32:38  AM=google/gemma-4-E4B-it
17:32:38  served 8002
17:32:38  EM=ibm-granite/granite-embedding-english-r2
17:32:38  t=2026-11-11T22:32:38Z
17:32:38  source scripts/measure-lib.sh gb10-2 8000
17:32:38  source scripts/measure-lib.sh gb10-2 8002
17:32:38  source scripts/measure-lib.sh gb10-2 8001
17:32:38  wait
17:32:39  GUIDELLM__SPEC__PROFILE__STREAMS=4
17:32:39  GUIDELLM__SPEC__PROFILE__STREAMS=16
17:32:39  GUIDELLM__SPEC__PROFILE__STREAMS=4
17:32:39  cell capability-vllm-v-mixed-vision role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
17:32:39  cell capability-vllm-v-mixed-embed role-split-mixed-embed ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
17:32:39  cell capability-vllm-v-mixed-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
17:37:04  v_after capability-vllm-v-mixed 2026-11-11T22:32:38Z
17:53:23  source <scratchpad>/v-mixed.sh
17:53:23  : 'capability-vllm-v-two: gb10-2'\''s vision 2, audio 2 and embedding 8 processes on vLLM, each to its row'\''s port, 240 s each, started together (with the Framework'\''s three)'
17:53:23  source <scratchpad>/v-common.sh
17:53:23  source <scratchpad>/v-after.sh
17:53:23  ping_host
17:53:23  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
17:53:23  memory
17:53:24  served 8000
17:53:24  VM=nvidia/Gemma-4-26B-A4B-NVFP4
17:53:24  served 8001
17:53:24  AM=google/gemma-4-E4B-it
17:53:24  served 8002
17:53:24  EM=ibm-granite/granite-embedding-english-r2
17:53:24  t=2026-11-11T22:53:24Z
17:53:24  source scripts/measure-lib.sh gb10-2 8000
17:53:24  source scripts/measure-lib.sh gb10-2 8001
17:53:24  wait
17:53:24  source scripts/measure-lib.sh gb10-2 8002
17:53:24  GUIDELLM__SPEC__PROFILE__STREAMS=2
17:53:24  GUIDELLM__SPEC__PROFILE__STREAMS=2
17:53:24  GUIDELLM__SPEC__PROFILE__STREAMS=8
17:53:24  cell capability-vllm-v-two-vision role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
17:53:24  cell capability-vllm-v-two-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
17:53:24  cell capability-vllm-v-two-embed role-split-mixed-embed ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
17:57:49  v_after capability-vllm-v-two 2026-11-11T22:53:24Z
17:58:12  source <scratchpad>/v-restore.sh
17:58:12  : 'capability-vllm restore on gb10-2 (Behavior 13): each row'\''s run log saved; vllm-vision, vllm-audio and vllm-embed stopped (images, compile caches and weights kept); docker start llama; helpers on 8080; the capability sections loaded fresh (gemma-4-26B-A4B-it-qat-Q4_0-16-slots gemma-4-E4B-it-Q8_0-16-slots mrutkows/granite-embedding-english-r2-GGUF:BF16); idle 30 s; drop the page cache; memory and footprint'
17:58:12  source <scratchpad>/v-common.sh
17:58:12  ping_host
17:58:12  ssh gb10-2 docker logs vllm-vision
17:58:13  ssh gb10-2 docker logs vllm-audio
17:58:13  ssh gb10-2 docker logs vllm-embed
17:58:13  ssh gb10-2 docker stop vllm-vision vllm-audio vllm-embed
17:58:15  ssh gb10-2 docker start llama
17:58:17  source scripts/measure-lib.sh gb10-2
17:58:17  loaded
17:58:17  unload --all
17:58:17  drop
17:58:17  memory
17:58:18  t0=2026-11-11T22:58:18Z
17:58:18  load gemma-4-26B-A4B-it-qat-Q4_0-16-slots
17:58:36  load gemma-4-E4B-it-Q8_0-16-slots
17:58:48  load mrutkows/granite-embedding-english-r2-GGUF:BF16
17:58:51  sleep 30
17:59:21  : 'capability sections loaded since 2026-11-11T22:58:18Z, idle 30 s'
17:59:21  drop
17:59:21  memory
17:59:22  footprint 2026-11-11T22:58:18Z
17:59:27  loaded
17:59:27  floorcheck 'the restore read'
17:59:27  ssh gb10-2 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; du -sh ~/.cache/vllm; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -i vllm; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1'
```

### Commands as run (framework)

From `.state/measure/framework/2026-11-11.log`, by the same rule, from the stack read at 14:12:00.

```
14:12:00  : 'capability-vllm stack on framework: pending updates, kernel, Mesa, ROCm-facing kernel driver, Docker, firmware, Tailscale, the engine containers and images, the clone, the drop-caches rule (read only)'
14:12:00  tailscale ping -c 1 framework
14:12:00  tee -a /home/jaime/experiments/spike-model-layout/.state/capability-vllm/stack-2026-11-11.txt
14:12:00  echo '== framework'
14:12:00  ssh framework 'checkupdates 2>/dev/null | wc -l; checkupdates >/dev/null 2>&1; echo "checkupdates exit $?"; uname -r; pacman -Q mesa vulkan-radeon docker linux-firmware; cat /sys/module/amdgpu/version 2>/dev/null; ls /dev/kfd /dev/dri/renderD* 2>&1; tailscale version | head -1; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" | grep -E "vllm|llama"; sudo -n -l 2>/dev/null | grep -i drop_caches; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && git branch -vv; df -B1 /srv/models / /var/lib/docker 2>/dev/null | tail -3'
14:12:16  source <scratchpad>/push.sh
14:12:16  : 'capability-vllm: the host/ branch to framework as hosts-next, then its clone onto a local hosts branch at it; the llama container'\''s preset mount and the preset'\''s diff checked first'
14:12:16  tailscale ping -c 1 framework
14:12:16  git -C /home/jaime/experiments/spike-model-engines log --oneline -1 capability-vllm
14:12:16  ssh framework 'docker inspect --format "{{range .Mounts}}{{.Source}} -> {{.Destination}} {{.Mode}}{{println}}{{end}}" llama; cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git log --oneline -1'
14:12:16  git -C /home/jaime/experiments/spike-model-engines push framework:repos/spike-model-engines capability-vllm:hosts-next
14:12:16  ssh framework 'cd ~/repos/spike-model-engines && git diff --stat HEAD hosts-next -- host/llama-preset && echo "llama-preset diff above (empty: unchanged)" && sha256sum host/llama-preset/models.ini && git checkout -B hosts hosts-next && sha256sum host/llama-preset/models.ini && git status -sb | head -1 && git log --oneline -1 && git branch -vv && grep -c "^\[.*-\(gb10\|framework\)\]" host/vllm-rows && grep -E "^\[.*-(gb10|framework)\]" host/vllm-rows && grep -o "unrestored through b12282" host/llama.env && grep -E "^VLLM_(RELEASE|ROCM_FALLBACK)=" host/vllm.env'
14:12:16  curl -s -o /dev/null -w 'llama /health %{http_code}\n' http://framework:8080/health
14:12:16  loaded
14:12:48  source <scratchpad>/stage-fw.sh
14:12:48  : 'capability-vllm: stage on the Framework, in parallel and in the background, without stopping llama: v0.33.0'\''s ROCm 10.0 image (the default tag) then the audio image built on it, the -rocm72 fallback then its audio image, and the 26B-A4B BF16, E4B BF16 and granite safetensors with every JSON file into /srv/models; granite'\''s pytorch_model.bin excluded'
14:12:48  tailscale ping -c 1 framework
14:12:48  ssh framework 'cd ~/repos/spike-model-engines && source host/vllm.sh && VLLM_FLAVOR=rocm vllm_flavor && vllm_image "$VLLM_RELEASE"'
14:12:48  ssh framework 'mkdir -p ~/prestage && ls -d ~/prestage && df -B1 /srv/models /var/lib/docker 2>/dev/null | tail -2'
14:12:48  ssh framework 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models HF_XET_HIGH_PERFORMANCE=1; for r in google/gemma-4-26B-A4B-it google/gemma-4-E4B-it; do nohup bash -c "date -Is; mise exec -- hf download $r; echo \"exit \$?\"; date -Is" > ~/prestage/capability-vllm-${r//\//--}.log 2>&1 < /dev/null & done; nohup bash -c "date -Is; mise exec -- hf download ibm-granite/granite-embedding-english-r2 --exclude pytorch_model.bin; echo \"exit \$?\"; date -Is" > ~/prestage/capability-vllm-ibm-granite--granite-embedding-english-r2.log 2>&1 < /dev/null & nohup bash -c "date -Is; docker pull vllm/vllm-openai-rocm:v0.33.0; echo \"pull exit \$?\"; date -Is; docker build -t spike-model-engines/vllm-openai-rocm-audio:v0.33.0 host/vllm-rocm-audio; echo \"build exit \$?\"; date -Is" > ~/prestage/capability-vllm-rocm100.log 2>&1 < /dev/null & nohup bash -c "date -Is; docker pull vllm/vllm-openai-rocm:v0.33.0-rocm72; echo \"pull exit \$?\"; date -Is; docker build --build-arg VLLM_ROCM_BUILD=rocm72 -t spike-model-engines/vllm-openai-rocm-audio:v0.33.0-rocm72 host/vllm-rocm-audio; echo \"build exit \$?\"; date -Is" > ~/prestage/capability-vllm-rocm72.log 2>&1 < /dev/null & sleep 5; pgrep -af "hf download|^docker (pull|build)"; head -2 ~/prestage/capability-vllm-*.log'
15:37:40  source <scratchpad>/stage-check-fw.sh
15:37:40  : 'capability-vllm: the staging result on the Framework: each log, both official images and their digests against the pinned ones, both audio images, each snapshot with its files and size, no incomplete blob, the disk'
15:37:40  tailscale ping -c 1 framework
15:37:40  ssh framework 'for f in ~/prestage/capability-vllm-*.log; do echo "== $f"; head -1 "$f"; grep -aE "exit [0-9]|^Digest|^Status|rror|^#[0-9]+ (DONE|ERROR)|naming to|writing image" "$f"; tail -1 "$f"; done'
15:37:40  ssh framework 'for i in vllm/vllm-openai-rocm:v0.33.0 vllm/vllm-openai-rocm:v0.33.0-rocm72; do docker image inspect --format "$i {{index .RepoDigests 0}} {{.Id}} {{.Size}} {{.Architecture}}" $i; done; for i in spike-model-engines/vllm-openai-rocm-audio:v0.33.0 spike-model-engines/vllm-openai-rocm-audio:v0.33.0-rocm72; do docker image inspect --format "$i {{.Id}} {{.Size}} {{.Created}}" $i; done; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" | grep -E "vllm"'
15:37:40  ssh framework 'for m in google--gemma-4-26B-A4B-it google--gemma-4-E4B-it ibm-granite--granite-embedding-english-r2; do echo "== $m"; cd /srv/models/models--$m && cat refs/main && echo && s=snapshots/$(cat refs/main) && find -L "$s" -type f -printf "%s\t%P\n" | sort -k2 && find -L "$s" -type f -printf "%s\n" | awk "{t+=\$1} END {printf \"%d files, %d bytes\n\", NR, t}" && find blobs -name "*.incomplete" | wc -l; done; du -sb /srv/models; df -B1 /srv/models | tail -1'
15:37:48  source <scratchpad>/image-checks.sh
15:37:48  : 'capability-vllm image checks on the Framework (read only, each a throwaway container with no server): the ROCm 10.0 image'\''s rocminfo names gfx1151; the official image lacks the audio extra'\''s decoders; the rebuilt audio images import av, soundfile and soxr'
15:37:48  tailscale ping -c 1 framework
15:37:48  ssh framework 'docker run --rm --device /dev/kfd --device /dev/dri --entrypoint rocminfo vllm/vllm-openai-rocm:v0.33.0 2>&1 | grep -E "Runtime Version|Marketing Name|^ Name: +gfx" | sort | uniq -c; docker run --rm --entrypoint cat vllm/vllm-openai-rocm:v0.33.0 /opt/rocm/.info/version'
15:37:48  echo '== vllm/vllm-openai-rocm:v0.33.0'
15:37:48  ssh framework 'docker run --rm -i --entrypoint python3 vllm/vllm-openai-rocm:v0.33.0 -'
15:37:48  grep -v '^WARNING\|^INFO'
15:37:52  echo '== spike-model-engines/vllm-openai-rocm-audio:v0.33.0'
15:37:52  grep -v '^WARNING\|^INFO'
15:37:52  ssh framework 'docker run --rm -i --entrypoint python3 spike-model-engines/vllm-openai-rocm-audio:v0.33.0 -'
15:37:55  echo '== vllm/vllm-openai-rocm:v0.33.0-rocm72'
15:37:55  grep -v '^WARNING\|^INFO'
15:37:55  ssh framework 'docker run --rm -i --entrypoint python3 vllm/vllm-openai-rocm:v0.33.0-rocm72 -'
15:37:58  echo '== spike-model-engines/vllm-openai-rocm-audio:v0.33.0-rocm72'
15:37:58  grep -v '^WARNING\|^INFO'
15:37:58  ssh framework 'docker run --rm -i --entrypoint python3 spike-model-engines/vllm-openai-rocm-audio:v0.33.0-rocm72 -'
15:38:01  ssh framework 'docker run --rm --device /dev/kfd --device /dev/dri --entrypoint rocminfo vllm/vllm-openai-rocm:v0.33.0-rocm72 2>&1 | grep -E "Runtime Version|^ Name: +gfx" | sort | uniq -c; docker run --rm --entrypoint cat vllm/vllm-openai-rocm:v0.33.0-rocm72 /opt/rocm/.info/version'
15:38:08  source <scratchpad>/l-load.sh
15:38:08  : 'capability-vllm llama.cpp phase on framework (Behavior 6): unload all, drop the page cache, load its capability sections fresh (google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16), idle 30 s, drop the page cache, read the pools and each process'
15:38:08  tailscale ping -c 1 framework
15:38:08  loaded
15:38:08  unload --all
15:38:17  drop
15:38:22  memory
15:38:22  t0=2026-11-11T20:38:22Z
15:38:22  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
15:38:28  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
15:38:34  load mrutkows/granite-embedding-english-r2-GGUF:BF16
15:38:37  sleep 30
15:39:07  : 'capability sections loaded since 2026-11-11T20:38:22Z, idle 30 s'
15:39:07  drop
15:39:08  memory
15:39:08  footprint 2026-11-11T20:38:22Z
15:39:08  loaded
15:39:08  curl -s http://framework:8080/models
15:39:08  jq -r '.data[] | select(.status.value == "loaded") | "\(.id): \(.status.args | join(" "))"'
15:58:58  source <scratchpad>/l-sweep.sh
15:58:58  : 'capability-vllm-l-vision: framework'\''s vision cell on llama.cpp, role-split-vision-full, unchanged, the other two sections loaded and idle, under watch with the host'\''s floors'
15:58:58  source <scratchpad>/after.sh
15:58:58  tailscale ping -c 1 framework
15:58:58  loaded
15:58:58  memory
15:58:58  cell capability-vllm-l-vision role-split-vision-full google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:04:41  after capability-vllm-l-vision
16:04:41  loaded
16:04:41  source <scratchpad>/l-sweep.sh
16:04:41  : 'capability-vllm-l-audio: framework'\''s audio cell on llama.cpp, role-split-audio-full, unchanged, the other two sections loaded and idle, under watch with the host'\''s floors'
16:04:41  source <scratchpad>/after.sh
16:04:41  tailscale ping -c 1 framework
16:04:41  loaded
16:04:41  memory
16:04:41  cell capability-vllm-l-audio role-split-audio-full ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:07:33  after capability-vllm-l-audio
16:07:34  loaded
16:07:34  source <scratchpad>/l-sweep.sh
16:07:34  : 'capability-vllm-l-embed: framework'\''s embed cell on llama.cpp, role-split-embed, unchanged, the other two sections loaded and idle, under watch with the host'\''s floors'
16:07:34  source <scratchpad>/after.sh
16:07:34  tailscale ping -c 1 framework
16:07:34  loaded
16:07:34  memory
16:07:35  cell capability-vllm-l-embed role-split-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:10:46  after capability-vllm-l-embed
16:10:47  loaded
16:10:59  source <scratchpad>/l-mixed.sh
16:10:59  : 'capability-vllm-l-mixed: framework'\''s vision 4, audio 4 and embedding 16 processes on llama.cpp, 240 s each, started together (this host alone)'
16:10:59  source <scratchpad>/after.sh
16:10:59  tailscale ping -c 1 framework
16:10:59  loaded
16:10:59  wait
16:10:59  GUIDELLM__SPEC__PROFILE__STREAMS=4
16:10:59  GUIDELLM__SPEC__PROFILE__STREAMS=16
16:10:59  GUIDELLM__SPEC__PROFILE__STREAMS=4
16:10:59  cell capability-vllm-l-mixed-audio role-split-mixed-audio ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:10:59  cell capability-vllm-l-mixed-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:10:59  cell capability-vllm-l-mixed-vision role-split-mixed-vision google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:15:22  after capability-vllm-l-mixed
16:15:22  loaded
16:15:31  source <scratchpad>/l-mixed.sh
16:15:31  : 'capability-vllm-l-two: framework'\''s vision 2, audio 2 and embedding 8 processes on llama.cpp, 240 s each, started together (with gb10-2'\''s three)'
16:15:31  source <scratchpad>/after.sh
16:15:31  tailscale ping -c 1 framework
16:15:31  loaded
16:15:31  wait
16:15:31  GUIDELLM__SPEC__PROFILE__STREAMS=8
16:15:31  GUIDELLM__SPEC__PROFILE__STREAMS=2
16:15:31  GUIDELLM__SPEC__PROFILE__STREAMS=2
16:15:31  cell capability-vllm-l-two-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:15:31  cell capability-vllm-l-two-vision role-split-mixed-vision google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:15:31  cell capability-vllm-l-two-audio role-split-mixed-audio ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:54:03  source <scratchpad>/l-mixed.sh
16:54:03  : 'capability-vllm-l-two: framework'\''s vision 2, audio 2 and embedding 8 processes on llama.cpp, 240 s each, started together (with gb10-2'\''s three)'
16:54:03  source <scratchpad>/after.sh
16:54:03  tailscale ping -c 1 framework
16:54:03  loaded
16:54:03  GUIDELLM__SPEC__PROFILE__STREAMS=2
16:54:03  wait
16:54:03  GUIDELLM__SPEC__PROFILE__STREAMS=2
16:54:03  GUIDELLM__SPEC__PROFILE__STREAMS=8
16:54:03  cell capability-vllm-l-two-vision role-split-mixed-vision google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:54:03  cell capability-vllm-l-two-embed role-split-mixed-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:54:03  cell capability-vllm-l-two-audio role-split-mixed-audio ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:58:26  after capability-vllm-l-two
16:58:27  loaded
17:03:15  source <scratchpad>/v-install.sh
17:03:15  : 'capability-vllm vLLM phase on framework (Behavior 7): docker stop llama; install the vision, audio and embedding rows in that order (ROCm build default), each after the previous one'\''s /health 200; these first starts fill the compile cache and are recorded apart, each start log saved and read for fetches, sizing, backends, errors and ROCM_ATTN; a start past 15 min stops the phase'
17:03:15  source <scratchpad>/v-common.sh
17:03:15  ping_host
17:03:15  loaded
17:03:15  ssh framework docker stop llama
17:03:16  ssh framework 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && ls -d ~/.cache/vllm 2>&1; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
17:03:16  memory
17:03:16  ssh framework date -u +%FT%T.%NZ
17:03:16  ht0=2026-11-11T22:03:16.136518310Z
17:03:16  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-26B-A4B-it-vision-framework host/engines vllm install'
17:03:17  vwait first-vision 2026-11-11T22:03:16.136518310Z 900 vision
17:06:06  startlog vision /home/jaime/experiments/spike-model-layout/.state/capability-vllm/framework-first-vision.log
17:06:07  memory
17:06:07  ssh framework date -u +%FT%T.%NZ
17:06:07  ht0=2026-11-11T22:06:07.122603534Z
17:06:07  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-E4B-it-audio-framework host/engines vllm install'
17:06:07  vwait first-audio 2026-11-11T22:06:07.122603534Z 900 audio
17:08:34  startlog audio /home/jaime/experiments/spike-model-layout/.state/capability-vllm/framework-first-audio.log
17:08:34  memory
17:08:34  ssh framework date -u +%FT%T.%NZ
17:08:34  ht0=2026-11-11T22:08:34.620595982Z
17:08:34  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=granite-embedding-english-r2-framework host/engines vllm install'
17:08:35  vwait first-embed 2026-11-11T22:08:34.620595982Z 900 embed
17:09:10  startlog embed /home/jaime/experiments/spike-model-layout/.state/capability-vllm/framework-first-embed.log
17:09:10  memory
17:09:10  ssh framework 'du -sh ~/.cache/vllm; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
17:11:01  source <scratchpad>/v-cold.sh
17:11:01  : 'capability-vllm cold starts on framework (Behavior 7): each row'\''s container restarted alone, the other two serving: docker stop, drop the page cache, docker start, timed to '\''Application startup complete.'\'' and /health 200 with MemAvailable sampled every 10 s; its start log saved and read; its footprint since the start'
17:11:01  source <scratchpad>/v-common.sh
17:11:01  ping_host
17:11:01  ssh framework docker stop vllm-vision
17:11:04  drop
17:11:05  memory
17:11:05  ssh framework date -u +%FT%T.%NZ
17:11:05  ht0=2026-11-11T22:11:05.562571808Z
17:11:05  ssh framework docker start vllm-vision
17:11:05  vwait cold-vision 2026-11-11T22:11:05.562571808Z 900 vision
17:12:47  startlog vision /home/jaime/experiments/spike-model-layout/.state/capability-vllm/framework-cold-vision.log
17:12:47  source scripts/measure-lib.sh framework 8000
17:12:47  footprint
17:12:47  ping_host
17:12:47  ssh framework docker stop vllm-audio
17:12:51  drop
17:12:52  memory
17:12:52  ssh framework date -u +%FT%T.%NZ
17:12:52  ht0=2026-11-11T22:12:52.594415809Z
17:12:52  ssh framework docker start vllm-audio
17:12:52  vwait cold-audio 2026-11-11T22:12:52.594415809Z 900 audio
17:14:07  startlog audio /home/jaime/experiments/spike-model-layout/.state/capability-vllm/framework-cold-audio.log
17:14:07  source scripts/measure-lib.sh framework 8001
17:14:07  footprint
17:14:07  ping_host
17:14:07  ssh framework docker stop vllm-embed
17:14:10  drop
17:14:11  memory
17:14:11  ssh framework date -u +%FT%T.%NZ
17:14:11  ht0=2026-11-11T22:14:11.294663587Z
17:14:11  ssh framework docker start vllm-embed
17:14:11  vwait cold-embed 2026-11-11T22:14:11.294663587Z 900 embed
17:14:32  startlog embed /home/jaime/experiments/spike-model-layout/.state/capability-vllm/framework-cold-embed.log
17:14:32  source scripts/measure-lib.sh framework 8002
17:14:32  footprint
17:17:16  source <scratchpad>/v-probe.sh
17:17:16  : 'capability-vllm on framework (Behavior 7): /version and /v1/models per port; one probe of each row'\''s kind (a 640x360 PNG of a red circle, a blue square and the text '\''GB10 42'\''; LibriSpeech 1272-128104-0000, 5.86 s; two embeddings), replies kept in probes/; one warm-up request a row; idle 30 s; drop the page cache; memory, each row'\''s footprint and readout since the cold starts; the idle floor check (Behavior 8)'
17:17:16  source <scratchpad>/v-common.sh
17:17:16  ping_host
17:17:16  curl -s http://framework:8000/version
17:17:16  echo 'vision (8000): version {"version":"0.33.0"}'
17:17:16  curl -s http://framework:8000/v1/models
17:17:16  jq -c '[.data[] | {id, max_model_len}]'
17:17:16  curl -s http://framework:8001/version
17:17:16  echo 'audio (8001): version {"version":"0.33.0"}'
17:17:16  curl -s http://framework:8001/v1/models
17:17:16  jq -c '[.data[] | {id, max_model_len}]'
17:17:16  curl -s http://framework:8002/version
17:17:16  echo 'embed (8002): version {"version":"0.33.0"}'
17:17:16  curl -s http://framework:8002/v1/models
17:17:16  jq -c '[.data[] | {id, max_model_len}]'
17:17:16  served 8000
17:17:16  VM=google/gemma-4-26B-A4B-it
17:17:16  served 8001
17:17:16  AM=google/gemma-4-E4B-it
17:17:16  served 8002
17:17:16  EM=ibm-granite/granite-embedding-english-r2
17:17:16  base64 -w0 /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-image.png
17:17:16  jq -n --arg m google/gemma-4-26B-A4B-it --arg img 'data:image/png;base64,…' '{model: $m, max_tokens: 200, messages: [{role: "user", content: [{type: "image_url", image_url: {url: $img}}, {type: "text", text: "Describe this image in one sentence: the shapes, their colors, and any text."}]}]}'
17:17:16  base64 -w0 /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.wav
17:17:16  jq -n --arg m google/gemma-4-E4B-it --arg wav … '{model: $m, max_tokens: 256, messages: [{role: "user", content: [{type: "input_audio", input_audio: {data: $wav, format: "wav"}}, {type: "text", text: "Transcribe the following speech segment in English into English text. Only output the transcription, with no newlines."}]}]}'
17:17:16  curl -s http://framework:8000/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/req-vision.json
17:17:20  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage, error}' /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/framework-vision.json
17:17:20  curl -s http://framework:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/req-audio.json
17:17:21  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage, error}' /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/framework-audio.json
17:17:21  jq -r .text /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.json
17:17:21  echo 'reference: MISTER QUILTER IS THE APOSTLE OF THE MIDDLE CLASSES AND WE ARE GLAD TO WELCOME HIS GOSPEL'
17:17:21  jq -nc --arg m ibm-granite/granite-embedding-english-r2 '{model: $m, input: ["The cat sat on the mat.", "A cat was sitting on a rug."]}'
17:17:21  curl -s http://framework:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":["The cat sat on the mat.","A cat was sitting on a rug."]}'
17:17:21  jq -c '{n: (.data | length), dims: [.data[].embedding | length], cosine: (if (.data | length) == 2 then ([.data[0].embedding, .data[1].embedding] | transpose | map(.[0] * .[1]) | add) / (([.data[0].embedding[] | . * .] | add | sqrt) * ([.data[1].embedding[] | . * .] | add | sqrt)) else null end), usage, error}' /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/framework-embed.json
17:17:21  : 'one warm-up request a row'
17:17:21  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage}'
17:17:21  jq -nc --arg m google/gemma-4-26B-A4B-it '{model: $m, messages: [{role: "user", content: "Say hello in one sentence."}], max_tokens: 64}'
17:17:21  curl -s http://framework:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"google/gemma-4-26B-A4B-it","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
17:17:22  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage}'
17:17:22  jq -nc --arg m google/gemma-4-E4B-it '{model: $m, messages: [{role: "user", content: "Say hello in one sentence."}], max_tokens: 64}'
17:17:22  curl -s http://framework:8001/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"google/gemma-4-E4B-it","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
17:17:24  jq -nc --arg m ibm-granite/granite-embedding-english-r2 '{model: $m, input: "Say hello in one sentence."}'
17:17:24  jq -c '{n: (.data | length), usage}'
17:17:24  curl -s http://framework:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":"Say hello in one sentence."}'
17:17:24  sleep 30
17:17:54  : 'three rows warmed up, idle 30 s'
17:17:54  drop
17:17:54  memory
17:17:54  source scripts/measure-lib.sh framework 8000
17:17:54  footprint
17:17:55  ssh framework 'docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-vision'
17:17:55  readout 2026-11-11T22:11:05.639785831Z
17:17:55  source scripts/measure-lib.sh framework 8001
17:17:55  footprint
17:17:55  ssh framework 'docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-audio'
17:17:55  readout 2026-11-11T22:12:52.672556716Z
17:17:55  source scripts/measure-lib.sh framework 8002
17:17:55  footprint
17:17:56  ssh framework 'docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-embed'
17:17:56  readout 2026-11-11T22:14:11.372182125Z
17:17:56  floorcheck 'the idle read'
17:18:12  source <scratchpad>/v-probe-audio.sh
17:18:12  : 'capability-vllm on framework: the audio probe again (LibriSpeech 1272-128104-0000, 5.86 s), its payload built with jq --rawfile; the first attempt'\''s jq --arg exceeded the argument limit and sent no body (400)'
17:18:12  source <scratchpad>/v-common.sh
17:18:12  served 8001
17:18:12  AM=google/gemma-4-E4B-it
17:18:12  base64 -w0 /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.wav
17:18:12  jq -n --arg m google/gemma-4-E4B-it --rawfile wav /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.b64 '{model: $m, max_tokens: 256, messages: [{role: "user", content: [{type: "input_audio", input_audio: {data: $wav, format: "wav"}}, {type: "text", text: "Transcribe the following speech segment in English into English text. Only output the transcription, with no newlines."}]}]}'
17:18:12  curl -s http://framework:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/req-audio.json
17:18:17  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage, error}' /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/framework-audio.json
17:18:17  jq -r .text /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes/probe-clip.json
17:18:17  echo 'reference: MISTER QUILTER IS THE APOSTLE OF THE MIDDLE CLASSES AND WE ARE GLAD TO WELCOME HIS GOSPEL'
17:18:17  echo 'vllm-vision warnings since start:'
17:18:17  ssh framework 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-vision) vllm-vision 2>&1'
17:18:17  grep -E ' (ERROR|WARNING) '
17:18:17  cut -c1-250
17:18:18  echo 'vllm-audio warnings since start:'
17:18:18  ssh framework 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-audio) vllm-audio 2>&1'
17:18:18  cut -c1-250
17:18:18  grep -E ' (ERROR|WARNING) '
17:18:18  echo 'vllm-embed warnings since start:'
17:18:18  ssh framework 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-embed) vllm-embed 2>&1'
17:18:18  grep -E ' (ERROR|WARNING) '
17:18:18  cut -c1-250
17:37:22  source <scratchpad>/v-sweep.sh
17:37:22  : 'capability-vllm-v-vision: framework'\''s vision cell on vLLM, role-split-vision-full, unchanged but for the target (its row'\''s port) and model (its served name), the other two rows loaded and idle, under watch with the host'\''s floors'
17:37:22  source <scratchpad>/v-common.sh
17:37:22  source <scratchpad>/v-after.sh
17:37:22  ping_host
17:37:22  source scripts/measure-lib.sh framework 8000
17:37:22  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
17:37:22  memory
17:37:22  t=2026-11-11T22:37:22Z
17:37:22  served 8000
17:37:22  cell capability-vllm-v-vision role-split-vision-full google/gemma-4-26B-A4B-it google/gemma-4-26B-A4B-it
17:43:05  v_after capability-vllm-v-vision 2026-11-11T22:37:22Z
17:43:07  source <scratchpad>/v-sweep.sh
17:43:07  : 'capability-vllm-v-audio: framework'\''s audio cell on vLLM, role-split-audio-full, unchanged but for the target (its row'\''s port) and model (its served name), the other two rows loaded and idle, under watch with the host'\''s floors'
17:43:07  source <scratchpad>/v-common.sh
17:43:07  source <scratchpad>/v-after.sh
17:43:07  ping_host
17:43:07  source scripts/measure-lib.sh framework 8001
17:43:07  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
17:43:07  memory
17:43:07  t=2026-11-11T22:43:07Z
17:43:07  served 8001
17:43:07  cell capability-vllm-v-audio role-split-audio-full google/gemma-4-E4B-it google/gemma-4-E4B-it
17:45:29  v_after capability-vllm-v-audio 2026-11-11T22:43:07Z
17:45:30  source <scratchpad>/v-sweep.sh
17:45:30  : 'capability-vllm-v-embed: framework'\''s embed cell on vLLM, role-split-embed, unchanged but for the target (its row'\''s port) and model (its served name), the other two rows loaded and idle, under watch with the host'\''s floors'
17:45:30  source <scratchpad>/v-common.sh
17:45:30  source <scratchpad>/v-after.sh
17:45:30  ping_host
17:45:30  source scripts/measure-lib.sh framework 8002
17:45:31  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
17:45:31  memory
17:45:31  t=2026-11-11T22:45:31Z
17:45:31  served 8002
17:45:31  cell capability-vllm-v-embed role-split-embed ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
17:48:43  v_after capability-vllm-v-embed 2026-11-11T22:45:31Z
17:48:46  source <scratchpad>/v-mixed.sh
17:48:46  : 'capability-vllm-v-mixed: framework'\''s vision 4, audio 4 and embedding 16 processes on vLLM, each to its row'\''s port, 240 s each, started together (this host alone)'
17:48:46  source <scratchpad>/v-common.sh
17:48:46  source <scratchpad>/v-after.sh
17:48:46  ping_host
17:48:46  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
17:48:46  memory
17:48:46  served 8000
17:48:46  VM=google/gemma-4-26B-A4B-it
17:48:46  served 8001
17:48:46  AM=google/gemma-4-E4B-it
17:48:46  served 8002
17:48:46  EM=ibm-granite/granite-embedding-english-r2
17:48:46  t=2026-11-11T22:48:46Z
17:48:46  wait
17:48:46  source scripts/measure-lib.sh framework 8000
17:48:46  source scripts/measure-lib.sh framework 8001
17:48:46  source scripts/measure-lib.sh framework 8002
17:48:46  GUIDELLM__SPEC__PROFILE__STREAMS=16
17:48:46  GUIDELLM__SPEC__PROFILE__STREAMS=4
17:48:46  GUIDELLM__SPEC__PROFILE__STREAMS=4
17:48:46  cell capability-vllm-v-mixed-embed role-split-mixed-embed ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
17:48:46  cell capability-vllm-v-mixed-vision role-split-mixed-vision google/gemma-4-26B-A4B-it google/gemma-4-26B-A4B-it
17:48:46  cell capability-vllm-v-mixed-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
17:53:09  v_after capability-vllm-v-mixed 2026-11-11T22:48:46Z
17:53:23  source <scratchpad>/v-mixed.sh
17:53:23  : 'capability-vllm-v-two: framework'\''s vision 2, audio 2 and embedding 8 processes on vLLM, each to its row'\''s port, 240 s each, started together (with gb10-2'\''s three)'
17:53:23  source <scratchpad>/v-common.sh
17:53:23  source <scratchpad>/v-after.sh
17:53:23  ping_host
17:53:23  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
17:53:23  memory
17:53:23  served 8000
17:53:23  VM=google/gemma-4-26B-A4B-it
17:53:23  served 8001
17:53:23  AM=google/gemma-4-E4B-it
17:53:23  served 8002
17:53:23  EM=ibm-granite/granite-embedding-english-r2
17:53:23  t=2026-11-11T22:53:23Z
17:53:23  source scripts/measure-lib.sh framework 8000
17:53:23  source scripts/measure-lib.sh framework 8001
17:53:23  wait
17:53:23  source scripts/measure-lib.sh framework 8002
17:53:23  GUIDELLM__SPEC__PROFILE__STREAMS=2
17:53:23  GUIDELLM__SPEC__PROFILE__STREAMS=2
17:53:23  GUIDELLM__SPEC__PROFILE__STREAMS=8
17:53:23  cell capability-vllm-v-two-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
17:53:23  cell capability-vllm-v-two-vision role-split-mixed-vision google/gemma-4-26B-A4B-it google/gemma-4-26B-A4B-it
17:53:23  cell capability-vllm-v-two-embed role-split-mixed-embed ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
17:57:46  v_after capability-vllm-v-two 2026-11-11T22:53:23Z
17:58:12  source <scratchpad>/v-restore.sh
17:58:12  : 'capability-vllm restore on framework (Behavior 13): each row'\''s run log saved; vllm-vision, vllm-audio and vllm-embed stopped (images, compile caches and weights kept); docker start llama; helpers on 8080; the capability sections loaded fresh (google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16); idle 30 s; drop the page cache; memory and footprint'
17:58:12  source <scratchpad>/v-common.sh
17:58:12  ping_host
17:58:12  ssh framework docker logs vllm-vision
17:58:12  ssh framework docker logs vllm-audio
17:58:12  ssh framework docker logs vllm-embed
17:58:13  ssh framework docker stop vllm-vision vllm-audio vllm-embed
17:58:16  ssh framework docker start llama
17:58:18  source scripts/measure-lib.sh framework
17:58:18  loaded
17:58:18  unload --all
17:58:18  drop
17:58:18  memory
17:58:18  t0=2026-11-11T22:58:18Z
17:58:18  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
17:58:24  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
17:58:30  load mrutkows/granite-embedding-english-r2-GGUF:BF16
17:58:33  sleep 30
17:59:03  : 'capability sections loaded since 2026-11-11T22:58:18Z, idle 30 s'
17:59:03  drop
17:59:04  memory
17:59:04  footprint 2026-11-11T22:58:18Z
17:59:04  loaded
17:59:04  floorcheck 'the restore read'
17:59:04  ssh framework 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; du -sh ~/.cache/vllm; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -i vllm; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1'
```

### Commands as run (gb10-1)

From `.state/measure/gb10-1/2026-11-11.log`, the stack read alone, by the same rule; nothing else
ran on gb10-1.

```
14:11:56  : 'capability-vllm stack on gb10-1: pending updates, kernel, driver, CUDA, Docker, Tailscale, the engine containers and images, the clone (read only)'
14:11:56  tailscale ping -c 1 gb10-1
14:11:56  tee -a /home/jaime/experiments/spike-model-layout/.state/capability-vllm/stack-2026-11-11.txt
14:11:56  echo '== gb10-1'
14:11:56  ssh gb10-1 'apt list --upgradable 2>/dev/null | grep -c upgradable; apt list --upgradable 2>/dev/null | grep upgradable | cut -d/ -f1 | paste -sd" "; uname -r; nvidia-smi --query-gpu=driver_version --format=csv,noheader; nvidia-smi | grep -o "CUDA Version: [0-9.]*"; docker --version; nvidia-ctk --version | head -1; . /etc/os-release; echo "$PRETTY_NAME"; grep -h -E "^DGX_(SWBUILD|OTA)_VERSION" /etc/dgx-release | tail -2; tailscale version | head -1; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" | grep -E "vllm|llama"; sudo -n -l 2>/dev/null | grep -i drop_caches; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && git branch -vv; df -B1 /srv/models / | tail -2'
14:11:57  tee -a /home/jaime/experiments/spike-model-layout/.state/capability-vllm/phased-2026-11-11.txt
14:11:57  echo '== gb10-1: apt-get -s upgrade (simulated, no root)'
14:11:57  ssh gb10-1 'apt-get -s upgrade 2>/dev/null | grep -A1 -E "deferred due to phasing|upgraded,"; for p in snapd distro-info python3-distro-info; do echo "$p: $(apt-cache policy $p | grep -E "Candidate|phased" | tr -s " " | paste -sd" ")"; done'
```

### Commands not in a step log

Each step file's write and launch, the probe inputs, the two-host rerun and the figures' reads ran
from the laptop outside the step helpers. They are quoted from the session's command history, each
headed by its time (UTC), from the project's root unless the command changes directory. Where a
command wrote a step file with a heredoc, `…` stands for its body, which is the step file's copy in
`.state/capability-vllm/step-files/` (`mkprobes.py` and `imports.py` among them). Those two and
the inline `python3 -` edit at 22:18:10Z are throwaway session helpers, quoted as run and never
tracked; they depart from the spike's rule that no Python is authored (`STANDARDS.md`, "Tools"),
and nothing in the repository depends on them. `<scratchpad>` is as above. Left out: the reads of
a step's output that only printed it, the waits that polled for a step's end, and the session's monitoring reads over SSH during staging (pending updates at
19:05Z, staging progress at 19:56Z and 20:35Z), which changed nothing and no figure rests on; and
the laptop's own clean-up before the rerun (I). The session's command at 21:16:32Z, which copied
the step files and slice 1's outputs into `.state/capability-vllm/` and wrote
`jq-figures-slice1.txt`, appears in full; so does the one at 22:59:35Z for slice 2's.

```sh
# 2026-11-11T19:11:56Z
D=<scratchpad>; mkdir -p $D /home/jaime/experiments/spike-model-layout/.state/capability-vllm
S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm
cat > $D/step.sh <<'EOF'
…
EOF
cat > $D/stack-gb.sh <<'EOF'
…
EOF
cat > $D/stack-fw.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout; for h in gb10-1 gb10-2; do bash $D/step.sh $h $D/stack-gb.sh 2>&1 | tail -40; done; bash $D/step.sh framework $D/stack-fw.sh 2>&1 | tail -40

# 2026-11-11T19:12:13Z
D=<scratchpad>
cat > $D/push.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout; for h in gb10-2 framework; do bash $D/step.sh $h $D/push.sh 2>&1 | tee $D/push-$h.out | tail -40; done

# 2026-11-11T19:12:42Z
D=<scratchpad>
cat > $D/stage-gb.sh <<'EOF'
…
EOF
cat > $D/stage-fw.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout; bash $D/step.sh gb10-2 $D/stage-gb.sh 2>&1 | tee $D/stage-gb.out | tail -25; bash $D/step.sh framework $D/stage-fw.sh 2>&1 | tee $D/stage-fw.out | tail -25

# 2026-11-11T19:13:31Z
D=<scratchpad>
P=/home/jaime/experiments/spike-model-layout/.state/capability-vllm/ping-2026-11-11.txt
cat > $D/after.sh <<EOF
…
EOF
cat > $D/l-load.sh <<EOF
…
EOF
cat > $D/l-sweep.sh <<EOF
…
EOF
cat > $D/l-mixed.sh <<EOF
…
EOF
cat > $D/two.sh <<EOF
…
EOF
bash -n $D/after.sh $D/l-load.sh $D/l-sweep.sh $D/l-mixed.sh $D/two.sh && cat $D/after.sh

# 2026-11-11T19:14:14Z
D=<scratchpad>
cat > $D/stage-check-gb.sh <<'EOF'
…
EOF
cat > $D/stage-check-fw.sh <<'EOF'
…
EOF
cat > $D/image-checks.sh <<'EOF'
…
EOF
echo ok

# 2026-11-11T19:14:24Z
D=<scratchpad>
cat > $D/imports.py <<'EOF'
…
EOF
cat > $D/image-checks.sh <<EOF
…
EOF
echo ok

# 2026-11-11T20:37:39Z
D=<scratchpad>; S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm; cd /home/jaime/experiments/spike-model-layout; date -u +%FT%TZ; bash $D/step.sh gb10-2 $D/stage-check-gb.sh > $S/stage-result-gb10-2.out 2>&1; bash $D/step.sh framework $D/stage-check-fw.sh > $S/stage-result-framework.out 2>&1; grep -v "^+" $S/stage-result-gb10-2.out | tail -60

# 2026-11-11T20:37:47Z
cd /home/jaime/experiments/spike-model-layout; grep -v "^+" .state/capability-vllm/stage-result-framework.out | grep -E "^==|exit|T1[45]:|Digest|naming|ERROR" | head -30; D=<scratchpad>; bash $D/step.sh framework $D/image-checks.sh > .state/capability-vllm/image-checks.out 2>&1; grep -v "^+" .state/capability-vllm/image-checks.out

# 2026-11-11T20:38:08Z
D=<scratchpad>; S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm; cd /home/jaime/experiments/spike-model-layout; date -u +%FT%TZ
SECTIONS="gemma-4-26B-A4B-it-qat-Q4_0-16-slots gemma-4-E4B-it-Q8_0-16-slots mrutkows/granite-embedding-english-r2-GGUF:BF16" bash $D/step.sh gb10-2 $D/l-load.sh > $S/l-load-gb10-2.out 2>&1 &
SECTIONS="google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16" bash $D/step.sh framework $D/l-load.sh > $S/l-load-framework.out 2>&1 &
wait; for h in gb10-2 framework; do echo "##### $h"; grep -v "^+" $S/l-load-$h.out; done

# 2026-11-11T20:39:27Z
D=<scratchpad>; S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm; cd /home/jaime/experiments/spike-model-layout; date -u +%FT%TZ; PURPOSE=vision SCENARIO=role-split-vision-split SECTION=gemma-4-26B-A4B-it-qat-Q4_0-16-slots TOKENIZER=google/gemma-4-26B-A4B-it bash $D/step.sh gb10-2 $D/l-sweep.sh > $S/l-vision-gb10-2.out 2>&1; echo rc $?; date -u +%FT%TZ; grep -v "^+" $S/l-vision-gb10-2.out | grep -E "pong|stream\(s\)|^exit|^watch|STOPPED|^memory|: pid|^pool"; jq -r --arg purpose vision -f bench/levels.jq .state/measure/gb10-2/capability-vllm-l-vision.json

# 2026-11-11T20:48:09Z
D=<scratchpad>; S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm; cd /home/jaime/experiments/spike-model-layout
run() { date -u +%FT%TZ; PURPOSE=$1 SCENARIO=$2 SECTION=$3 TOKENIZER=$4 timeout 660 bash $D/step.sh $H $D/l-sweep.sh > $S/l-$1-$H.out 2>&1; echo "rc $?"; date -u +%FT%TZ; grep -v "^+" $S/l-$1-$H.out | grep -E "pong|stream\(s\)|^exit|^watch|STOPPED|^memory|: pid|^pool"; jq -r --arg purpose $1 -f bench/levels.jq .state/measure/$H/capability-vllm-l-$1.json; }
H=gb10-2
run audio role-split-audio-split gemma-4-E4B-it-Q8_0-16-slots google/gemma-4-E4B-it
grep -q STOPPED $S/l-audio-$H.out && exit 1
run embed role-split-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2

# 2026-11-11T20:54:12Z
D=<scratchpad>; S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm; cd /home/jaime/experiments/spike-model-layout; H=gb10-2; date -u +%FT%TZ; MIX=mixed VISION=4 AUDIO=4 EMBED=16 VSEC=gemma-4-26B-A4B-it-qat-Q4_0-16-slots ASEC=gemma-4-E4B-it-Q8_0-16-slots timeout 660 bash $D/step.sh $H $D/l-mixed.sh > $S/l-mixed-$H.out 2>&1; echo rc $?; date -u +%FT%TZ; grep -v "^+" $S/l-mixed-$H.out | grep -E "pong|stream\(s\)|^exit|^watch|STOPPED|^memory|: pid|^pool"; for p in vision audio embed; do jq -r --arg purpose $p -f bench/levels.jq .state/measure/$H/capability-vllm-l-mixed-$p.json; done

# 2026-11-11T20:58:57Z
D=<scratchpad>; S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm; cd /home/jaime/experiments/spike-model-layout
run() { date -u +%FT%TZ; PURPOSE=$1 SCENARIO=$2 SECTION=$3 TOKENIZER=$4 timeout 660 bash $D/step.sh $H $D/l-sweep.sh > $S/l-$1-$H.out 2>&1; echo "rc $?"; date -u +%FT%TZ; grep -v "^+" $S/l-$1-$H.out | grep -E "pong|stream\(s\)|^exit|^watch|STOPPED|^memory|: pid|^pool"; jq -r --arg purpose $1 -f bench/levels.jq .state/measure/$H/capability-vllm-l-$1.json; grep -q STOPPED $S/l-$1-$H.out && exit 1; }
H=framework
run vision role-split-vision-full google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
run audio role-split-audio-full ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
run embed role-split-embed mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2

# 2026-11-11T21:10:59Z
D=<scratchpad>; S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm; cd /home/jaime/experiments/spike-model-layout; H=framework; date -u +%FT%TZ; MIX=mixed VISION=4 AUDIO=4 EMBED=16 VSEC=google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ASEC=ggml-org/gemma-4-E4B-it-GGUF:Q8_0 timeout 660 bash $D/step.sh $H $D/l-mixed.sh > $S/l-mixed-$H.out 2>&1; echo rc $?; date -u +%FT%TZ; grep -v "^+" $S/l-mixed-$H.out | grep -E "pong|stream\(s\)|^exit|^watch|STOPPED|^memory|: pid|^pool"; for p in vision audio embed; do jq -r --arg purpose $p -f bench/levels.jq .state/measure/$H/capability-vllm-l-mixed-$p.json; done

# 2026-11-11T21:15:31Z
D=<scratchpad>; S=/home/jaime/experiments/spike-model-layout/.state/capability-vllm; cd /home/jaime/experiments/spike-model-layout; date -u +%FT%TZ; MIX=two VISION=2 AUDIO=2 EMBED=8 timeout 700 bash $D/two.sh; echo rc $?; cat $D/two.done; date -u +%FT%TZ; for h in gb10-2 framework; do cp $D/two-$h.out $S/l-two-$h.out; echo "##### $h"; grep -v "^+" $S/l-two-$h.out | grep -E "pong|stream\(s\)|^exit|^watch|STOPPED|^memory|: pid|^pool"; for p in vision audio embed; do jq -r --arg purpose $p -f bench/levels.jq .state/measure/$h/capability-vllm-l-two-$p.json; done; done

# 2026-11-11T21:16:32Z
cd /home/jaime/experiments/spike-model-layout; D=<scratchpad>; S=.state/capability-vllm; mkdir -p $S/step-files; cp $D/*.sh $D/imports.py $S/step-files/; cp $D/push-*.out $D/stage-*.out $D/two-*.out $S/ 2>/dev/null; M=.state/measure; { date -u +%FT%TZ; for p in vision audio embed; do for f in $M/gb10-2/capability-vllm-l-$p.json $M/framework/capability-vllm-l-$p.json $M/*/capability-vllm-l-mixed-$p.json; do echo "# ${f#$M/}"; jq -r --arg purpose $p -f bench/levels.jq $f; done; done; for f in $M/*/capability-vllm-l-*.json; do jq -r --arg f "${f#$M/}" '.benchmarks[] | (.config.strategy.streams|tostring) as $s | .requests.errored[]? | "\($f) s=\($s): \(.info.error // .error // "?" | tostring | .[0:220])"' $f; done; } > $S/jq-figures-slice1.txt 2>&1; echo rc $?; tail -8 $S/jq-figures-slice1.txt; ls $S; git status --short; git -C ../spike-model-engines status --short

# 2026-11-11T21:53:58Z
cd /home/jaime/experiments/spike-model-layout; for h in gb10-2 framework; do d=.state/measure/$h/reaped-two-2026-11-11; mkdir -p $d; mv .state/measure/$h/capability-vllm-l-two-* $d/; ls $d; done; S=<scratchpad>; mv $S/two-gb10-2.out .state/measure/gb10-2/reaped-two-2026-11-11/; mv $S/two-framework.out .state/measure/framework/reaped-two-2026-11-11/; rm -f $S/two.done; for h in gb10-2 framework; do tailscale ping -c 1 $h; done; ssh gb10-2 'curl -s localhost:8080/models | head -c 300'; echo; free -m | sed -n 2,3p

# 2026-11-11T21:54:01Z
MIX=two VISION=2 AUDIO=2 EMBED=8 bash <scratchpad>/two.sh

# 2026-11-11T22:00:41Z
cd ~/experiments/spike-model-layout && mkdir -p .state/capability-vllm/probes && cat > <scratchpad>/mkprobes.py <<'EOF'
…
EOF
MISE_ENV=bench mise exec -- python -I <scratchpad>/mkprobes.py /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes 2>&1 | tail -5; ls -la .state/capability-vllm/probes

# 2026-11-11T22:00:49Z
cd /tmp && /home/jaime/.local/share/mise/installs/pipx-guidellm/0.8.1/guidellm/bin/python -I <scratchpad>/mkprobes.py /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes 2>&1 | tail -5; ls -la /home/jaime/experiments/spike-model-layout/.state/capability-vllm/probes

# 2026-11-11T22:02:23Z
D=<scratchpad>
cat > $D/v-common.sh <<'EOF'
…
EOF
cat > $D/v-install.sh <<'EOF'
…
EOF
echo ok

# 2026-11-11T22:03:05Z
D=<scratchpad>
cat > $D/v-cold.sh <<'EOF'
…
EOF
cat > $D/v-probe.sh <<'EOF'
…
EOF
cat > $D/v-after.sh <<'EOF'
…
EOF
cat > $D/v-sweep.sh <<'EOF'
…
EOF
cat > $D/v-mixed.sh <<'EOF'
…
EOF
cat > $D/v-two.sh <<'EOF'
…
EOF
cat > $D/v-restore.sh <<'EOF'
…
EOF
cd $D && shellcheck -s bash -e SC2034,SC1090,SC1091,SC2154 v-*.sh && echo shellcheck-ok

# 2026-11-11T22:03:11Z
D=<scratchpad>; bash -n $D/v-common.sh $D/v-install.sh && cd /home/jaime/experiments/spike-model-layout && (bash $D/step.sh gb10-2 $D/v-install.sh > $D/v-install-gb10-2.out 2>&1 &) ; (bash $D/step.sh framework $D/v-install.sh > $D/v-install-framework.out 2>&1 &); sleep 20; cat $D/v-install-gb10-2.out $D/v-install-framework.out

# 2026-11-11T22:04:00Z
D=<scratchpad>; cp $D/v-*.sh $D/mkprobes.py /home/jaime/experiments/spike-model-layout/.state/capability-vllm/step-files/ && ls /home/jaime/experiments/spike-model-layout/.state/capability-vllm/step-files/

# 2026-11-11T22:11:01Z
D=<scratchpad>; cd /home/jaime/experiments/spike-model-layout; bash $D/step.sh gb10-2 $D/v-cold.sh > $D/v-cold-gb10-2.out 2>&1 & bash $D/step.sh framework $D/v-cold.sh > $D/v-cold-framework.out 2>&1 & wait; grep -hE 'cold-|FAILED|ROCM_ATTN|error lines|^memory|container:|pool:' $D/v-cold-*.out | cut -c1-230

# 2026-11-11T22:17:16Z
D=<scratchpad>; cd /home/jaime/experiments/spike-model-layout; bash $D/step.sh gb10-2 $D/v-probe.sh > $D/v-probe-gb10-2.out 2>&1 & bash $D/step.sh framework $D/v-probe.sh > $D/v-probe-framework.out 2>&1 & wait; for h in gb10-2 framework; do echo "=== $h"; grep -vE '^\s+\(EngineCore|^\s+INFO|non-default' $D/v-probe-$h.out | cut -c1-400; done

# 2026-11-11T22:18:10Z
D=<scratchpad>; cd $D && python3 - <<'EOF'
p='v-probe.sh'; s=open(p).read()
s=s.replace('''jq -n --arg m "$AM" --arg wav "$(base64 -w0 "$P/probe-clip.wav")" \\''','''base64 -w0 "$P/probe-clip.wav" >"$P/probe-clip.b64"
jq -n --arg m "$AM" --rawfile wav "$P/probe-clip.b64" \\''')
open(p,'w').write(s)
EOF
grep -n 'rawfile' v-probe.sh
cat > $D/v-probe-audio.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout; for h in gb10-2 framework; do bash $D/step.sh $h $D/v-probe-audio.sh > $D/v-probe-audio-$h.out 2>&1; echo "== $h"; cat $D/v-probe-audio-$h.out; done

# 2026-11-11T22:18:52Z
D=<scratchpad>; head -20 /home/jaime/experiments/spike-model-layout/bench/role-split-vision-full.yaml | grep -n "streams\|seconds"; grep -n "initial_streams\|seconds\|count" /home/jaime/experiments/spike-model-layout/bench/role-split-vision-full.yaml /home/jaime/experiments/spike-model-layout/bench/role-split-audio-full.yaml
cat > $D/v-cells.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout && export PURPOSE SCENARIO MIX VISION AUDIO EMBED; bash $D/v-cells.sh gb10-2

# 2026-11-11T22:37:17Z
bash <scratchpad>/v-cells.sh framework

# 2026-11-11T22:53:22Z
D=<scratchpad>; cd /home/jaime/experiments/spike-model-layout; free -m | head -2 | tee $D/v-two-laptop-free.txt; MIX=two VISION=2 AUDIO=2 EMBED=8 bash $D/v-two.sh; free -m | head -2 | tee -a $D/v-two-laptop-free.txt; cat $D/v-two.done

# 2026-11-11T22:58:12Z
D=<scratchpad>; cd /home/jaime/experiments/spike-model-layout; SECTIONS="gemma-4-26B-A4B-it-qat-Q4_0-16-slots gemma-4-E4B-it-Q8_0-16-slots mrutkows/granite-embedding-english-r2-GGUF:BF16" bash $D/step.sh gb10-2 $D/v-restore.sh > $D/v-restore-gb10-2.out 2>&1 & SECTIONS="google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16" bash $D/step.sh framework $D/v-restore.sh > $D/v-restore-framework.out 2>&1 & wait; for h in gb10-2 framework; do echo "=== $h"; grep -vE '^\s+(router|gemma|ggml|google|mrutkows|port)' $D/v-restore-$h.out | cut -c1-220; done

# 2026-11-11T22:59:35Z
cd /home/jaime/experiments/spike-model-layout; D=<scratchpad>; S=.state/capability-vllm; grep -hE '^memory' $S/l-load-*.out | tail -4; for f in v-install v-cold v-probe v-probe-audio v-vision v-audio v-embed v-mixed v-two v-restore; do for h in gb10-2 framework; do [ -f $D/$f-$h.out ] && cp $D/$f-$h.out $S/; done; done; cp $D/v-two-laptop-free.txt $D/v-cells.sh $D/v-probe-audio.sh $S/step-files/ 2>/dev/null; mv $S/step-files/v-two-laptop-free.txt $S/; cp $D/v-*.sh $S/step-files/; { for h in gb10-2 framework; do for c in vision audio embed mixed-vision mixed-audio mixed-embed two-vision two-audio two-embed; do p=${c##*-}; echo "# $h/capability-vllm-v-$c.json"; jq -r --arg purpose $p -f bench/levels.jq .state/measure/$h/capability-vllm-v-$c.json; done; done; } > $S/jq-figures-slice2.txt; git status --short | head; ls $S | wc -l
```

In this finding's slice, after the re-read below, the two-host rerun's step outputs kept beside
the reaped run's (23:17:12Z):

```sh
cd /home/jaime/experiments/spike-model-layout && D=<scratchpad>; for h in gb10-2 framework; do cp $D/two-$h.out .state/capability-vllm/two-rerun-$h.out; done; ls -la .state/capability-vllm/two-*; head -3 .state/measure/framework/capability-vllm-v-vision.watch.tsv; sort -t$'\t' -k5,5n .state/measure/framework/capability-vllm-v-vision.watch.tsv | head -2
```

**The figures' re-read** (23:09:44Z), every per-level table in G to J from the cells' JSON through
`bench/levels.jq`, with each cell's exit, and the start logs' sizing and backend lines, into
`.state/capability-vllm/jq-figures-slice3.txt`; its tables match `jq-figures-slice1.txt` and
`jq-figures-slice2.txt` line for line, and add L-two's:

```sh
cd /home/jaime/experiments/spike-model-layout && M=.state/measure A=.state/capability-vllm; { date -u +%FT%TZ; for e in l v; do for h in gb10-2 framework; do for c in vision audio embed mixed-vision mixed-audio mixed-embed two-vision two-audio two-embed; do p=${c##*-}; echo "# $h $e-$c (exit $(cat $M/$h/capability-vllm-$e-$c.exit))"; jq -r --arg purpose $p -f bench/levels.jq $M/$h/capability-vllm-$e-$c.json; done; done; done; for l in $A/*-first-*.log $A/*-cold-*.log; do echo "# ${l#$A/}"; grep -E 'Loading weights took|Model loading took|Available KV cache memory|GPU KV cache size|Free memory on device|Using .*[Bb]ackend|Directly load AOT|Application startup complete' $l | sed -E 's/^\((EngineCore|APIServer) pid=[0-9]+\) //' | cut -c1-220; done; } > $A/jq-figures-slice3.txt 2>&1; echo rc $?; wc -l $A/jq-figures-slice3.txt; grep -c MISSES $A/jq-figures-slice3.txt
```

**After the reviews**, the standards review added bb68cbd, "vllm.sh: say that update removes a
staged ROCm fallback image", a comment-only change to `host/vllm.sh` (3 lines added, 1 removed), on
top of 4ad76e6. The session then moved both capability hosts' clones to it (23:2xZ); the same two
commands ran for `framework`:

```sh
git push gb10-2:repos/spike-model-engines capability-vllm:hosts-next   # 4ad76e6..bb68cbd
ssh gb10-2 'cd ~/repos/spike-model-engines && git checkout -B hosts hosts-next'   # "Reset branch 'hosts'"; hosts bb68cbd
```

Afterwards `curl http://<host>:8080/health` returned `{"status":"ok"}` on gb10-2 and the Framework
(23:29:18Z). No figure was taken at bb68cbd: every run above measured the clones at 4ad76e6.

**The ROCm tags' digests** (2026-11-11T23:29:44Z), read from Docker Hub into
`.state/capability-vllm/tag-digests.out`: v0.33.0's default tag and `-rocm100` share one digest,
the one the Framework's rows ran ("Stack, engine and network path"); `-rocm72` is a different image.

```sh
curl -s https://hub.docker.com/v2/repositories/vllm/vllm-openai-rocm/tags/v0.33.0 | jq -r .digest
# sha256:4fcd39b758b660c4e9c345c021e2ea8f0ccdb31e3c32507d676cc3005ae83fba
curl -s https://hub.docker.com/v2/repositories/vllm/vllm-openai-rocm/tags/v0.33.0-rocm100 | jq -r .digest
# sha256:4fcd39b758b660c4e9c345c021e2ea8f0ccdb31e3c32507d676cc3005ae83fba
curl -s https://hub.docker.com/v2/repositories/vllm/vllm-openai-rocm/tags/v0.33.0-rocm72 | jq -r .digest
# sha256:4fe7bc121cbe2f0791ebc38dcc2f0d615612233b4bfc0c1f4b9daeab05aba182
```
