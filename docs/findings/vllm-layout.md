# Finding: the vLLM layout tuned and measured as it stands, on gb10-1, gb10-2 and the Framework

Measured 2026-11-12, task `vllm-layout`. This finding is dated: every figure holds for the versions,
stack, rows and network path below, on that day, and nothing after it.

**What it establishes, as evidence.** The spike decides nothing; the architect chose the layout,
and this finding records the evidence each choice rests on. The task set out to tune the layout
the plan round chose (gb10-1 the agent alone; gb10-2 vision and audio; the Framework embedding
alone, with a lighter vision row and an audio row staged as a manual failover) and to measure it as
it would stand. The measurements moved it. On gb10-2, audio missed its floor beside vision at every
pair level from 2 + 2 to 8 + 8 streams, while each held alone (E). On the Framework, audio missed
beside embedding run flat out at 16 streams, and held beside embedding sent at a steady 8.4 or 34
requests a second (F). On those figures the architect placed audio on the Framework beside
embedding, with embedding rate-limited by the gateway, gave gb10-2 to vision alone, and dropped the
Framework's vision row and the failover (goal record, escalations 1 to 3). The accuracy check, the
task's one new tool, found no significant loss on the agent's FP8 KV row against BF16, so FP8
became the agent row (C), and none on NVIDIA's NVFP4 vision checkpoint against Google's BF16 (G).
The standing layout, all three hosts at once at the load targets, met every purpose's floor after
each host's one reboot (I, J). It answers evidence 7.

| Host | Purpose, vLLM row | Cap (max-num-seqs) | Load target | Alone on its host | Standing cell, all three hosts at once (J) | Pool idle after the reboot / lowest in the standing cell (floor) | Start after the reboot (I) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-1 | agent: `gpt-oss-120b-agent-fp8`, FP8 KV at 32,993,476,982 bytes, 0.80, 131,072 tokens | 12 | 4 sessions | 4: ITL 49.13 ms; 12: 99.07 ms, meets (D) | ITL 48.13 ms, meets | 15.07 / 14.87 GiB (12.2) | 502.5 s (c), unattended |
| gb10-2 | vision: `gemma-4-26B-A4B-NVFP4-vision-gb10`, 0.40, 8,192 tokens | 16 | 4 requests | 4: 4.68 s; 16: 9.64 s, meets (E) | 4.49 s, 212 of 212 ≤10 s, meets | 66.73 / 65.21 GiB (12.2) | 193.2 s (c), unattended |
| framework | audio: `gemma-4-E4B-it-audio-framework`, 0.18, 8,192 tokens | 4 | 4 requests | 4: RTFx 6.54; beside embedding at 34 req/s 5.84; 8 beside it: 4.94, misses (F) | RTFx 5.78, meets | GTT 90.78 / 90.24 GiB (11.2); system 89.44 / 87.27 GiB (12.5) | 68.7 s (c), after the LUKS passphrase |
| framework | embedding: `granite-embedding-english-r2-framework`, 0.03, 128 sequences, 65,536 batched tokens | 128; the gateway holds it to ≤34 req/s | 16 streams; at the gateway's rate | knee at 16 streams, 98,325 prompt tok/s (F) | 34 req/s, 17,442 prompt tok/s, meets | as audio | 22.8 s (c), as audio |

It also found that:

- **FP8 KV costs the agent no measurable accuracy at 95%**, but the test can't rule out a few
  points: GPQA diamond 0.6212 against BF16's 0.6667 (b 24, c 15, p 0.20); RULER's needle at
  32,768 tokens 0.80 against 0.88 (p 0.22) and at 65,536 0.92 against 0.90 (p 1). The 95% interval
  on GPQA's paired difference runs from −10.7 to +1.6 points (c) (C.4, C.5).
- **RULER's misses are number formatting, not retrieval**: on both rows all but one miss is the
  right number printed with spaces or commas, which RULER's substring match scores wrong (C.6).
- **gb10-2 can't serve audio beside vision.** Audio's RTFx median sat at 2.86 to 3.36 at all five
  pair levels, its ITL at 88 to 104 ms against 44 ms alone, while vision met its floor at every
  pair but 8 + 8 (E.3, E.4). Alone, vision holds 16 streams (9.64 s), the row's cap (E.5).
- **On the Framework, embedding's knee is 16 streams** (98,325 prompt tok/s, about 23 times the
  floor, c); 128 sequences and 65,536 batched tokens hold the plateau to 128 streams without an
  error (F.2). Run flat out at 16 streams it takes audio to RTFx 2.44 (F.3); at a steady 34
  requests a second (17,442 prompt tok/s, 4.06 times the floor, c) audio holds at 5.84 (F.4), and
  at 8 audio streams it misses by 0.06 (4.94), so audio's cap is 4 (F.5).
- **NVFP4 vision costs no measurable accuracy at 95%**: mmmu_val 0.6111 against Google's BF16
  0.6178 on the Framework (b 78, c 72, p 0.68; every prompt matched), with the CUDA-against-ROCm
  difference a limit (G).
- **The standing state survives a reboot.** Every row came back by itself with `unless-stopped`;
  the nonlocal-bind sysctl was already set on all three hosts, so the root step changed nothing
  there; the Framework's deprecated gttsize option is gone with its GTT unchanged at 112 GiB (I).
  The Framework's LUKS-encrypted root needs a person at its console to enter the passphrase, so it
  neither returns unattended nor reboots remotely, as the GB10s do (I.4).
- **llama.cpp left all three workstations**: its container, every llama.cpp image, and the four
  GGUF repositories, 81.87 GiB of store on each host (H).
- vLLM v0.34.0 was not released when BUILD started, so every host stays on v0.33.0 (A.2).

**The conclusion, as evidence.** The spike records it and decides nothing.

- On this session's figures the layout the architect chose holds every purpose's load target at
  its floor, with the hosts at once: the agent at 4 sessions on gb10-1, vision at 4 on gb10-2,
  audio at 4 and embedding at the gateway's 34 requests a second on the Framework (J). Each purpose
  ran within a few percent of its figure alone on its host, so the hosts don't interact.
- **Headroom per purpose**: the agent holds 12 sessions on its row (3 times the target), vision 16
  (4 times); audio holds exactly its target of 4, and embedding 4.06 times its floor at the
  admitted rate (c). Past each row's cap requests queue in vLLM; past the hosts' capacity, the
  gateway's overflow takes them (`docs/layout.md`, "Requirements for spike-model-gateway").
- **What placement buys**: each GPU carries one heavy purpose, or one light pair held apart by the
  gateway's rate limit. Every miss this spike measured was two purposes
  sharing a GPU's compute and bandwidth, never memory: gb10-2 read 35.53 GiB free in the pair
  cell that missed audio, and the Framework 86.83 GiB of system memory at its lowest (K).
- **No failover**: each purpose has one host, by the architect's choice, so a down host fails its
  purpose visibly until it returns (goal record, escalation 2).
- **Open items** (N): FP8's uncalibrated KV scale, which the test can't clear to a point or two;
  audio's zero headroom above its target; the Framework's console-only reboot; the FP8 row's
  compile-time dip under gb10-1's floor; v0.34.0.

"Holds" and "meets" are role-split's rule: the highest level meeting the purpose's floor at or below
GuideLLM's knee, or, where it found none, the highest level meeting it
([role-split](role-split.md), I). The floors: agent ITL median ≤100 ms; vision request latency
median ≤10 s; audio RTFx median ≥5; embedding mean prompt tok/s ≥4,300.

