# Finding: gpt-oss-120b on vLLM v0.33.0 against llama.cpp's agent-only section on gb10-1

Measured 2026-11-11, task `agent-vllm`. This finding is dated: every figure holds for the
versions, stack, rows and network path below, on that day, and nothing after it.

**What it establishes.** The finding answers evidence 6: the agent model alone on one GB10
(gb10-1), served by llama.cpp's agent-only section (c 1,179,648 over 16 slots, unified) and by two
vLLM v0.33.0 rows in a container, both at max-model-len 131,072 and 16 sequences: **BF16**
(`gpt-oss-120b-agent`, KV in the checkpoint's BF16, gpu-memory-utilization 0.80) and **FP8**
(`gpt-oss-120b-agent-fp8`, KV in fp8 e4m3, kv-cache-memory-bytes 32,993,476,982). In one session,
on the same host, one engine at a time, it measures speed and ITL at the agent's target of 4
sessions and at every level of role-split's S-agent sweep, TTFT under multi-turn load, memory and
the margin above the floor, KV tokens per GiB, 131,072-token sessions per host, cold start, the
backends, the probes and the errors (sections C to J).

| At the target of 4 sessions (F) | llama.cpp, agent-only | vLLM BF16 (0.80) | vLLM FP8 (fixed bytes) |
| --- | --- | --- | --- |
| Output tok/s (completed turns) | 55.85 | 55.85 | **65.16** |
| ITL median (p95) | 54.44 ms (66.12) | 50.03 ms (55.49) | 49.55 ms (51.27) |
| TTFT median | 2,258 ms | 574 ms | 566 ms |
| Meets the floor (ITL ≤100 ms) through | 4 sessions | 8 | **12** |
| KV cache, tokens (I) | 1,179,648 | 846,411 | **1,733,910** |
| 131,072-token sessions in the cache (c) | 9 | 6 (6.46) | **13** (13.23) |
| Pool idle / lowest under load (floor 12.2 GiB) | 13.66 / 12.59 GiB | **15.88 / 15.46** | 13.88 / 13.92 GiB (12.52 during its start) |
| Cold start (C) | **48.4 s** (load) | 503.1 s (first start 555.9 s) | 530.7 s |
| Errors | 0 | 0 errored; 3 Harmony warnings | 0 |

It also found that:

- **The brief's premise for the capacity cell changed.** The brief computed the BF16 row at about
  494,000 tokens from v0.32.0's accounting (25.71 GiB, 493,523 tokens: 55,936 bytes a token, c),
  so 8 concurrent requests of 65,536 tokens (524,288 in all) were meant to make it queue. v0.33.0
  counts about **38,058 bytes a token in BF16 (c, from 30.0 GiB / 846,411)** and **19,028 in
  FP8 (c, from 32,993,476,982 bytes / 1,733,910)**, so BF16 held 846,411 tokens and FP8 held
  1,733,910, not the computed 1,179,648 (c). Both rows held all 8 requests at once with no
  preemption, and the capacity cell tested neither row over its cache (H, I.2).
- In the capacity cells the 8 long prompts **prefilled one at a time**, about 23.5 s each (c), so
  TTFT ran from 22 to 193 s; the waiting count of 7 was the prefill queue, with the KV cache at
  7.8% and 3.4% (H).
- The BF16 row's KV cache depends on the start: the first start, which compiled, gave 25.7 GiB and
  725,243 tokens; the timed restart, from the compile cache, gave 30.0 GiB and 846,411 (D, L.1).
- Every vLLM start contacted the Hugging Face hub for metadata ("Fetching 14 files" and the
  unauthenticated-request warning) and downloaded no model file (A.3).
- Both rows answered the reasoning and tool-call probes, the reasoning in `reasoning`, not
  `reasoning_content` (J).

It decides nothing.

**The conclusion, as evidence (the architect's framing).** The architect agreed this framing of
the figures; the spike records it and decides nothing.

- On this session's figures, **vLLM is the stronger agent engine on gb10-1.**
- **The architect's view:** vLLM is the more attractive engine for the agent, chiefly for its
  concurrency (F: the floor met through 8 and 12 sessions against llama.cpp's 4).
- **The FP8 row leads the BF16 row**: it met the floor through 12 sessions against 8, gave 65.16
  tok/s at the target of 4 against 55.85, and its cache holds about 13 sessions of 131,072 tokens
  (c) against 6. That holds if its output quality matches BF16's.
- **The one open item is FP8's output quality.** The FP8 KV cache runs uncalibrated, at scale 1.0,
  and only the two probes and the error counts checked it. An accuracy check of FP8 against BF16
  would settle the choice; it is outside this task, since it would be a new tool (N).
- **Cold start is an accepted trade.** vLLM starts in about 500 to 530 s against llama.cpp's 48 s.
  For the agent, the architect would rather accept a longer cold start in exchange for better
  concurrency and overall performance, so the start is a trade accepted for a resident agent, not a
  qualifier on the choice (**the architect's preference**). The on-demand task takes up loading
  on demand. The start is mostly GB10's per-tensor mmap-copy cost in weight loading, which a
  merged upstream fix addresses in v0.34.0, not in v0.33.0 (C); the pin stays v0.33.0.
- llama.cpp leads at 1 stream: 37.24 tok/s and ITL 20.07 ms, against 27.93 / 29.65 ms (BF16) and
  32.58 / 28.97 ms (FP8) (F).
- Long prompts arriving together prefill serially on vLLM (H).
- BF16 at 0.80 is the cautious middle: it met the floor through 8 sessions, raises no quality
  question, and leaves 3.68 GiB above the floor idle (c).

"Meets the floor through" is the highest level whose ITL median is ≤100 ms. Under role-split's rule
for "holds" (the highest such level at or below GuideLLM's knee), llama.cpp and FP8, with no knee,
hold 4 and 12; the BF16 row's knee is 6.71, so it holds 4 by the rule, though 8 met the floor (F).

**Which figures size the layout.** Production clients sit on the same direct network as the GPUs,
so the layout is sized on LAN figures (role-split's decision). Every run with a recorded ping went
direct on the LAN, 0 to 2 ms to gb10-1, so client-side and server-side figures both stand as LAN
figures; the stack read and the staging, which measured nothing, recorded none (M).

| Host | Serves at the end of the session |
| --- | --- |
| gb10-1 | `gpt-oss-120b-MXFP4-agent-only` (c 1,179,648, 16 slots, unified), freshly loaded in 48.4 s: 13.73 GiB available, read 16:54:09Z. The `vllm` container stopped (Exited (0)) on the FP8 row, its v0.33.0 image (d825baf9ce4b), its compile cache (178M) and gpt-oss-120b's safetensors kept. spike-model-engines' clone on the local `hosts` branch at c5251be |
| gb10-2 | as the framework task left it: its 16-slot 26B-A4B and E4B and granite; clone on `main` at 21b5e8c. Read only, for the stack |
| framework | as the framework task left it: set A's capped 26B-A4B and E4B and granite; clone on `main` at 21b5e8c. Read only, for the stack |

## Stack, engine and network path

Read by the session over SSH, read-only, at 2026-11-11T09:42:31-05:00 (14:42:31Z), after the
architect's root updates (`.state/agent-vllm/stack-2026-11-11.txt`, `phased-2026-11-11.txt`):

| Host | Pending updates | OS | Kernel | GPU stack | Docker | Tailscale | Engine | Clone |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gb10-1 | 3, phased (apt; A) | DGX OS 7.6.0 (`DGX_OTA_VERSION`), Ubuntu 24.04.5 LTS | 7.0.0-1025-nvidia | driver 580.178.04, CUDA 13.0, NVIDIA Container Toolkit 1.20.1 | 29.6.2 | 1.104.6 | llama.cpp `server-cuda13-b12098`, up 27 hours (healthy); vLLM v0.33.0 from A | `main` at 21b5e8c, moved to `hosts` at c5251be in A |
| gb10-2 | 3, phased (apt; A) | as gb10-1 | 7.0.0-1025-nvidia | as gb10-1 | 29.6.2 | 1.104.6 | llama.cpp `server-cuda13-b12098`, up 27 hours (healthy) | `main` at 21b5e8c |
| framework | 0 (`checkupdates` exit 2) | Omarchy | 7.2.15-1-omarchy | mesa and vulkan-radeon 1:26.2.5-1, linux-firmware 20260916-1 | 1:29.9.2-1 | 1.104.2 | llama.cpp `server-vulkan-b12098`, up 17 hours (healthy) | `main` at 21b5e8c |

The stack is the framework task's in every column ([framework](framework.md), "Stack, engine and
network path"): the root updates moved no kernel, driver or Mesa, and no container restarted with
them. Nothing on gb10-2 or the Framework changed after this read: no load, request, clone move or
anchor.

**Network path.** `tailscale ping -c 1 gb10-1` from the laptop preceded every run on gb10-1 but
the stack read and the staging steps, each dated in `.state/agent-vllm/ping-2026-11-11.txt`, and
every pong came via gb10-1's LAN address. The stack read and the staging steps recorded no ping;
the staging's downloads ran on gb10-1 itself (M):

| Run | Ping (UTC) | Pong |
| --- | --- | --- |
| The push to gb10-1 (A) | 14:42:43, dated by the step log's trace; the pong is in `push-gb10-1.out` | 2 ms |
| llama.cpp baseline load (C) | 15:38:06 | 2 ms |
| L-agent | 15:39:35 | 1 ms |
| vLLM install, BF16 first start (D) | 15:52:28 | 2 ms |
| BF16 timed restart (D) | 16:02:15 | 2 ms |
| VA | 16:11:27 | 1 ms |
| VB | 16:12:49 | 0 s |
| BF16 probes | 16:14:52 | 1 ms |
| B-agent | 16:15:01 | 1 ms |
| B-cap | 16:25:01 | 2 ms |
| FP8 update and start | 16:29:02 | 2 ms |
| FP8 probes | 16:38:41 | 1 ms |
| F-agent | 16:38:49 | 1 ms |
| F-cap | 16:48:50 | 2 ms |
| Restore (Behavior 14) | 16:52:44 | 2 ms |

**Every run with a recorded ping went direct on the LAN, 0 to 2 ms.** Had the laptop been off the LAN,
the relay's trip would have landed on the client-side figures only (TTFT, request latency); ITL
and memory don't carry the path ([role-split](role-split.md), L.7).

**Engines.** llama.cpp b12098 serving spike-model-engines' shared preset's
`gpt-oss-120b-MXFP4-agent-only`, as `load` printed its arguments: `--no-cache-idle-slots
--ctx-size 1179648 --checkpoint-min-step 4096 --cache-ram 0 --kv-unified --parallel 16`. vLLM
v0.33.0 (`/version` read `{"version":"0.33.0"}` on both rows), `vllm/vllm-openai:v0.33.0`, digest
`sha256:d825baf9ce4b1b6bfc5ecc7b79880c7e6748c65a72d697ce3d47607aafa84c6e`, arm64, run by
spike-model-engines' `host/engines vllm` from the PR branch (A). Each row's container command, as
`docker inspect` printed it:

```
openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 131072 --gpu-memory-utilization 0.80 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai
openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 131072 --gpu-memory-utilization 0.80 --kv-cache-dtype fp8 --kv-cache-memory-bytes 32993476982 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai
```

Neither row names an attention or MoE backend; vLLM chose them (E). `/v1/models` read
`[{"id":"openai/gpt-oss-120b","max_model_len":131072}]`.

**Tools.** The step helpers in `scripts/measure-lib.sh` (`load`, `unload`, `loaded`, `memory`,
`footprint`, `cell`, `watch`, `summarize`, `readout`), with this task's change to read a vLLM
container (B), sourced for gb10-1's router on 8080 and for vLLM on 8000. Every cell is GuideLLM
0.8.1 from the laptop (`mise.bench.toml`), run by `cell` under `watch`: the pool sampled every 10 s
into `<cell>.watch.tsv`, the cell stopped under the 12.2 GiB floor, capped at 10 min. Each cell's
GuideLLM JSON, `.watch.tsv`, `.exit` and `.log` are under `.state/measure/gb10-1/`, named
`agent-vllm-*`. Every cell's `.exit` reads 0: none was stopped. The scenarios are role-split's
S-agent file, anchors A and B, and this task's capacity cell, listed in
[`bench/README.md`](../../bench/README.md). The steps ran from step files in
`.state/agent-vllm/step-files/`, each through `step.sh <host> <file>`, which sources the helpers
for the host and exports its floor; the step log traces every command inside them (M). Each vLLM
start was timed by `vllm_wait` (`vllm-wait.sh`), which polls `/health` every 2 s, samples the pool
every 10 s into `.state/agent-vllm/<label>.mem.tsv`, and prints the seconds from the start command
to the start log's "Application startup complete." on gb10-1's clock.

**Reading the figures.** The pool is MemAvailable, read just after dropping the page cache (`ssh
gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3`), against the floor of 12.2 GiB; `watch`'s
samples during a cell and `vllm_wait`'s during a start are not taken after a drop. The per-level
tables come from each cell's JSON through [`bench/levels.jq`](../../bench/levels.jq), judged by the
agent floor (ITL median ≤100 ms); the capacity cells through
[`bench/capacity.jq`](../../bench/capacity.jq) and [`bench/readouts.awk`](../../bench/readouts.awk);
all re-read at 16:59:12Z into `.state/agent-vllm/jq-figures-slice3.txt` by one quoted command (M,
"Commands not in a step log"). Output tok/s is GuideLLM's completed-turn rate; the step log's
"every-token" rate, which counts tokens of turns still running at the level's end, is given beside
it where it matters. Logs give buffers in MiB and vLLM gives GiB; pools are in GiB (1 GiB = 1024
MiB). The command lists show the step log's local times (UTC−5); the prose gives UTC. Every figure
is measured, read from a cell's JSON, the step log or a saved file, unless marked **(c)**: computed
from measured figures, with the arithmetic shown where it isn't a plain difference or ratio.
**(m)** marks a measured figure where computed ones sit beside it.

## A. Hosts brought current, the pull request, the staging (Behaviors 1, 2, 3)

### A.1 Root updates

The architect applied the root updates on all three hosts before the session's first read. The
stack read then found 0 pending on the Framework and 3 listed on each GB10, the same three Ubuntu
phased updates the framework task found (distro-info and python3-distro-info 1.7ubuntu0.1, snapd
2.78+ubuntu24.04, each "phased 10%"); a simulated upgrade on each GB10 printed "The following
upgrades have been deferred due to phasing: distro-info python3-distro-info snapd" and "0
upgraded, 0 newly installed, 0 to remove and 3 not upgraded" (`phased-2026-11-11.txt`). By the
framework task's decision the phased three count as no pending updates.

### A.2 The pull request reaches gb10-1 (Behavior 2)

**Decision it informs:** whether gb10-1 serves the two rows and the v0.33.0 pin before the merge.
The host/ change is commit c5251be, "host: vLLM v0.33.0 and gpt-oss-120b's agent rows", on
spike-model-engines' `agent-vllm` branch:

- `vllm.env` moves `VLLM_RELEASE` from v0.32.0 to v0.33.0 and rewrites the hold comment: the
  v0.33.0 tag and images are v0.33.0rc3's commit, and currency reports the pin against rc3 until
  GitHub's release object moves;
- `vllm-rows` adds `[gpt-oss-120b-agent]` and `[gpt-oss-120b-agent-fp8]`;
- `llama.env`'s hold note reads "checked still unrestored through b12271".

At 14:42:43Z the branch was pushed to gb10-1 alone as `hosts-next`, and its clone checked out a
local `hosts` branch at it: `git branch -vv` listed `* hosts c5251be`, `hosts-next c5251be` and
`main 21b5e8c [origin/main]`; the clone read `VLLM_RELEASE=v0.33.0`, the two rows at lines 121
and 130 of `host/vllm-rows`, and "through b12271" (`push-gb10-1.out`). gb10-2's and the
Framework's clones stayed on `main` at 21b5e8c (Stack).

### A.3 Staging, and what each start fetched (Behavior 3)

**Decision it informs:** whether every vLLM start reads its weights from the store, so that its
start time is a load, not a download. From 14:43:00Z, in parallel and in the background on gb10-1:
`hf download openai/gpt-oss-120b --exclude "original/*.safetensors" --exclude "metal/*"` into
`/srv/models` and `docker pull vllm/vllm-openai:v0.33.0`. The first pull didn't start (its log's
redirect ran before the `mkdir` in a backgrounded `&&` chain), and was started again at 14:43:42Z.
The weights finished at 15:33:26Z (`exit 0`), the image at 15:37:32Z (`exit 0`, "Downloaded newer
image"): 50 min 26 s and 53 min 50 s (c). The check at 15:37:57Z (`stage-result.out`):

- the image: `vllm/vllm-openai@sha256:d825baf9…`, arm64, content size 10,901,699,690 bytes, disk
  usage 37.7GB;
- the snapshot `b5c939de8f754692c1647ca79fbf85e8c1e70f8a`: **29 files, 65,276,917,241 bytes**, the
  15 safetensors shards (`model-00000-of-00014` to `model-00014-of-00014`), `config.json`,
  `generation_config.json`, `chat_template.jinja`, the tokenizer files,
  `model.safetensors.index.json`, and `original/config.json`, `original/dtypes.json` and
  `original/model.safetensors.index.json` (the three JSON files v0.32.0's start fetched, which
  pre-staging had left out then); no `*.incomplete` blob.

**No model file was downloaded at any start.** After the first start, `find
/srv/models/models--openai--gpt-oss-120b -newermt "2026-11-11T15:52:30Z"` printed nothing, and
the one file under the container's Hugging Face cache was `.agent_harnesses.json`, 9,285 bytes
(`bf16-restart.out`). **The hub was contacted for metadata at every start.** Each start log prints
`Warning: You are sending unauthenticated requests to the HF Hub. Please set a HF_TOKEN to enable
higher rate limits and faster downloads.` and `Fetching 14 files: 100%|██████████| 14/14`, twice
per start (four `download|fetching` lines since the BF16 restart), at 1,114 to 1,789 files a
second: the files resolved against the staged snapshot, with no transfer the logs show. So
Behavior 3's "no vLLM start fetches a file" holds for files and not for hub contact: the rows set
no offline flag (N).

## B. The step helpers read a vLLM container (Behavior 4)

**Decision it informs:** whether every vLLM read comes from a tracked helper. Commit a906e3f,
"agent-vllm: helpers read a vLLM container; the capacity cell", in `scripts/measure-lib.sh`, with
the helpers sourced for port 8000:

- `footprint` prints the container's state and start, each of its processes (host pids from
  `docker top`) with nvidia-smi's GPU memory and `ps` RSS, the container's totals, the pool, and
  the start log's sizing lines since the container's current start: the non-default sizing
  arguments, the attention and MoE backends, model loading and its time, the CUDA graphs, the
  available KV cache memory or the `kv_cache_memory_bytes` reservation, the KV cache tokens and
  maximum concurrency, and the startup free memory;
- `readout <since>` prints `/metrics` (running, waiting, KV cache usage; requests by finish
  reason, prompt and generation tokens, preemptions), then counts the server log's ERROR lines,
  its Harmony, parsing and tool-call errors and warnings, HarmonyError lines and responses ≥400
  since the time, then `memory`.

A llama.cpp host reads as before (C's `footprint` prints llama-server's row and its buffers);
`watch`, `memory` and `cell` are unchanged. Commit 2b7009c adds the capacity cell's readers,
`bench/capacity.jq` and `bench/readouts.awk`, and 0792dc4 stops the capacity cell at 570 s, inside
`cell`'s 10 min cap, since GuideLLM writes its JSON at its own `max_duration`. The check passed at
each commit.

## C. Cold starts and idle reads (Behaviors 5, 6, 11)

**Decision it informs:** what each engine takes to come up, and what it leaves of the pool idle.
Each start began from a dropped page cache, nothing else loaded; each idle read is after one
warm-up request (vLLM) or none (llama.cpp), 30 s idle, and a cache drop.

| Start | Configuration | Pool before | Start | Weights (log) | Lowest during the start | Idle, 30 s (m) | Above the floor (c) |
| --- | --- | --- | --- | --- | --- | --- | --- |
| llama.cpp load, 15:38:11Z | `load gpt-oss-120b-MXFP4-agent-only` after `unload --all` | 117.75 GiB | **48.4 s** to loaded | 59,851.68 + 586.82 MiB buffers | – | **13.66 GiB** | 1.46 GiB |
| vLLM first start, BF16, 15:52:30Z | `docker stop llama`; `VLLM_MODEL=gpt-oss-120b-agent host/engines vllm install`; compiles afresh | 118.06 GiB | **555.9 s** (/health 200 after 556.6 s, laptop) | 66.14 GiB in 478.04 s (weights read 467.52 s) | 19.63 GiB | 19.30 GiB (no warm-up, no drop) | – |
| vLLM BF16, timed, 16:02:16Z | cache dropped; `docker restart vllm`; compile cache warm | 19.46 GiB | **503.1 s** (500.5 s from StartedAt; /health 200 after 500.8 s) | 66.14 GiB in 456.81 s (weights read 446.09 s) | 15.90 GiB | **15.88 GiB** | 3.68 GiB |
| vLLM FP8, 16:29:03Z | cache dropped; `VLLM_MODEL=gpt-oss-120b-agent-fp8 host/engines vllm update`; compiles afresh | 15.69 GiB | **530.7 s** (529.0 s from StartedAt; /health 200 after 529.8 s) | 66.14 GiB in 460.83 s (weights read 450.32 s) | **12.52 GiB** (16:37:46Z) | **13.88 GiB** | 1.68 GiB |
| llama.cpp restore, 16:52:50Z | `docker stop vllm`; `docker start llama`; `load` | 117.78 GiB | 48.4 s | as above | – | 13.73 GiB | 1.53 GiB |

**vLLM's timed cold start is 503.1 s on BF16 and 530.7 s on FP8, about 10.4 and 11.0 times
llama.cpp's 48.4 s (c)**; nearly all of it is reading the weights (446 to 468 s). The first start,
recorded apart, took 555.9 s. The FP8 start compiled afresh, since the KV dtype is part of the
compile hash (its log saved a new AOT function, `96b6f1cb…`, beside BF16's `93145931…`), and its
weight load (460.83 s) is within 4.0 s (c) of BF16's timed one (456.81 s). v0.32.0's
gpt-oss-120b starts on gb10-1 took 576.5 and 546.3 s with weights in 503.4 and 509.4 s
(spike-model-engines' bench-gb10-container finding, cited); they stand beside v0.33.0's as a
record across versions, not a comparison, since the version, the row's max-model-len and the
session all differ.

**What the start is.** Model loading took 456.81 s of the BF16 row's 503.1 s timed start, about
30 s a shard over the 15 shards (c: 446.09 s of weight reads / 15); the compiled graphs loaded from
the AOT cache (0.23 s of compilation), so import and compile are a minor part. The known cause on
GB10, researched from GitHub on 2026-11-11 (cited, not measured here): vllm-project/vllm#58726,
"Weight loading is slow on GB10 (DGX Spark): per-tensor H2D copies straight from safetensors mmap
views" (closed 2026-11-05), found that on GB10 a tensor copied straight from the checkpoint's mmap
costs about 7 times a copy from anonymous memory, paid per tensor, which dominates MoE checkpoints
with many small expert tensors. Its fix, #58868, "[Perf][Model Loader] Fault in mmap'd weight
pages before host-to-device copies on integrated GPUs", merged 2026-11-03 at 437288d; it is not in
v0.33.0, whose branch was cut 2026-10-26 (GitHub's compare reads "diverged"), and it is in
v0.34.0rc0 ("behind"). The PR's example, an NVFP4 MoE, loaded in about 475 s from local NVMe before
the fix. Tracking: #48193, "[Roadmap] Weight-loading-bound startup" (open), with #65713 (open).
Other startup work, in brief: #59433 (serial per-process Python imports, about 10 s a tier;
partial fixes merged), #61289 (overlapped weight staging with AOT reuse, −42.5% on an H100; a
proposal), RFC #34303 (CUDA checkpoint and restore), and sleep mode, which would avoid restarts
but whose `wake_up` crashes on DGX Spark (#50011, open; a fix proposed in #57629). **So the cold
start here is mostly GB10's mmap-copy cost, and a merged upstream fix lands in v0.34.0.** The pin
stays v0.33.0 in this task; remeasuring is an open item (N).

**The idle reads against role-split's G.** llama.cpp's agent-only section read 13.66 GiB, and
13.73 GiB on the restore, against role-split's 13.59 (cited); its process 102,925 MiB GPU and
2,358 MiB RSS, router 170 / 89, and every buffer line role-split G's (`base-gb10-1.out`):
weights 59,851.68 MiB CUDA0 and 586.82 CUDA_Host; KV 41,472.00 MiB (1,179,648 cells, 18 layers,
K and V f16 20,736.00 each) and 90.00 MiB (2,560 cells); compute 1,316.68 / 1,249.18; output
12.27. vLLM's BF16 row leaves **2.22 GiB more (c) than llama.cpp** idle, and the FP8 row 0.22 GiB
more (c). The FP8 row's idle read, 13.88 GiB, is above the 12.2 GiB floor, so no escalation and no
28 GiB fallback (Behavior 11). During its start the pool fell to 12.52 GiB, 0.32 GiB above the
floor (c), at 16:37:46Z, the second of the graph capture (L.2).

## D. The vLLM rows' sizing (Behaviors 6, 11)

From each start log, by `footprint` (`bf16-restart.out`, `fp8-update.out`) and re-read from the
saved logs (`vllm-first-start.log`, `vllm-bf16-run.log`, `vllm-fp8-start.log`):

| | BF16, first start (compiling) | BF16, timed restart | FP8 | v0.32.0, gpt-oss-120b (cited; a record across versions, not a comparison) |
| --- | --- | --- | --- | --- |
| Sizing arguments | `'max_model_len': 131072, 'gpu_memory_utilization': 0.8, 'max_num_seqs': 16` | the same | the same with `'kv_cache_memory_bytes': 32993476982, 'kv_cache_dtype': 'fp8'` | max-model-len 8192, 0.80, 16 |
| Model loading | 66.14 GiB, 478.04 s | 66.14 GiB, 456.81 s | 66.14 GiB, 460.83 s | 66.14 GiB, 503.4 s |
| CUDA graphs | 3.30 GiB (26 s), then 0.18 GiB | 1.41 GiB, then 0.18 GiB | 0.48 GiB | 3.58 + 0.13 GiB |
| Compile | afresh: "saved AOT compiled function", 9.04 s in init | "Directly load AOT compilation", 0.23 s | afresh, 8.58 s | – |
| KV cache memory | 25.7 GiB available | **30.0 GiB** available | **30.73 GiB** reserved (`kv_cache_memory_bytes`, "skipped memory profiling") | 25.71 GiB |
| KV cache tokens | 725,243 | **846,411** | **1,733,910** | 493,523 |
| Maximum concurrency for 131,072 tokens | 5.53x | **6.46x** | **13.23x** | – |
| Startup line | free 114.79 / 121.63 GiB; consumed 67.34, peak activation 4.26, graphs 0.18 GiB | free 114.69; consumed 65.78, peak activation 1.52, graphs 0.18 | initial free 114.99 GiB | – |

v0.32.0's round 5 rerun of the same row read 28.35 GiB and 544,172 tokens (cited); the BF16 row's
cache moves with the start (L.1). The FP8 row's 1,733,910 tokens are the measured figure; the
row's 1,179,648 were computed in the brief from half of v0.32.0's bytes a token (27,969 bytes, c:
32,993,476,982 / 1,179,648). It holds 47% more (c).

**Where 32,993,476,982 comes from.** It is the row's chosen sizing input, computed before the
session, not a measured figure. The scratch computation that produced it wasn't quoted; this awk
command reproduces it exactly from v0.32.0's two logged BF16 accountings of gpt-oss-120b (25.71 GiB
for 493,523 tokens, 28.35 GiB for 544,172; bench-gb10-container, "Cold load and footprint",
cited): the mean of their bytes a token (55,936.40 and 55,939.26, c), halved for FP8, times
1,179,648. It prints `32993476982`; the product before rounding is 32,993,476,981.77 (c).

```sh
awk 'BEGIN { g = 1024 ^ 3; a = 25.71 * g / 493523; b = 28.35 * g / 544172; printf "%.0f\n", (a + b) / 2 / 2 * 1179648 }'
```

The FP8 row keeps `--gpu-memory-utilization 0.80` beside `--kv-cache-memory-bytes`: vLLM sizes the
cache from the bytes, and the 0.80 still sets the startup free-memory check.

## E. Backends (Behaviors 6, 11)

Each start log names the backends vLLM chose; no row names one:

| Row | Attention | MoE | FlashInfer's resolved dtypes |
| --- | --- | --- | --- |
| BF16 (both starts) | `Using FLASHINFER attention backend out of potential backends: ['FLASHINFER', 'TRITON_ATTN']` | `Using 'MARLIN' Mxfp4 MoE backend` | `prefill=torch.bfloat16, decode=torch.bfloat16, decode_backend=xqa, kv_cache_dtype=torch.bfloat16, arch=sm121` |
| FP8 | the same, FLASHINFER | MARLIN | `prefill=torch.bfloat16, decode=torch.bfloat16, decode_backend=xqa, kv_cache_dtype=torch.float8_e4m3fn, arch=sm121` |

**The FP8 row runs FlashInfer's xqa decode with a float8_e4m3fn KV cache on SM121**, the case the
brief called unproven for gpt-oss's attention sinks: it started, answered both probes (J) and ran
every cell with no error (F, H). That shows it works; it doesn't show its output matches BF16's,
since the cache runs uncalibrated at scale 1.0 (goal record, Decisions) and no accuracy check ran
(N).

## F. Evidence 6: S-agent on all three, at the target and per level (Behavior 9)

**Decision it informs:** which engine and row holds the agent's sessions at its floor on one
GB10. Each sweep is role-split's S-agent unchanged (`bench/role-split-agent-split.yaml`): GuideLLM
multi-turn synthetic sessions of 4 turns (an 8,192-token first turn, then 3 × 512 in, 512 out a
turn), knee profile at [1, 4, 8, 12, 16], 110 s a level, adaptive refinement off, no ramp-up.

| Cell | Engine and row | Window (UTC) | Knee |
| --- | --- | --- | --- |
| L-agent | llama.cpp, agent-only | 15:39:35-15:49:26 | **none** ("No breakpoint satisfied the saturation thresholds") |
| B-agent | vLLM BF16 | 16:15:02-16:24:52 | **6.71** (breakpoint 8, saturation 8: "A rising segment followed by a substantially flatter tail was detected") |
| F-agent | vLLM FP8 | 16:38:50-16:48:41 | **none** |

**Per level** (turns ok / errored / incomplete; output tok/s completed, every-token in brackets;
TTFT and ITL medians; ITL p95; the floor):

| Streams | llama.cpp agent-only | vLLM BF16 | vLLM FP8 |
| --- | --- | --- | --- |
| 1 | 8 / 0 / 1; **37.24** (41.38); TTFT 812 ms; ITL **20.07** ms (p95 20.61): meets | 6 / 0 / 1; 27.93 (31.79); 473 ms; 29.65 ms (29.89): meets | 7 / 0 / 1; 32.58 (32.58); 436 ms; 28.97 ms (29.09): meets |
| **4 (target)** | 12 / 0 / 4; 55.85 (58.50); 2,258 ms; 54.44 ms (66.12): **meets** | 12 / 0 / 4; 55.85 (73.52); 574 ms; 50.03 ms (55.49): **meets** | 14 / 0 / 4; **65.16** (74.38); 566 ms; 49.55 ms (51.27): **meets** |
| 8 | 8 / 0 / 8; 37.24 (52.70); 25,074 ms; 110.28 ms (140.81): **misses** | 16 / 0 / 8; 74.47 (89.82); 723 ms; 76.36 ms (93.37): meets | 16 / 0 / 8; 74.47 (95.42); 699 ms; 72.25 ms (88.37): meets |
| 12 | 1 / 0 / 12; 4.65 (52.67); 9,741 ms; 195.10 ms: **misses** | 12 / 0 / 12; 55.85 (97.33); 15,709 ms; 101.83 ms (123.20): **misses** | 12 / 0 / 12; 55.85 (106.04); 15,818 ms; 95.04 ms (120.06): meets |
| 16 | 0 / 0 / 16; no turn completed (31.52): **misses** | 16 / 0 / 16; 74.47 (102.84); 17,819 ms; 118.64 ms (152.71): **misses** | 16 / 0 / 16; 74.47 (110.85); 17,864 ms; 118.75 ms (142.84): **misses** |
| **Meets the floor through** | **4** | **8** | **12** |
| **Holds, role-split's rule** | 4 (no knee) | 4 (8 meets, above the knee of 6.71) | 12 (no knee) |
| Pool lowest during (`watch`) | 12.59 GiB (15:45:11Z) | 15.46 GiB (16:15:22Z) | 13.96 GiB (16:47:39Z) |

**At the target of 4 every engine meets the floor.** The FP8 row gives the most output, 65.16
tok/s against 55.85 on the other two (+16.7%, c), at the lowest ITL; both vLLM rows answer the
first token in under 0.6 s against llama.cpp's 2.3 s (G). **At every level past 4 vLLM leads**:
llama.cpp misses at 8 (ITL 110.28 ms) and completes almost no turn at 12 and 16, where both vLLM
rows still complete 12 and 16 turns; FP8 meets the floor one level further than BF16 (95.04 ms at
12 against 101.83). **At 1 stream llama.cpp leads**: 37.24 tok/s and ITL 20.07 ms, against 27.93
and 29.65 ms (BF16) and 32.58 and 28.97 ms (FP8). Role-split's S-agent on the same section
(cited) met the floor at 4 and missed at 8 (109.63 ms), as L-agent did.

Completed-turn output tok/s moves in steps over a 110 s level, which is why 55.85 repeats; the
every-token rate, which counts the tokens of turns cut at the level's end, rises with streams on
vLLM (73.52 → 102.84 on BF16, 74.38 → 110.85 on FP8) and falls past 8 on llama.cpp (58.50 →
31.52).

## G. TTFT under multi-turn load (Behavior 9)

TTFT medians from the sweeps in F, a client-side figure, every run on the LAN:

| Streams | llama.cpp | vLLM BF16 | vLLM FP8 |
| --- | --- | --- | --- |
| 1 | 812 ms | 473 ms | 436 ms |
| 4 | 2,258 ms | 574 ms | 566 ms |
| 8 | 25,074 ms | 723 ms | 699 ms |
| 12 | 9,741 ms (1 turn completed) | 15,709 ms | 15,818 ms |
| 16 | – (no turn completed) | 17,819 ms | 17,864 ms |

Each session's first turn carries an 8,192-token prompt. vLLM keeps TTFT under 1 s through 8
sessions; llama.cpp's grows to 2.3 s at 4 and 25 s at 8. From 12 sessions vLLM's first tokens wait
about 16 to 18 s on both rows, as prompts queue behind one another (H shows the same queue with
longer prompts).

## H. The capacity cells: B-cap and F-cap (Behavior 10)

**Decision it informs:** whether each vLLM row holds 8 long sessions at once in its cache.
`bench/agent-vllm-capacity.yaml`: 8 streams, one request each, 65,536 prompt tokens and exactly 256
out, read with `MEASURE_READOUT_EVERY=30`; B-cap 16:25:02Z on BF16, F-cap 16:48:50Z on FP8. Each
request carried 65,603 prompt tokens as the server counted them (the chat template's 67 more, c).

Per request, in order of start (`capacity.jq`):

| | B-cap TTFT | B-cap latency | F-cap TTFT | F-cap latency |
| --- | --- | --- | --- | --- |
| 1 | 22,204 ms | 190.89 s | 71,249 ms | 202.64 s |
| 2 | 44,680 | 195.05 | 49,484 | 200.20 |
| 3 | 67,600 | 198.72 | 95,533 | 205.07 |
| 4 | 90,989 | 201.86 | 25,477 | 197.01 |
| 5 | 114,688 | 204.52 | 120,029 | 207.16 |
| 6 | 138,806 | 206.61 | 144,757 | 208.93 |
| 7 | 163,189 | 208.01 | 169,593 | 210.14 |
| 8 | 186,423 | 208.99 | 193,107 | 210.97 |

| | B-cap (BF16) | F-cap (FP8) |
| --- | --- | --- |
| Completed | **8 of 8**, 0 errored, 0 incomplete, each 256 of 256 out | **8 of 8**, the same |
| Starts' spread | 0.54 s: all 8 sent at once | 0.44 s |
| TTFT median / min / max | 102,838 / 22,204 / 186,423 ms | 107,781 / 25,477 / 193,107 ms |
| Latency median / max | 203.19 / 208.99 s | 206.12 / 210.97 s |
| Preemptions (counters, first to last readout) | **0** | **0** |
| Highest running (readout) | 8 (readout 7) | 8 (readout 7) |
| Highest waiting | 7 (readout 2) | 7 (readout 2) |
| Highest KV cache usage | **57.1%** (readout 7) | **27.0%** (readout 7) |
| Tokens held at once, all 8 prefilled (c) | 526,872 (8 × 65,859): 62.2% of 846,411 | 30.4% of 1,733,910 |
| Output tok/s; ITL median (step log) | 9.77; 352.27 ms | 9.69; 341.70 ms |
| Pool lowest during | 15.67 GiB (16:27:45Z) | 13.92 GiB (16:49:10Z) |
| Server log since the start | ERROR 0, Harmony or parser 0, ≥400 0 | the same |

**Both rows held all 8 requests at once, with no preemption.** The readouts, 30 s apart, show
the queue (`b-cap.out`, `f-cap.out`): running and waiting went 1 / 7, 3 / 5, 4 / 4, 5 / 3, 7 / 1
(BF16; FP8 6 / 2) and 8 / 0, while KV usage rose 7.8% → 57.1% (BF16) and 3.4% → 27.0% (FP8). **The
waiting count was the prefill queue, not the cache**: at the highest waiting the cache was 7.8%
and 3.4% used. The prefills ran one at a time, about 23.5 s each on BF16 and 23.9 s on FP8 (c:
(186,423 − 22,204) / 7 and (193,107 − 25,477) / 7 ms), about 2,800 prompt tokens a second (c:
65,603 / 23.5). The readout at the 8 / 0 point came before the eighth prefill finished, so the
true peak lies between readouts; the 62.2% and 30.4% are its computed figures.

The cell was planned to make BF16 queue on its cache, at ~494,000 tokens (c, the brief, from
v0.32.0). At v0.33.0's 846,411 it didn't: neither row was tested over its cache (I.2, N).

## I. Memory and capacity rows (Behaviors 6, 10, 11, 13)

### I.1 Per engine and row

| | llama.cpp agent-only | vLLM BF16 (timed start) | vLLM FP8 |
| --- | --- | --- | --- |
| Weights (m) | 59,851.68 + 586.82 MiB (58.45 + 0.57 GiB, c) | 66.14 GiB ("Model loading took") | 66.14 GiB |
| KV cache (m) | 41,472.00 + 90.00 MiB, f16 | 30.0 GiB, BF16 | 30.73 GiB, fp8 e4m3 |
| KV tokens (m) | 1,179,648 (unified, 16 slots) | 846,411 | 1,733,910 |
| KV bytes a token (c) | 36,864 (41,472 MiB / 1,179,648) | ~38,058 (30.0 GiB / 846,411) | ~19,028 (32,993,476,982 / 1,733,910) |
| KV tokens per GiB (c) | ~29,127 | ~28,214 | ~56,428 |
| 131,072-token sessions in the cache (c) | **9** (9.00) | **6** (6.46, the log's "maximum concurrency") | **13** (13.23); the row's 16 sequences cap concurrency above that |
| Measured: 8 concurrent requests of 65,603 prompt tokens (H) | not run (out of scope) | held, 0 preemptions, KV 57.1% at its highest readout | held, 0 preemptions, KV 27.0% |
| Process or container GPU / RSS, idle (m, MiB) | 102,925 / 2,358 (router 170 / 89) | 100,373 / 3,277 (EngineCore 100,373 / 2,347) | 102,085 / 3,806 (EngineCore 102,085 / 2,615) |
| Pool idle (m) | 13.66 GiB | 15.88 GiB | 13.88 GiB |
| Idle margin above 12.2 GiB (c) | 1.46 GiB | **3.68 GiB** | 1.68 GiB |
| Lowest under load (m), and margin (c) | 12.59 GiB (L-agent): 0.39 GiB | 15.46 GiB (B-agent): 3.26 GiB | 13.92 GiB (F-cap): 1.72 GiB; 12.52 GiB during its start: 0.32 GiB |

The capacity cell's 8 requests of 65,603 tokens are 4.00 sessions of 131,072 by token count (c);
the measured row is "8 at once, held", and the session counts above it are computed from each
cache's tokens.

### I.2 The premise changed

The brief and the FP8 row's sizing rest on v0.32.0's per-token accounting: 25.71 GiB for 493,523
tokens on gb10-1, **55,936 bytes a token (c)**, about 3.8 sessions of 131,072 (c). On v0.33.0 the
same model and BF16 cache count **~38,058 bytes a token (c)**, 32% less (c), and FP8 counts
**~19,028 (c)**, half of BF16's (c). So:

| | Computed before the session (brief) | Measured on v0.33.0 |
| --- | --- | --- |
| BF16 row at 0.80 | ~494,000 tokens (v0.32.0's 493,523), ~3.8 sessions (c) | 846,411 tokens, 6.46 sessions (m); 725,243 on a compiling start |
| FP8 row at 32,993,476,982 bytes | 1,179,648 tokens (c), 9 sessions (c) | 1,733,910 tokens, 13.23 sessions (m) |
| The capacity cell on BF16 | 524,288 tokens over a ~494,000-token cache: queues | 526,872 (c) in 846,411: held, no preemption |

llama.cpp's f16 KV for gpt-oss's 18 full-attention layers is 36,864 bytes a token (role-split K.1,
cited), so v0.33.0's BF16 count is within 3.2% of it (c), and its FP8 count about half. The
finding records the accounting as vLLM logged it; it doesn't read vLLM's allocator.

## J. Probes and errors (Behavior 8)

**Decision it informs:** whether each row's reasoning and tool-call parsing works, since the
quantization floor doesn't cover KV precision. The vLLM API page's two probes, once on each row by
curl (`probes.sh`), the replies in `.state/agent-vllm/probe-<row>-*.json`:

| Probe | BF16 (16:14:53Z) | FP8 (16:38:41Z) |
| --- | --- | --- |
| Reasoning: "What is 17 times 23?", `reasoning_effort` high | `finish_reason` stop; content `\(17 \times 23 = 391.\)`; `reasoning` 394 characters; `reasoning_content` null; 113 completion tokens, 92 reasoning | stop; content `17 × 23 = 391.`; `reasoning` 291 characters; `reasoning_content` null; 100 completion tokens, 80 reasoning |
| Tool call: Paris weather, `get_weather` | `finish_reason` tool_calls; 1 call, `get_weather` `{"city": "Paris"}`; content null | the same |
| Verdict | **passes** | **passes** |

**The reasoning field is `reasoning`, not `reasoning_content`**, on v0.33.0 with the
`openai_gptoss` parser, and the reasoning stays out of the content.

**Errors in every cell.** GuideLLM's errored count and the server log's lines since each cell's
start (`readout`):

| Cell | GuideLLM errored | ERROR lines | Harmony or parser errors and warnings | HarmonyError | Responses ≥400 |
| --- | --- | --- | --- | --- | --- |
| L-agent (llama.cpp) | 0 at every level | – | – | – | – |
| VA | 0 | 0 | 0 | 0 | 0 |
| VB | 0 | 0 | 1 | 0 | 0 |
| BF16 probes | – | 0 | 0 | 0 | 0 |
| B-agent | 0 at every level | 0 | 2 | 0 | 0 |
| B-cap | 0 | 0 | 0 | 0 | 0 |
| FP8 probes | – | 0 | 0 | 0 | 0 |
| F-agent | 0 at every level | 0 | 0 | 0 | 0 |
| F-cap | 0 | 0 | 0 | 0 | 0 |

**No request errored in any cell.** The three warnings on BF16 are `Harmony parser ended in a
non-terminal state; returning the recovered raw output.` (16:13:35Z in VB; 16:22:15Z and 16:24:20Z
in B-agent). In both cells nearly every reply was cut at its output length: the counters'
`length` finish reason rose by 32 of 32 requests in VB and 62 of 62 in B-agent (c, from the
counters before and after), so a reply cut mid-message leaves Harmony's parser mid-state. The FP8
row logged none. Each start also logged twice `Auto-initialization of reasoning token IDs failed`
(4 on BF16's two starts, 2 on FP8's), a start-time warning, counted in the restarts' readouts.

## K. Anchors VA and VB against v0.32.0 (Behavior 7)

**Decision it informs:** whether gpt-oss's speed on vLLM moved from v0.32.0 to v0.33.0, as a
record, not a gate. Anchors A (1 stream, 8 requests) and B (4 streams, 32 requests), 512 in, 256
out, reasoning on, on the BF16 row, against spike-model-engines' bench-gb10-container (v0.32.0,
cited). The row's max-model-len is 131,072; v0.32.0's was 8,192.

| Run | Requests | Output tok/s (v0.32.0) | Change (c) | TTFT median (v0.32.0) | ITL median (v0.32.0) | Change (c) | Pool lowest |
| --- | --- | --- | --- | --- | --- | --- | --- |
| VA, 16:11:28Z | 8 of 8 | **34.39** (34.0; rerun 34.0) | +1.15% | 326 ms (330; 328) | 27.90 ms (28.21; 28.19) | −1.10% | 15.84 GiB |
| VB, 16:12:50Z | 32 of 32 | **88.40** (86.7) | +1.96% | 711 ms (733) | 43.22 ms (43.70) | −1.10% | 15.65 GiB |

v0.32.0's two A runs read 34.0 tok/s both, a difference under the figure's 0.1 tok/s, so VA's move
of +0.39 tok/s is beyond it: **v0.33.0 is about 1 to 2% faster on both anchors**, recorded as a
finding and gating nothing.

## L. What else was found

### L.1 The BF16 row's cache moves with the start

At gpu-memory-utilization 0.80, vLLM sizes the KV cache from what is left after profiling. The
first start, which compiled, profiled 4.26 GiB of peak activation and captured graphs taking 3.30
GiB, and gave **25.7 GiB, 725,243 tokens, 5.53x**; the timed restart, loading the compiled AOT
function, profiled 1.52 GiB and 1.41 GiB, and gave **30.0 GiB, 846,411 tokens, 6.46x** (D). Both
starts logged the same weights (66.14 GiB). v0.32.0 shows the same spread (25.71 then 28.35 GiB,
cited). So the BF16 row's sessions depend on whether the compile cache is warm; the FP8 row's
fixed bytes don't.

### L.2 The FP8 start's lowest

The FP8 row reserves 30.73 GiB by bytes and skips memory profiling, so its pool during the start
fell to 12.52 GiB (16:37:46Z, `fp8-start.mem.tsv`, 12,816 MiB), 0.32 GiB above the floor (c), at
the end of its graph capture; it settled at 13.88 GiB idle. A start isn't run under `watch`, so a
dip under the floor there would not have been stopped.

### L.3 After-cell reads

Each read is after the cell, the cache dropped (`after`): `memory`, then `footprint`.

| After | Pool (GiB) | Lowest during | GPU / RSS, MiB (container) |
| --- | --- | --- | --- |
| llama.cpp idle, 30 s | 13.66 | – | 102,925 / 2,358 |
| L-agent | 12.69 | **12.59** | 103,029 / 3,219 |
| BF16 idle, 30 s | 15.88 | 15.90 (start) | 100,373 / 3,277 |
| VA | 15.83 | 15.84 | 100,373 / 3,288 |
| VB | 15.70 | 15.65 | 100,445 / 3,292 |
| B-agent | 15.72 | **15.46** | 100,485 / 3,312 |
| B-cap | 15.69 | 15.67 | 100,485 / 3,339 |
| FP8 idle, 30 s | 13.88 | **12.52** (start) | 102,085 / 3,806 |
| F-agent | 13.97 | 13.96 | 102,189 / 3,844 |
| F-cap | 13.93 | 13.92 | 102,189 / 3,871 |
| llama.cpp restore, 30 s | 13.73 | – | 102,925 / 2,419 (router 170 / 345) |

No cell fell under the floor. llama.cpp's RSS grew 2,358 → 3,219 MiB over L-agent, as role-split
and framework found; vLLM's container RSS grew under 100 MiB a row.

## M. Every run

| Run | Tool and configuration | Load | Duration | Path | Decision it informs |
| --- | --- | --- | --- | --- | --- |
| Stack read | SSH read-only, all three hosts; `apt-get -s upgrade` on the GB10s | none | one read | no ping recorded | Behavior 1's record (Stack, A.1) |
| Push and clone move | `git push gb10-1:… agent-vllm:hosts-next`; `git checkout -B hosts hosts-next` on gb10-1 | none | one step | direct, 2 ms | the rows on gb10-1 before merge (A.2) |
| Staging | `hf download` and `docker pull`, in parallel, in the background on gb10-1 | none | 50 and 54 min | no ping recorded; the downloads ran on gb10-1 itself | starts that read, not download (A.3) |
| llama.cpp baseline | `unload --all`, cache drop, `load gpt-oss-120b-MXFP4-agent-only`, 30 s idle, read | none | 48.4 s load | direct, 2 ms | llama.cpp's cold start and idle pool (C) |
| L-agent | GuideLLM 0.8.1, `cell`, `bench/role-split-agent-split.yaml`, agent-only section | 4-turn sessions, [1,4,8,12,16] | 110 s a level, 591 s | direct, 1 ms | llama.cpp's sessions at the floor (F, G) |
| vLLM install, BF16 first start | `docker stop llama`; `VLLM_MODEL=gpt-oss-120b-agent host/engines vllm install` | none | 555.9 s | direct, 2 ms | the compile cache filled; recorded apart (C, D) |
| BF16 timed start | cache drop, `docker restart vllm`, warm-up, 30 s idle, read | 1 request | 503.1 s | direct, 2 ms | BF16's cold start, sizing and idle pool (C, D, E) |
| VA | `cell`, `bench/anchor-a.yaml`, BF16 row | 1 stream × 8, 512 in, 256 out | 60 s | direct, 1 ms | v0.33.0 against v0.32.0's 34.0 (K) |
| VB | `bench/anchor-b.yaml`, BF16 row | 4 streams × 32 | 93 s | direct, 0 s | against 86.7 (K) |
| BF16 probes | curl, reasoning and tool call | 2 requests | 4 s | direct, 1 ms | BF16's parsing (J) |
| B-agent | `bench/role-split-agent-split.yaml`, BF16 row | as L-agent | 110 s a level, 590 s | direct, 1 ms | BF16's sessions at the floor (F, G) |
| B-cap | `bench/agent-vllm-capacity.yaml`, BF16 row, readouts every 30 s | 8 × 65,536 in, 256 out | 225 s | direct, 2 ms | whether BF16 holds 8 long sessions at once (H) |
| FP8 update and start | cache drop; `VLLM_MODEL=gpt-oss-120b-agent-fp8 host/engines vllm update`; warm-up; 30 s idle; read | 1 request | 530.7 s | direct, 2 ms | FP8's cold start, sizing, backend, idle pool (C, D, E) |
| FP8 probes | as BF16's | 2 requests | 5 s | direct, 1 ms | FP8's parsing (J) |
| F-agent | as B-agent, FP8 row | as L-agent | 110 s a level, 591 s | direct, 1 ms | FP8's sessions at the floor (F, G) |
| F-cap | as B-cap, FP8 row | as B-cap | 225 s | direct, 2 ms | whether FP8 holds 8 at once (H) |
| Restore | `docker stop vllm`; `docker start llama`; `load`; 30 s idle; read | none | 48.4 s load | direct, 2 ms | Behavior 14's state |

Every cell ran under `watch`, memory sampled every 10 s, capped at 10 min, floor 12.2 GiB
(`MEASURE_FLOOR_GIB`, set by `step.sh`).

### Commands as run (gb10-1)

From `.state/measure/gb10-1/2026-11-11.log`, every command at the step level, in log order: the
`source` lines are the step files (copies in `.state/agent-vllm/step-files/`), and the commands
traced after each are what they ran. Every line inside a helper (`load`, `memory`, `footprint`,
`cell`, `readout`, `after`, `vllm_wait` and the rest, each traced with its name), the log's header
lines and the floor `step.sh` exported stay in the log. A step file's `{ date -u +%FT%TZ; tailscale
ping -c 1 gb10-1; } 2>&1 | tee -a …/ping-2026-11-11.txt` is one line, which the trace prints as
three, in the order the shell started them; a pipeline prints each of its commands. gb10-2's and
the Framework's logs for the day hold only their stack reads (`stack-gb.sh`, `stack-fw.sh`), the
same commands as gb10-1's first step.

```
09:42:31  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/stack-gb.sh
09:42:31  : 'agent-vllm stack on gb10-1: pending updates, kernel, driver, Docker, the llama image, the clone (read only)'
09:42:31  date -Is
09:42:31  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/stack-2026-11-11.txt
09:42:31  echo '== gb10-1'
09:42:31  ssh gb10-1 'apt list --upgradable 2>/dev/null | grep -c upgradable; uname -r; nvidia-smi --query-gpu=driver_version --format=csv,noheader; nvidia-smi | grep -o "CUDA Version: [0-9.]*"; docker --version; nvidia-ctk --version | head -1; . /etc/os-release; echo "$PRETTY_NAME"; grep -h -E "^DGX_(SWBUILD|OTA)_VERSION" /etc/dgx-release | tail -2; tailscale version | head -1; docker ps --format "{{.Names}} {{.Image}} {{.Status}}"; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1'
09:42:32  echo '== gb10-1: apt-get -s upgrade (simulated, no root)'
09:42:32  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/phased-2026-11-11.txt
09:42:32  ssh gb10-1 'apt-get -s upgrade 2>/dev/null | grep -A1 -E "deferred due to phasing|upgraded,"; for p in snapd distro-info python3-distro-info; do echo "$p: $(apt-cache policy $p | grep -E "Candidate|phased" | tr -s " " | paste -sd" ")"; done'
09:42:43  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/push.sh
09:42:43  : 'agent-vllm: the host/ branch to gb10-1 only, as hosts-next, then its clone onto a local hosts branch at it'
09:42:43  tailscale ping -c 1 gb10-1
09:42:43  git -C /home/jaime/experiments/spike-model-engines log --oneline -1 agent-vllm
09:42:43  git -C /home/jaime/experiments/spike-model-engines push gb10-1:repos/spike-model-engines agent-vllm:hosts-next
09:42:43  ssh gb10-1 'cd ~/repos/spike-model-engines && git checkout -B hosts hosts-next && git status -sb | head -1 && git log --oneline -1 && git branch -vv && grep -E "^VLLM_RELEASE=" host/vllm.env && grep -n -A4 "^\[gpt-oss-120b-agent" host/vllm-rows && grep -o "through b12271" host/llama.env'
09:43:00  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/stage.sh
09:43:00  : 'agent-vllm: stage on gb10-1, in parallel and in the background, the cuda flavor image host/vllm.sh names at the pin (vllm/vllm-openai:v0.33.0) and gpt-oss-120b safetensors with every JSON file, original/*.safetensors and metal/* excluded (models.md, Pre-staging everything at once)'
09:43:00  ssh gb10-1 'cd ~/repos/spike-model-engines && source host/vllm.sh && VLLM_FLAVOR=cuda vllm_flavor && vllm_image "$VLLM_RELEASE"'
09:43:00  ssh gb10-1 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models HF_XET_HIGH_PERFORMANCE=1 && mkdir -p ~/prestage && date -Is && nohup bash -c "date -Is; mise exec -- hf download openai/gpt-oss-120b --exclude \"original/*.safetensors\" --exclude \"metal/*\"; echo \"exit \$?\"; date -Is" > ~/prestage/agent-vllm-openai--gpt-oss-120b.log 2>&1 < /dev/null & nohup bash -c "date -Is; docker pull vllm/vllm-openai:v0.33.0; echo \"exit \$?\"; date -Is" > ~/prestage/agent-vllm-vllm-image.log 2>&1 < /dev/null & sleep 5; pgrep -af "hf download|docker pull"'
09:43:42  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/stage-image.sh
09:43:42  : 'agent-vllm: the image pull again; the first did not start, since its log redirect ran before mkdir in the backgrounded && chain'
09:43:42  ssh gb10-1 'ls -d ~/prestage && nohup bash -c "date -Is; docker pull vllm/vllm-openai:v0.33.0; echo \"exit \$?\"; date -Is" > ~/prestage/agent-vllm-vllm-image.log 2>&1 < /dev/null & sleep 5; pgrep -af "^docker pull|hf download"; cat ~/prestage/agent-vllm-vllm-image.log | head -3'
10:37:57  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/stage-check.sh
10:37:57  : 'agent-vllm: the staging result on gb10-1: both logs, the image and its digest, the weights snapshot and its files and size'
10:37:57  ssh gb10-1 'for f in ~/prestage/agent-vllm-*.log; do echo "== $f"; head -1 "$f"; grep -E "^exit|^Digest|^Status" "$f"; tail -1 "$f"; done'
10:37:57  ssh gb10-1 'docker image inspect --format "{{index .RepoDigests 0}} {{.Id}} {{.Size}} {{.Architecture}}" vllm/vllm-openai:v0.33.0; docker image ls vllm/vllm-openai'
10:37:57  ssh gb10-1 'cd /srv/models/models--openai--gpt-oss-120b && cat refs/main && echo && s=snapshots/$(cat refs/main) && find -L "$s" -type f -printf "%s\t%P\n" | sort -k2 && find -L "$s" -type f -printf "%s\n" | awk "{t+=\$1} END {printf \"%d files, %d bytes\n\", NR, t}" && find blobs -name "*.incomplete" | wc -l && du -sb . && df -B1 /srv/models | tail -1'
10:38:06  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/base-gb10-1.sh
10:38:06  : 'agent-vllm baseline on gb10-1 (slice 1): unload all, drop the page cache, load the agent-only section alone (its time the cold start), idle 30 s, drop the cache, read against role-split G'
10:38:06  date -u +%FT%TZ
10:38:06  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
10:38:06  tailscale ping -c 1 gb10-1
10:38:06  ssh gb10-1 'pgrep -af "hf download|docker pull" || echo "staging: nothing running"'
10:38:06  loaded
10:38:06  unload --all
10:38:09  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
10:38:11  memory
10:38:11  t0=2026-11-11T15:38:11Z
10:38:11  load gpt-oss-120b-MXFP4-agent-only
10:38:59  date -u +%FT%TZ
10:38:59  sleep 30
10:39:29  : 'agent-only loaded since 2026-11-11T15:38:11Z, idle 30 s'
10:39:29  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
10:39:30  memory
10:39:30  footprint 2026-11-11T15:38:11Z
10:39:30  loaded
10:39:35  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/l-agent.sh
10:39:35  : 'agent-vllm L-agent: S-agent (role-split-agent-split) on the agent-only section, knee [1,4,8,12,16], 110 s a level, under watch every 10 s, cap 10 min; then the after-cell read'
10:39:35  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/after.sh
10:39:35  date -u +%FT%TZ
10:39:35  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
10:39:35  tailscale ping -c 1 gb10-1
10:39:35  loaded
10:39:35  memory
10:39:35  cell agent-vllm-l-agent role-split-agent-split gpt-oss-120b-MXFP4-agent-only openai/gpt-oss-120b
10:49:26  after agent-vllm-l-agent
10:49:27  loaded
10:52:28  source .state/agent-vllm/step-files/vllm-install.sh
10:52:28  : 'agent-vllm slice 2: the llama container stops, vLLM installs serving gpt-oss-120b-agent (BF16 KV); this first start fills the compile cache and is recorded apart, its log saved; the log is searched for any fetch (Behavior 3)'
10:52:28  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/vllm-wait.sh
10:52:28  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
10:52:28  date -u +%FT%TZ
10:52:28  tailscale ping -c 1 gb10-1
10:52:28  loaded
10:52:28  ssh gb10-1 docker stop llama
10:52:30  memory
10:52:30  ssh gb10-1 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1 && ls -d ~/.cache/vllm 2>&1'
10:52:30  ht0=2026-11-11T15:52:30.266617324Z
10:52:30  ssh gb10-1 'cd ~/repos/spike-model-engines && VLLM_MODEL=gpt-oss-120b-agent host/engines vllm install'
10:52:31  vllm_wait vllm-first-start 2026-11-11T15:52:30.266617324Z 1800
11:01:48  ssh gb10-1 docker logs vllm
11:01:48  ssh gb10-1 'docker ps -a --filter name=vllm --format '\''{{.Names}} {{.Image}} {{.Status}}'\''; docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
11:01:48  echo 'fetch lines in the first start log:'
11:01:48  grep -inE 'download|fetching|huggingface\.co|snapshot_download|[0-9]+(\.[0-9]+)?[kMG]B/s' /home/jaime/experiments/spike-model-layout/.state/agent-vllm/vllm-first-start.log
11:01:48  cut -c1-300
11:01:48  grep -E 'Model loading took|Loading weights took|Available KV cache memory|GPU KV cache size|Maximum concurrency|torch.compile take|Graph capturing finished|[Bb]ackend' /home/jaime/experiments/spike-model-layout/.state/agent-vllm/vllm-first-start.log
11:01:48  ssh gb10-1 'du -sh ~/.cache/vllm; ls ~/.cache/vllm ~/.cache/vllm/.cache 2>/dev/null | head -20'
11:01:48  memory
11:02:15  source .state/agent-vllm/step-files/bf16-restart.sh
11:02:15  : 'agent-vllm BF16 row cold start: drop the page cache, restart the vllm container, timed to "Application startup complete." and /health 200; /version reads 0.33.0; one warm-up request; idle 30 s; drop the cache, read memory and footprint (weights, KV memory and tokens, graphs, backends) against v0.32.0 25.71 GiB / 493,523 tokens'
11:02:15  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/vllm-wait.sh
11:02:15  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:02:15  date -u +%FT%TZ
11:02:15  tailscale ping -c 1 gb10-1
11:02:15  source scripts/measure-lib.sh gb10-1 8000
11:02:15  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
11:02:16  memory
11:02:16  echo 'model store files written since the first start (Behavior 3):'
11:02:16  ssh gb10-1 'find /srv/models/models--openai--gpt-oss-120b -newermt "2026-11-11T15:52:30Z" -printf "%TT %s %p\n" | head; find ~/.cache/vllm/.cache/huggingface -type f -printf "%s %p\n"'
11:02:16  ht0=2026-11-11T16:02:16.607018730Z
11:02:16  ssh gb10-1 docker restart vllm
11:02:19  vllm_wait bf16-start 2026-11-11T16:02:16.607018730Z 1800
11:10:40  curl -s http://gb10-1:8000/version
11:10:40  echo
11:10:40  jq -c '[.data[] | {id, max_model_len}]'
11:10:40  curl -s http://gb10-1:8000/v1/models
11:10:40  echo 'fetch lines since the restart:'
11:10:40  grep -icE 'download|fetching'
11:10:40  ssh gb10-1 'docker logs --since $(docker inspect -f '\''{{.State.StartedAt}}'\'' vllm) vllm 2>&1'
11:10:40  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage}'
11:10:40  curl -s http://gb10-1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model": "openai/gpt-oss-120b", "messages": [{"role": "user", "content": "Say hello in one sentence."}], "max_tokens": 128}'
11:10:43  sleep 30
11:11:13  : 'BF16 row warmed up, idle 30 s'
11:11:13  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
11:11:14  memory
11:11:14  footprint
11:11:14  readout 2026-11-11T16:02:16.607018730Z
11:11:27  source .state/agent-vllm/step-files/va.sh
11:11:27  : 'agent-vllm VA: anchor A (1 stream, 8 requests, 512 in, 256 out) on the BF16 row, against v0.32.0 34.0 tok/s, under watch every 10 s, cap 10 min; readout since its start (Harmony and parser errors); then the after-cell read'
11:11:27  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/after.sh
11:11:27  date -u +%FT%TZ
11:11:27  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:11:27  tailscale ping -c 1 gb10-1
11:11:27  source scripts/measure-lib.sh gb10-1 8000
11:11:27  ssh gb10-1 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
11:11:27  memory
11:11:27  t=2026-11-11T16:11:27Z
11:11:27  cell agent-vllm-va anchor-a openai/gpt-oss-120b openai/gpt-oss-120b
11:12:49  readout 2026-11-11T16:11:27Z
11:12:49  after agent-vllm-va
11:12:49  source .state/agent-vllm/step-files/vb.sh
11:12:49  : 'agent-vllm VB: anchor B (4 streams, 32 requests, 512 in, 256 out) on the BF16 row, against v0.32.0 86.7 tok/s, under watch every 10 s, cap 10 min; readout since its start (Harmony and parser errors); then the after-cell read'
11:12:49  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/after.sh
11:12:49  date -u +%FT%TZ
11:12:49  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:12:49  tailscale ping -c 1 gb10-1
11:12:49  source scripts/measure-lib.sh gb10-1 8000
11:12:50  ssh gb10-1 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
11:12:50  memory
11:12:50  t=2026-11-11T16:12:50Z
11:12:50  cell agent-vllm-vb anchor-b openai/gpt-oss-120b openai/gpt-oss-120b
11:14:42  readout 2026-11-11T16:12:50Z
11:14:42  after agent-vllm-vb
11:14:52  source .state/agent-vllm/step-files/probes.sh
11:14:52  : 'agent-vllm probes on the row the vllm container serves (bf16 or fp8, read from its args): the vLLM API page reasoning probe and tool-call probe, once each, by curl; the replies kept in .state/agent-vllm/probe-<row>-*.json; whether each parsed; readout since the first'
11:14:52  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:14:52  date -u +%FT%TZ
11:14:52  tailscale ping -c 1 gb10-1
11:14:52  source scripts/measure-lib.sh gb10-1 8000
11:14:53  args='openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 131072 --gpu-memory-utilization 0.80 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai'
11:14:53  echo 'openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 131072 --gpu-memory-utilization 0.80 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai'
11:14:53  row=bf16
11:14:53  [[ openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 131072 --gpu-memory-utilization 0.80 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai == *\-\-kv\-cache\-dtype fp8* ]]
11:14:53  d=/home/jaime/experiments/spike-model-layout/.state/agent-vllm
11:14:53  t=2026-11-11T16:14:53Z
11:14:53  curl -s http://gb10-1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model": "openai/gpt-oss-120b", "messages": [{"role": "user", "content": "What is 17 times 23?"}], "reasoning_effort": "high"}'
11:14:56  jq '.choices[0] | {finish_reason, content: .message.content, reasoning: .message.reasoning, reasoning_content: .message.reasoning_content}' /home/jaime/experiments/spike-model-layout/.state/agent-vllm/probe-bf16-reasoning.json
11:14:56  jq -r '.choices[0].message as $m | "reasoning probe (\($row)): reasoning field \(if ($m.reasoning // "" | length) > 0 then "present" else "ABSENT" end), reasoning_content \(if ($m.reasoning_content // "" | length) > 0 then "present" else "absent" end), content holds 391 \(if ($m.content // "" | test("391")) then "yes" else "NO" end), reasoning kept out of content \(if ($m.content // "" | test("<\\|channel\\|>|analysis")) then "NO" else "yes" end); usage \(.usage | tojson)"' --arg row bf16 /home/jaime/experiments/spike-model-layout/.state/agent-vllm/probe-bf16-reasoning.json
11:14:56  curl -s http://gb10-1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model": "openai/gpt-oss-120b", "messages": [{"role": "user", "content": "What is the weather in Paris right now?"}], "tools": [{"type": "function", "function": {"name": "get_weather", "description": "Get the current weather in a city", "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}}]}'
11:14:57  jq '.choices[0] | {finish_reason, tool_calls: .message.tool_calls, content: .message.content}' /home/jaime/experiments/spike-model-layout/.state/agent-vllm/probe-bf16-tool.json
11:14:57  jq -r '.choices[0] as $c | ($c.message.tool_calls // []) as $tc | "tool-call probe (\($row)): finish_reason \($c.finish_reason), calls \($tc | length), well formed \(if $c.finish_reason == "tool_calls" and ($tc | length) == 1 and $tc[0].type == "function" and $tc[0].function.name == "get_weather" and (($tc[0].function.arguments | fromjson? | .city // "") | test("Paris"; "i")) then "yes" else "NO" end); usage \(.usage | tojson)"' --arg row bf16 /home/jaime/experiments/spike-model-layout/.state/agent-vllm/probe-bf16-tool.json
11:14:57  readout 2026-11-11T16:14:53Z
11:15:01  source .state/agent-vllm/step-files/b-agent.sh
11:15:01  : 'agent-vllm B-AGENT: S-agent (role-split-agent-split) on the BF16 row, knee [1,4,8,12,16], 110 s a level, under watch every 10 s, cap 10 min; readout since its start (Harmony and parser errors); then the after-cell read'
11:15:01  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/after.sh
11:15:01  date -u +%FT%TZ
11:15:01  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:15:01  tailscale ping -c 1 gb10-1
11:15:01  source scripts/measure-lib.sh gb10-1 8000
11:15:01  ssh gb10-1 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
11:15:02  memory
11:15:02  t=2026-11-11T16:15:02Z
11:15:02  cell agent-vllm-b-agent role-split-agent-split openai/gpt-oss-120b openai/gpt-oss-120b
11:24:52  readout 2026-11-11T16:15:02Z
11:24:53  after agent-vllm-b-agent
11:25:01  source .state/agent-vllm/step-files/b-cap.sh
11:25:01  : 'agent-vllm B-CAP: the capacity cell (agent-vllm-capacity: 8 streams, 1 request each, 65,536 in, 256 out) on the BF16 row, under watch every 10 s with readouts every 30 s, cap 10 min; readout since its start; then the after-cell read'
11:25:01  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/after.sh
11:25:01  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:25:01  date -u +%FT%TZ
11:25:01  tailscale ping -c 1 gb10-1
11:25:01  source scripts/measure-lib.sh gb10-1 8000
11:25:01  ssh gb10-1 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
11:25:01  memory
11:25:01  t=2026-11-11T16:25:01Z
11:25:01  readout 2026-11-11T16:25:01Z
11:25:02  MEASURE_READOUT_EVERY=30
11:25:02  cell agent-vllm-b-cap agent-vllm-capacity openai/gpt-oss-120b openai/gpt-oss-120b
11:28:47  readout 2026-11-11T16:25:01Z
11:28:47  after agent-vllm-b-cap
11:29:02  source .state/agent-vllm/step-files/fp8-update.sh
11:29:02  : 'agent-vllm FP8 row: the BF16 run log saved; drop the page cache; vLLM updates to gpt-oss-120b-agent-fp8 (its one start, compiling afresh, timed); its log saved and its backends read; /version; warm-up; idle 30 s; drop the cache, read memory and footprint; under 12.2 GiB at idle reads UNDER FLOOR'
11:29:02  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/vllm-wait.sh
11:29:02  date -u +%FT%TZ
11:29:02  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:29:02  tailscale ping -c 1 gb10-1
11:29:02  source scripts/measure-lib.sh gb10-1 8000
11:29:02  ssh gb10-1 docker logs vllm
11:29:02  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
11:29:03  memory
11:29:03  ht0=2026-11-11T16:29:03.166588562Z
11:29:03  ssh gb10-1 'cd ~/repos/spike-model-engines && VLLM_MODEL=gpt-oss-120b-agent-fp8 host/engines vllm update'
11:29:05  vllm_wait fp8-start 2026-11-11T16:29:03.166588562Z 1800
11:37:55  ssh gb10-1 docker logs vllm
11:37:55  ssh gb10-1 'docker ps -a --filter name=vllm --format '\''{{.Names}} {{.Image}} {{.Status}}'\''; docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
11:37:55  echo 'backend, error and fetch lines in the FP8 start log:'
11:37:55  grep -E '[Bb]ackend|ERROR|Traceback|download|fetching' /home/jaime/experiments/spike-model-layout/.state/agent-vllm/vllm-fp8-start.log
11:37:55  cut -c1-300
11:37:55  [[ 200 == 200 ]]
11:37:55  curl -s http://gb10-1:8000/version
11:37:55  echo
11:37:55  curl -s http://gb10-1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model": "openai/gpt-oss-120b", "messages": [{"role": "user", "content": "Say hello in one sentence."}], "max_tokens": 128}'
11:37:55  jq -c '{finish_reason: .choices[0].finish_reason, content: .choices[0].message.content, usage}'
11:37:58  sleep 30
11:38:28  : 'FP8 row warmed up, idle 30 s'
11:38:28  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
11:38:29  memory
11:38:29  footprint
11:38:29  readout 2026-11-11T16:29:03.166588562Z
11:38:29  a=14214
11:38:29  (( a < 12492 ))
11:38:41  source .state/agent-vllm/step-files/probes.sh
11:38:41  : 'agent-vllm probes on the row the vllm container serves (bf16 or fp8, read from its args): the vLLM API page reasoning probe and tool-call probe, once each, by curl; the replies kept in .state/agent-vllm/probe-<row>-*.json; whether each parsed; readout since the first'
11:38:41  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:38:41  date -u +%FT%TZ
11:38:41  tailscale ping -c 1 gb10-1
11:38:41  source scripts/measure-lib.sh gb10-1 8000
11:38:41  args='openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 131072 --gpu-memory-utilization 0.80 --kv-cache-dtype fp8 --kv-cache-memory-bytes 32993476982 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai'
11:38:41  echo 'openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 131072 --gpu-memory-utilization 0.80 --kv-cache-dtype fp8 --kv-cache-memory-bytes 32993476982 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai'
11:38:41  row=bf16
11:38:41  [[ openai/gpt-oss-120b --host 0.0.0.0 --port 8000 --max-num-seqs 16 --max-model-len 131072 --gpu-memory-utilization 0.80 --kv-cache-dtype fp8 --kv-cache-memory-bytes 32993476982 --reasoning-parser openai_gptoss --enable-auto-tool-choice --tool-call-parser openai == *\-\-kv\-cache\-dtype fp8* ]]
11:38:41  row=fp8
11:38:41  d=/home/jaime/experiments/spike-model-layout/.state/agent-vllm
11:38:41  t=2026-11-11T16:38:41Z
11:38:41  curl -s http://gb10-1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model": "openai/gpt-oss-120b", "messages": [{"role": "user", "content": "What is 17 times 23?"}], "reasoning_effort": "high"}'
11:38:44  jq '.choices[0] | {finish_reason, content: .message.content, reasoning: .message.reasoning, reasoning_content: .message.reasoning_content}' /home/jaime/experiments/spike-model-layout/.state/agent-vllm/probe-fp8-reasoning.json
11:38:44  jq -r '.choices[0].message as $m | "reasoning probe (\($row)): reasoning field \(if ($m.reasoning // "" | length) > 0 then "present" else "ABSENT" end), reasoning_content \(if ($m.reasoning_content // "" | length) > 0 then "present" else "absent" end), content holds 391 \(if ($m.content // "" | test("391")) then "yes" else "NO" end), reasoning kept out of content \(if ($m.content // "" | test("<\\|channel\\|>|analysis")) then "NO" else "yes" end); usage \(.usage | tojson)"' --arg row fp8 /home/jaime/experiments/spike-model-layout/.state/agent-vllm/probe-fp8-reasoning.json
11:38:44  curl -s http://gb10-1:8000/v1/chat/completions -H 'Content-Type: application/json' -d '{"model": "openai/gpt-oss-120b", "messages": [{"role": "user", "content": "What is the weather in Paris right now?"}], "tools": [{"type": "function", "function": {"name": "get_weather", "description": "Get the current weather in a city", "parameters": {"type": "object", "properties": {"city": {"type": "string"}}, "required": ["city"]}}}]}'
11:38:46  jq '.choices[0] | {finish_reason, tool_calls: .message.tool_calls, content: .message.content}' /home/jaime/experiments/spike-model-layout/.state/agent-vllm/probe-fp8-tool.json
11:38:46  jq -r '.choices[0] as $c | ($c.message.tool_calls // []) as $tc | "tool-call probe (\($row)): finish_reason \($c.finish_reason), calls \($tc | length), well formed \(if $c.finish_reason == "tool_calls" and ($tc | length) == 1 and $tc[0].type == "function" and $tc[0].function.name == "get_weather" and (($tc[0].function.arguments | fromjson? | .city // "") | test("Paris"; "i")) then "yes" else "NO" end); usage \(.usage | tojson)"' --arg row fp8 /home/jaime/experiments/spike-model-layout/.state/agent-vllm/probe-fp8-tool.json
11:38:46  readout 2026-11-11T16:38:41Z
11:38:49  source .state/agent-vllm/step-files/f-agent.sh
11:38:49  : 'agent-vllm F-AGENT: S-agent (role-split-agent-split) on the FP8 row, knee [1,4,8,12,16], 110 s a level, under watch every 10 s, cap 10 min; readout since its start (Harmony and parser errors); then the after-cell read'
11:38:49  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/after.sh
11:38:49  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:38:49  date -u +%FT%TZ
11:38:49  tailscale ping -c 1 gb10-1
11:38:49  source scripts/measure-lib.sh gb10-1 8000
11:38:49  ssh gb10-1 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
11:38:49  memory
11:38:50  t=2026-11-11T16:38:50Z
11:38:50  cell agent-vllm-f-agent role-split-agent-split openai/gpt-oss-120b openai/gpt-oss-120b
11:48:41  readout 2026-11-11T16:38:50Z
11:48:41  after agent-vllm-f-agent
11:48:50  source .state/agent-vllm/step-files/f-cap.sh
11:48:50  : 'agent-vllm F-CAP: the capacity cell (agent-vllm-capacity: 8 streams, 1 request each, 65,536 in, 256 out) on the FP8 row, under watch every 10 s with readouts every 30 s, cap 10 min; readout since its start; then the after-cell read'
11:48:50  source /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files/after.sh
11:48:50  date -u +%FT%TZ
11:48:50  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:48:50  tailscale ping -c 1 gb10-1
11:48:50  source scripts/measure-lib.sh gb10-1 8000
11:48:50  ssh gb10-1 'docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm'
11:48:50  memory
11:48:50  t=2026-11-11T16:48:50Z
11:48:50  readout 2026-11-11T16:48:50Z
11:48:50  MEASURE_READOUT_EVERY=30
11:48:50  cell agent-vllm-f-cap agent-vllm-capacity openai/gpt-oss-120b openai/gpt-oss-120b
11:52:35  readout 2026-11-11T16:48:50Z
11:52:35  after agent-vllm-f-cap
11:52:44  source .state/agent-vllm/step-files/restore.sh
11:52:44  : 'agent-vllm restore (Behavior 14): the FP8 run log saved; docker stop vllm (container, image, compile cache and weights kept); docker start llama; helpers on 8080; load the agent-only section, idle 30 s, drop the cache, read memory and footprint; the vllm container stopped on the FP8 row'
11:52:44  date -u +%FT%TZ
11:52:44  tee -a /home/jaime/experiments/spike-model-layout/.state/agent-vllm/ping-2026-11-11.txt
11:52:44  tailscale ping -c 1 gb10-1
11:52:44  ssh gb10-1 docker logs vllm
11:52:44  ssh gb10-1 docker stop vllm
11:52:47  ssh gb10-1 docker start llama
11:52:47  _measure_quiet 'polling http://gb10-1:8080/health every 2 s until 200 (cap 300 s)'
11:52:49  loaded
11:52:50  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
11:52:50  memory
11:52:50  t0=2026-11-11T16:52:50Z
11:52:50  load gpt-oss-120b-MXFP4-agent-only
11:53:38  date -u +%FT%TZ
11:53:38  sleep 30
11:54:08  : 'agent-only loaded since 2026-11-11T16:52:50Z, idle 30 s'
11:54:08  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
11:54:09  memory
11:54:09  footprint 2026-11-11T16:52:50Z
11:54:09  loaded
11:54:10  ssh gb10-1 'docker ps -a --format '\''{{.Names}} {{.Image}} {{.Status}}'\''; docker inspect -f '\''{{join .Config.Cmd " "}}'\'' vllm; du -sh ~/.cache/vllm; docker image ls vllm/vllm-openai; cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1'
```

### Commands not in a step log

Each step file's launch, and the figures' re-read, ran from the laptop outside the step helpers.
They are quoted from the session's command history, each headed by its time (UTC), from the
project's root: the step files' writes and edits, each step's launch, and the per-slice table
reads. Where a command wrote its step files with heredocs, `…` stands for a heredoc's body, which
is the step file's copy in `.state/agent-vllm/step-files/`. `<session>` stands for the session's
directory under `/tmp/claude-1000/`. The reads of a step's output that only printed it stay out.

```sh
# 2026-11-11T14:42:31Z
D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm; mkdir -p $D/step-files; cp /home/jaime/experiments/spike-model-layout/.state/framework/step-files/step.sh $D/step-files/step.sh
cat > $D/step-files/stack-gb.sh <<'EOF'
…
EOF
cat > $D/step-files/stack-fw.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout && for h in gb10-1 gb10-2; do bash $D/step-files/step.sh $h $D/step-files/stack-gb.sh; done; bash $D/step-files/step.sh framework $D/step-files/stack-fw.sh

# 2026-11-11T14:42:41Z
D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm
cat > $D/step-files/push.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout && bash $D/step-files/step.sh gb10-1 $D/step-files/push.sh 2>&1 | tee $D/push-gb10-1.out

# 2026-11-11T14:43:00Z
D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm
cat > $D/step-files/stage.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout && bash $D/step-files/step.sh gb10-1 $D/step-files/stage.sh 2>&1 | tee $D/stage-start.out

# 2026-11-11T14:43:41Z
D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm
cat > $D/step-files/stage-image.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout && bash $D/step-files/step.sh gb10-1 $D/step-files/stage-image.sh 2>&1 | tee -a $D/stage-start.out

# 2026-11-11T14:44:33Z
D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm; cp /home/jaime/experiments/spike-model-layout/.state/framework/step-files/after.sh $D/step-files/after.sh
cat > $D/step-files/base-gb10-1.sh <<'EOF'
…
EOF
cat > $D/step-files/l-agent.sh <<'EOF'
…
EOF
echo ok

# 2026-11-11T15:37:57Z
D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm
cat > $D/step-files/stage-check.sh <<'EOF'
…
EOF
cd /home/jaime/experiments/spike-model-layout && bash $D/step-files/step.sh gb10-1 $D/step-files/stage-check.sh 2>&1 | tee $D/stage-result.out

# 2026-11-11T15:38:02Z
D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm; cd /home/jaime/experiments/spike-model-layout && bash $D/step-files/step.sh gb10-1 $D/step-files/base-gb10-1.sh 2>&1 | tee $D/base-gb10-1.out

# 2026-11-11T15:39:34Z
D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm; cd /home/jaime/experiments/spike-model-layout && bash $D/step-files/step.sh gb10-1 $D/step-files/l-agent.sh > $D/l-agent.out 2>&1; echo rc=$?; cat $D/l-agent.out

# 2026-11-11T15:49:31Z
cd /home/jaime/experiments/spike-model-layout && cat <session>/tasks/b70ost4is.output; echo ====; jq -r --arg purpose agent -f bench/levels.jq .state/measure/gb10-1/agent-vllm-l-agent.json | tee .state/agent-vllm/jq-figures-slice1.txt

# 2026-11-11T15:52:01Z
: vllm-wait.sh written by the session's file tool, not a shell command

# 2026-11-11T15:52:10Z
cd /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files && cat > vllm-install.sh <<'EOF'
…
EOF
cat vllm-install.sh | head -3

# 2026-11-11T15:52:19Z
# Note, not part of the command: `python3 -` ran with no input and did nothing; the perl edit swapped bc for awk in vllm-wait.sh.
cd /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files && python3 - 2>/dev/null; perl -0pi -e 's/\$\(echo "\$\(date \+%s\.%N\) - \$t0" \| bc\)/\$(awk -v a="\$(date +%s.%N)" -v b="\$t0" "BEGIN { print a - b }")/; s/"\$\(echo "\$\(date -d "\$ts" \+%s\.%N\) - \$\(date -d "\$ht0" \+%s\.%N\)" \| bc\)"/"\$(awk -v a="\$(date -d "\$ts" +%s.%N)" -v b="\$(date -d "\$ht0" +%s.%N)" "BEGIN { print a - b }")"/; s/"\$\(echo "\$\(date -d "\$ts" \+%s\.%N\) - \$\(date -d "\$started" \+%s\.%N\)" \| bc\)"/"\$(awk -v a="\$(date -d "\$ts" +%s.%N)" -v b="\$(date -d "\$started" +%s.%N)" "BEGIN { print a - b }")"/' vllm-wait.sh && grep -n "awk -v a\|bc" vllm-wait.sh; bash -n vllm-wait.sh && date -d 2026-11-11T16:00:00.123456789Z +%s.%N

# 2026-11-11T15:52:23Z
bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/vllm-install.sh > .state/agent-vllm/vllm-install.out 2>&1; echo done $?

# 2026-11-11T15:55:01Z
cd /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files && D=/home/jaime/experiments/spike-model-layout/.state/agent-vllm
cat > bf16-restart.sh <<'EOF'
…
EOF
for c in va:anchor-a:'anchor A (1 stream, 8 requests, 512 in, 256 out) on the BF16 row, against v0.32.0 34.0 tok/s' vb:anchor-b:'anchor B (4 streams, 32 requests, 512 in, 256 out) on the BF16 row, against v0.32.0 86.7 tok/s' b-agent:role-split-agent-split:'S-agent (role-split-agent-split) on the BF16 row, knee [1,4,8,12,16], 110 s a level' f-agent:role-split-agent-split:'S-agent (role-split-agent-split) on the FP8 row, knee [1,4,8,12,16], 110 s a level'; do
  n=${c%%:*}; r=${c#*:}; s=${r%%:*}; d=${r#*:}
  cat > $n.sh <<EOF
…
EOF
done
for c in b-cap:BF16 f-cap:FP8; do n=${c%%:*}; r=${c#*:}
  cat > $n.sh <<EOF
…
EOF
done
cat > probes.sh <<'EOF'
…
EOF
cat > fp8-update.sh <<'EOF'
…
EOF
cat > restore.sh <<'EOF'
…
EOF
for f in *.sh; do bash -n $f || echo BAD $f; done; ls; cat va.sh

# 2026-11-11T16:02:03Z
cd /home/jaime/experiments/spike-model-layout/.state/agent-vllm/step-files && sed -i 's|^ht0=\$(ssh gb10-1 date -u +%FT%T.%NZ)$|echo "model store files written since the first start (Behavior 3):"; ssh gb10-1 '"'"'find /srv/models/models--openai--gpt-oss-120b -newermt "2026-11-11 15:52:30" -printf "%TT %s %p\\n" \| head; find ~/.cache/vllm/.cache/huggingface -type f -printf "%s %p\\n"'"'"'\nht0=$(ssh gb10-1 date -u +%FT%T.%NZ)|' bf16-restart.sh && sed -n 5,10p bf16-restart.sh && bash -n bf16-restart.sh

# 2026-11-11T16:02:11Z
sed -i 's|-newermt "2026-11-11 15:52:30"|-newermt "2026-11-11T15:52:30Z"|' .state/agent-vllm/step-files/bf16-restart.sh && grep -c 'T15:52:30Z' .state/agent-vllm/step-files/bf16-restart.sh

# 2026-11-11T16:02:14Z
bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/bf16-restart.sh > .state/agent-vllm/bf16-restart.out 2>&1; echo done $?

# 2026-11-11T16:11:27Z
bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/va.sh > .state/agent-vllm/va.out 2>&1; echo "va $?"; bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/vb.sh > .state/agent-vllm/vb.out 2>&1; echo "vb $?"

# 2026-11-11T16:14:52Z
bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/probes.sh > .state/agent-vllm/probes-bf16.out 2>&1; echo $?; cut -c1-400 .state/agent-vllm/probes-bf16.out

# 2026-11-11T16:15:00Z
bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/b-agent.sh > .state/agent-vllm/b-agent.out 2>&1; echo "b-agent $?"

# 2026-11-11T16:24:56Z
grep -vE '^  gpu' .state/agent-vllm/b-agent.out | cut -c1-250; jq -r --arg purpose agent -f bench/levels.jq .state/measure/gb10-1/agent-vllm-b-agent.json

# 2026-11-11T16:25:00Z
bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/b-cap.sh > .state/agent-vllm/b-cap.out 2>&1; echo "b-cap $?"

# 2026-11-11T16:28:50Z
cd /home/jaime/experiments/spike-model-layout && grep -vE '^  gpu' .state/agent-vllm/b-cap.out | grep -vE '^memory' | cut -c1-200 | head -60; jq -r -f bench/capacity.jq .state/measure/gb10-1/agent-vllm-b-cap.json; awk -f bench/readouts.awk .state/agent-vllm/b-cap.out

# 2026-11-11T16:29:01Z
cd /home/jaime/experiments/spike-model-layout && bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/fp8-update.sh > .state/agent-vllm/fp8-update.out 2>&1; echo "fp8 $?"

# 2026-11-11T16:38:40Z
cd /home/jaime/experiments/spike-model-layout && bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/probes.sh > .state/agent-vllm/probes-fp8.out 2>&1; echo $?; grep -E "probe \(|^log since|\"content\"|reasoning\"" .state/agent-vllm/probes-fp8.out | cut -c1-300

# 2026-11-11T16:38:48Z
cd /home/jaime/experiments/spike-model-layout && bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/f-agent.sh > .state/agent-vllm/f-agent.out 2>&1; echo "f-agent $?"

# 2026-11-11T16:48:45Z
cd /home/jaime/experiments/spike-model-layout && grep -E "^(exit|watch|log since|counters|memory)|stream\(s\)" .state/agent-vllm/f-agent.out | cut -c1-220; jq -r --arg purpose agent -f bench/levels.jq .state/measure/gb10-1/agent-vllm-f-agent.json

# 2026-11-11T16:48:48Z
cd /home/jaime/experiments/spike-model-layout && bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/f-cap.sh > .state/agent-vllm/f-cap.out 2>&1; echo "f-cap $?"

# 2026-11-11T16:52:38Z
cd /home/jaime/experiments/spike-model-layout && grep -E "^(exit|watch|log since)|stream\(s\)" .state/agent-vllm/f-cap.out | cut -c1-220 | tail -5; jq -r -f bench/capacity.jq .state/measure/gb10-1/agent-vllm-f-cap.json; awk -f bench/readouts.awk .state/agent-vllm/f-cap.out; grep -E "^metrics" .state/agent-vllm/f-cap.out

# 2026-11-11T16:52:43Z
cd /home/jaime/experiments/spike-model-layout && bash .state/agent-vllm/step-files/step.sh gb10-1 .state/agent-vllm/step-files/restore.sh > .state/agent-vllm/restore.out 2>&1; echo "restore $?"; cut -c1-260 .state/agent-vllm/restore.out

# 2026-11-11T16:54:26Z
cd /home/jaime/experiments/spike-model-layout && S=.state/measure/gb10-1 A=.state/agent-vllm && {
echo "# agent-vllm slice 2 figures, 2026-11-11 (gb10-1; GuideLLM 0.8.1; vLLM v0.33.0 vllm/vllm-openai@sha256:d825baf9...)"
echo; echo "# Per-level tables: jq -r --arg purpose agent -f bench/levels.jq <json>"
echo "# (anchors read with purpose agent: the floor column is the agent floor's, not the anchors')"
for c in va vb b-agent f-agent; do echo; jq -r --arg purpose agent -f bench/levels.jq $S/agent-vllm-$c.json; done
echo; echo "# L-agent beside them (slice 1):"; jq -r --arg purpose agent -f bench/levels.jq $S/agent-vllm-l-agent.json
for c in b-cap f-cap; do
  echo; echo "# ${c^^}: jq -r -f bench/capacity.jq $S/agent-vllm-$c.json; awk -f bench/readouts.awk $A/$c.out"
  jq -r -f bench/capacity.jq $S/agent-vllm-$c.json
  awk -f bench/readouts.awk $A/$c.out
  grep -E 'stream\(s\):' $A/$c.out
  grep -E '^watch:' $A/$c.out
done
echo; echo "# Per cell: GuideLLM errored (summarize), server log since the cell's start (readout <start>), the pool's lowest under watch"
for c in va vb b-agent b-cap f-agent f-cap; do
  echo "## ${c^^}"
  grep -E 'stream\(s\):' $A/$c.out | sed -E 's/;.*//; s/^/  /'
  tail -n +1 $A/$c.out | grep -E '^log since' | tail -2 | head -1 | sed 's/^/  /'
  grep -E '^watch:' $A/$c.out | sed 's/^/  /'
done
echo; echo "# Probes (raw replies in .state/agent-vllm/probe-<row>-*.json)"
grep -hE '^(reasoning|tool-call) probe' $A/probes-bf16.out $A/probes-fp8.out
echo; echo "# Harmony and parser warnings in the run logs (vllm-bf16-run.log, vllm-fp8-run.log), by kind"
for r in bf16 fp8; do echo "## $r"; grep -E ' (ERROR|WARNING) [0-9]{2}-[0-9]{2} ' $A/vllm-$r-run.log | grep -iE 'harmony|pars(e|er|ing)|tool.call' | sed -E 's/.*\] //' | sort | uniq -c; done
} > $A/jq-figures-slice2.txt; cat $A/jq-figures-slice2.txt | sed -n '/# Per cell/,$p'
```

**The figures' re-read** (16:59:12Z), every table in C to L from the cells' JSON through the
tracked readers, the probes' replies, the run logs' Harmony and parser warnings, and the start
logs' sizing lines, into `.state/agent-vllm/jq-figures-slice3.txt`; it reads the same figures as
the session's tables after each slice (`jq-figures-slice1.txt`, `jq-figures-slice2.txt`):

```sh
M=.state/measure/gb10-1 A=.state/agent-vllm; { date -u +%FT%TZ; for c in l-agent b-agent f-agent va vb; do echo "# $c"; jq -r --arg purpose agent -f bench/levels.jq $M/agent-vllm-$c.json; done; for c in b-cap f-cap; do echo "# $c"; jq -r -f bench/capacity.jq $M/agent-vllm-$c.json; awk -f bench/readouts.awk $A/$c.out; done; for c in l-agent va vb b-agent b-cap f-agent f-cap; do echo "# $c: $(grep -E '^watch:' $A/$c.out) | $(grep -E '^log since' $A/$c.out | tail -1)"; done; for p in $A/probe-*-reasoning.json; do jq -r --arg f "${p#$A/}" '.choices[0].message as $m | "\($f): reasoning \($m.reasoning|length) chars, reasoning_content \($m.reasoning_content), content \($m.content), usage \(.usage|tojson)"' $p; done; for p in $A/probe-*-tool.json; do jq -r --arg f "${p#$A/}" '.choices[0] as $c | "\($f): finish_reason \($c.finish_reason), calls \($c.message.tool_calls|length), \($c.message.tool_calls[0].function.name) \($c.message.tool_calls[0].function.arguments)"' $p; done; for r in bf16 fp8; do echo "# $r run log"; grep -E ' (ERROR|WARNING) [0-9]{2}-[0-9]{2} ' $A/vllm-$r-run.log | grep -iE 'harmony|pars(e|er|ing)|tool.call' | sed -E 's/^\(([A-Za-z]+) pid=[0-9]+\) ([A-Z]+) ([0-9-]+ [0-9:]+) \[[^]]*\] /\3 \1 \2 /' | cut -c1-110; done; for l in vllm-first-start vllm-bf16-run vllm-fp8-start; do echo "# $l"; grep -E 'Loading weights took|Model loading took|Graph capturing finished|Available KV cache memory|reserved .* for KV|GPU KV cache size|resolved query dtypes|Using .* backend|init engine' $A/$l.log | sed -E 's/^\(EngineCore pid=[0-9]+\) INFO //' | cut -c1-200; done; } > $A/jq-figures-slice3.txt 2>&1; echo rc $?; cat $A/jq-figures-slice3.txt | sed -n '/# b-cap/,$p'
```

## N. Open items and intake notes

None of these is decided here.

- **FP8's output quality** (the one open item, by the architect's framing). The FP8 KV cache
  runs uncalibrated, at scale 1.0, and only the two probes and the error counts checked it (E,
  J). An accuracy check of the FP8 row against the BF16 row would settle the choice between them;
  it is out of this task's scope, since it would be a new tool.
- **Cold start**, ~503 to 531 s on vLLM against llama.cpp's 48 s (C), is accepted for a resident
  agent by **the architect's preference**; the on-demand task takes up loading on demand.
- **Remeasure the agent row's cold start on v0.34.0**, once it is final, in the on-demand or
  two-node task: the start is mostly GB10's mmap-copy cost in weight loading, which #58868 fixes
  in v0.34.0 and not in v0.33.0 (C). The pin stays v0.33.0 until then.
- **Neither row was tested over its cache.** The capacity cell's 526,872 tokens (c) sat at 62%
  of BF16's cache and 30% of FP8's (H); what each row does when sessions outgrow it (queueing,
  preemption) stays unmeasured.
- **Long prompts arriving together prefill serially** on vLLM, ~23.5 s per 65,603 tokens (c, H);
  a burst of long first turns waits in line.
- **The BF16 row's cache depends on the compile cache** (L.1): 725,243 tokens on a compiling start
  against 846,411 warm.
- **The hub is contacted at every start** (A.3): the rows set no offline flag, so a start without
  the network, or with the hub rate-limiting unauthenticated requests, is untested. Setting one is
  a change to spike-model-engines' `host/`, for a later pull request.
- **Intake note, spike-model-engines (currency):** `scripts/currency.sh` compares `VLLM_RELEASE`
  with GitHub's latest release, still named v0.33.0rc3, though the v0.33.0 tag and images are the
  same commit; currency reports the pin against rc3 until GitHub publishes a v0.33.0 release. The
  fix is outside `host/` (goal record, Pending edits).
- **Intake note, the FP8 KV cache:** it runs uncalibrated at scale 1.0, with no accuracy eval
  beyond the two probes; KV-scale calibration was out of this task's scope.
- **For the next task, the capability models on vLLM:** each vLLM start reads the hub (A.3), a
  0.80 row's cache moves with the compile cache (L.1), the suite runs one `vllm` container on port
  8000, so a model per process means more containers or rows than `host/engines` serves today, and
  the step helpers' `footprint` and `readout` already read a vLLM container (B). On the
  Framework, from the session's research of 2026-11-11 (GitHub, cited, not measured):
  - #58868, the GB10 loading fix (in v0.34.0rc0, not v0.33.0; C), doesn't reach ROCm. Only the
    CUDA platform implements `is_integrated_gpu`; the base default returns False (checked at
    v0.34.0rc0, `vllm/platforms/interface.py`, `cuda.py`, `rocm.py`).
  - Its ROCm counterpart, #49991, "[ROCm] Add VLLM_ROCM_CLONE_MMAP_WEIGHTS to avoid slow H2D
    copies from mapped weights", is opt-in, open, and stalled since 2026-09-25. Its kernel cause
    was fixed in Ubuntu 7.0.0-30; the Framework runs Arch.
  - No upstream issue targets vLLM startup on gfx1151. Upstream gfx1151 work is kernel and
    tuning: #50436, #63455, #57614.
  - The Framework's vLLM load time is unmeasured in this spike, so the next task should measure
    it.
- **Intake note, spike-model-engines (vLLM docs):** `docs/engines/vllm/models.md` (lines ~81, 110,
  209, 226, 268-269) and `docs/engines/vllm/api.md` (~11, 102, 142, 148) still describe v0.32.0,
  and neither lists the `gpt-oss-120b-agent` or `gpt-oss-120b-agent-fp8` rows. Both are outside
  `host/`, and this spike changes only `host/`, so the edit is spike-model-engines' own.
- **For two-node:** gb10-1 keeps vLLM v0.33.0's image, its compile cache and gpt-oss-120b's
  safetensors (End state); gb10-2 holds none of them, and staging took 50 min for the weights and
  54 for the image on gb10-1 (A.3). v0.33.0's ~38,058 bytes a token in BF16 and ~19,028 in FP8 (c)
  are the per-token figures a pooled cache would be sized from, and the FP8 quality item above
  applies there too.