**Which figures size the layout.** Production clients sit on the same direct network as the GPUs,
so the layout is sized on LAN figures (role-split's decision). Every run went direct on the LAN, 0
to 7 ms ("Stack, engine and network path"), so client-side and server-side figures both stand.

| Host | Serves at the end of slice 3 |
| --- | --- |
| gb10-1 | `vllm` (`vllm/vllm-openai:v0.33.0`) on the row `gpt-oss-120b-agent-fp8`, port 8000, `unless-stopped`, started by the reboot at 21:18:26Z, RestartCount 0; nothing else in `docker ps -a`. llama.cpp's container, its `server-cuda13-b12098` image and the GGUF repositories removed; the store holds `openai/gpt-oss-120b` alone. spike-model-engines' clone on a local `hosts` branch at 8f981ee, where every figure was measured, before merge (B) |
| gb10-2 | `vllm-vision` on `gemma-4-26B-A4B-NVFP4-vision-gb10`, port 8000, `unless-stopped`, started 21:13:18Z, RestartCount 0; nothing else. llama.cpp removed; the store holds `nvidia/Gemma-4-26B-A4B-NVFP4` alone (18.8G). Clone on `hosts` at 8f981ee |
| framework | `vllm-audio` (the audio image) on `gemma-4-E4B-it-audio-framework`, port 8001, and `vllm-embed` on `granite-embedding-english-r2-framework`, port 8002, both `unless-stopped`, started 21:16:24Z, RestartCount 0; nothing else. llama.cpp's container and its Vulkan and ROCm images removed; the store holds `google/gemma-4-E4B-it` and `ibm-granite/granite-embedding-english-r2`; the BF16 26B-A4B removed (G). Images kept: `vllm/vllm-openai-rocm:v0.33.0` and both audio images (`v0.33.0`, `v0.33.0-rocm72`). Clone on `hosts` at 8f981ee |

## Stack, engine and network path

Read by the session over SSH, read-only, at 13:52:37 to 13:52:43Z, after the architect's root
updates (`.state/vllm-layout/stack-2026-11-12.txt`, `phased-2026-11-12.txt`):

| Host | Pending updates | OS | Kernel | GPU stack | Docker | Tailscale | Engine at the read | Clone |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-1 | 3, phased (distro-info, python3-distro-info, snapd) | DGX OS 7.6.0, Ubuntu 24.04.5 LTS | 7.0.0-1025-nvidia | driver 580.178.04, CUDA 13.0, NVIDIA Container Toolkit 1.20.1 | 29.6.2 | 1.104.6 | llama.cpp `server-cuda13-b12098` up; `vllm` Exited (0) | `main` at a294e4e, moved to 96b4743 (A.3) |
| gb10-2 | 3, phased, as gb10-1 | as gb10-1 | 7.0.0-1025-nvidia | as gb10-1 | 29.6.2 | 1.104.6 | llama.cpp up; `vllm-vision`, `vllm-audio`, `vllm-embed` Exited (0) | `main` at 96b4743 |
| framework | 0 (`checkupdates` exit 2) | Omarchy | 7.2.15-1-omarchy | mesa and vulkan-radeon 1:26.2.5-1, linux-firmware 20260916-1 | 1:29.9.2-1 | 1.104.2 | llama.cpp `server-vulkan-b12098` up; the three vLLM containers Exited (0) | `main` at 96b4743 |

The stack is capability-vllm's in every column ([capability-vllm](capability-vllm.md), "Stack,
engine and network path"). The Framework's stack read again at 17:16:58Z, before its delivery,
was unchanged but for one pending desktop update, gliff 0.4.2-1 → 0.4.3-1, left for the architect
(goal record). No kernel, driver or Mesa moved during the session, and each host's reboot (I)
came back on the same kernel.

**Network path.** `tailscale ping -c 1 <host>` from the laptop preceded every run, each dated in
`.state/vllm-layout/ping-2026-11-12.txt` (70 pongs), and every pong came via the host's LAN
address, 0 to 7 ms (the 7 ms at 20:38:21Z, gb10-1, before a clone move). No run took a relay.

**Engines.** vLLM v0.33.0 on all three hosts (`/version` read `0.33.0` on every row), from
spike-model-engines' `host/engines vllm` at the pull request's commits (B):
`vllm/vllm-openai:v0.33.0` (d825baf9ce4b) on the GB10s and `vllm/vllm-openai-rocm:v0.33.0`
(ROCm 10.0, 4fcd39b758b6) on the Framework, with its audio row on
`spike-model-engines/vllm-openai-rocm-audio:v0.33.0` (298c73773c66), built on it. llama.cpp
b12098 served until it was stopped on each host, and was then removed (H).

| Host | Row | Container, port | Server flags (`host/vllm-rows` at 8f981ee) |
| --- | --- | --- | --- |
| gb10-1 | `gpt-oss-120b-agent-fp8` | `vllm`, 8000 | `openai/gpt-oss-120b --max-num-seqs 12 --max-model-len 131072 --gpu-memory-utilization 0.80 --kv-cache-dtype fp8 --kv-cache-memory-bytes 32993476982 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai` |
| gb10-2 | `gemma-4-26B-A4B-NVFP4-vision-gb10` | `vllm-vision`, 8000 | `nvidia/Gemma-4-26B-A4B-NVFP4 --max-num-seqs 16 --max-model-len 8192 --gpu-memory-utilization 0.40 --kv-cache-dtype bfloat16 --reasoning-parser gemma4 --enable-auto-tool-choice --tool-call-parser gemma4` |
| framework | `gemma-4-E4B-it-audio-framework` | `vllm-audio`, 8001 | `google/gemma-4-E4B-it --max-num-seqs 4 --max-model-len 8192 --gpu-memory-utilization 0.18 --kv-cache-dtype bfloat16 --reasoning-parser gemma4 --enable-auto-tool-choice --tool-call-parser gemma4` |
| framework | `granite-embedding-english-r2-framework` | `vllm-embed`, 8002 | `ibm-granite/granite-embedding-english-r2 --runner pooling --max-num-seqs 128 --max-model-len 8192 --gpu-memory-utilization 0.03 --max-num-batched-tokens 65536` |

Each start log read its `max_num_seqs` back after the reboot (I.3). Backends, as vLLM chose them:
FLASHINFER attention (xqa decode, FP8 KV) and MARLIN MXFP4 MoE on gb10-1; TRITON_ATTN (forced by
Gemma 4's heterogeneous heads) and FLASHINFER_CUTLASS NVFP4 MoE on gb10-2; TRITON_ATTN on the
Framework's audio row and ROCM_ATTN (encoder-only) on granite.

**Tools.** The step helpers in `scripts/measure-lib.sh`, unchanged this task. Load cells are
GuideLLM 0.8.1 from the laptop (`mise.bench.toml`), each run by `cell` under `watch`: the pool
sampled every 10 s, both pools on the Framework, the cell stopped under a floor, capped at 10
min. Accuracy runs are lm-evaluation-harness 0.4.13 (C.1), under `watch` with `timeout 45m`,
one run `60m` (G). Each run's files are under `.state/measure/<host>/vllm-layout-*`
(`.json`, `.log`, `.watch.tsv`, `.exit`), the lm-eval results under `.state/vllm-layout/lm-eval/`.
The steps ran from step files, each through `step.sh <host> <file>`, which sources the helpers
for the host and exports its floors; copies are in `.state/vllm-layout/step-files/`, and each
step's output in `.state/vllm-layout/<name>.out`. The session's run notes are
`.state/vllm-layout/slice1-partA-notes.md`, `slice1-partB-notes.md`, `slice2-partA-notes.md`,
`slice2-partB-notes.md` and `slice3-notes.md`; the architect's root steps are in `root-steps.md`
and `root-steps-slice3.md` beside them.

**Reading the figures.** On a GB10 the pool is MemAvailable against 12.2 GiB; on the Framework,
GTT available against 11.2 GiB and system MemAvailable against 12.5 GiB. Idle and after-cell
reads follow a page-cache drop. The per-level tables come from each cell's JSON through
[`bench/levels.jq`](../../bench/levels.jq), and the paired tests from each run's samples through
[`bench/paired.awk`](../../bench/paired.awk); every table and test was re-read at 21:38:06Z into
`.state/vllm-layout/jq-figures-slice4.txt` by one quoted command (O, "Commands not in a step
log"), and matches the session's reads. Pools are in GiB (1 GiB = 1024 MiB). The command lists
show the step logs' local times (UTC−5); the prose gives UTC. Every figure is measured, read from a
result file, the step log or a saved output, unless marked **(c)**: computed from measured figures,
with the arithmetic shown where it isn't a plain difference or ratio. **(m)** marks a measured
figure where computed ones sit beside it.

## A. Hosts and pin (Behavior 1)

### A.1 Root updates

The architect's, at the session's start (`.state/vllm-layout/root-steps.md`): on each GB10 `sudo
apt update && sudo apt full-upgrade -y && sudo apt autoremove -y`, which moved google-chrome-stable
157.0.8103.50-1 → 157.0.8103.78-1 and deferred the three phased packages; on the Framework
`omarchy update`, which moved google-chrome and yt-dlp and installed nodejs 26.12.0-1 with its
libraries. No kernel, driver, CUDA or Mesa package moved, and no reboot was taken then. The stack
read counted the GB10s' three phased packages as no pending updates, as the framework task
decided.

### A.2 The pin: v0.34.0 not released, every host stays on v0.33.0

At BUILD's start GitHub's latest vLLM release was v0.33.0, and v0.34.0 had tags rc0 to rc2 only,
with no official release or images. By the brief's rule every host stays on v0.33.0, with no A/B,
and v0.34 goes to the intake as a note (N.6): it carries the GB10 weight-loading fix (#58868) and
the extensible KV cache. The Framework's audio image was not rebuilt.

### A.3 The clones to main

gb10-1's clone moved from a294e4e to `main` at 96b4743 (capability-vllm's merge), fast-forward
only; gb10-2's and the Framework's were already there, with no `hosts` branch left
(`.state/vllm-layout/clones-main.out`, 13:53:31Z). Each then moved to a local `hosts` branch at the
pull request's commit as it reached it (B).

## B. The host/ pull request (Behaviors 2, 7)

Four commits on spike-model-engines' `vllm-layout` branch. The first three each reached a host
before merge by `git push <host>:repos/spike-model-engines vllm-layout:hosts-next` and `git
checkout -B hosts hosts-next` on the host, the way the earlier tasks did. The fourth, 90ef16f,
changes comments only, so every figure was measured at 8f981ee. `mise run check` passed in
spike-model-engines at each commit. The pull request changes `host/vllm-rows` and `host/llama.env`
only.

| Commit | What it changed | Cites | Reached |
| --- | --- | --- | --- |
| 3efb444 | the agent rows' caps: `gpt-oss-120b-agent` `--max-num-seqs 8` and `gpt-oss-120b-agent-fp8` `--max-num-seqs 12`, from 16 each, everything else unchanged; llama.env's hold note reads "unrestored through b12318"; the vLLM pin stays v0.33.0 | agent-vllm F, "Meets the floor through" | gb10-1, 13:53:37Z |
| f0d0d0a | gb10-2's embedding row `granite-embedding-english-r2-gb10` removed, its vision (0.40) and audio (0.20) at 16 sequences; the Framework's granite row at `--max-num-seqs 128 --max-num-batched-tokens 65536`, 0.03; a new row `gemma-4-12B-it-qat-w4a16-ct-vision-framework` (Google's 12B QAT w4a16, 9.56 GiB, 0.20, port 8000) as the vision failover, and the E4B audio row described as the audio failover; the BF16 26B-A4B row kept as the accuracy reference | capability-vllm H, I, N.1, K, N.2, G | gb10-2 16:10:42Z; the Framework 17:16:58Z |
| 8f981ee | gb10-2's audio row removed, its vision row unchanged at 16; the Framework's audio row at `--max-num-seqs 4`, standing, no longer a failover; the Framework's 12B and BF16 26B-A4B rows removed; the section comment states the standing layout and granite's comment the gateway's 34 requests a second | this task's cells: vllm-layout-g2-vision-capacity, -fw-pair-a4r34, -fw-stress-a8r34 (E, F) | gb10-2 20:28:55Z; the Framework 20:32:47Z; gb10-1 20:38:22Z |
| 90ef16f | comments only, every row's flags as at 8f981ee: the section comment says vision met its floor "at every pair but 8 + 8", and it and the audio row's comment are rewrapped at 100 columns | this task's E.3, E.6 | no host; the hosts run 8f981ee |

Behavior 7 set gb10-2's caps from the pair cells; no pair held both purposes (E.3, E.4), so no
pair cap was committed, and 8f981ee carries the caps the architect's later answers set instead:
vision 16 alone, audio 4 on the Framework. Each cap was read back from the row's start log: gb10-2
`max_num_seqs 16, 0.40` (20:28:58Z start), the Framework `max_num_seqs 4, 0.18` (20:32:48Z start),
and every row again after the reboot (I.3). gb10-1 moved to 8f981ee without a restart: the agent
row's block hashes the same at 3efb444 and 8f981ee, and the container's StartedAt and
RestartCount didn't change (`.state/vllm-layout/g1-swap.out`).

On gb10-2 the granite row's container was removed from the clone that still named it, before the
push: `VLLM_MODEL=granite-embedding-english-r2-gb10 host/engines vllm uninstall` on `main`
(16:10:42Z), then the audio row's the same way from f0d0d0a (20:28:55Z). On the Framework the
BF16 row's container left through `host/engines vllm uninstall` from f0d0d0a (G.4). The
Framework's `engines vllm update` for granite removed the `vllm/vllm-openai-rocm:v0.33.0-rocm72`
tag, since the suite removes every official image no container was created from; its layers stay
under the `-rocm72` audio image, and `docker pull` restores the tag (goal record).

## C. The agent's accuracy (Behavior 3)

### C.1 The tool

lm-evaluation-harness 0.4.13 is the task's one new tool, installed on the laptop by mise's pipx
backend through uv into the bench environment (`mise.bench.toml`: `"pipx:lm-eval" = { version =
"0.4.13", extras = ["api", "ruler"], uvx_args = "--with transformers --with pillow" }`). It runs
as `lm_eval run --model local-chat-completions` against a host's `/v1/chat/completions`, so vLLM
applies the model's own chat template and parsers as it does for any client. GPQA's dataset is
gated: the architect accepted its terms and ran `hf auth login` on the laptop
(`.state/vllm-layout/gpqa-access.txt`: HEAD 200 with the token, 401 without).

The tasks: `gpqa_diamond_cot_zeroshot` (198 questions, zero-shot, generative, the variant a chat
API can serve), scored by flexible-extract's exact match, with strict-match beside it (0.0 on
both rows: gpt-oss never writes "The answer is (X)"); and RULER's `niah_single_2` at 32,768 and
65,536 tokens, `--limit 50` each, one run a length, its haystacks sized by gpt-oss's own
tokenizer. Every run is greedy at `reasoning_effort=low`, `num_concurrent=16`, seeds
`0,1234,1234,1234`, `--log_samples`, so every question is kept; `max_gen_toks` 16,384 for GPQA and
4,096 for RULER. The prepared commands and the reason for each flag are in
`.state/vllm-layout/lm-eval-walk.md`.

### C.2 The walk

The architect's first run, 14:14:59Z, on the BF16 row: GPQA `--limit 10`. 10 of 10 answered;
flexible-extract 0.8, strict-match 0.0; 82 s; about 745 generated tokens a question; the readout 0
errors, 0 length finishes, 0 responses ≥400; the pool's lowest 19.39 GiB. The tool, its flags and
the per-question records worked before the full runs.

### C.3 The six runs

| Run | Row | Window (UTC) | Score | Readout | Pool lowest (floor 12.2) |
| --- | --- | --- | --- | --- | --- |
| bf16-gpqa | `gpt-oss-120b-agent`, BF16, 8 seqs | 14:18:36-14:43:20, about 24.8 min | 0.6667 (132/198) | 198 stop, 0 length, 0 error, 0 preemptions; about 817 generated tokens a question (c) | 19.46 GiB |
| bf16-niah-32768 | as above | 14:43:41-14:49:58 | 0.88 (44/50) | 50 stop; KV usage up to 16.2% | 19.42 GiB |
| bf16-niah-65536 | as above | 14:50:09-15:06:28 | 0.90 (45/50) | 50 stop | 19.38 GiB |
| fp8-gpqa | `gpt-oss-120b-agent-fp8`, FP8, 12 seqs | 15:16:00-15:37:40, about 21.7 min | 0.6212 (123/198) | 198 stop, 0 length, 0 error, 0 preemptions; about 840 a question (c) | 13.03 GiB |
| fp8-niah-32768 | as above | 15:37:52-15:44:08 | 0.80 (40/50) | 50 stop | 13.00 GiB |
| fp8-niah-65536 | as above | 15:44:19-16:01:09 | 0.92 (46/50) | 50 stop | 12.96 GiB |

Every run's `.exit` reads 0, under the 45 min cap; lm-eval logged no error and wrote no
placeholder answer; the server logged no ERROR, Harmony or parser line and no response ≥400.

### C.4 The paired test: FP8 becomes the agent row

The brief's rule: FP8 becomes the agent row unless its paired per-question loss against BF16 is
significant at 95% on any task. `paired.awk` pairs the runs on `doc_id`, checks each pair asked
the same prompt, and gives McNemar's exact two-sided p:

| Task | Pairs, prompt mismatches | BF16 | FP8 | b (BF16 right, FP8 wrong) | c (the reverse) | p | FP8's loss significant |
| --- | --- | --- | --- | --- | --- | --- | --- |
| GPQA diamond | 198, 0 | 0.6667 | 0.6212 | 24 | 15 | 0.1996 | no |
| RULER niah_single_2, 32,768 | 50, 0 | 0.88 | 0.80 | 5 | 1 | 0.2188 | no |
| RULER niah_single_2, 65,536 | 50, 0 | 0.90 | 0.92 | 2 | 3 | 1 | no |

No task's loss is significant, so FP8 is the agent row, and gb10-1 serves it alone. It already
did: the FP8 row's start (C.7) came before its runs, and the BF16 row was not restarted.

### C.5 What 198 questions can't rule out

The test can say FP8's loss is not significant; it can't say there is none. The 95% interval on
each paired difference, FP8 minus BF16, (c − b) / n ± 1.96 × √(b + c − (b − c)² / n) / n:

| Task | Difference (c) | 95% interval (c) |
| --- | --- | --- |
| GPQA diamond | −4.55 points | −10.69 to +1.60 points |
| RULER 32,768 | −8.00 points | −17.34 to +1.34 points |
| RULER 65,536 | +2.00 points | −6.75 to +10.75 points |

GPQA's 198 questions leave room for a loss of up to about 10 points, or none. The rejected
alternative, "within about 1%", is unresolvable at 198 questions (goal record, the plan's
decisions). FP8's KV cache still runs uncalibrated at scale 1.0, and
calibration was out of scope (N.1).

### C.6 RULER's misses are number formatting

RULER scores a sample 1 when the answer contains the number as written. Of BF16's 11 misses and
FP8's 14, all but one print the right number with digit grouping, such as "**9 174 960**" for
9174960 (BF16, 32,768, doc 1). The one retrieval miss is FP8's doc 33 at 32,768, "4 645 909" for
4644909, a wrong digit. The formatting misses fall on both rows alike (32,768: BF16 docs 1, 2,
19, 30, 34, 48; FP8 1, 2, 3, 19, 32, 34, 36, 46, 48 beside 33), so the paired test still compares
like with like, and both rows retrieve better than their scores read.

### C.7 The agent rows' starts on gb10-1

| Start | Command → "Application startup complete." | Weights | KV cache | Lowest MemAvailable during the start (floor 12.2) | Idle after warm-up, 30 s and a drop |
| --- | --- | --- | --- | --- | --- |
| BF16, `gpt-oss-120b-agent` (13:57:17Z, llama stopped, page cache dropped) | 526.0 s; a new compile (max-num-seqs is in the compile hash), 3.57 s | 66.14 GiB in 457.94 s | 25.32 GiB, 714,316 tokens, 5.45 × 131,072 | 19.97 GiB | 19.62 GiB |
| FP8, `gpt-oss-120b-agent-fp8` (15:06:47Z, from the BF16 row, page cache dropped) | 490.0 s; a new compile, 9.30 s | 66.14 GiB, loading 424.36 s | 30.73 GiB reserved, 1,733,910 tokens, 13.23 × 131,072 | **11.39 GiB** (15:14:40Z), under the floor for three samples during graph capture | 13.07 GiB |

BF16's cache came up at 714,316 tokens against agent-vllm's 846,411 on another start; FP8's at
1,733,910, as agent-vllm's ([agent-vllm](agent-vllm.md), I.2, L.1). The FP8 start's dip under the
floor came after the KV reservation, during graph capture, and was neither an idle read nor a
cell, so the stop rule didn't apply; it was recorded for the reboot, where the start loaded the
compile cache and stayed above the floor (I.3). Each row's probe, one low-effort chat, returned
"Hello! 😊" with its reasoning and 16 completion tokens; each start logged two "Auto-initialization
of reasoning token IDs failed" warnings and no ERROR.

## D. gb10-1's cells on the FP8 row (Behavior 5)

`vllm-layout-fp8-agent`, 16:01:55Z: S-agent's 4-turn sessions (8,192-token first turn, then 3 ×
512 in, 512 out a turn, no think time) at the target of 4 and the row's cap of 12, 110 s a level
(`bench/vllm-layout-agent.yaml`, a concurrent sweep, since two levels give no knee):

| Sessions | ok / err / inc | Output tok/s | TTFT median | ITL median (p95) | Latency median | Floor |
| --- | --- | --- | --- | --- | --- | --- |
| 4 (target) | 12 / 0 / 4 | 55.85 | 575 ms | 49.13 ms (54.90) | 26.40 s | meets |
| 12 (cap) | 12 / 0 / 12 | 55.85 | 15,913 ms | 99.07 ms (121.21) | 69.18 s | meets, by 0.93 ms (c) |

The row's readout: 0 ERROR, Harmony or parser lines, 0 responses ≥400, 0 preemptions; its 24
`length` finishes are GuideLLM's fixed 512-token turns. The pool sat at 12.96 GiB before, at its
lowest and after the drop, 0.76 GiB above the floor (c); the EngineCore held 102,173 MiB of GPU
memory and the container 4,288 MiB of RSS. At 12 sessions the TTFT of 15.9 s is the cost of the
cap: the 12th session's 8,192-token first turn waits behind 11 others' prefill.

## E. gb10-2: vision and audio (Behaviors 6, 7)

### E.1 Starts and the idle read

`docker stop llama`, a page-cache drop, then each row from f0d0d0a (`VLLM_MODEL=<row> host/engines
vllm update; docker start <container>`), then each restarted cold from a dropped cache with the
other serving. The compile cache was warm (438M, "Directly load AOT compilation"):

| Row | Cold start, command → startup complete | Weights | KV tokens (first / cold) | Lowest during the start |
| --- | --- | --- | --- | --- |
| vision, NVFP4 26B-A4B, 0.40 | 178.1 s | 18.13 GiB, read in 126.39 s | 163,373 / 162,699 (19.86 × 8,192) | 36.25 GiB |
| audio, E4B BF16, 0.20 | 159.1 s | 15.08 GiB, read in 99.15 s | 205,912 / 177,813 (21.71 × 8,192) | 30.22 GiB |

The probes answered as capability-vllm's did: the image ("a red circle on the left, a blue square
on the right, and the text "GB10 42" centered above them") and the clip, word for word. Idle,
after one warm-up a row, 30 s and a drop: **38.36 GiB**, 26.16 above the floor (c).

### E.2 Each alone at 4

| Cell (UTC) | Load | Result | Floor | Lowest pool |
| --- | --- | --- | --- | --- |
| vllm-layout-g2-vision-4 (16:25:32) | vision 4 streams, 90 s, audio idle | 76 / 0 / 4; TTFT 1,178 ms; ITL 35.40 ms; latency median 4.68 s, 76 of 76 ≤10 s | meets | 37.49 GiB |
| vllm-layout-g2-audio-4 (16:27:26) | audio 4 streams, 64 requests (17 s), vision idle | 64 / 0 / 0; ITL 44.28 ms; RTFx median 6.36 (min 3.77), 56 of 64 ≥5 | meets | 37.36 GiB |

### E.3 The pairs at 4 + 4 and 8 + 8, 240 s

| Cell (UTC) | Vision | Audio | Both hold | Lowest pool |
| --- | --- | --- | --- | --- |
| vllm-layout-g2-pair-4 (16:28:08) | 4: latency 9.88 s, 80 of 96 ≤10 s; ITL 78.83 ms: meets | 4: RTFx **3.19**, 12 of 470 ≥5; ITL 93.18 ms: misses | no | 37.33 GiB |
| vllm-layout-g2-pair-8 (16:32:37) | 8: 13.00 s, 0 of 144: misses | 8: RTFx 2.86, 20 of 848; ITL 103.99 ms: misses | no | 35.53 GiB |

Neither level held both purposes, so Behavior 7 had no level to cap the rows at, and the session
stopped for the architect (escalation 1). His answer added three uneven pairs and vision alone at
8 and 16, so that every arrangement that could hold was measured.

### E.4 The uneven pairs, 240 s

| Cell (UTC) | Vision | Audio | Both hold | Lowest pool |
| --- | --- | --- | --- | --- |
| vllm-layout-g2-pair-v4a2 (16:44:17) | 4: 9.90 s, 92 of 96: meets | 2: RTFx 3.31, 5 of 236; ITL 89.66 ms: misses | no | 35.54 GiB |
| vllm-layout-g2-pair-v2a2 (16:48:34) | 2: 7.91 s, 60 of 60: meets | 2: RTFx 3.36, 5 of 244; ITL 88.42 ms: misses | no | 35.56 GiB |
| vllm-layout-g2-pair-v2a4 (16:52:53) | 2: 7.88 s, 60 of 60: meets | 4: RTFx 3.24, 13 of 478; ITL 92.22 ms: misses | no | 35.55 GiB |

### E.5 Vision alone at 8 and 16

`vllm-layout-g2-vision-capacity` (16:57:20Z, `bench/vllm-layout-vision-capacity.yaml`), 90 s a
level, audio loaded and idle:

| Streams | ok / err / inc | Output tok/s | TTFT median | ITL median | Latency median (p90) | ≤10 s | Floor |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 8 | 112 / 0 / 8 | 124.44 | 1,900 ms | 42.61 ms | 6.11 s (6.18) | 112 of 112 | meets |
| 16 | 144 / 0 / 16 | 160.00 | 3,049 ms | 66.87 ms | 9.64 s (9.84) | 133 of 144 | meets |

16 is the row's max-num-seqs, so it is the highest level the row can take: gb10-2's vision-only
capacity is its row's 16, 4 times the target (c). 8f981ee keeps the cap at 16.

### E.6 What the cells show: audio can't share a GPU with vision

Across all five pairs, from 2 + 2 to 8 + 8, audio's RTFx median sat at 2.86 to 3.36 against its
floor of 5, and its ITL at 88 to 104 ms against 44 ms alone, while vision met its floor at every
pair but 8 + 8. Halving vision's streams (v2a4 against pair-4) moved audio from 3.19 to 3.24;
halving audio's own (v4a2) to 3.31. Audio's decode is held back by sharing the GPU with vision at
any vision load, not by how many audio streams run. Memory was never near the floor: the lowest
pool in any pair cell was 35.53 GiB, 23.33 above it (c). Without granite on the GPU, audio did
better than capability-vllm's three-row mixed cell (RTFx 2.15 at 4 / 4 / 16, another session, for
scale only), and still missed.

### E.7 Vision alone, delivered

After the architect's answer to escalation 2 (audio leaves gb10-2), `g2-swap.sh` (20:28:54Z):
the audio row's container removed through the suite, the clone onto 8f981ee, then vision
restarted from a dropped cache. **Startup complete 182.2 s**; KV 165,213 tokens (20.17 × 8,192),
against 162,699 beside audio; `max_num_seqs 16, 0.40` read back; ports 8001 and 8002 closed.
Idle: **65.72 GiB**, 53.52 above the floor (c), against 38.36 beside audio. The vision container
held 46,288 MiB of GPU memory.

## F. The Framework: audio and embedding (Behaviors 8, 9, as the escalations changed them)

### F.1 Starts and the idle read

`docker stop llama`, a drop, then each row from f0d0d0a, first and then cold:

| Row | Cold start, command → startup complete | Weights | KV | Lowest during the start |
| --- | --- | --- | --- | --- |
| granite, 0.03, 128 seqs, 65,536 batched | 20.9 s (the first, 28.0 s, compiled the new range (1, 65536) in 3.09 s) | 0.29 GiB | pooling, no KV pool | GTT 110.84, system 113.79 GiB |
| audio, E4B BF16, 0.18, 16 seqs (f0d0d0a) | 66.8 s | 15.22 GiB, read 2.94 s | 104,813 tokens (12.79 × 8,192), 3.86 GiB | GTT 90.60, system 87.96 GiB |

Probes: two embeddings of 768 dimensions; the clip transcribed word for word. Idle with both rows,
30 s and a drop: **GTT 90.47, system 88.53 GiB** (79.27 and 76.03 above the floors, c).

### F.2 The embedding sweep and its knee

`vllm-layout-fw-embed-sweep` (17:43:51Z, `bench/vllm-layout-embed-sweep.yaml`): granite alone,
audio loaded and idle, 512-token inputs, 30 s a level:

| Streams | ok / err / inc | req/s | Prompt tok/s | Latency median (p90) | × floor (c) |
| --- | --- | --- | --- | --- | --- |
| 1 | 2,882 / 0 / 0 | 96.03 | 49,265 | 0.01 s (0.01) | 11.5 |
| 4 | 5,309 / 0 / 2 | 176.90 | 90,750 | 0.02 s (0.02) | 21.1 |
| **16** | 5,759 / 0 / 7 | 191.67 | **98,325** | 0.08 s (0.08) | 22.9 |
| 32 | 5,791 / 0 / 11 | 192.33 | 98,667 (the peak) | 0.16 s (0.17) | 22.9 |
| 64 | 5,744 / 0 / 64 | 191.47 | 98,222 | 0.33 s (0.33) | 22.8 |
| 128 | 5,642 / 0 / 128 | 188.07 | 96,478 | 0.67 s (0.67) | 22.4 |

**The knee is 16 streams**: throughput rises ×1.84 from 1 to 4 and ×1.08 from 4 to 16 (c), then
stops rising (+0.3% to 32, c); from 32 each doubling of streams doubles latency, pure queueing,
and 128 falls 2.2% under the peak (c). Every level meets the floor 11 to 23 times over. The 128
sequences and 65,536 batched tokens hold the plateau to 128 streams with no error and no
preemption; against capability-vllm's V-embed at 16 sequences and 8,192 batched tokens (96,803
at 16, another session, for scale only) the wider batch adds little at 16 streams. The sweep's
lowest pools: GTT 89.47 GiB, system 87.13 GiB.

### F.3 The placement cell missed audio

Escalation 2's evidence cell, `vllm-layout-fw-pair-a4e16` (17:47:56Z), audio 4 and embedding 16
streams closed-loop, started together, 240 s:

| Purpose | Result | Floor |
| --- | --- | --- |
| audio 4 | 356 / 0 / 4; TTFT 447 ms; ITL 119.80 ms (p95 135.27); RTFx median **2.44**, min 1.21, 0 of 356 ≥5 | **misses** |
| embedding 16 | 33,592 / 0 / 10; 139.94 req/s; 71,790 prompt tok/s | meets (16.7 ×, c) |

Run flat out, granite took the GPU from audio; the session stopped for the architect (escalation
2, answer 5).

### F.4 Embedding at a steady rate

The architect's answer to escalation 3: audio alone, then beside embedding at a constant 8.4
requests a second (512 tokens each, about the floor's 4,300 tok/s) and at 34 (four times it),
240 s each, through GuideLLM's own constant profile
(`bench/vllm-layout-embed-rate-floor.yaml`, `-rate-4x.yaml`):

| Cell (UTC) | Audio 4 streams | Embedding | Lowest GTT / system |
| --- | --- | --- | --- |
| vllm-layout-fw-audio-4 (18:11:05), granite idle | 876 / 0 / 0; ITL 45.59 ms; RTFx **6.54**, min 3.68, 786 of 876 ≥5: meets; ran 220 s (its 876 rows ran out) | idle | 89.15 / 86.94 GiB |
| vllm-layout-fw-pair-a4r8 (18:15:09) | 876 / 0 / 0; ITL 46.79 ms; RTFx **6.43**, 762 of 876: meets; 225 s | 2,016 / 0 / 1; 8.400 req/s; **4,309 prompt tok/s**; latency 0.02 s: meets | 89.19 / 86.83 GiB |
| vllm-layout-fw-pair-a4r34 (18:19:42) | 855 / 0 / 4; ITL 50.77 ms; RTFx **5.84**, 667 of 855: meets; 240 s | 8,160 / 0 / 1; 34.000 req/s; **17,442 prompt tok/s**; latency 0.02 s: meets | 89.19 / 87.02 GiB |

Against audio alone, the floor's rate costs audio 0.11 of RTFx median and the 4x rate 0.70 (c),
with 5.18 ms more ITL (c). Embedding answers at 0.02 s at either rate. By the architect's answer
the layout is gb10-1 the agent, gb10-2 vision, the Framework audio and embedding, embedding
rate-limited by the gateway at the measured rate audio holds beside, 34 requests a second.

### F.5 The stress cell: audio's cap is 4

`vllm-layout-fw-stress-a8r34` (18:26:21Z): audio 8 streams beside embedding at 34 requests a
second.

| Purpose | Result | Floor |
| --- | --- | --- |
| audio 8 | 876 / 0 / 0; 5.984 req/s; TTFT 207 ms; ITL 60.54 ms (p95 63.59); RTFx median **4.94**, min 2.65, 406 of 876 ≥5; ran 146 s | **misses**, by 0.06 (c) |
| embedding 34 req/s | 8,160 / 0 / 1; 17,442 prompt tok/s; latency 0.02 s | meets |

Audio missed at 8, so its cap is 4, the brief's rule (8f981ee). At 8 streams the audio file's 876
rows ran out at 146 s, so audio ran 146 s beside embedding and embedding its last 94 s alone; the
miss covers all of audio's run beside it. The lowest pools: GTT 89.23, system 87.08 GiB.

### F.6 The delivered rows

`fw-swap.sh` (20:32:47Z): the clone onto 8f981ee, then `VLLM_MODEL=gemma-4-E4B-it-audio-framework
host/engines vllm update`, which restarted the audio row at 4 sequences: **startup complete
144.9 s**, a new compile for 4 sequences (the compile cache 1006M → 1.2G; the 16-sequence
restarts took 67 s); `max_num_seqs 4, 0.18` read back; KV 106,065 tokens (12.95 × 8,192); port
8000 closed. Idle: **GTT 89.50, system 88.02 GiB**, 78.30 and 75.52 above the floors (c). The two
rows take 0.21 of the 112 GiB GTT ceiling (c), against capability-vllm's three rows' 0.81, which
left the system pool 0.76 GiB above its floor; this layout's lowest system read in any cell of its
standing rows was 86.83 GiB (K).

## G. Vision accuracy: NVFP4 against BF16 (Behavior 4)

### G.1 The runs

lm-eval's `mmmu_val` (900 questions over 30 subjects, `max_images=7`, chat template applied,
greedy, seeds `0,1234,1234,1234`, `num_concurrent=16`, `timeout=1800`, `max_retries=1`), on
gb10-2's NVFP4 26B-A4B and on Google's BF16 26B-A4B served on the Framework as the reference, the
same flags but the endpoint and the model. The 12B QAT w4a16's run was dropped with the
Framework's vision row (escalation 2, answer 1).

| Run | Host, row | max_gen_toks | Questions | Requests took | Watch window (UTC) | Cut at the limit | acc | Pool lowest |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| nvfp4-mmmu-smoke | gb10-2, NVFP4, 16 seqs | 512 | 300 (10 a subject) | 5:04 | 17:01:08-17:11:48 (the dataset downloaded first) | 81 of 300 | 0.5433 | 34.16 GiB |
| nvfp4-mmmu-smoke-1024 | as above | 1024 | 300 | 5:48 | 17:12:38-17:20:06 | 31 of 300 | 0.6267 | 34.21 GiB |
| **nvfp4-mmmu** | as above | 1024 | 900 | 18:47 | 17:20:35-17:43:30 | 88 of 900 | **0.6111** (550/900), stderr 0.0155 | 31.89 GiB |
| bf16-mmmu-cap45 | the Framework, BF16 26B-A4B, 0.60, beside granite | 1024 | 869 of 900 when cut | 42:46 | 18:33:02-19:18:02, exit 124 | – | none written | GTT 40.94, system 35.13 GiB |
| **bf16-mmmu** | as above, `timeout 60m` | 1024 | 900 | 46:24 | 19:35:25-20:26:34, exit 0 | 107 of 900 (the server's count) | **0.6178** (556/900), stderr 0.0155 | GTT 40.45, system 35.24 GiB |

**Why max_gen_toks 1024.** The task's default of 512 cut 81 of 300 answers in the first smoke run:
asked to answer with the option's letter, Gemma 4 wrote a worked solution on 139 of 300 and ended
it with the letter, and a cut answer has no letter, so MMMU's parser picks one at random (seeded),
noise in a paired test. 1024 cut 31 of 300, and the 900 ran in 18:47, well inside the cap; a
higher limit would cut fewer at a longer run, and wasn't tried. The BF16 reference ran at 1024 too,
so the pairs compare.

**The 45-minute miss and the 60-minute rerun.** The BF16 row on the Framework answered more
slowly than NVFP4 on gb10-2 at the same concurrency (164 requests at 3:58, then the long-answer
subjects: 869 at 42:46), and `timeout 45m` killed the run at 869 of 900. lm-eval writes its
samples and results only at the end, so nothing was kept (escalation 4). The architect's answer:
one rerun, settings identical but a 60-minute cap. It finished 900 in 46:24. The results JSON's
configuration matches NVFP4's but for the model and the endpoint.

### G.2 The paired test

| Pairs, prompt mismatches | BF16 (reference) | NVFP4 | b (BF16 right, NVFP4 wrong) | c | p | NVFP4's loss significant |
| --- | --- | --- | --- | --- | --- | --- |
| 900, 0 | 0.6178 | 0.6111 | 78 | 72 | 0.6832 | no |

The difference is −0.67 points (c), and its 95% interval −3.33 to +2.00 points (c), by C.5's
formula. Every prompt matched, its images included, so both rows answered the same questions.
**NVIDIA's NVFP4 checkpoint shows no significant loss against Google's BF16**, which settles
capability-vllm's open warning (its L.3, N.3) as far as 900 questions can.

### G.3 Limits

- **CUDA against ROCm.** The reference ran on the Framework's ROCm image and NVFP4 on gb10-2's
  CUDA image; BF16 can't be served on gb10-2 beside its rows at a comparable fraction, and the
  plan rejected staging it there. A difference between the two stacks' kernels sits inside the
  paired difference, unseparated.
- **The cut answers**: 88 of NVFP4's and 107 of BF16's answers reached the 1024-token limit and
  were scored by MMMU's seeded random pick.
- The 12B QAT w4a16, the lighter Gemma 4 vision model the plan chose for the Framework, was never
  measured: its row was removed and its weights never downloaded (B, 8f981ee).

### G.4 The BF16 weights removed

`fw-bf16-remove.sh` (20:26:57Z): `docker stop vllm-vision`;
`VLLM_MODEL=gemma-4-26B-A4B-it-vision-framework host/engines vllm uninstall` ("removed container
vllm-vision; the vLLM images and the compile cache stay"); `hf cache rm --dry-run
model/google/gemma-4-26B-A4B-it`, then `--yes`: "Deleted 1 repo(s) and 1 revision(s); freed
51.6G". The audio row restarted after (66.8 s), idle GTT 89.47, system 88.07 GiB.

## H. llama.cpp leaves the workstations (Behavior 10)

`llama-remove.sh` on each host, from its clone at 8f981ee: `host/engines llama uninstall`, which
removed the `llama` container and every llama.cpp image; the store's repositories classified by
file (a GGUF repository holds `.gguf` files and no `.safetensors`); then `hf cache rm --dry-run`
and `--yes` on the four GGUF repositories, the same on every host:
`model/ggml-org/gemma-4-E4B-it-GGUF`, `model/ggml-org/gpt-oss-120b-GGUF`,
`model/google/gemma-4-26B-A4B-it-qat-q4_0-gguf`, `model/mrutkows/granite-embedding-english-r2-GGUF`
(87.9G each time, hf's decimal figure).

| Host (UTC) | Images removed | Store, `du -sb`, before → after | Freed (c) | Kept |
| --- | --- | --- | --- | --- |
| gb10-1 (20:38:52) | `server-cuda13-b12098` (7.02 GB) | 153,189,472,797 → 65,276,934,508 | 81.87 GiB | `openai/gpt-oss-120b` |
| gb10-2 (20:39:05) | `server-cuda13-b12098` | 123,064,699,795 → 35,152,161,318 | 81.87 GiB | the NVFP4 26B-A4B; E4B and granite, then removed (below) |
| framework (20:39:17) | `server-rocm-b12098` (30.7 GB), `server-vulkan-b12098` (1.21 GB) | 104,239,012,825 → 16,326,477,663 | 81.87 GiB | E4B, granite |

After, on each host: no llama container, no llama.cpp image, no `.gguf` file, and every standing
row's `/health` 200. No llama or vllm systemd unit exists on any host. spike-model-engines keeps
every llama.cpp feature; `engines llama install` and a download bring it back.

gb10-2 still held the E4B and granite safetensors, which no gb10-2 row serves. The architect had
them removed (21:20:05Z, `g2-store-rm.sh`): `hf cache rm --yes model/google/gemma-4-E4B-it
model/ibm-granite/granite-embedding-english-r2`, "freed 16.3G", `du -sb` 35,152,161,318 →
18,825,683,848, 15.21 GiB (c). gb10-2's store holds the NVFP4 26B-A4B alone.

**The Framework's disk didn't move.** `df /` read 388,335,898,624 bytes used before the removal
and 388,336,754,688 after. Its root is btrfs with snapper's root configuration (NUMBER_LIMIT 5),
so earlier snapshots likely still hold the blocks until they rotate out; reading them needs root.
The architect left the snapshots as they are (intake note, N).

## I. Root steps and reboots (Behavior 11)

### I.1 The sysctl was already set

The before-state read (`before-reboot.sh`, 20:40Z) found the brief's premise didn't hold: gb10-1
and the Framework already set `net.ipv4.ip_nonlocal_bind = 1` persistently, as gb10-2 does.

| Host | Live value | File | Written |
| --- | --- | --- | --- |
| gb10-1 | 1 | `/etc/sysctl.d/90-nonlocal-bind.conf` | Oct 30 |
| gb10-2 | 1 | `/etc/sysctl.d/90-nonlocal-bind.conf` | Oct 30 |
| framework | 1 | `/etc/sysctl.d/60-tailnet-bind.conf` | Nov 2 |

So Behavior 11's sysctl step changed nothing, and the Framework's file keeps its name (the
architect). Every standing container is `--restart unless-stopped` and publishes its port on the
host's Tailscale address; `docker.service` is ordered after `network-online.target`, not after
`tailscaled`, so the nonlocal bind is what lets Docker publish before Tailscale has the address.

### I.2 The Framework's gttsize option removed

Before: `/etc/modprobe.d/amdgpu.conf` held `options amdgpu gttsize=114688` and `ttm.conf`
`options ttm pages_limit=29360128`; the GPU reported GTT 120,259,084,288 bytes; the boot log read
`amdgpu 0000:c3:00.0: [drm] Configuring gttsize via module parameter is deprecated, please use
ttm.pages_limit`. The architect's root step, as prepared in
`.state/vllm-layout/root-steps-slice3.md` (spike-model-engines' setup guide's rebuild; his own
shell, so no step log holds it):

```sh
sudo rm /etc/modprobe.d/amdgpu.conf
sudo limine-mkinitcpio
```

After the reboot: `/etc/modprobe.d/` holds `hid_apple.conf`, `omarchy-usb-autosuspend.conf` and
`ttm.conf`, no `amdgpu.conf`; `pages_limit` 29360128; `mem_info_gtt_total` **120,259,084,288
bytes**, unchanged; `journalctl -k -b | grep -i gttsize` prints nothing (exit 1), and the kernel
logs `114688M of GTT memory ready.`. The GTT ceiling stays 112 GiB through `ttm.pages_limit`
alone. Back out: `echo 'options amdgpu gttsize=114688' | sudo tee /etc/modprobe.d/amdgpu.conf &&
sudo limine-mkinitcpio`, then a reboot.

### I.3 The reboots

The session started a timer on the laptop (`reboot-timing.sh <host> <port>...`: a pass every 2 s,
`tailscale ping` and each port's `/health`, into `.state/vllm-layout/reboot-<host>.txt`), then the
architect ran `sudo reboot` on the host; one host at a time, gb10-2, the Framework, gb10-1.

| Host | Down (timer) | Up, first pong (from down) | Every row's /health 200 (from down) | Container start → /health (c) | Reboot sent → serving (c) |
| --- | --- | --- | --- | --- | --- |
| gb10-2 | 21:12:56.5Z | 21:13:25.1Z (28.5 s) | 8000 at 21:16:31.2Z (214.7 s) | 193.2 s from StartedAt 21:13:18.0Z | 3 min 49 s, from 21:12:42Z |
| framework | 21:15:55.1Z | 21:16:37.2Z (42.1 s), after the LUKS passphrase | 8002 at 21:16:47.2Z (52.1 s); 8001 at 21:17:33.2Z (98.1 s) | granite 22.8 s, audio 68.7 s, from StartedAt 21:16:24.4Z | about 98 s from down; the send came before the timer's first pass |
| gb10-1 | 21:17:54.1Z | 21:18:33.1Z (39.1 s) | 8000 at 21:26:49.2Z (535.1 s) | 502.5 s from StartedAt 21:18:26.8Z | 8 min 58 s, from 21:17:51Z |

gb10-2's first timer gave up after its 20-minute cap before the reboot was sent; the second
started after the send, with the host already gone, so its "down" is the timer's first pass. The
send times, 21:12:42Z and 21:17:51Z, are the session's record of the architect's commands
(`slice3-notes.md`), not a timer's.

After each reboot (`after-reboot.sh`, 21:19:14Z on gb10-2 and the Framework, 21:26:58Z on
gb10-1):

| Host | Booted | nonlocal_bind | Rows (RestartCount) | max_num_seqs (start log) | KV (start log) | Start log ERROR / Traceback | Idle after 30 s and a drop |
| --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-2 | 21:13:06Z | 1 | `vllm-vision` (0) | 16 | 26.0 GiB, 162,963 tokens | 0 / 0 | 66.73 GiB |
| framework | 21:15:59Z | 1 | `vllm-audio` (0), `vllm-embed` (0) | 4; 128 | audio 3.91 GiB, 106,052 tokens | 0 / 0 each | GTT 90.78, system 89.44 GiB |
| gb10-1 | 21:18:15Z | 1 | `vllm` (0) | 12 | 1,733,910 tokens, 13.23 × 131,072 | 0 / 0 | 15.07 GiB |

Each host's only containers are its standing rows. gb10-2's vision weights loaded in 127.9 s from
a cold page cache; gb10-1's in 436.52 s (`Model loading took 66.14 GiB memory and 454.13
seconds`), then `Directly load AOT compilation`, torch.compile 0.18 s and graph capture 5 s.
**gb10-1's start stayed above its floor**: sampled every 3 s from the laptop
(`gb10-1-reboot-start.mem.tsv`), its lowest MemAvailable was 14.94 GiB at the `/health` 200 sample,
against 11.39 GiB during slice 1's compiling start (C.7). The compile cache slice 1 wrote removed
the compile's transient peak. gb10-1's idle read, 15.07 GiB, is 2.00 GiB above slice 1's 13.07
after its own start (c), with the EngineCore at 101,207 MiB against 102,069.

### I.4 The Framework needs a person at its console

The Framework's root is LUKS-encrypted. Its reboot waited at the disk-unlock prompt until the
architect entered the passphrase at its console, so its timeline includes the passphrase, and it
**neither returns unattended nor can be rebooted remotely**, as the GB10s can. Behavior 11's
"returns to its layout unattended" holds for the GB10s only. Unlocking without a person (TPM2
enrollment, a keyfile) or remotely (SSH in the initramfs) is a security decision outside the task;
it goes to the intake as a note (N). The architect weighed headless Ubuntu Server for the
Framework against Omarchy and kept Omarchy; the unlock question stands on either OS (goal record).

## J. The standing-layout cell (Behavior 12)

`vllm-layout-standing` (21:27:42Z, `standing-cell.sh`): four GuideLLM processes started together
from the laptop, each with the helpers sourced for its host and port and under `watch` with its
host's floors, 240 s:

- agent: `GUIDELLM__SPEC__PROFILE__STREAMS=4 cell vllm-layout-standing-agent role-split-mixed-agent
  openai/gpt-oss-120b openai/gpt-oss-120b`, gb10-1 8000 (S-agent's sessions at one level);
- vision: `GUIDELLM__SPEC__PROFILE__STREAMS=4 cell vllm-layout-standing-vision
  role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it`, gb10-2 8000;
- audio: `GUIDELLM__SPEC__PROFILE__STREAMS=4 cell vllm-layout-standing-audio role-split-mixed-audio
  google/gemma-4-E4B-it google/gemma-4-E4B-it`, the Framework 8001;
- embedding: `cell vllm-layout-standing-embed vllm-layout-embed-rate-4x
  ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2`, the
  Framework 8002.

**Embedding ran at the gateway's rate, 34 requests a second, not 16 closed-loop streams.** The
brief's "embedding 16" predates the decision to rate-limit embedding at the gateway; the admitted
rate is the load the Framework stands under, so the cell runs the layout's standing condition.

| Purpose (host) | ok / err / inc | Figures | Floor | Verdict |
| --- | --- | --- | --- | --- |
| agent 4 (gb10-1) | 32 / 0 / 4 | 68.27 output tok/s; TTFT 554 ms; **ITL median 48.13 ms** (p95 54.25) | ≤100 ms | **meets** |
| vision 4 (gb10-2) | 212 / 0 / 4 | TTFT 1,161 ms; ITL 33.74 ms; **latency median 4.49 s** (p90 4.53), 212 of 212 ≤10 s | ≤10 s | **meets** |
| audio 4 (the Framework) | 835 / 0 / 3 | TTFT 175 ms; ITL 51.08 ms; **RTFx median 5.78**, min 2.39, 631 of 835 ≥5 | ≥5 | **meets** |
| embedding 34 req/s (the Framework) | 8,161 / 0 / 0 | 34.000 req/s; **17,442 prompt tok/s**; latency 0.02 s | ≥4,300 | **meets** |

Against the same session's cells on each host alone (before the reboots, on the same v0.33.0
rows): the agent's ITL 48.13 ms against 49.13 at 4 (D); vision 4.49 s against 4.68 (E.2); audio
5.78 against 5.84 beside embedding at the same rate (F.4); embedding 17,442 as there. Each
purpose ran within a few percent of its host-alone figure.

Memory: lowest during the cell gb10-1 14.87 GiB, gb10-2 65.21 GiB, the Framework GTT 90.24 and
system 87.27 GiB; after a drop gb10-1 14.88, gb10-2 65.25, the Framework GTT 90.49 and system 88.16
GiB (GTT used 21.51 of 112.00 GiB). No floor was approached and no cell stopped. Readouts: 0
errors, 0 preemptions, 0 ERROR lines, 0 parser or Harmony lines and 0 responses ≥400 on every row;
GuideLLM errored none. The saved warning lines: gb10-2 one Triton JIT compile on the first
requests after the reboot; `vllm-audio` the torchcodec fallback line once a request (L).

## K. Memory through the session (Behavior 13)

Every cell's `.exit` reads 0 but `vllm-layout-bf16-mmmu-cap45`'s 124 (its `timeout`); no cell
stopped under a floor.

| Host, configuration | Idle | Lowest in a cell | Above the floor at the lowest (c) |
| --- | --- | --- | --- |
| gb10-1, BF16 agent row (slice 1) | 19.62 GiB | 19.38 GiB (bf16-niah-65536) | 7.18 GiB |
| gb10-1, FP8 agent row (slice 1) | 13.07 GiB | 12.96 GiB (fp8-niah-65536, fp8-agent) | 0.76 GiB |
| gb10-1, FP8 agent row after the reboot | 15.07 GiB | 14.87 GiB (standing) | 2.67 GiB |
| gb10-2, vision and audio (f0d0d0a) | 38.36 GiB | 31.89 GiB (nvfp4-mmmu); 35.43 in a load cell | 19.69 GiB |
| gb10-2, vision alone (8f981ee) | 65.72; 66.73 after the reboot | 65.21 GiB (standing) | 53.01 GiB |
| framework, granite and audio at 16 (f0d0d0a) | GTT 90.47, system 88.53 GiB | GTT 89.15 (fw-audio-4), system 86.83 GiB (fw-pair-a4r8) | GTT 77.95, system 74.33 GiB |
| framework, granite and BF16 26B-A4B (reference only) | GTT 41.95, system 40.72 GiB | GTT 40.45, system 35.13 GiB (bf16-mmmu runs) | GTT 29.25, system 22.63 GiB |
| framework, granite and audio at 4 (8f981ee) | GTT 89.50, system 88.02; after the reboot 90.78, 89.44 GiB | GTT 90.24, system 87.27 GiB (standing) | GTT 79.04, system 74.77 GiB |

The tightest standing margin is gb10-1's: 0.76 GiB above its floor under slice 1's cells, 2.67
after the reboot. During a start that compiles afresh the FP8 row went 0.81 GiB under it (C.7).

## L. Errors and readouts

Every cell and accuracy run: 0 errored requests in GuideLLM and lm-eval, 0 responses ≥400, 0
preemptions, 0 ERROR or Traceback lines in any row's log. The warnings: the agent rows' two
reasoning-token warnings at each start; two FlashInfer AutoTuner fallbacks on gb10-2's vision row
in pair-8; one Triton JIT compile on gb10-2 after the reboot; and on the Framework's audio row one
`torchcodec unavailable ... falling back to soundfile/PyAV` line a request, as capability-vllm
found, since the audio image keeps that fallback (decision; torchcodec goes to the intake). Every
request on the audio row answered.

## M. How the layout moved during BUILD

| Step | Measured | The architect's answer (goal record) |
| --- | --- | --- |
| The plan | – | gb10-1 the agent; gb10-2 vision and audio; the Framework granite, with the 12B vision row and the E4B audio row staged, stopped, as a manual failover |
| Escalation 1 | gb10-2's pairs missed audio at 4 + 4 and 8 + 8 (E.3) | uneven pairs; vision alone at 8 and 16; one Framework cell, audio beside granite; mmmu_val on NVFP4 now |
| Escalation 2 | every uneven pair missed audio; vision held 16 alone (E.4, E.5) | if audio holds beside granite, the layout is gb10-1 agent, gb10-2 vision, the Framework audio and embedding; the 12B row, its sweep and mmmu, the failover cell and the Framework's vision dropped; gb10-2's vision cap 16 |
| Escalation 3 | audio missed beside granite run flat out (F.3) | audio alone, then beside embedding at 8.4 and 34 requests a second; if it holds, embedding is rate-limited by the gateway and a stress cell sets audio's cap. The absolute fallback, gb10-2 vision with embedding and the Framework audio alone, only if no tuning lets the two share the Framework |
| The answer | audio held at both rates (F.4), missed at 8 (F.5) | the layout as it stands; audio's cap 4; no failover |
| Escalation 4 | the BF16 reference hit its 45-minute cap (G.1) | one rerun at 60 minutes |

The brief's Behavior 9 (the Framework's vision sweeps and failover cell) and the walkthrough's
failover step went with the Framework's vision row.

## N. Open items and intake notes

None of these is decided here.

- **N.1 FP8's KV scale.** The agent row runs FP8 KV at scale 1.0, uncalibrated; the paired test
  found no significant loss, and can't exclude one of up to about 10 points on GPQA (C.5).
  Calibration, or a larger set, would narrow it.
- **N.2 Audio's headroom is zero.** Audio holds exactly its target of 4 beside embedding at 34
  requests a second, and missed at 8 by 0.06 (F.5). A fifth stream goes to the gateway's queue or
  overflow. Lowering embedding's rate toward the floor's 8.4 gave audio 6.43 at 4 (F.4); 8 streams
  at that rate is untested.
- **N.3 The Framework's reboot needs its console** (I.4): the unlock method is a security decision
  for the architect, on either OS.
- **N.4 The FP8 row's compiling start dips under gb10-1's floor** (C.7: 11.39 GiB). A start with
  the compile cache warm stayed above it (I.3); a new compile, after a vLLM upgrade or a flag that
  enters the compile hash, would dip again.
- **N.5 The Framework's disk** keeps the removed GGUFs' blocks in btrfs snapshots until they
  rotate (H).
- **N.6 vLLM v0.34.0** (A.2): its GB10 weight-loading fix bears on gb10-1's 437-second and gb10-2's
  128-second weight reads after a reboot (I.3).
- **N.7 The 12B QAT w4a16** was chosen and never measured (G.3); a Framework vision row returns
  only with a layout that gives it a GPU.
- **N.8 The walkthrough was waived.** The brief's slice 5 started the Framework's 12B row, which
  8f981ee removed. The architect agreed a replacement step (audio 4 beside embedding at 34
  requests a second), then waived the walkthrough, that step with it (goal record).
- **N.9 The pull request merges when the task ships**: until then all three clones serve from a
  local `hosts` branch at 8f981ee, and Behavior 16's state, serving from the merged `main`, follows
  the merge.
- **Intake notes**, carried in the goal record's pending edits: v0.34 (A.2); torchcodec in the
  audio image (L); the Framework's LUKS unlock (I.4); its btrfs snapshots (H); its OS and GTT
  configuration (I.2: GTT already 112 GiB through `ttm.pages_limit`, the gttsize option removed, a
  512 MiB carve-out, Omarchy kept).

## O. Every run

| Run | Host | Tool and configuration | Load | Duration | Path | Decision it informs |
| --- | --- | --- | --- | --- | --- | --- |
| Stack read | all three | SSH read-only; `apt-get -s upgrade` on the GB10s | none | one read | direct, 1-2 ms | Behavior 1's record (Stack) |
| Clones to main | all three | `git fetch`, `git merge --ff-only origin/main` | none | one step | direct, 2 ms | A.3 |
| Push, 3efb444 | gb10-1 | `git push gb10-1:repos/spike-model-engines vllm-layout:hosts-next`; `git checkout -B hosts hosts-next` | none | one step | direct, 2 ms | the agent caps on gb10-1 (B) |
| BF16 start | gb10-1 | `docker stop llama`, drop, `VLLM_MODEL=gpt-oss-120b-agent host/engines vllm update`, timed; probe; idle read | 1 + 1 requests | 526.0 s | direct, 2 ms | the BF16 runs' row (C.7) |
| The walk | gb10-1 | lm-eval 0.4.13, GPQA `--limit 10`, BF16 (the architect's) | 10 questions, 16 concurrent | 82 s | direct, 1 ms | that the tool works (C.2) |
| bf16-gpqa | gb10-1 | lm-eval, `gpqa_diamond_cot_zeroshot`, BF16 | 198 questions, 16 concurrent | 24.8 min | direct, 1 ms | GPQA's BF16 side (C.3, C.4) |
| bf16-niah-32768, -65536 | gb10-1 | lm-eval, `niah_single_2`, BF16, `--limit 50` | 50 samples each | 6.3 min; 16.3 min | direct, 1-2 ms | RULER's BF16 side |
| FP8 start | gb10-1 | drop, `VLLM_MODEL=gpt-oss-120b-agent-fp8 host/engines vllm update`, timed; probe; idle read | 1 + 1 | 490.0 s | direct, 1 ms | FP8's sizing, start and pool (C.7) |
| fp8-gpqa | gb10-1 | as bf16-gpqa, FP8 | as above | 21.7 min | direct, 1 ms | GPQA's FP8 side |
| fp8-niah-32768, -65536 | gb10-1 | as above, FP8 | as above | 6.3 min; 16.8 min | direct, 1 ms | RULER's FP8 side |
| Paired test | laptop | `paired.awk` over the samples | none | – | – | FP8 becomes the agent row (C.4) |
| vllm-layout-fp8-agent | gb10-1 | GuideLLM 0.8.1, `cell`, `bench/vllm-layout-agent.yaml` | S-agent sessions at 4 and 12 | 110 s a level | direct, 2 ms | the FP8 row at its target and cap (D) |
| Push, f0d0d0a; granite row removed | gb10-2 | `VLLM_MODEL=granite-embedding-english-r2-gb10 host/engines vllm uninstall` on `main`; push; `checkout -B hosts` | none | one step | direct, 2 ms | gb10-2 without granite (B) |
| Starts | gb10-2 | `docker stop llama`; first and cold starts of vision and audio, timed | none | 178.1 s; 159.1 s cold | direct, 0-2 ms | E.1 |
| Probes, idle | gb10-2 | curl: models, an image, a clip; warm-up; 30 s; drop; read | 2 + 2 | about 40 s | direct, 1 ms | E.1 |
| g2-vision-4, g2-audio-4 | gb10-2 | `cell`, `bench/vllm-layout-vision-alone.yaml`, `-audio-alone.yaml` | 4 streams | 90 s; 17 s (64 requests) | direct, 1 ms | each alone at the target (E.2) |
| g2-pair-4, g2-pair-8 | gb10-2 | `cell` × 2 at once, `role-split-mixed-vision.yaml` and `-audio.yaml` | 4 + 4; 8 + 8 | 240 s each | direct, 1-2 ms | Behavior 7's caps; escalation 1 (E.3) |
| g2-pair-v4a2, v2a2, v2a4 | gb10-2 | as above | 4 + 2; 2 + 2; 2 + 4 | 240 s each | direct, 1 ms | escalation 2 (E.4) |
| g2-vision-capacity | gb10-2 | `cell`, `bench/vllm-layout-vision-capacity.yaml` | 8, 16 | 90 s a level | direct, 1 ms | vision's cap of 16 (E.5) |
| nvfp4-mmmu-smoke, -smoke-1024 | gb10-2 | lm-eval `mmmu_val --limit 10`, max_gen_toks 512, 1024 | 300 questions | 10.7 min; 7.5 min | direct, 2 ms | max_gen_toks 1024 (G.1) |
| nvfp4-mmmu | gb10-2 | lm-eval `mmmu_val`, 1024 | 900, 16 concurrent | 23 min | direct, 2 ms | NVFP4's side (G) |
| Stack read, push, f0d0d0a | framework | SSH read-only; push; `checkout -B hosts` | none | one step | direct, 0-1 ms | B |
| Starts | framework | `docker stop llama`; first and cold starts of granite and audio, timed | none | 20.9 s; 66.8 s cold | direct, 1-2 ms | F.1 |
| Probes, idle | framework | curl: models, two embeddings, a clip; warm-up; 30 s; drop; read | 3 + 2 | about 40 s each | direct, 1 ms | F.1 |
| fw-embed-sweep | framework | `cell`, `bench/vllm-layout-embed-sweep.yaml` | 1 to 128 streams, 512 tokens | 30 s a level, 3.5 min | direct, 1 ms | granite's row and knee (F.2) |
| fw-pair-a4e16 | framework | `cell` × 2, `role-split-mixed-audio.yaml`, `-embed.yaml` | audio 4 + embedding 16 | 240 s | direct, 1 ms | escalation 2's evidence (F.3) |
| fw-audio-4 | framework | `cell`, `role-split-mixed-audio.yaml` | audio 4 | 220 s | direct, 1 ms | audio alone (F.4) |
| fw-pair-a4r8, -a4r34 | framework | `cell` × 2, audio and `bench/vllm-layout-embed-rate-floor.yaml`, `-4x.yaml` | audio 4 + 8.4 req/s; + 34 req/s | 240 s each | direct, 0-1 ms | the gateway's rate (F.4) |
| fw-stress-a8r34 | framework | as above | audio 8 + 34 req/s | 240 s (audio 146 s) | direct, 1 ms | audio's cap of 4 (F.5) |
| BF16 start | framework | `docker stop vllm-audio`, drop, `VLLM_MODEL=gemma-4-26B-A4B-it-vision-framework host/engines vllm update; docker start vllm-vision`, timed; probe; idle | 1 | 67.0 s | direct, 1 ms | the reference's row (G) |
| bf16-mmmu-cap45 | framework | lm-eval `mmmu_val`, `timeout 45m` | 900, 16 concurrent | 45 min, exit 124 | direct, 1 ms | none: no result (escalation 4) |
| Restore | framework | `docker stop vllm-vision`, drop, `docker start vllm-audio`, timed; idle | 1 | 67.1 s | direct, 0 s | the standing rows back |
| BF16 start, again | framework | as before | 1 | 73.2 s | direct, 1 ms | the rerun's row |
| bf16-mmmu | framework | lm-eval `mmmu_val`, `timeout 60m` | 900, 16 concurrent | 46:24 of requests, 51 min watched | direct, 1 ms | the BF16 side (G) |
| Paired test | laptop | `paired.awk` | none | – | – | NVFP4's warning settled (G.2) |
| BF16 removal | framework | `engines vllm uninstall`; `hf cache rm --dry-run`, `--yes`; audio restart | none | about 2 min | direct, 1 ms | G.4 |
| Delivery, 8f981ee | gb10-2 | audio row uninstalled; push; `checkout -B hosts`; vision restarted, timed; idle | 1 | 182.2 s | direct, 1 ms | vision alone (E.7) |
| Delivery, 8f981ee | framework | push; `checkout -B hosts`; `engines vllm update` of the audio row, timed; idle | 1 | 144.9 s | direct, 1 ms | audio at 4 (F.6) |
| Delivery, 8f981ee | gb10-1 | push; `checkout -B hosts`; no restart | none | one step | direct, 7 ms | B |
| llama.cpp removal | each host | `host/engines llama uninstall`; `hf cache rm --dry-run`, `--yes` of the four GGUF repositories | none | one step each | direct, 1-2 ms | H |
| Before-state | each host | SSH read-only: restart policies, sysctl, modprobe.d, the boot log | none | one read | direct, 1 ms | I.1, I.2 |
| Root step and reboots | each host | the architect: the gttsize removal and `limine-mkinitcpio` on the Framework; `sudo reboot` on each; the laptop's `reboot-timing.sh` | none | 214.7, 98.1, 535.1 s from down | – | I.3 |
| After-reboot reads | each host | `after-reboot.sh`: boot, sysctl, containers, start logs, GTT, the boot log; 30 s; drop; read | none | one read | direct, 0-2 ms | I.3 |
| gb10-1's start sampled | gb10-1 | `ssh` MemAvailable and `curl /health` every 3 s from the laptop | none | 21:19:00-21:26:49Z | – | I.3 |
| gb10-2's store | gb10-2 | `hf cache rm --dry-run`, then `--yes`, of E4B and granite | none | one step | direct, 1 ms | H |
| vllm-layout-standing | all three at once | `cell` × 4, `standing-cell.sh` | agent 4; vision 4; audio 4; embedding 34 req/s | 240 s | direct, 1-2 ms | the standing layout (J) |

Every cell ran under `watch`, memory sampled every 10 s, capped at 10 min (the accuracy runs at
45 min, the BF16 rerun at 60): floor 12.2 GiB on the GB10s, 11.2 GiB GTT and 12.5 GiB system
memory on the Framework, set by `step.sh` for each host.

### Commands as run (gb10-1)

From `.state/measure/gb10-1/2026-11-12.log`, every command at the step level, in log order, from
the stack read at 08:52:37: the `source .state/vllm-layout/step-files/…` lines are the step files
(copies in `.state/vllm-layout/step-files/`), and the commands traced after each are what they
ran. The lines from 09:14:34 to 09:16:41 are the architect's walk, from his shell, whose trace
shows only the `tee` of his ping line (its pong is in the ping file, 14:14:34Z). Left in the log
and not quoted here: every line inside a helper (`memory`, `footprint`, `readout`, `cell`,
`watch`, `vllm_wait`, `ping_host`, `drop`, `floorcheck` and the rest, each traced with its name),
the log's header lines and the floors `step.sh` exported, the `date -u` and `tee -a …` halves of
each ping line, `echo` and loop lines, the filters a pipeline's later commands ran (`grep`, `cut`,
`sort`, `head` and the like), variable assignments, and the lines of the architect's shell that
weren't the task's (`clear`, a directory change). The gb10-1 log also holds the standing cell's
step file, which drove all three hosts; its gb10-2 and Framework commands are in their own logs.

```
08:52:37  source .state/vllm-layout/step-files/stack-gb.sh
08:52:37  : 'vllm-layout stack on gb10-1: pending updates, OS, kernel, driver, CUDA, Docker, Tailscale, the engine containers and images, the clone (read only)'
08:52:37  tailscale ping -c 1 gb10-1
08:52:37  ssh gb10-1 'apt list --upgradable 2>/dev/null | grep -c upgradable; apt list --upgradable 2>/dev/null | grep upgradable | cut -d/ -f1 | paste -sd" "; uname -r; nvidia-smi --query-gpu=driver_version --format=csv,noheader; nvidia-smi | grep -o "CUDA Version: [0-9.]*"; docker --version; nvidia-ctk --version | head -1; . /etc/os-release; echo "$PRETTY_NAME"; grep -h -E "^DGX_(SWBUILD|OTA)_VERSION" /etc/dgx-release | tail -2; tailscale version | head -1; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" | grep -E "vllm|llama"; sudo -n -l 2>/dev/null | grep -i drop_caches; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && git branch -vv && git status --porcelain | wc -l; df -B1 /srv/models / | tail -2'
08:52:38  ssh gb10-1 'apt-get -s upgrade 2>/dev/null | grep -A1 -E "deferred due to phasing|upgraded,"; for p in snapd distro-info python3-distro-info; do echo "$p: $(apt-cache policy $p | grep -E "Candidate|phased" | tr -s " " | paste -sd" ")"; done'
08:53:31  source .state/vllm-layout/step-files/clones.sh
08:53:31  : 'vllm-layout: each host'\''s spike-model-engines clone to main (fetched from origin, fast-forward only), then read back'
08:53:31  tailscale ping -c 1 gb10-1
08:53:31  ssh gb10-1 'cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git fetch -q origin && git checkout -q main && git merge -q --ff-only origin/main && git status -sb | head -1 && git log --oneline -1 && git branch -vv'
08:53:32  tailscale ping -c 1 gb10-2
08:53:32  ssh gb10-2 'cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git fetch -q origin && git checkout -q main && git merge -q --ff-only origin/main && git status -sb | head -1 && git log --oneline -1 && git branch -vv'
08:53:32  tailscale ping -c 1 framework
08:53:32  ssh framework 'cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git fetch -q origin && git checkout -q main && git merge -q --ff-only origin/main && git status -sb | head -1 && git log --oneline -1 && git branch -vv'
08:53:37  source .state/vllm-layout/step-files/push.sh
08:53:37  : 'vllm-layout: the host/ branch to gb10-1 as hosts-next, then its clone onto a local hosts branch at it; the caps and the hold note read back'
08:53:37  tailscale ping -c 1 gb10-1
08:53:37  git -C /home/jaime/experiments/spike-model-engines log --oneline -1 vllm-layout
08:53:37  git -C /home/jaime/experiments/spike-model-engines push gb10-1:repos/spike-model-engines vllm-layout:hosts-next
08:53:37  ssh gb10-1 'cd ~/repos/spike-model-engines && git checkout -B hosts hosts-next && git status -sb | head -1 && git log --oneline -1 && git branch -vv && grep -E "^VLLM_RELEASE=" host/vllm.env && grep -n -A3 "^\[gpt-oss-120b-agent" host/vllm-rows && grep -o "unrestored through b12318" host/llama.env'
08:57:14  source .state/vllm-layout/step-files/bf16-start.sh
08:57:14  : 'vllm-layout slice 1: gb10-1 stops the llama container (llama.cpp stays installed), drops the page cache, and vLLM moves to gpt-oss-120b-agent (BF16 KV, max-num-seqs 8) from the hosts branch; the start timed to "Application startup complete." and /health 200, its log saved; /version, /v1/models, one short chat at reasoning_effort low; idle 30 s; drop the cache, read memory, footprint (KV tokens, sizing) and readout'
08:57:14  tailscale ping -c 1 gb10-1
08:57:14  ssh gb10-1 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && grep -n -A3 "^\[gpt-oss-120b-agent\]" host/vllm-rows'
08:57:14  ssh gb10-1 'docker ps -a --format '\''{{.Names}} {{.Image}} {{.Status}}'\''; docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
08:57:15  ssh gb10-1 docker stop llama
08:57:16  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
08:57:17  memory
08:57:17  ssh gb10-1 'cd ~/repos/spike-model-engines && VLLM_MODEL=gpt-oss-120b-agent host/engines vllm update'
08:57:18  vllm_wait bf16-start 2026-11-12T13:57:17.569272932Z 1800
09:06:04  ssh gb10-1 docker logs vllm
09:06:04  ssh gb10-1 'docker ps -a --format '\''{{.Names}} {{.Image}} {{.Status}}'\''; docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
09:06:04  curl -s -o /dev/null -w '/health %{http_code}\n' http://gb10-1:8000/health
09:06:04  curl -s http://gb10-1:8000/version
09:06:04  curl -s http://gb10-1:8000/v1/models
09:06:04  curl -s http://gb10-1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model": "openai/gpt-oss-120b", "messages": [{"role": "user", "content": "Say hello in one sentence."}], "reasoning_effort": "low", "max_tokens": 512}'
09:06:35  : 'BF16 row warmed up, idle 30 s'
09:06:35  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
09:06:35  memory
09:06:36  footprint
09:06:36  readout 2026-11-12T13:57:17.569272932Z
09:14:34  tee -a .state/vllm-layout/ping-2026-11-12.txt
09:14:43  curl -s -o /dev/null -w '/health %{http_code}\n' http://gb10-1:8000/health
09:14:59  watch vllm-layout-walk-bf16-gpqa timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=openai/gpt-oss-120b,base_url=http://gb10-1:8000/v1/chat/completions,num_concurrent=16,timeout=1800,max_retries=1 --tasks gpqa_diamond_cot_zeroshot --apply_chat_template --gen_kwargs reasoning_effort=low,max_gen_toks=16384 --seed 0,1234,1234,1234 --limit 10 --log_samples --output_path .state/vllm-layout/lm-eval/walk-bf16-gpqa
09:16:41  readout 2026-11-12T14:14:50Z
09:18:26  watch vllm-layout-bf16-gpqa timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=openai/gpt-oss-120b,base_url=http://gb10-1:8000/v1/chat/completions,num_concurrent=16,timeout=1800,max_retries=1 --tasks gpqa_diamond_cot_zeroshot --apply_chat_template --gen_kwargs reasoning_effort=low,max_gen_toks=16384 --seed 0,1234,1234,1234 --log_samples --output_path .state/vllm-layout/lm-eval/bf16-gpqa
09:43:31  watch vllm-layout-bf16-niah-32768 timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=openai/gpt-oss-120b,tokenizer=openai/gpt-oss-120b,base_url=http://gb10-1:8000/v1/chat/completions,num_concurrent=16,timeout=1800,max_retries=1 --tasks niah_single_2 --metadata '{"max_seq_lengths": [32768]}' --apply_chat_template --gen_kwargs reasoning_effort=low,max_gen_toks=4096 --seed 0,1234,1234,1234 --limit 50 --log_samples --output_path .state/vllm-layout/lm-eval/bf16-niah-32768
09:49:59  watch vllm-layout-bf16-niah-65536 timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=openai/gpt-oss-120b,tokenizer=openai/gpt-oss-120b,base_url=http://gb10-1:8000/v1/chat/completions,num_concurrent=16,timeout=1800,max_retries=1 --tasks niah_single_2 --metadata '{"max_seq_lengths": [65536]}' --apply_chat_template --gen_kwargs reasoning_effort=low,max_gen_toks=4096 --seed 0,1234,1234,1234 --limit 50 --log_samples --output_path .state/vllm-layout/lm-eval/bf16-niah-65536
10:06:47  source .state/vllm-layout/step-files/fp8-start.sh
10:06:47  : 'vllm-layout slice 1: gb10-1 (llama container already stopped, llama.cpp installed) drops the page cache, and vLLM moves from the BF16 row to gpt-oss-120b-agent-fp8 (FP8 KV, max-num-seqs 12) from the hosts branch; the start timed to "Application startup complete." and /health 200, its log saved; /version, /v1/models, one short chat at reasoning_effort low; idle 30 s; drop the cache, read memory, footprint (KV tokens, sizing) and readout'
10:06:47  tailscale ping -c 1 gb10-1
10:06:47  ssh gb10-1 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && grep -n -A3 "^\[gpt-oss-120b-agent-fp8\]" host/vllm-rows'
10:06:47  ssh gb10-1 'docker ps -a --format '\''{{.Names}} {{.Image}} {{.Status}}'\''; docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
10:06:47  ssh gb10-1 docker logs vllm
10:06:47  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
10:06:47  memory
10:06:47  ssh gb10-1 'cd ~/repos/spike-model-engines && VLLM_MODEL=gpt-oss-120b-agent-fp8 host/engines vllm update'
10:06:49  vllm_wait fp8-start 2026-11-12T15:06:47.823826379Z 1800
10:14:59  ssh gb10-1 docker logs vllm
10:14:59  ssh gb10-1 'docker ps -a --format '\''{{.Names}} {{.Image}} {{.Status}}'\''; docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
10:14:59  curl -s -o /dev/null -w '/health %{http_code}\n' http://gb10-1:8000/health
10:14:59  curl -s http://gb10-1:8000/version
10:14:59  curl -s http://gb10-1:8000/v1/models
10:14:59  curl -s http://gb10-1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model": "openai/gpt-oss-120b", "messages": [{"role": "user", "content": "Say hello in one sentence."}], "reasoning_effort": "low", "max_tokens": 512}'
10:15:30  : 'FP8 row warmed up, idle 30 s'
10:15:30  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
10:15:31  memory
10:15:31  footprint
10:15:31  readout 2026-11-12T15:06:47.823826379Z
10:15:49  watch vllm-layout-fp8-gpqa timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=openai/gpt-oss-120b,base_url=http://gb10-1:8000/v1/chat/completions,num_concurrent=16,timeout=1800,max_retries=1 --tasks gpqa_diamond_cot_zeroshot --apply_chat_template --gen_kwargs reasoning_effort=low,max_gen_toks=16384 --seed 0,1234,1234,1234 --log_samples --output_path .state/vllm-layout/lm-eval/fp8-gpqa
10:37:41  watch vllm-layout-fp8-niah-32768 timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=openai/gpt-oss-120b,tokenizer=openai/gpt-oss-120b,base_url=http://gb10-1:8000/v1/chat/completions,num_concurrent=16,timeout=1800,max_retries=1 --tasks niah_single_2 --metadata '{"max_seq_lengths": [32768]}' --apply_chat_template --gen_kwargs reasoning_effort=low,max_gen_toks=4096 --seed 0,1234,1234,1234 --limit 50 --log_samples --output_path .state/vllm-layout/lm-eval/fp8-niah-32768
10:44:09  watch vllm-layout-fp8-niah-65536 timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=openai/gpt-oss-120b,tokenizer=openai/gpt-oss-120b,base_url=http://gb10-1:8000/v1/chat/completions,num_concurrent=16,timeout=1800,max_retries=1 --tasks niah_single_2 --metadata '{"max_seq_lengths": [65536]}' --apply_chat_template --gen_kwargs reasoning_effort=low,max_gen_toks=4096 --seed 0,1234,1234,1234 --limit 50 --log_samples --output_path .state/vllm-layout/lm-eval/fp8-niah-65536
11:01:45  memory
11:01:45  cell vllm-layout-fp8-agent vllm-layout-agent openai/gpt-oss-120b openai/gpt-oss-120b
11:05:50  readout 2026-11-12T16:01:45Z
11:05:50  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
11:05:50  memory
11:05:50  footprint
11:05:51  jq -r --arg purpose agent -f bench/levels.jq .state/measure/gb10-1/vllm-layout-fp8-agent.json
15:38:21  source .state/vllm-layout/step-files/g1-swap.sh
15:38:21  : 'vllm-layout slice 3, part A on gb10-1: host/ 8f981ee delivered (pushed as hosts-next, the clone'\''s local hosts branch reset to it) without restarting the agent row, whose row block is identical between 3efb444 and 8f981ee; the row block compared on the host, the container'\''s StartedAt and command read before and after, so the row is shown not to have restarted'
15:38:21  ping_host
15:38:21  ssh gb10-1 'cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git status -sb | head -1 && git log --oneline -1 && docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
15:38:22  git -C /home/jaime/experiments/spike-model-engines log --oneline -1 vllm-layout
15:38:22  git -C /home/jaime/experiments/spike-model-engines push gb10-1:repos/spike-model-engines vllm-layout:hosts-next
15:38:22  ssh gb10-1 'cd ~/repos/spike-model-engines && for c in 3efb444 hosts-next; do git show $c:host/vllm-rows | awk "/^\[gpt-oss-120b-agent-fp8\]/{f=1} f&&/^\$/{exit} f" | sha256sum; done; git diff --stat 3efb444 hosts-next -- host/vllm.env host/engines host/vllm.sh'
15:38:22  ssh gb10-1 'cd ~/repos/spike-model-engines && git checkout -B hosts hosts-next && git status -sb | head -1 && git log --oneline -1 && grep -E "^VLLM_RELEASE=" host/vllm.env && grep -n -A4 "^\[gpt-oss-120b-agent-fp8\]" host/vllm-rows'
15:38:22  ssh gb10-1 'docker ps --format '\''{{.Names}}'\'' | grep '\''^vllm'\'' | xargs -r docker inspect -f '\''{{.Name}} {{.Config.Image}} :: {{join .Config.Cmd " "}}'\'''
15:38:52  source .state/vllm-layout/step-files/llama-remove.sh
15:38:52  : 'vllm-layout slice 3, part A (Behavior 10): llama.cpp leaves the host. The llama container and every llama.cpp image removed through the suite (engines llama uninstall, from the clone'\''s hosts branch; /srv/models stays); then the GGUF repositories removed from the model store with hf cache rm, dry run first, every safetensors repo kept; sizes before and after; no llama container, image or GGUF left (docker ps -a, docker images, hf cache ls); the vLLM rows'\'' /health read after'
15:38:52  ping_host
15:38:52  ssh gb10-1 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}"; docker system df; df -B1 /srv/models | tail -1; du -sb /srv/models'
15:38:52  : 'the store'\''s repositories by file type: a GGUF repository holds .gguf files and no .safetensors'
15:38:52  ssh gb10-1 'for r in /srv/models/models--*; do printf "%s gguf %s safetensors %s\n" "${r##*/}" "$(find -L "$r/snapshots" -name "*.gguf" | wc -l)" "$(find -L "$r/snapshots" -name "*.safetensors" | wc -l)"; done'
15:38:52  ssh gb10-1 'cd ~/repos/spike-model-engines && host/engines llama uninstall'
15:38:53  ssh gb10-1 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}"; docker system df'
15:38:53  ssh gb10-1 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --dry-run model/ggml-org/gemma-4-E4B-it-GGUF model/ggml-org/gpt-oss-120b-GGUF model/google/gemma-4-26B-A4B-it-qat-q4_0-gguf model/mrutkows/granite-embedding-english-r2-GGUF 2>&1 | grep -v Hint'
15:38:53  ssh gb10-1 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --yes model/ggml-org/gemma-4-E4B-it-GGUF model/ggml-org/gpt-oss-120b-GGUF model/google/gemma-4-26B-A4B-it-qat-q4_0-gguf model/mrutkows/granite-embedding-english-r2-GGUF 2>&1 | grep -v Hint'
15:38:54  ssh gb10-1 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache ls 2>&1 | grep -v Hint; du -sb /srv/models; df -B1 /srv/models | tail -1; ls /srv/models; echo "gguf files left: $(find -L /srv/models -name "*.gguf" | wc -l)"'
15:38:54  ssh gb10-1 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}" | grep -i llama || echo "no llama container"; docker images --format "{{.Repository}}:{{.Tag}}" | grep -i llama || echo "no llama.cpp image"'
15:40:03  source .state/vllm-layout/step-files/before-reboot.sh
15:40:03  : 'vllm-layout slice 3, part A (Behavior 11, before-state): every standing vLLM container'\''s restart policy, published ports and state; the nonlocal-bind sysctl and /etc/sysctl.d; on the Framework /etc/modprobe.d (ttm.conf, amdgpu.conf), the GTT the GPU reports, and the current boot'\''s gttsize deprecation line; boot time and kernel; read only'
15:40:03  ping_host
15:40:03  ssh gb10-1 'for c in $(docker ps -a --format "{{.Names}}"); do docker inspect --format "{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} max={{.HostConfig.RestartPolicy.MaximumRetryCount}} status={{.State.Status}} started={{.State.StartedAt}} restarts={{.RestartCount}} image={{.Config.Image}} ports={{json .HostConfig.PortBindings}}" "$c"; done'
15:40:03  ssh gb10-1 'systemctl is-enabled docker.service docker.socket tailscaled.service 2>&1; systemctl show -p After -p Wants docker.service | tr " " "\n" | grep -iE "tailscale|network-online" || echo "docker.service: no ordering on tailscaled"'
15:40:03  ssh gb10-1 'uname -r; uptime -s; sysctl net.ipv4.ip_nonlocal_bind; ls -la /etc/sysctl.d/; for f in /etc/sysctl.d/*; do echo "--- $f"; cat "$f"; done 2>/dev/null'
16:26:58  source .state/vllm-layout/step-files/after-reboot.sh
16:26:58  : 'vllm-layout slice 3, part B (Behavior 11, after the reboot): boot time and kernel, the nonlocal-bind sysctl, every container with its restart policy, StartedAt and restart count; each standing row'\''s /health, /v1/models and the start log'\''s max_num_seqs, KV and startup lines; on the Framework /etc/modprobe.d, ttm pages_limit, the GTT the GPU reports and the boot'\''s gttsize lines; then 30 s idle, a cache drop, memory and the floor check; read only, no root beyond the drop-caches rule'
16:26:58  ping_host
16:26:58  ssh gb10-1 'uptime -s; uptime; uname -r; sysctl net.ipv4.ip_nonlocal_bind'
16:26:58  ssh gb10-1 'for c in $(docker ps -a --format "{{.Names}}"); do docker inspect --format "{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} status={{.State.Status}} started={{.State.StartedAt}} restarts={{.RestartCount}} image={{.Config.Image}} ports={{json .HostConfig.PortBindings}}" "$c"; done'
16:26:59  curl -s -o /dev/null -w '/health %{http_code}\n' --max-time 10 http://gb10-1:8000/health
16:26:59  curl -s --max-time 10 http://gb10-1:8000/v1/models
16:26:59  ssh gb10-1 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm) vllm 2>&1'
16:26:59  memory
16:27:29  drop
16:27:29  memory
16:27:30  floorcheck 'idle after the reboot'
16:27:41  source .state/vllm-layout/step-files/standing-cell.sh
16:27:41  : 'vllm-layout-standing (Behavior 12): the standing layout at today'\''s targets on all three hosts at once, 240 s, four GuideLLM processes started together, each under watch with its host'\''s floors every 10 s, cap 10 min: agent 4 sessions on gb10-1 8000 (bench/role-split-mixed-agent.yaml, vllm-layout-agent.yaml'\''s S-agent sessions at 240 s, GUIDELLM__SPEC__PROFILE__STREAMS=4), vision 4 on gb10-2 8000 (role-split-mixed-vision.yaml), audio 4 on the Framework 8001 (role-split-mixed-audio.yaml) and embedding on the Framework 8002 at a constant 34 req/s (vllm-layout-embed-rate-4x.yaml: the layout rate-limits embedding at the gateway, so the standing condition is the admitted rate, not closed-loop streams). The laptop'\''s available memory read first (12 GiB or the cell doesn'\''t start); a dated tailscale ping and memory on each host; then per host a cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check; each purpose judged at its floor by bench/levels.jq'
16:27:41  tailscale ping -c 1 gb10-1
16:27:41  ssh gb10-1 'docker ps --format "{{.Names}} {{.Status}}"'
16:27:42  floors gb10-1
16:27:42  memory
16:27:42  tailscale ping -c 1 gb10-2
16:27:42  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
16:27:42  tailscale ping -c 1 framework
16:27:42  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
16:27:42  floors gb10-1
16:27:42  cell vllm-layout-standing-agent role-split-mixed-agent openai/gpt-oss-120b openai/gpt-oss-120b
16:32:08  drop gb10-1
16:32:08  floors gb10-1
16:32:08  memory
16:32:08  footprint 2026-11-12T21:32:08Z
16:32:08  readout 2026-11-12T21:27:42Z
16:32:09  ssh gb10-1 'docker logs --since 2026-11-12T21:27:42Z vllm 2>&1'
16:32:09  drop gb10-2
16:32:10  ssh gb10-2 'docker logs --since 2026-11-12T21:27:42Z vllm-vision 2>&1'
16:32:10  drop framework
16:32:11  ssh framework 'docker logs --since 2026-11-12T21:27:42Z vllm-audio 2>&1'
16:32:11  ssh framework 'docker logs --since 2026-11-12T21:27:42Z vllm-embed 2>&1'
16:32:11  jq -r --arg purpose agent -f bench/levels.jq .state/measure/gb10-1/vllm-layout-standing-agent.json
16:32:11  jq -r --arg purpose vision -f bench/levels.jq .state/measure/gb10-2/vllm-layout-standing-vision.json
16:32:12  jq -r --arg purpose audio -f bench/levels.jq .state/measure/framework/vllm-layout-standing-audio.json
16:32:13  jq -r --arg purpose embed -f bench/levels.jq .state/measure/framework/vllm-layout-standing-embed.json
```

### Commands as run (gb10-2)

From `.state/measure/gb10-2/2026-11-12.log`, by the same rule, from 08:52:42.

```
08:52:42  source .state/vllm-layout/step-files/stack-gb.sh
08:52:42  : 'vllm-layout stack on gb10-2: pending updates, OS, kernel, driver, CUDA, Docker, Tailscale, the engine containers and images, the clone (read only)'
08:52:42  tailscale ping -c 1 gb10-2
08:52:42  ssh gb10-2 'apt list --upgradable 2>/dev/null | grep -c upgradable; apt list --upgradable 2>/dev/null | grep upgradable | cut -d/ -f1 | paste -sd" "; uname -r; nvidia-smi --query-gpu=driver_version --format=csv,noheader; nvidia-smi | grep -o "CUDA Version: [0-9.]*"; docker --version; nvidia-ctk --version | head -1; . /etc/os-release; echo "$PRETTY_NAME"; grep -h -E "^DGX_(SWBUILD|OTA)_VERSION" /etc/dgx-release | tail -2; tailscale version | head -1; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" | grep -E "vllm|llama"; sudo -n -l 2>/dev/null | grep -i drop_caches; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && git branch -vv && git status --porcelain | wc -l; df -B1 /srv/models / | tail -2'
08:52:43  ssh gb10-2 'apt-get -s upgrade 2>/dev/null | grep -A1 -E "deferred due to phasing|upgraded,"; for p in snapd distro-info python3-distro-info; do echo "$p: $(apt-cache policy $p | grep -E "Candidate|phased" | tr -s " " | paste -sd" ")"; done'
11:10:41  source .state/vllm-layout/step-files/g2-push.sh
11:10:41  : 'vllm-layout slice 2: on gb10-2'\''s main clone, the embedding row'\''s container removed (engines vllm uninstall; images and compile cache stay, since vllm-vision and vllm-audio are left); then the host/ branch pushed to gb10-2 as hosts-next, its clone onto a local hosts branch at it, the rows read back'
11:10:41  ping_host
11:10:41  ssh gb10-2 'cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git status -sb | head -1 && git log --oneline -1 && docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
11:10:42  ssh gb10-2 'cd ~/repos/spike-model-engines && VLLM_MODEL=granite-embedding-english-r2-gb10 host/engines vllm uninstall'
11:10:42  git -C /home/jaime/experiments/spike-model-engines log --oneline -2 vllm-layout
11:10:42  git -C /home/jaime/experiments/spike-model-engines push gb10-2:repos/spike-model-engines vllm-layout:hosts-next
11:10:42  ssh gb10-2 'cd ~/repos/spike-model-engines && git checkout -B hosts hosts-next && git status -sb | head -1 && git log --oneline -2 && git branch -vv && grep -E "^\[.*-(gb10|framework)\]" host/vllm-rows && grep -n -A5 -E "^\[(gemma-4-26B-A4B-NVFP4-vision-gb10|gemma-4-E4B-it-audio-gb10)\]" host/vllm-rows && grep -E "^VLLM_RELEASE=" host/vllm.env; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; du -sh ~/.cache/vllm'
11:10:58  source .state/vllm-layout/step-files/g2-start.sh
11:10:58  : 'vllm-layout slice 2 on gb10-2 (Behavior 6): docker stop llama (llama.cpp stays installed); drop the page cache; the vision row, then the audio row, started from the hosts branch (engines vllm update reads each container against its row, then docker start), each after the previous one'\''s /health 200: the first starts. Then each row'\''s container stopped, the page cache dropped, and started alone while the other serves: the cold starts. Each start timed to '\''Application startup complete.'\'' and /health 200, MemAvailable every 10 s; each start log saved and read'
11:10:58  ping_host
11:10:58  ssh gb10-2 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && du -sh ~/.cache/vllm; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
11:10:58  ssh gb10-2 docker stop llama
11:10:59  drop
11:10:59  memory
11:11:00  ssh gb10-2 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-26B-A4B-NVFP4-vision-gb10 host/engines vllm update; docker start vllm-vision'
11:11:00  vwait first-vision 2026-11-12T16:11:00.160192646Z 900 vision
11:14:08  startlog vision /home/jaime/experiments/spike-model-layout/.state/vllm-layout/gb10-2-first-vision.log
11:14:08  memory
11:14:09  ssh gb10-2 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-E4B-it-audio-gb10 host/engines vllm update; docker start vllm-audio'
11:14:09  vwait first-audio 2026-11-12T16:14:09.118575653Z 900 audio
11:16:46  startlog audio /home/jaime/experiments/spike-model-layout/.state/vllm-layout/gb10-2-first-audio.log
11:16:46  memory
11:16:46  ping_host
11:16:46  ssh gb10-2 docker stop vllm-vision
11:16:48  drop
11:16:48  memory
11:16:48  ssh gb10-2 docker start vllm-vision
11:16:49  vwait cold-vision 2026-11-12T16:16:48.929011506Z 900 vision
11:19:49  startlog vision /home/jaime/experiments/spike-model-layout/.state/vllm-layout/gb10-2-cold-vision.log
11:19:49  footprint
11:19:49  ping_host
11:19:49  ssh gb10-2 docker stop vllm-audio
11:19:50  drop
11:19:51  memory
11:19:51  ssh gb10-2 docker start vllm-audio
11:19:51  vwait cold-audio 2026-11-12T16:19:51.208281431Z 900 audio
11:22:30  startlog audio /home/jaime/experiments/spike-model-layout/.state/vllm-layout/gb10-2-cold-audio.log
11:22:30  footprint
11:22:31  ssh gb10-2 'du -sh ~/.cache/vllm; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
11:24:51  source .state/vllm-layout/step-files/g2-probe.sh
11:24:51  : 'vllm-layout slice 2 on gb10-2 (Behavior 6): /health, /version and /v1/models per port; one probe of each row'\''s kind (capability-vllm'\''s: a 640x360 PNG of a red circle, a blue square and the text '\''GB10 42'\''; LibriSpeech 1272-128104-0000, 5.86 s), replies kept in probes/; one warm-up request a row; idle 30 s; drop the page cache; memory, each row'\''s footprint and readout since its cold start; the idle floor check (12.2 GiB; under it the phase stops)'
11:24:51  ping_host
11:24:51  curl -s http://gb10-2:8000/v1/models
11:24:51  curl -s http://gb10-2:8001/v1/models
11:24:52  curl -s http://gb10-2:8000/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-vision.json
11:24:53  curl -s http://gb10-2:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-audio.json
11:24:54  : 'one warm-up request a row'
11:24:54  curl -s http://gb10-2:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"nvidia/Gemma-4-26B-A4B-NVFP4","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
11:24:54  curl -s http://gb10-2:8001/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"google/gemma-4-E4B-it","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
11:25:25  : 'two rows warmed up, idle 30 s'
11:25:25  drop
11:25:25  memory
11:25:25  footprint
11:25:26  readout 2026-11-12T16:16:49.058217139Z
11:25:26  footprint
11:25:26  readout 2026-11-12T16:19:51.316485894Z
11:25:27  floorcheck 'the idle read'
11:25:31  source .state/vllm-layout/step-files/g2-alone.sh
11:25:31  : 'vllm-layout-g2-vision-4: gb10-2'\''s vision row alone at 4 streams (bench/vllm-layout-vision-alone.yaml), the other row loaded and idle, under watch with the 12.2 GiB floor every 10 s, cap 10 min; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
11:25:31  ping_host
11:25:32  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
11:25:32  memory
11:25:32  cell vllm-layout-g2-vision-4 vllm-layout-vision-alone nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
11:27:24  v_after vllm-layout-g2-vision-4 2026-11-12T16:25:32Z
11:27:26  source .state/vllm-layout/step-files/g2-alone.sh
11:27:26  : 'vllm-layout-g2-audio-4: gb10-2'\''s audio row alone at 4 streams (bench/vllm-layout-audio-alone.yaml), the other row loaded and idle, under watch with the 12.2 GiB floor every 10 s, cap 10 min; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
11:27:26  ping_host
11:27:26  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
11:27:26  memory
11:27:26  cell vllm-layout-g2-audio-4 vllm-layout-audio-alone google/gemma-4-E4B-it google/gemma-4-E4B-it
11:27:57  v_after vllm-layout-g2-audio-4 2026-11-12T16:27:26Z
11:28:08  source .state/vllm-layout/step-files/g2-pair.sh
11:28:08  : 'vllm-layout-g2-pair-4: gb10-2'\''s vision and audio rows together, 4 + 4 streams (bench/role-split-mixed-vision.yaml and -audio.yaml, streams from GUIDELLM__SPEC__PROFILE__STREAMS), 240 s each, the two GuideLLM processes started together, each under watch with the 12.2 GiB floor every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
11:28:08  ping_host
11:28:08  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
11:28:08  memory
11:28:08  cell vllm-layout-g2-pair-4-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
11:28:08  cell vllm-layout-g2-pair-4-vision role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
11:32:24  v_after vllm-layout-g2-pair-4 2026-11-12T16:28:08Z
11:32:37  source .state/vllm-layout/step-files/g2-pair.sh
11:32:37  : 'vllm-layout-g2-pair-8: gb10-2'\''s vision and audio rows together, 8 + 8 streams (bench/role-split-mixed-vision.yaml and -audio.yaml, streams from GUIDELLM__SPEC__PROFILE__STREAMS), 240 s each, the two GuideLLM processes started together, each under watch with the 12.2 GiB floor every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
11:32:37  ping_host
11:32:37  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
11:32:37  memory
11:32:38  cell vllm-layout-g2-pair-8-vision role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
11:32:38  cell vllm-layout-g2-pair-8-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
11:36:54  v_after vllm-layout-g2-pair-8 2026-11-12T16:32:37Z
11:44:16  source .state/vllm-layout/step-files/g2-pair-uneven.sh
11:44:16  : 'vllm-layout-g2-pair-v4a2: gb10-2'\''s vision and audio rows together, vision 4 + audio 2 streams (bench/role-split-mixed-vision.yaml and -audio.yaml, streams from GUIDELLM__SPEC__PROFILE__STREAMS), 240 s each, the two GuideLLM processes started together, each under watch with the 12.2 GiB floor every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
11:44:16  ping_host
11:44:16  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
11:44:17  memory
11:44:17  cell vllm-layout-g2-pair-v4a2-vision role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
11:44:17  cell vllm-layout-g2-pair-v4a2-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
11:48:32  v_after vllm-layout-g2-pair-v4a2 2026-11-12T16:44:17Z
11:48:34  source .state/vllm-layout/step-files/g2-pair-uneven.sh
11:48:34  : 'vllm-layout-g2-pair-v2a2: gb10-2'\''s vision and audio rows together, vision 2 + audio 2 streams (bench/role-split-mixed-vision.yaml and -audio.yaml, streams from GUIDELLM__SPEC__PROFILE__STREAMS), 240 s each, the two GuideLLM processes started together, each under watch with the 12.2 GiB floor every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
11:48:34  ping_host
11:48:34  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
11:48:34  memory
11:48:34  cell vllm-layout-g2-pair-v2a2-vision role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
11:48:34  cell vllm-layout-g2-pair-v2a2-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
11:52:50  v_after vllm-layout-g2-pair-v2a2 2026-11-12T16:48:34Z
11:52:52  source .state/vllm-layout/step-files/g2-pair-uneven.sh
11:52:52  : 'vllm-layout-g2-pair-v2a4: gb10-2'\''s vision and audio rows together, vision 2 + audio 4 streams (bench/role-split-mixed-vision.yaml and -audio.yaml, streams from GUIDELLM__SPEC__PROFILE__STREAMS), 240 s each, the two GuideLLM processes started together, each under watch with the 12.2 GiB floor every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
11:52:52  ping_host
11:52:52  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
11:52:52  memory
11:52:53  cell vllm-layout-g2-pair-v2a4-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
11:52:53  cell vllm-layout-g2-pair-v2a4-vision role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
11:57:08  v_after vllm-layout-g2-pair-v2a4 2026-11-12T16:52:53Z
11:57:20  source .state/vllm-layout/step-files/g2-alone.sh
11:57:20  : 'vllm-layout-g2-vision-capacity: gb10-2'\''s vision row alone at the levels bench/vllm-layout-vision-capacity.yaml names, the other row loaded and idle, under watch with the 12.2 GiB floor every 10 s, cap 10 min; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
11:57:20  ping_host
11:57:20  ssh gb10-2 'docker ps --format "{{.Names}} {{.Status}}"'
11:57:20  memory
11:57:20  cell vllm-layout-g2-vision-capacity vllm-layout-vision-capacity nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
12:00:44  v_after vllm-layout-g2-vision-capacity 2026-11-12T16:57:20Z
12:00:57  source .state/vllm-layout/step-files/g2-mmmu.sh
12:00:57  : 'vllm-layout Behavior 4, NVFP4: lm-eval mmmu_val (--limit 10 a subject, 900 questions without it; max_images 7, chat template applied, greedy, max_gen_toks 512) on gb10-2'\''s vision row, num_concurrent 16 (the row'\''s cap), under watch with the 12.2 GiB floor every 10 s, cap 45 min; then readout since its start, cache drop, memory, footprint, lm-eval'\''s errored count and placeholders'
12:00:57  ping_host
12:00:57  curl -s -o /dev/null -w '/health %{http_code}\n' http://gb10-2:8000/health
12:00:57  curl -s http://gb10-2:8000/v1/models
12:00:57  ssh gb10-2 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm-vision'
12:00:57  memory
12:00:57  watch vllm-layout-nvfp4-mmmu-smoke timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=nvidia/Gemma-4-26B-A4B-NVFP4,base_url=http://gb10-2:8000/v1/chat/completions,num_concurrent=16,max_images=7,timeout=1800,max_retries=1 --tasks mmmu_val --apply_chat_template --gen_kwargs temperature=0,max_gen_toks=512 --seed 0,1234,1234,1234 --limit 10 --log_samples --output_path .state/vllm-layout/lm-eval/nvfp4-mmmu-smoke
12:11:48  readout 2026-11-12T17:00:57Z
12:11:48  drop
12:11:49  memory
12:11:49  footprint
12:12:27  source .state/vllm-layout/step-files/g2-mmmu.sh
12:12:27  : 'vllm-layout Behavior 4, NVFP4: lm-eval mmmu_val (--limit 10 a subject, 900 questions without it; max_images 7, chat template applied, greedy, max_gen_toks 1024) on gb10-2'\''s vision row, num_concurrent 16 (the row'\''s cap), under watch with the 12.2 GiB floor every 10 s, cap 45 min; then readout since its start, cache drop, memory, footprint, lm-eval'\''s errored count and placeholders'
12:12:27  ping_host
12:12:28  curl -s -o /dev/null -w '/health %{http_code}\n' http://gb10-2:8000/health
12:12:28  curl -s http://gb10-2:8000/v1/models
12:12:28  ssh gb10-2 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm-vision'
12:12:28  memory
12:12:28  watch vllm-layout-nvfp4-mmmu-smoke-1024 timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=nvidia/Gemma-4-26B-A4B-NVFP4,base_url=http://gb10-2:8000/v1/chat/completions,num_concurrent=16,max_images=7,timeout=1800,max_retries=1 --tasks mmmu_val --apply_chat_template --gen_kwargs temperature=0,max_gen_toks=1024 --seed 0,1234,1234,1234 --limit 10 --log_samples --output_path .state/vllm-layout/lm-eval/nvfp4-mmmu-smoke-1024
12:20:06  readout 2026-11-12T17:12:28Z
12:20:07  drop
12:20:07  memory
12:20:07  footprint
12:20:24  source .state/vllm-layout/step-files/g2-mmmu.sh
12:20:24  : 'vllm-layout Behavior 4, NVFP4: lm-eval mmmu_val (900 questions without it; max_images 7, chat template applied, greedy, max_gen_toks 1024) on gb10-2'\''s vision row, num_concurrent 16 (the row'\''s cap), under watch with the 12.2 GiB floor every 10 s, cap 45 min; then readout since its start, cache drop, memory, footprint, lm-eval'\''s errored count and placeholders'
12:20:24  ping_host
12:20:24  curl -s -o /dev/null -w '/health %{http_code}\n' http://gb10-2:8000/health
12:20:24  curl -s http://gb10-2:8000/v1/models
12:20:24  ssh gb10-2 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm-vision'
12:20:24  memory
12:20:24  watch vllm-layout-nvfp4-mmmu timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=nvidia/Gemma-4-26B-A4B-NVFP4,base_url=http://gb10-2:8000/v1/chat/completions,num_concurrent=16,max_images=7,timeout=1800,max_retries=1 --tasks mmmu_val --apply_chat_template --gen_kwargs temperature=0,max_gen_toks=1024 --seed 0,1234,1234,1234 --log_samples --output_path .state/vllm-layout/lm-eval/nvfp4-mmmu
12:43:30  readout 2026-11-12T17:20:24Z
12:43:30  drop
12:43:30  memory
12:43:30  footprint
15:28:54  source .state/vllm-layout/step-files/g2-swap.sh
15:28:54  : 'vllm-layout slice 2, part B stage 3 on gb10-2 (escalation 2, answer 3): the audio row'\''s container removed through the suite from the clone'\''s current hosts branch, which still names the row (engines vllm uninstall; images and compile cache stay, since vllm-vision is left); the host/ branch pushed as hosts-next, the clone onto a local hosts branch at it, the rows read back; vision restarted from the new branch (engines vllm update, then stopped, page cache dropped, started: timed), its cap read from the start log; the image probe; idle 30 s, drop, memory, footprint, readout, the idle floor check'
15:28:54  ping_host
15:28:54  ssh gb10-2 'cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git status -sb | head -1 && git log --oneline -1 && docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
15:28:55  ssh gb10-2 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-E4B-it-audio-gb10 host/engines vllm uninstall'
15:28:55  git -C /home/jaime/experiments/spike-model-engines log --oneline -2 vllm-layout
15:28:55  git -C /home/jaime/experiments/spike-model-engines push gb10-2:repos/spike-model-engines vllm-layout:hosts-next
15:28:55  ssh gb10-2 'cd ~/repos/spike-model-engines && git checkout -B hosts hosts-next && git status -sb | head -1 && git log --oneline -2 && grep -E "^\[.*-(gb10|framework)\]" host/vllm-rows && grep -n -A5 -E "^\[gemma-4-26B-A4B-NVFP4-vision-gb10\]" host/vllm-rows && grep -E "^VLLM_RELEASE=" host/vllm.env; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
15:28:56  ssh gb10-2 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-26B-A4B-NVFP4-vision-gb10 host/engines vllm update'
15:28:56  ssh gb10-2 docker stop vllm-vision
15:28:58  drop
15:28:58  memory
15:28:58  ssh gb10-2 docker start vllm-vision
15:28:59  vwait swap-vision 2026-11-12T20:28:58.579517035Z 900 vision
15:32:01  startlog vision /home/jaime/experiments/spike-model-layout/.state/vllm-layout/gb10-2-swap-vision.log
15:32:01  curl -s http://gb10-2:8000/v1/models
15:32:01  curl -s http://gb10-2:8000/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-vision.json
15:32:33  : 'vision warmed up, idle 30 s'
15:32:33  drop
15:32:33  memory
15:32:33  footprint
15:32:34  readout 2026-11-12T20:28:58.697349762Z
15:32:34  floorcheck 'the idle read (vision alone)'
15:32:34  ssh gb10-2 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -E "vllm|llama"; du -sh ~/.cache/vllm'
15:39:05  source .state/vllm-layout/step-files/llama-remove.sh
15:39:05  : 'vllm-layout slice 3, part A (Behavior 10): llama.cpp leaves the host. The llama container and every llama.cpp image removed through the suite (engines llama uninstall, from the clone'\''s hosts branch; /srv/models stays); then the GGUF repositories removed from the model store with hf cache rm, dry run first, every safetensors repo kept; sizes before and after; no llama container, image or GGUF left (docker ps -a, docker images, hf cache ls); the vLLM rows'\'' /health read after'
15:39:05  ping_host
15:39:05  ssh gb10-2 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}"; docker system df; df -B1 /srv/models | tail -1; du -sb /srv/models'
15:39:06  : 'the store'\''s repositories by file type: a GGUF repository holds .gguf files and no .safetensors'
15:39:06  ssh gb10-2 'for r in /srv/models/models--*; do printf "%s gguf %s safetensors %s\n" "${r##*/}" "$(find -L "$r/snapshots" -name "*.gguf" | wc -l)" "$(find -L "$r/snapshots" -name "*.safetensors" | wc -l)"; done'
15:39:06  ssh gb10-2 'cd ~/repos/spike-model-engines && host/engines llama uninstall'
15:39:06  ssh gb10-2 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}"; docker system df'
15:39:07  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --dry-run model/ggml-org/gemma-4-E4B-it-GGUF model/ggml-org/gpt-oss-120b-GGUF model/google/gemma-4-26B-A4B-it-qat-q4_0-gguf model/mrutkows/granite-embedding-english-r2-GGUF 2>&1 | grep -v Hint'
15:39:07  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --yes model/ggml-org/gemma-4-E4B-it-GGUF model/ggml-org/gpt-oss-120b-GGUF model/google/gemma-4-26B-A4B-it-qat-q4_0-gguf model/mrutkows/granite-embedding-english-r2-GGUF 2>&1 | grep -v Hint'
15:39:07  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache ls 2>&1 | grep -v Hint; du -sb /srv/models; df -B1 /srv/models | tail -1; ls /srv/models; echo "gguf files left: $(find -L /srv/models -name "*.gguf" | wc -l)"'
15:39:07  ssh gb10-2 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}" | grep -i llama || echo "no llama container"; docker images --format "{{.Repository}}:{{.Tag}}" | grep -i llama || echo "no llama.cpp image"'
15:40:02  source .state/vllm-layout/step-files/before-reboot.sh
15:40:02  : 'vllm-layout slice 3, part A (Behavior 11, before-state): every standing vLLM container'\''s restart policy, published ports and state; the nonlocal-bind sysctl and /etc/sysctl.d; on the Framework /etc/modprobe.d (ttm.conf, amdgpu.conf), the GTT the GPU reports, and the current boot'\''s gttsize deprecation line; boot time and kernel; read only'
15:40:02  ping_host
15:40:02  ssh gb10-2 'for c in $(docker ps -a --format "{{.Names}}"); do docker inspect --format "{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} max={{.HostConfig.RestartPolicy.MaximumRetryCount}} status={{.State.Status}} started={{.State.StartedAt}} restarts={{.RestartCount}} image={{.Config.Image}} ports={{json .HostConfig.PortBindings}}" "$c"; done'
15:40:02  ssh gb10-2 'systemctl is-enabled docker.service docker.socket tailscaled.service 2>&1; systemctl show -p After -p Wants docker.service | tr " " "\n" | grep -iE "tailscale|network-online" || echo "docker.service: no ordering on tailscaled"'
15:40:03  ssh gb10-2 'uname -r; uptime -s; sysctl net.ipv4.ip_nonlocal_bind; ls -la /etc/sysctl.d/; for f in /etc/sysctl.d/*; do echo "--- $f"; cat "$f"; done 2>/dev/null'
16:19:14  source .state/vllm-layout/step-files/after-reboot.sh
16:19:14  : 'vllm-layout slice 3, part B (Behavior 11, after the reboot): boot time and kernel, the nonlocal-bind sysctl, every container with its restart policy, StartedAt and restart count; each standing row'\''s /health, /v1/models and the start log'\''s max_num_seqs, KV and startup lines; on the Framework /etc/modprobe.d, ttm pages_limit, the GTT the GPU reports and the boot'\''s gttsize lines; then 30 s idle, a cache drop, memory and the floor check; read only, no root beyond the drop-caches rule'
16:19:14  ping_host
16:19:14  ssh gb10-2 'uptime -s; uptime; uname -r; sysctl net.ipv4.ip_nonlocal_bind'
16:19:14  ssh gb10-2 'for c in $(docker ps -a --format "{{.Names}}"); do docker inspect --format "{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} status={{.State.Status}} started={{.State.StartedAt}} restarts={{.RestartCount}} image={{.Config.Image}} ports={{json .HostConfig.PortBindings}}" "$c"; done'
16:19:14  curl -s -o /dev/null -w '/health %{http_code}\n' --max-time 10 http://gb10-2:8000/health
16:19:14  curl -s --max-time 10 http://gb10-2:8000/v1/models
16:19:14  ssh gb10-2 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-vision) vllm-vision 2>&1'
16:19:14  memory
16:19:44  drop
16:19:45  memory
16:19:45  floorcheck 'idle after the reboot'
16:19:57  source .state/vllm-layout/step-files/g2-store-rm.sh
16:19:57  : 'vllm-layout slice 3, part B (the architect'\''s decision): gb10-2'\''s E4B and ibm-granite safetensors, which no gb10-2 row serves, leave the model store with hf cache rm; the NVFP4 repo stays. RM=yes removes; otherwise the dry run alone. Store and disk before and after; vision'\''s /health after'
16:19:57  ping_host
16:19:57  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache ls 2>&1 | grep -v Hint; du -sb /srv/models; df -B1 /srv/models | tail -1'
16:19:58  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --dry-run model/google/gemma-4-E4B-it model/ibm-granite/granite-embedding-english-r2 2>&1 | grep -v Hint'
16:20:05  source .state/vllm-layout/step-files/g2-store-rm.sh
16:20:05  : 'vllm-layout slice 3, part B (the architect'\''s decision): gb10-2'\''s E4B and ibm-granite safetensors, which no gb10-2 row serves, leave the model store with hf cache rm; the NVFP4 repo stays. RM=yes removes; otherwise the dry run alone. Store and disk before and after; vision'\''s /health after'
16:20:05  ping_host
16:20:05  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache ls 2>&1 | grep -v Hint; du -sb /srv/models; df -B1 /srv/models | tail -1'
16:20:05  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --dry-run model/google/gemma-4-E4B-it model/ibm-granite/granite-embedding-english-r2 2>&1 | grep -v Hint'
16:20:06  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --yes model/google/gemma-4-E4B-it model/ibm-granite/granite-embedding-english-r2 2>&1 | grep -v Hint'
16:20:06  ssh gb10-2 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache ls 2>&1 | grep -v Hint; du -sb /srv/models; df -B1 /srv/models | tail -1; ls /srv/models'
16:27:42  floors gb10-2
16:27:42  memory
16:27:42  floors gb10-2
16:27:42  cell vllm-layout-standing-vision role-split-mixed-vision nvidia/Gemma-4-26B-A4B-NVFP4 google/gemma-4-26B-A4B-it
16:32:09  floors gb10-2
16:32:09  memory
16:32:09  footprint 2026-11-12T21:32:09Z
16:32:09  readout 2026-11-12T21:27:42Z
```

### Commands as run (framework)

From `.state/measure/framework/2026-11-12.log`, by the same rule, from 08:52:43. The log's earlier
lines are capability-vllm's walkthrough and the architect's laptop setup (below).

```
08:52:43  source .state/vllm-layout/step-files/stack-fw.sh
08:52:43  : 'vllm-layout stack on framework: pending updates, OS, kernel, Mesa, firmware, Docker, Tailscale, the engine containers and images, the clone, the drop-caches rule (read only)'
08:52:43  tailscale ping -c 1 framework
08:52:43  ssh framework 'checkupdates 2>/dev/null | wc -l; checkupdates >/dev/null 2>&1; echo "checkupdates exit $?"; . /etc/os-release; echo "$PRETTY_NAME"; uname -r; pacman -Q mesa vulkan-radeon docker linux-firmware; cat /sys/module/amdgpu/version 2>/dev/null; tailscale version | head -1; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}" | grep -E "vllm|llama"; sudo -n -l 2>/dev/null | grep -i drop_caches; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && git branch -vv && git status --porcelain | wc -l; df -B1 /srv/models / /var/lib/docker 2>/dev/null | tail -3'
12:16:57  source .state/vllm-layout/step-files/fw-push.sh
12:16:57  : 'vllm-layout slice 2, part B: the Framework'\''s stack read (stack-fw.sh); then the host/ branch pushed to the Framework as hosts-next, its clone onto a local hosts branch at it, the granite and audio rows read back'
12:16:58  ping_host
12:16:58  git -C /home/jaime/experiments/spike-model-engines log --oneline -1 vllm-layout
12:16:58  git -C /home/jaime/experiments/spike-model-engines push framework:repos/spike-model-engines vllm-layout:hosts-next
12:16:58  ssh framework 'cd ~/repos/spike-model-engines && git checkout -B hosts hosts-next && git status -sb | head -1 && git log --oneline -2 && git branch -vv && grep -E "^VLLM_RELEASE=" host/vllm.env && grep -n -A6 -E "^\[(granite-embedding-english-r2-framework|gemma-4-E4B-it-audio-framework)\]" host/vllm-rows; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; du -sh ~/.cache/vllm'
12:18:09  source .state/vllm-layout/step-files/fw-start.sh
12:18:09  : 'vllm-layout slice 2, part B on the Framework: (once, with ROW_STOP_LLAMA=yes) docker stop llama (llama.cpp stays installed). The embed row from the hosts branch: page cache dropped, engines vllm update (which replaces the container when its command differs from the row'\''s, else says docker start starts it), docker start: the first start. Then the container stopped, the page cache dropped, and started again: the cold start. Each start timed to '\''Application startup complete.'\'' and /health 200, MemAvailable and GTT free every 10 s; each start log saved and read; footprint after'
12:18:09  ping_host
12:18:09  ssh framework 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && du -sh ~/.cache/vllm; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -E "vllm|llama"'
12:18:09  ssh framework docker stop llama
12:18:10  drop
12:18:11  memory
12:18:11  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=granite-embedding-english-r2-framework host/engines vllm update; docker start vllm-embed'
12:18:11  vwait first-embed 2026-11-12T17:18:11.177858425Z 900 embed
12:18:40  startlog embed /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-first-embed.log
12:18:40  memory
12:18:40  ping_host
12:18:40  ssh framework docker stop vllm-embed
12:18:43  drop
12:18:43  memory
12:18:43  ssh framework docker start vllm-embed
12:18:43  vwait cold-embed 2026-11-12T17:18:43.622051690Z 900 embed
12:19:04  startlog embed /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-cold-embed.log
12:19:04  footprint
12:19:05  ssh framework 'du -sh ~/.cache/vllm; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -E "vllm|llama"'
12:19:13  source .state/vllm-layout/step-files/fw-probe.sh
12:19:13  : 'vllm-layout slice 2, part B on the Framework: the rows PURPOSES names (embed, then embed audio). /health, /version and /v1/models per port; for embed two embeddings (one input each), for audio one clip (capability-vllm'\''s LibriSpeech 1272-128104-0000, 5.86 s), replies kept in probes/; one warm-up request a row (a 512-word input for embed, a hello for audio); idle 30 s; drop the page cache; memory, each row'\''s footprint and readout since its cold start; the idle floor check (GTT 11.2 GiB, system 12.5 GiB; under either the phase stops)'
12:19:13  ping_host
12:19:13  curl -s http://framework:8002/v1/models
12:19:13  curl -s http://framework:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":"The quick brown fox jumps over the lazy dog."}'
12:19:13  curl -s http://framework:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":"GB10 and the Framework serve the layout'\''s capability rows."}'
12:19:13  : 'warm-up: one 512-word input'
12:19:13  curl -s http://framework:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":"word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word "}'
12:19:43  : 'rows warmed up, idle 30 s'
12:19:43  drop
12:19:43  memory
12:19:43  footprint
12:19:44  readout 2026-11-12T17:18:43.684221293Z
12:19:44  floorcheck 'the idle read (embed)'
12:19:49  source .state/vllm-layout/step-files/fw-start.sh
12:19:49  : 'vllm-layout slice 2, part B on the Framework: (once, with ROW_STOP_LLAMA=yes) docker stop llama (llama.cpp stays installed). The audio row from the hosts branch: page cache dropped, engines vllm update (which replaces the container when its command differs from the row'\''s, else says docker start starts it), docker start: the first start. Then the container stopped, the page cache dropped, and started again: the cold start. Each start timed to '\''Application startup complete.'\'' and /health 200, MemAvailable and GTT free every 10 s; each start log saved and read; footprint after'
12:19:49  ping_host
12:19:49  ssh framework 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && du -sh ~/.cache/vllm; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -E "vllm|llama"'
12:19:49  drop
12:19:49  memory
12:19:49  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-E4B-it-audio-framework host/engines vllm update; docker start vllm-audio'
12:19:50  vwait first-audio 2026-11-12T17:19:49.809663870Z 900 audio
12:20:58  startlog audio /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-first-audio.log
12:20:58  memory
12:20:58  ping_host
12:20:58  ssh framework docker stop vllm-audio
12:21:01  drop
12:21:01  memory
12:21:01  ssh framework docker start vllm-audio
12:21:01  vwait cold-audio 2026-11-12T17:21:01.621873466Z 900 audio
12:22:10  startlog audio /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-cold-audio.log
12:22:10  footprint
12:22:10  ssh framework 'du -sh ~/.cache/vllm; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -E "vllm|llama"'
12:22:17  source .state/vllm-layout/step-files/fw-probe.sh
12:22:17  : 'vllm-layout slice 2, part B on the Framework: the rows PURPOSES names (embed, then embed audio). /health, /version and /v1/models per port; for embed two embeddings (one input each), for audio one clip (capability-vllm'\''s LibriSpeech 1272-128104-0000, 5.86 s), replies kept in probes/; one warm-up request a row (a 512-word input for embed, a hello for audio); idle 30 s; drop the page cache; memory, each row'\''s footprint and readout since its cold start; the idle floor check (GTT 11.2 GiB, system 12.5 GiB; under either the phase stops)'
12:22:17  ping_host
12:22:17  curl -s http://framework:8002/v1/models
12:22:17  curl -s http://framework:8001/v1/models
12:22:17  curl -s http://framework:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":"The quick brown fox jumps over the lazy dog."}'
12:22:17  curl -s http://framework:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":"GB10 and the Framework serve the layout'\''s capability rows."}'
12:22:17  : 'warm-up: one 512-word input'
12:22:17  curl -s http://framework:8002/v1/embeddings -H 'Content-Type: application/json' -d '{"model":"ibm-granite/granite-embedding-english-r2","input":"word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word word "}'
12:22:17  curl -s http://framework:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-audio.json
12:22:19  : warm-up
12:22:19  curl -s http://framework:8001/v1/chat/completions -H 'Content-Type: application/json' -d '{"model":"google/gemma-4-E4B-it","messages":[{"role":"user","content":"Say hello in one sentence."}],"max_tokens":64}'
12:22:49  : 'rows warmed up, idle 30 s'
12:22:49  drop
12:22:50  memory
12:22:50  footprint
12:22:50  readout 2026-11-12T17:18:43.684221293Z
12:22:50  footprint
12:22:51  readout 2026-11-12T17:21:01.690721244Z
12:22:51  floorcheck 'the idle read (embed audio)'
12:43:51  source .state/vllm-layout/step-files/fw-sweep.sh
12:43:51  : 'vllm-layout-fw-embed-sweep: the Framework'\''s granite row alone at 1, 4, 16, 32, 64 and 128 streams (bench/vllm-layout-embed-sweep.yaml), 30 s a level, the audio row loaded and idle, under watch with GTT 11.2 GiB and system 12.5 GiB every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
12:43:51  ping_host
12:43:51  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
12:43:51  memory
12:43:51  cell vllm-layout-fw-embed-sweep vllm-layout-embed-sweep ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
12:47:44  v_after vllm-layout-fw-embed-sweep 2026-11-12T17:43:51Z
12:47:56  source .state/vllm-layout/step-files/fw-pair.sh
12:47:56  : 'vllm-layout-fw-pair-a4e16: the Framework'\''s audio and embedding rows together, audio 4 + embedding 16 streams (bench/role-split-mixed-audio.yaml and -embed.yaml, streams from GUIDELLM__SPEC__PROFILE__STREAMS), 240 s each, the two GuideLLM processes started together, each under watch with GTT 11.2 GiB and system 12.5 GiB every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
12:47:56  ping_host
12:47:56  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
12:47:56  memory
12:47:56  cell vllm-layout-fw-pair-a4e16-embed role-split-mixed-embed ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
12:47:56  cell vllm-layout-fw-pair-a4e16-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
12:52:30  v_after vllm-layout-fw-pair-a4e16 2026-11-12T17:47:56Z
13:11:05  source .state/vllm-layout/step-files/fw-cell.sh
13:11:05  : 'vllm-layout-fw-audio-4: the Framework'\''s audio row at 4 streams (bench/role-split-mixed-audio.yaml, GUIDELLM__SPEC__PROFILE__STREAMS=4, 240 s) beside granite, idle when EMBED_SCENARIO is empty, else at bench/none.yaml (a constant rate, 240 s), the processes started together, each under watch with GTT 11.2 GiB and system 12.5 GiB every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
13:11:05  ping_host
13:11:05  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
13:11:05  memory
13:11:05  cell vllm-layout-fw-audio-4-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
13:14:58  v_after vllm-layout-fw-audio-4 2026-11-12T18:11:05Z
13:15:09  source .state/vllm-layout/step-files/fw-cell.sh
13:15:09  : 'vllm-layout-fw-pair-a4r8: the Framework'\''s audio row at 4 streams (bench/role-split-mixed-audio.yaml, GUIDELLM__SPEC__PROFILE__STREAMS=4, 240 s) beside granite, idle when EMBED_SCENARIO is empty, else at bench/vllm-layout-embed-rate-floor.yaml (a constant rate, 240 s), the processes started together, each under watch with GTT 11.2 GiB and system 12.5 GiB every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
13:15:09  ping_host
13:15:09  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
13:15:09  memory
13:15:09  cell vllm-layout-fw-pair-a4r8-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
13:15:09  cell vllm-layout-fw-pair-a4r8-embed vllm-layout-embed-rate-floor ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
13:19:31  v_after vllm-layout-fw-pair-a4r8 2026-11-12T18:15:09Z
13:19:42  source .state/vllm-layout/step-files/fw-cell.sh
13:19:42  : 'vllm-layout-fw-pair-a4r34: the Framework'\''s audio row at 4 streams (bench/role-split-mixed-audio.yaml, GUIDELLM__SPEC__PROFILE__STREAMS=4, 240 s) beside granite, idle when EMBED_SCENARIO is empty, else at bench/vllm-layout-embed-rate-4x.yaml (a constant rate, 240 s), the processes started together, each under watch with GTT 11.2 GiB and system 12.5 GiB every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
13:19:42  ping_host
13:19:42  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
13:19:42  memory
13:19:42  cell vllm-layout-fw-pair-a4r34-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
13:19:42  cell vllm-layout-fw-pair-a4r34-embed vllm-layout-embed-rate-4x ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
13:24:04  v_after vllm-layout-fw-pair-a4r34 2026-11-12T18:19:42Z
13:26:21  source .state/vllm-layout/step-files/fw-cell.sh
13:26:21  : 'vllm-layout-fw-stress-a8r34: the Framework'\''s audio row at 8 streams (bench/role-split-mixed-audio.yaml, GUIDELLM__SPEC__PROFILE__STREAMS=8, 240 s or its 876 rows) beside granite, idle when EMBED_SCENARIO is empty, else at bench/vllm-layout-embed-rate-4x.yaml (a constant rate, 240 s), the processes started together, each under watch with GTT 11.2 GiB and system 12.5 GiB every 10 s, cap 10 min; the laptop'\''s available memory read first; then cache drop, memory, each row'\''s footprint and readout since the cell'\''s start, errors saved, the floor check'
13:26:21  ping_host
13:26:21  ssh framework 'docker ps --format "{{.Names}} {{.Status}}"'
13:26:21  memory
13:26:21  cell vllm-layout-fw-stress-a8r34-embed vllm-layout-embed-rate-4x ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
13:26:21  cell vllm-layout-fw-stress-a8r34-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
13:30:44  v_after vllm-layout-fw-stress-a8r34 2026-11-12T18:26:21Z
13:31:02  source .state/vllm-layout/step-files/fw-bf16-start.sh
13:31:02  : 'vllm-layout slice 2, part B stage 3 on the Framework: vllm-audio stopped for the BF16 reference (its 0.18 off the pool; granite'\''s 0.03 stays), the page cache dropped, the BF16 26B-A4B row (gemma-4-26B-A4B-it-vision-framework, 0.60, vllm-vision, 8000) from the hosts branch by engines vllm update, then docker start: the start timed to '\''Application startup complete.'\'' and /health 200, MemAvailable and GTT free every 10 s; the start log saved and read; /version, /v1/models, the image probe, one warm-up; idle 30 s, drop, memory, footprint, readout, the idle floor check'
13:31:03  ping_host
13:31:03  ssh framework 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && grep -n -A6 "^\[gemma-4-26B-A4B-it-vision-framework\]" host/vllm-rows; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
13:31:03  ssh framework docker stop vllm-audio
13:31:05  drop
13:31:05  memory
13:31:05  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-26B-A4B-it-vision-framework host/engines vllm update; docker start vllm-vision'
13:31:06  vwait bf16-vision 2026-11-12T18:31:05.959020169Z 1200 vision
13:32:14  startlog vision /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-bf16-vision.log
13:32:15  memory
13:32:15  curl -s http://framework:8000/v1/models
13:32:15  : 'the image probe: capability-vllm'\''s PNG, as part A'\''s'
13:32:15  curl -s http://framework:8000/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-bf16-image.json
13:32:47  : 'BF16 row warmed up, idle 30 s'
13:32:47  drop
13:32:48  memory
13:32:48  footprint
13:32:48  readout 2026-11-12T18:31:06.164367328Z
13:32:48  floorcheck 'the idle read (BF16 vision + embed)'
13:33:02  source .state/vllm-layout/step-files/fw-bf16-mmmu.sh
13:33:02  : 'vllm-layout Behavior 4, the BF16 reference (g2-mmmu.sh on the Framework): lm-eval mmmu_val (900 questions; max_images 7, chat template applied, greedy, max_gen_toks 1024, seeds 0,1234,1234,1234) on the Framework'\''s BF16 26B-A4B row, num_concurrent 16, the NVFP4 run'\''s settings but base_url and model, under watch with GTT 11.2 GiB and system 12.5 GiB every 10 s, cap 45 min; then readout since its start, cache drop, memory, footprint, lm-eval'\''s errored count and placeholders'
13:33:02  ping_host
13:33:02  curl -s -o /dev/null -w '/health %{http_code}\n' http://framework:8000/health
13:33:02  curl -s http://framework:8000/v1/models
13:33:02  ssh framework 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm-vision'
13:33:02  memory
13:33:02  watch vllm-layout-bf16-mmmu timeout 45m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=google/gemma-4-26B-A4B-it,base_url=http://framework:8000/v1/chat/completions,num_concurrent=16,max_images=7,timeout=1800,max_retries=1 --tasks mmmu_val --apply_chat_template --gen_kwargs temperature=0,max_gen_toks=1024 --seed 0,1234,1234,1234 --log_samples --output_path .state/vllm-layout/lm-eval/bf16-mmmu
14:18:09  readout 2026-11-12T18:33:02Z
14:18:09  drop
14:18:09  memory
14:18:09  footprint
14:18:10  floorcheck 'after bf16-mmmu'
14:18:44  source .state/vllm-layout/step-files/fw-restore.sh
14:18:44  : 'vllm-layout slice 2, part B stage 3 on the Framework, after the BF16 mmmu_val run hit its 45 min cap (869 of 900, no results written): the BF16 row stopped, its container and weights kept for the architect'\''s decision; vllm-audio started again, its start timed; the audio probe; idle 30 s, drop, memory, each row'\''s footprint and readout, the idle floor check on both pools'
14:18:44  ping_host
14:18:44  ssh framework docker stop vllm-vision
14:18:47  ssh framework 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
14:18:47  drop
14:18:47  memory
14:18:47  ssh framework docker start vllm-audio
14:18:47  vwait restart-audio 2026-11-12T19:18:47.442563864Z 900 audio
14:19:56  startlog audio /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-restart-audio.log
14:19:56  curl -s http://framework:8001/v1/models
14:19:56  curl -s http://framework:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-audio.json
14:20:28  : 'rows warmed up, idle 30 s'
14:20:28  drop
14:20:28  memory
14:20:28  footprint
14:20:29  readout 2026-11-12T17:18:43.684221293Z
14:20:29  footprint
14:20:29  readout 2026-11-12T19:18:47.509895896Z
14:20:30  floorcheck 'the idle read (embed audio, BF16 stopped)'
14:33:19  source .state/vllm-layout/step-files/fw-bf16-start.sh
14:33:19  : 'vllm-layout slice 2, part B stage 3 on the Framework: vllm-audio stopped for the BF16 reference (its 0.18 off the pool; granite'\''s 0.03 stays), the page cache dropped, the BF16 26B-A4B row (gemma-4-26B-A4B-it-vision-framework, 0.60, vllm-vision, 8000) from the hosts branch by engines vllm update, then docker start: the start timed to '\''Application startup complete.'\'' and /health 200, MemAvailable and GTT free every 10 s; the start log saved and read; /version, /v1/models, the image probe, one warm-up; idle 30 s, drop, memory, footprint, readout, the idle floor check'
14:33:19  ping_host
14:33:19  ssh framework 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && grep -n -A6 "^\[gemma-4-26B-A4B-it-vision-framework\]" host/vllm-rows; docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
14:33:19  ssh framework docker stop vllm-audio
14:33:22  drop
14:33:22  memory
14:33:22  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-26B-A4B-it-vision-framework host/engines vllm update; docker start vllm-vision'
14:33:22  vwait bf16-vision 2026-11-12T19:33:22.296922634Z 1200 vision
14:34:37  startlog vision /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-bf16-vision.log
14:34:37  memory
14:34:37  curl -s http://framework:8000/v1/models
14:34:37  : 'the image probe: capability-vllm'\''s PNG, as part A'\''s'
14:34:37  curl -s http://framework:8000/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-bf16-image.json
14:35:09  : 'BF16 row warmed up, idle 30 s'
14:35:09  drop
14:35:10  memory
14:35:10  footprint
14:35:10  readout 2026-11-12T19:33:22.495097413Z
14:35:11  floorcheck 'the idle read (BF16 vision + embed)'
14:35:14  source .state/vllm-layout/step-files/fw-bf16-mmmu.sh
14:35:14  : 'vllm-layout Behavior 4, the BF16 reference (g2-mmmu.sh on the Framework): lm-eval mmmu_val (900 questions; max_images 7, chat template applied, greedy, max_gen_toks 1024, seeds 0,1234,1234,1234) on the Framework'\''s BF16 26B-A4B row, num_concurrent 16, the NVFP4 run'\''s settings but base_url and model, under watch with GTT 11.2 GiB and system 12.5 GiB every 10 s, cap 60m; then readout since its start, cache drop, memory, footprint, lm-eval'\''s errored count and placeholders'
14:35:15  ping_host
14:35:15  curl -s -o /dev/null -w '/health %{http_code}\n' http://framework:8000/health
14:35:15  curl -s http://framework:8000/v1/models
14:35:15  ssh framework 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm-vision'
14:35:15  memory
14:35:15  watch vllm-layout-bf16-mmmu timeout 60m env MISE_ENV=bench mise exec -- lm_eval run --model local-chat-completions --model_args model=google/gemma-4-26B-A4B-it,base_url=http://framework:8000/v1/chat/completions,num_concurrent=16,max_images=7,timeout=1800,max_retries=1 --tasks mmmu_val --apply_chat_template --gen_kwargs temperature=0,max_gen_toks=1024 --seed 0,1234,1234,1234 --log_samples --output_path .state/vllm-layout/lm-eval/bf16-mmmu
15:26:34  readout 2026-11-12T19:35:15Z
15:26:34  drop
15:26:34  memory
15:26:35  footprint
15:26:35  floorcheck 'after bf16-mmmu'
15:26:57  source .state/vllm-layout/step-files/fw-bf16-remove.sh
15:26:57  : 'vllm-layout slice 2, part B stage 3 on the Framework, after the BF16 reference (escalation 2, answer 2): the BF16 row'\''s container stopped and removed through the suite (engines vllm uninstall names it; the images and compile cache stay, since vllm-embed and vllm-audio are left), the BF16 26B-A4B weights removed from the store with hf cache rm (dry run first); vllm-audio started again, its start timed; the audio probe; idle 30 s, drop, memory, each row'\''s footprint and readout, the idle floor check on both pools'
15:26:57  ping_host
15:26:57  ssh framework 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
15:26:57  ssh framework docker stop vllm-vision
15:26:59  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-26B-A4B-it-vision-framework host/engines vllm uninstall'
15:27:00  ssh framework 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -E "vllm|llama"; du -sh ~/.cache/vllm'
15:27:00  ssh framework 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --dry-run model/google/gemma-4-26B-A4B-it 2>&1 | grep -v Hint'
15:27:00  ssh framework 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --yes model/google/gemma-4-26B-A4B-it 2>&1 | grep -v Hint; mise exec -- hf cache ls 2>&1 | grep -v Hint; du -sb /srv/models; df -B1 /srv/models | tail -1'
15:27:01  drop
15:27:01  memory
15:27:01  ssh framework docker start vllm-audio
15:27:01  vwait restart-audio 2026-11-12T20:27:01.318611377Z 900 audio
15:28:09  startlog audio /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-restart-audio.log
15:28:10  curl -s http://framework:8001/v1/models
15:28:10  curl -s http://framework:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-audio.json
15:28:41  : 'rows warmed up, idle 30 s'
15:28:41  drop
15:28:42  memory
15:28:42  footprint
15:28:42  readout 2026-11-12T17:18:43.684221293Z
15:28:43  footprint
15:28:43  readout 2026-11-12T20:27:01.386487774Z
15:28:43  floorcheck 'the idle read (embed audio, BF16 removed)'
15:32:47  source .state/vllm-layout/step-files/fw-swap.sh
15:32:47  : 'vllm-layout slice 2, part B stage 3 on the Framework: the host/ branch pushed as hosts-next, the clone onto a local hosts branch at it, the rows read back; the audio row from the new branch (engines vllm update, which replaces vllm-audio under the row'\''s new max-num-seqs), the start timed, its cap read from the start log; the audio probe; idle 30 s, drop, memory, each row'\''s footprint and readout, the idle floor check on both pools'
15:32:47  ping_host
15:32:47  ssh framework 'cd ~/repos/spike-model-engines && git status --porcelain | wc -l && git status -sb | head -1 && git log --oneline -1 && docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"'
15:32:47  git -C /home/jaime/experiments/spike-model-engines log --oneline -2 vllm-layout
15:32:47  git -C /home/jaime/experiments/spike-model-engines push framework:repos/spike-model-engines vllm-layout:hosts-next
15:32:47  ssh framework 'cd ~/repos/spike-model-engines && git checkout -B hosts hosts-next && git status -sb | head -1 && git log --oneline -2 && grep -E "^\[.*-(gb10|framework)\]" host/vllm-rows && grep -n -A6 -E "^\[(granite-embedding-english-r2-framework|gemma-4-E4B-it-audio-framework)\]" host/vllm-rows && grep -E "^VLLM_RELEASE=" host/vllm.env'
15:32:47  drop
15:32:48  memory
15:32:48  ssh framework 'cd ~/repos/spike-model-engines && VLLM_MODEL=gemma-4-E4B-it-audio-framework host/engines vllm update; docker start vllm-audio'
15:32:48  vwait swap-audio 2026-11-12T20:32:48.157619460Z 900 audio
15:35:13  startlog audio /home/jaime/experiments/spike-model-layout/.state/vllm-layout/framework-swap-audio.log
15:35:13  curl -s http://framework:8001/v1/models
15:35:13  curl -s http://framework:8001/v1/chat/completions -H 'Content-Type: application/json' -d @/home/jaime/experiments/spike-model-layout/.state/vllm-layout/probes/req-audio.json
15:35:47  : 'rows warmed up, idle 30 s'
15:35:47  drop
15:35:48  memory
15:35:48  footprint
15:35:48  readout 2026-11-12T17:18:43.684221293Z
15:35:49  footprint
15:35:49  readout 2026-11-12T20:32:48.657928326Z
15:35:49  floorcheck 'the idle read (embed audio, the standing layout)'
15:35:49  ssh framework 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker image ls --format "{{.Repository}}:{{.Tag}} {{.ID}}" | grep -E "vllm|llama"; du -sh ~/.cache/vllm'
15:39:17  source .state/vllm-layout/step-files/llama-remove.sh
15:39:17  : 'vllm-layout slice 3, part A (Behavior 10): llama.cpp leaves the host. The llama container and every llama.cpp image removed through the suite (engines llama uninstall, from the clone'\''s hosts branch; /srv/models stays); then the GGUF repositories removed from the model store with hf cache rm, dry run first, every safetensors repo kept; sizes before and after; no llama container, image or GGUF left (docker ps -a, docker images, hf cache ls); the vLLM rows'\'' /health read after'
15:39:17  ping_host
15:39:17  ssh framework 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}"; docker system df; df -B1 /srv/models | tail -1; du -sb /srv/models'
15:39:17  : 'the store'\''s repositories by file type: a GGUF repository holds .gguf files and no .safetensors'
15:39:17  ssh framework 'for r in /srv/models/models--*; do printf "%s gguf %s safetensors %s\n" "${r##*/}" "$(find -L "$r/snapshots" -name "*.gguf" | wc -l)" "$(find -L "$r/snapshots" -name "*.safetensors" | wc -l)"; done'
15:39:17  ssh framework 'cd ~/repos/spike-model-engines && host/engines llama uninstall'
15:39:19  ssh framework 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}"; docker images --format "{{.Repository}}:{{.Tag}} {{.ID}} {{.Size}}"; docker system df'
15:39:19  ssh framework 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --dry-run model/ggml-org/gemma-4-E4B-it-GGUF model/ggml-org/gpt-oss-120b-GGUF model/google/gemma-4-26B-A4B-it-qat-q4_0-gguf model/mrutkows/granite-embedding-english-r2-GGUF 2>&1 | grep -v Hint'
15:39:19  ssh framework 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache rm --yes model/ggml-org/gemma-4-E4B-it-GGUF model/ggml-org/gpt-oss-120b-GGUF model/google/gemma-4-26B-A4B-it-qat-q4_0-gguf model/mrutkows/granite-embedding-english-r2-GGUF 2>&1 | grep -v Hint'
15:39:19  ssh framework 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache ls 2>&1 | grep -v Hint; du -sb /srv/models; df -B1 /srv/models | tail -1; ls /srv/models; echo "gguf files left: $(find -L /srv/models -name "*.gguf" | wc -l)"'
15:39:20  ssh framework 'docker ps -a --format "{{.Names}} {{.Image}} {{.Status}}" | grep -i llama || echo "no llama container"; docker images --format "{{.Repository}}:{{.Tag}}" | grep -i llama || echo "no llama.cpp image"'
15:40:03  source .state/vllm-layout/step-files/before-reboot.sh
15:40:03  : 'vllm-layout slice 3, part A (Behavior 11, before-state): every standing vLLM container'\''s restart policy, published ports and state; the nonlocal-bind sysctl and /etc/sysctl.d; on the Framework /etc/modprobe.d (ttm.conf, amdgpu.conf), the GTT the GPU reports, and the current boot'\''s gttsize deprecation line; boot time and kernel; read only'
15:40:03  ping_host
15:40:03  ssh framework 'for c in $(docker ps -a --format "{{.Names}}"); do docker inspect --format "{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} max={{.HostConfig.RestartPolicy.MaximumRetryCount}} status={{.State.Status}} started={{.State.StartedAt}} restarts={{.RestartCount}} image={{.Config.Image}} ports={{json .HostConfig.PortBindings}}" "$c"; done'
15:40:03  ssh framework 'systemctl is-enabled docker.service docker.socket tailscaled.service 2>&1; systemctl show -p After -p Wants docker.service | tr " " "\n" | grep -iE "tailscale|network-online" || echo "docker.service: no ordering on tailscaled"'
15:40:03  ssh framework 'uname -r; uptime -s; sysctl net.ipv4.ip_nonlocal_bind; ls -la /etc/sysctl.d/; for f in /etc/sysctl.d/*; do echo "--- $f"; cat "$f"; done 2>/dev/null'
15:40:03  ssh framework 'ls -la /etc/modprobe.d/; for f in /etc/modprobe.d/ttm.conf /etc/modprobe.d/amdgpu.conf; do echo "--- $f"; cat "$f"; done; cat /sys/module/ttm/parameters/pages_limit; for f in /sys/class/drm/card*/device/mem_info_gtt_total; do echo "$f $(cat "$f")"; done; journalctl -k -b --no-pager | grep -i gttsize || echo "journalctl -k -b: no gttsize line (exit $?)"'
15:40:03  ssh framework 'command -v limine-mkinitcpio; ls -la /boot 2>&1 | head; findmnt -no TARGET,SOURCE,FSTYPE /boot 2>&1'
16:19:14  source .state/vllm-layout/step-files/after-reboot.sh
16:19:14  : 'vllm-layout slice 3, part B (Behavior 11, after the reboot): boot time and kernel, the nonlocal-bind sysctl, every container with its restart policy, StartedAt and restart count; each standing row'\''s /health, /v1/models and the start log'\''s max_num_seqs, KV and startup lines; on the Framework /etc/modprobe.d, ttm pages_limit, the GTT the GPU reports and the boot'\''s gttsize lines; then 30 s idle, a cache drop, memory and the floor check; read only, no root beyond the drop-caches rule'
16:19:14  ping_host
16:19:14  ssh framework 'uptime -s; uptime; uname -r; sysctl net.ipv4.ip_nonlocal_bind'
16:19:14  ssh framework 'for c in $(docker ps -a --format "{{.Names}}"); do docker inspect --format "{{.Name}} restart={{.HostConfig.RestartPolicy.Name}} status={{.State.Status}} started={{.State.StartedAt}} restarts={{.RestartCount}} image={{.Config.Image}} ports={{json .HostConfig.PortBindings}}" "$c"; done'
16:19:14  curl -s -o /dev/null -w '/health %{http_code}\n' --max-time 10 http://framework:8001/health
16:19:14  curl -s --max-time 10 http://framework:8001/v1/models
16:19:14  ssh framework 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-audio) vllm-audio 2>&1'
16:19:14  curl -s -o /dev/null -w '/health %{http_code}\n' --max-time 10 http://framework:8002/health
16:19:14  curl -s --max-time 10 http://framework:8002/v1/models
16:19:14  ssh framework 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm-embed) vllm-embed 2>&1'
16:19:14  ssh framework 'ls -la /etc/modprobe.d/; cat /etc/modprobe.d/ttm.conf; echo "pages_limit $(cat /sys/module/ttm/parameters/pages_limit)"; for f in /sys/class/drm/card*/device/mem_info_gtt_total; do echo "$f $(cat "$f")"; done; journalctl -k -b --no-pager | grep -i gttsize || echo "journalctl -k -b: no gttsize line (grep exit $?)"; journalctl -k -b --no-pager | grep -iE "amdgpu.*(GTT|gtt)|ttm" | head -5'
16:19:14  memory
16:19:44  drop
16:19:45  memory
16:19:45  floorcheck 'idle after the reboot'
16:27:42  floors framework
16:27:42  memory
16:27:42  floors framework
16:27:42  floors framework
16:27:42  cell vllm-layout-standing-embed vllm-layout-embed-rate-4x ibm-granite/granite-embedding-english-r2 ibm-granite/granite-embedding-english-r2
16:27:42  cell vllm-layout-standing-audio role-split-mixed-audio google/gemma-4-E4B-it google/gemma-4-E4B-it
16:32:10  floors framework
16:32:10  memory
16:32:10  footprint 2026-11-12T21:32:10Z
16:32:10  readout 2026-11-12T21:27:42Z
16:32:11  floors framework
16:32:11  memory
16:32:11  footprint 2026-11-12T21:32:11Z
16:32:11  readout 2026-11-12T21:27:42Z
```

### Commands not in a step log

The architect's laptop setup, in his shell with the helpers sourced (the Framework's step log,
08:49:13 to 08:50:24), for the gated GPQA dataset:

```
08:49:13  hf --help
08:49:41  mise install pipx:huggingface_hub
08:49:57  mise install uv
08:50:00  mise use -g uv
08:50:03  mise install pipx:huggingface_hub
08:50:14  mise use -g pipx:huggingface_hub
08:50:19  hf --help
08:50:24  hf auth login
```

The architect's root steps (A.1, I.2) and reboots ran in his own shells on each host, as prepared
in `.state/vllm-layout/root-steps.md` and `root-steps-slice3.md`; no step log holds them:

```sh
# gb10-1 and gb10-2, slice 1
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y
# the Framework, slice 1
omarchy update
# the Framework, slice 3
sudo rm /etc/modprobe.d/amdgpu.conf
sudo limine-mkinitcpio
# each host in turn, gb10-2, the Framework, gb10-1, after the session's timer started
sudo reboot
```

The session's commands on the laptop, outside the step helpers:

```sh
# the reboot timer, one a host, started before each reboot (I.3)
.state/vllm-layout/step-files/reboot-timing.sh gb10-2 8000
.state/vllm-layout/step-files/reboot-timing.sh framework 8001 8002
.state/vllm-layout/step-files/reboot-timing.sh gb10-1 8000
# the paired tests (C.4, G.2)
cut='select(.filter == "flexible-extract") | [.doc_id, .prompt_hash, .exact_match] | @tsv'
awk -f bench/paired.awk <(jq -r "$cut" .state/vllm-layout/lm-eval/bf16-gpqa/openai__gpt-oss-120b/samples_*.jsonl) <(jq -r "$cut" .state/vllm-layout/lm-eval/fp8-gpqa/openai__gpt-oss-120b/samples_*.jsonl)
for len in 32768 65536; do cut="[.doc_id, .prompt_hash, .[\"$len\"]] | @tsv"; awk -f bench/paired.awk <(jq -r "$cut" .state/vllm-layout/lm-eval/bf16-niah-$len/openai__gpt-oss-120b/samples_*.jsonl) <(jq -r "$cut" .state/vllm-layout/lm-eval/fp8-niah-$len/openai__gpt-oss-120b/samples_*.jsonl); done
cut='[.doc.id, .prompt_hash, .acc] | @tsv'
awk -f bench/paired.awk <(jq -r "$cut" .state/vllm-layout/lm-eval/bf16-mmmu/google__gemma-4-26B-A4B-it/samples_*.jsonl) <(jq -r "$cut" .state/vllm-layout/lm-eval/nvfp4-mmmu/nvidia__Gemma-4-26B-A4B-NVFP4/samples_*.jsonl)
# the paired differences' intervals (C.5, G.2)
awk 'BEGIN { split("GPQA 198 24 15|RULER32k 50 5 1|RULER64k 50 2 3|mmmu_val 900 78 72", r, "|"); for (i=1;i<=4;i++) { split(r[i], f, " "); n=f[2]; b=f[3]; c=f[4]; d=(c-b)/n; se=sqrt(b+c-(b-c)^2/n)/n; printf "%s: difference %+.4f, se %.4f, 95%% interval %+.4f to %+.4f\n", f[1], d, se, d-1.96*se, d+1.96*se } }'
```

The figures' re-read, 21:38:06Z, into `.state/vllm-layout/jq-figures-slice4.txt`: every cell's
table through `levels.jq` and every paired test, in one command:

```sh
{ date -u +%FT%TZ; for f in gb10-1:agent:vllm-layout-fp8-agent gb10-1:agent:vllm-layout-standing-agent gb10-2:vision:vllm-layout-g2-vision-4 gb10-2:audio:vllm-layout-g2-audio-4 gb10-2:vision:vllm-layout-g2-pair-4-vision gb10-2:audio:vllm-layout-g2-pair-4-audio gb10-2:vision:vllm-layout-g2-pair-8-vision gb10-2:audio:vllm-layout-g2-pair-8-audio gb10-2:vision:vllm-layout-g2-pair-v4a2-vision gb10-2:audio:vllm-layout-g2-pair-v4a2-audio gb10-2:vision:vllm-layout-g2-pair-v2a2-vision gb10-2:audio:vllm-layout-g2-pair-v2a2-audio gb10-2:vision:vllm-layout-g2-pair-v2a4-vision gb10-2:audio:vllm-layout-g2-pair-v2a4-audio gb10-2:vision:vllm-layout-g2-vision-capacity gb10-2:vision:vllm-layout-standing-vision framework:embed:vllm-layout-fw-embed-sweep framework:audio:vllm-layout-fw-pair-a4e16-audio framework:embed:vllm-layout-fw-pair-a4e16-embed framework:audio:vllm-layout-fw-audio-4-audio framework:audio:vllm-layout-fw-pair-a4r8-audio framework:embed:vllm-layout-fw-pair-a4r8-embed framework:audio:vllm-layout-fw-pair-a4r34-audio framework:embed:vllm-layout-fw-pair-a4r34-embed framework:audio:vllm-layout-fw-stress-a8r34-audio framework:embed:vllm-layout-fw-stress-a8r34-embed framework:audio:vllm-layout-standing-audio framework:embed:vllm-layout-standing-embed; do IFS=: read -r h p n <<<"$f"; echo "== .state/measure/$h/$n.json ($p)"; jq -r --arg purpose "$p" -f bench/levels.jq ".state/measure/$h/$n.json"; done; echo "== paired: GPQA"; cut='select(.filter == "flexible-extract") | [.doc_id, .prompt_hash, .exact_match] | @tsv'; awk -f bench/paired.awk <(jq -r "$cut" .state/vllm-layout/lm-eval/bf16-gpqa/openai__gpt-oss-120b/samples_*.jsonl) <(jq -r "$cut" .state/vllm-layout/lm-eval/fp8-gpqa/openai__gpt-oss-120b/samples_*.jsonl); for len in 32768 65536; do echo "== paired: RULER $len"; cut="[.doc_id, .prompt_hash, .[\"$len\"]] | @tsv"; awk -f bench/paired.awk <(jq -r "$cut" .state/vllm-layout/lm-eval/bf16-niah-$len/openai__gpt-oss-120b/samples_*.jsonl) <(jq -r "$cut" .state/vllm-layout/lm-eval/fp8-niah-$len/openai__gpt-oss-120b/samples_*.jsonl); done; echo "== paired: mmmu_val"; cut='[.doc.id, .prompt_hash, .acc] | @tsv'; awk -f bench/paired.awk <(jq -r "$cut" .state/vllm-layout/lm-eval/bf16-mmmu/google__gemma-4-26B-A4B-it/samples_*.jsonl) <(jq -r "$cut" .state/vllm-layout/lm-eval/nvfp4-mmmu/nvidia__Gemma-4-26B-A4B-NVFP4/samples_*.jsonl); } > .state/vllm-layout/jq-figures-slice4.txt 2>&1
```
