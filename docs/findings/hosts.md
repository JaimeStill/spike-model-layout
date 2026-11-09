# Finding: hosts current, the Framework on b12098, gb10-2 joins and matches gb10-1

Measured 2026-11-09, task `hosts`. This finding is dated: every figure holds for the versions,
stack and network path below, on that day, and nothing after it.

**What it establishes.** Evidence 1, host parity: with both GB10s on the same stack, engine and
preset, gb10-2's output throughput and inter-token latency on anchors A and B sit within run noise
of gb10-1's, so cells measured on either GB10 compare. On the way: all three hosts were brought
current, the Framework moved from llama.cpp b11960 to b12098 without a regression, and gb10-2 left
spike-ai-pipeline's clone for spike-model-engines' engines suite, aligned to gb10-1.

| Host | Serves at the end of the session |
| --- | --- |
| gb10-1 | nothing loaded |
| gb10-2 | set A (4 sections) |
| framework | set A (4 sections) |

## Stack, engine and network path

Read after the root updates (`.state/hosts/stack-2026-11-09.txt`; the session, read-only SSH):

| Host | OS | Kernel | GPU stack | Docker | Engine |
| --- | --- | --- | --- | --- | --- |
| gb10-1 | DGX OS 7.6.0, Ubuntu 24.04.5 LTS | 7.0.0-1025-nvidia | driver 580.178.04, CUDA 13.0, NVIDIA Container Toolkit 1.20.1 | 29.6.2 | llama.cpp `server-cuda13-b12098` |
| gb10-2 | DGX OS 7.6.0, Ubuntu 24.04.5 LTS | 7.0.0-1025-nvidia | driver 580.178.04, CUDA 13.0, NVIDIA Container Toolkit 1.20.1 | 29.6.2 | llama.cpp `server-cuda13-b12098` |
| framework | Omarchy | 7.2.15-1-omarchy | Mesa 26.2.5 | 29.9.2 | llama.cpp `server-vulkan-b11960`, then `server-vulkan-b12098` (build 12098, commit 149f5641b) |

`tailscale ping -c 1` from the laptop: gb10-1 via DERP(nyc) 55 ms, gb10-2 via DERP(iad) 51 ms,
framework via DERP(nyc) 53 ms; no direct connection to any host. Every request in this finding
crossed a relay, which adds to TTFT; TTFT here compares only within this session and path.

Benchmark tool: GuideLLM 0.8.1 from the laptop (`mise.bench.toml`), anchors `bench/anchor-a.yaml`
and `bench/anchor-b.yaml`, run through the `cell` helper in `scripts/measure-lib.sh`.

## A. Hosts brought current (the architect, root)

From `.state/hosts/root-updates.md`, as run:

```
# gb10-1 (11:22 EST)
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove
sudo ./scripts/generate-cdi.sh
cat /var/run/reboot-required 2>/dev/null; echo "exit $?"

# gb10-2
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove && cat /var/run/reboot-required 2>/dev/null; echo "exit $?"
sudo ./scripts/generate-cdi.sh

# framework
omarchy update
```

- **gb10-1 and gb10-2:** 6 packages upgraded on each, same versions: libfreerdp-server3-3,
  libfreerdp3-3 and libwinpr3-3 3.32.1 → 3.32.2+dfsg-0ubuntu0.24.04.1; libnfs14
  5.0.2-1ubuntu0.24.04.1 → .2; openjdk-8-jre and openjdk-8-jre-headless 8u504 → 8u512-b09. The
  plan round had counted 4; the two openjdk-8 packages arrived since. On gb10-2 the upgrade
  removed kernel 7.0.0-1019-nvidia's packages and autoremove its headers and tools (7.0.0-1025,
  7.0.0-1024 and 6.17.0-1008 remain); gb10-1's autoremove removed nothing. No reboot required on
  either (`exit 1`). `generate-cdi.sh` regenerated the CDI spec on both (driver 580.178.04, CDI
  0.7.0).
- **framework:** pacman upgraded mise-bin 2026.11.2-1 → 2026.11.4-1 and spotify 1:1.3.4.258-1 →
  1:1.3.8.620-1; mise tools all current; AUR nothing to do.

After the updates: 0 upgradable on both GB10s, 0 `checkupdates` on the Framework.

## B. The spike-model-engines `host/` pull request

Branch `hosts` in spike-model-engines, commit 3b60fa4, citing this finding:

- The Framework's llama.cpp pin moves from b11960 to b12098 (section C is the evidence).
- The `gemma-4-26B-A4B` QAT preset section gains `ub = 1120`, `image-min-tokens = 560` and
  `mtmd-batch-max-tokens = 512`, taken from spike-ai-pipeline's preset (694f71b), which gb10-2
  served until this session.

Currency after the change reports only held items: the gb10 and strix-halo pins b12098 → b12211
(held for the QAT `_` tag matching, llama.cpp #31620 and #31639), vLLM v0.32.0 → v0.33.0rc3, the
bench python 3.14.10 and the native python 3.12.

Before merge the branch reached each host by a push to the host's clone and a local branch there,
spike-hosting-upgrades' precedent; each host clone returns to `main` once the pull request
merges. On the Framework, as run (`.state/measure/framework/2026-11-09.log`):

```
11:31:45  ssh framework 'cd ~/repos/spike-model-engines && git status -sb | head -1 && git log --oneline -1'
11:31:46  git -C /home/jaime/experiments/spike-model-engines push framework:repos/spike-model-engines hosts:hosts-next
11:31:47  ssh framework 'cd ~/repos/spike-model-engines && git switch -c hosts hosts-next 2>&1 | tail -1 && git log --oneline -1'
```

## C. The Framework: b11960 → b12098

**Decision it informs:** whether the move to b12098 regresses the Framework.

**Configuration (R1–R4).** Tool GuideLLM 0.8.1 from the laptop, helper `cell`, preset section
`gpt-oss-120b-MXFP4-set-a` (args from the load line: `--ctx-size 131072 --kv-unified --parallel 4
--cache-ram 0 --no-cache-idle-slots --checkpoint-min-step 4096`), the only section loaded and
freshly loaded before each run; memory floor 11.2 GiB (`MEASURE_FLOOR_GIB`); tokenizer
`openai/gpt-oss-120b`. Load: anchor A, 1 stream × 8 requests; anchor B, 4 streams × 32 requests;
each request 512 prompt tokens and exactly 256 output tokens. Anchors before the move (R1, R2)
and after it (R3, R4).

| Run | Build | Anchor | Duration | Output tok/s | ITL median (ms) | TTFT median (ms) | Requests |
| --- | --- | --- | --- | --- | --- | --- | --- |
| R1 | vulkan b11960 | A | 64 s | 44.23 | 19.64 | 683 | 8 ok, 0 errored, full |
| R2 | vulkan b11960 | B | 138 s | 71.25 | 46.44 | 2383 | 32 ok, 0 errored, full |
| R3 | vulkan b12098 | A | 63 s | 43.90 | 19.67 | 680 | 8 ok, 0 errored, full |
| R4 | vulkan b12098 | B | 137 s | 70.72 | 46.64 | 2370 | 32 ok, 0 errored, full |

Change in output tok/s: A −0.75%, B −0.74%. Both sit inside the Framework's within-session run
noise of 1.1% (spike-hosting-upgrades, `docs/hosts/framework.md`, "Run noise"). **No
regression.** Available memory stayed at 47.75 GiB (GTT) through every run, far above the floor.

**Deviation.** The first `host/engines llama update` on the Framework ran without
`LLAMA_FLAVOR`. The script defaults an AMD GPU to the rocm flavor, so it moved the container to
`server-rocm-b12098` and removed the `server-vulkan-b11960` image (`.state/hosts/framework-update.log`):

```
llama moved from ghcr.io/ggml-org/llama.cpp:server-vulkan-b11960 to ghcr.io/ggml-org/llama.cpp:server-rocm-b12098
removed image ghcr.io/ggml-org/llama.cpp:server-vulkan-b11960
exit 0
```

Before any b12098 run the session reran it as spike-model-engines'
`docs/engines/llama.cpp/update.md` says, with `LLAMA_FLAVOR=vulkan`:

```
ghcr.io/ggml-org/llama.cpp:server-vulkan-b12098
llama moved from ghcr.io/ggml-org/llama.cpp:server-rocm-b12098 to ghcr.io/ggml-org/llama.cpp:server-vulkan-b12098
exit 0
```

So R3 and R4 ran on `server-vulkan-b12098`, the flavor R1 and R2 ran on. The rocm b12098 image
stays on disk: the update keeps each flavor's image of the pinned build.

**After.** The Framework serves set A again: granite loaded in 3.4 s, E4B in 6.6 s, 26B-A4B in
6.6 s, beside the gpt-oss section left from R4 (19.3 s); 19.03 GiB available (GTT) with all four
loaded. The 26B-A4B section's args show `--ubatch-size 1120 --image-min-tokens 560
--mtmd-batch-max-tokens 512`.

### Commands as run (framework)

From `.state/measure/framework/2026-11-09.log`. xtrace prints each element of a pipeline on its
own line; the filters (`grep`, `tail`, `jq`), the health-poll loop's iterations and every line
inside a helper are left out here and stay in the log.

```
11:27:12  unload --all
11:27:13  loaded
11:27:16  load gpt-oss-120b-MXFP4-set-a
11:27:36  memory
11:27:40  MEASURE_FLOOR_GIB=11.2
11:27:40  cell hosts-fw-b11960-a anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
11:28:50  unload gpt-oss-120b-MXFP4-set-a
11:28:54  load gpt-oss-120b-MXFP4-set-a
11:29:13  MEASURE_FLOOR_GIB=11.2
11:29:13  cell hosts-fw-b11960-b anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
          (the three git commands quoted in section B)
11:31:56  tee .state/hosts/framework-update.log
11:31:56  ssh framework 'cd ~/repos/spike-model-engines && host/engines llama update; echo "exit $?"'
11:36:46  for i in $(seq 1 60)
11:36:46  curl -sf http://framework:8080/health
11:36:49  curl -s http://framework:8080/health
11:36:49  ssh framework 'docker ps --format "{{.Names}} {{.Image}} {{.Status}}"'
11:37:04  ssh framework 'cd ~/repos/spike-model-engines && LLAMA_FLAVOR=vulkan host/engines llama update; echo "exit $?"'
11:37:04  tee -a .state/hosts/framework-update.log
11:37:21  for i in $(seq 1 60)
11:37:21  curl -sf http://framework:8080/health
11:37:24  curl -s http://framework:8080/health
11:37:24  ssh framework 'docker ps --format "{{.Names}} {{.Image}} {{.Status}}"; docker images --format "{{.Repository}}:{{.Tag}}" | grep llama'
11:37:25  curl -s http://framework:8080/models
11:37:29  load gpt-oss-120b-MXFP4-set-a
11:37:49  MEASURE_FLOOR_GIB=11.2
11:37:49  cell hosts-fw-b12098-a anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
11:38:58  unload gpt-oss-120b-MXFP4-set-a
11:39:01  load gpt-oss-120b-MXFP4-set-a
11:39:21  MEASURE_FLOOR_GIB=11.2
11:39:21  cell hosts-fw-b12098-b anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
11:41:47  for m in mrutkows/granite-embedding-english-r2-GGUF:BF16 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
11:41:47  load mrutkows/granite-embedding-english-r2-GGUF:BF16
11:41:51  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
11:41:58  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
11:42:04  loaded
11:42:05  curl -s http://framework:8080/models
11:42:05  memory
11:42:05  ssh framework 'docker exec llama /app/llama-server --version 2>&1 | tail -2'
```

Each `cell` printed its summary line, for example R1's:

```
1 stream(s): requests ok 8, errored 0, incomplete 0 of 8, full yes; output tok/s completed 44.23, every-token 44.23; TTFT median 683 ms; ITL median 19.64 ms
```

## D. gb10-2 onto the engines suite, aligned to gb10-1

**The engines suite.** gb10-2 cloned spike-model-engines at `~/repos/spike-model-engines`, the
path gb10-1 uses, and `host/engines llama update` moved the router's preset mount to it with the
image unchanged (`.state/hosts/align/gb10-2-update.log`):

```
llama restarted ghcr.io/ggml-org/llama.cpp:server-cuda13-b12098 with its preset mount moved from /home/jaime/repos/spike-ai-pipeline/host/llama-preset to /home/jaime/repos/spike-model-engines/host/llama-preset
exit 0
```

gb10-1's router was restarted (`docker restart llama`) to read the `hosts` preset; its 26B-A4B
section then loaded in 12.9 s with `--ctx-size 32768 --parallel 4`.

**Removed from gb10-2:** the spike-ai-pipeline clone (nothing unpushed; only its ignored `.state/`
was local), its mise trust, golangci-lint 2.15.0, and `~/qat-download.log`, the record of the
26B-A4B QAT download (`.state/hosts/align/gb10-2-qat-download.log`, progress bars elided):

```
Fetching 2 files: ... 100%|██████████| 2/2 [11:07<00:00, 333.54s/it]
✓ Downloaded
  path: /srv/models/models--google--gemma-4-26B-A4B-it-qat-q4_0-gguf/snapshots/d1c082be9cf3c8a514acf63b8761f4b41935842e
exit 0 elapsed 668
```

**On both GB10s,** in the engines clone: `MISE_ENV=host mise install` (uv 0.13.7, hf 2.4.0),
`mise upgrade gh` (2.103.3 on both), `mise prune -y` (removed uv 0.13.5 and 0.13.6).

**gb10-1's model store** dropped the repos set A doesn't use (`.state/hosts/align/gb10-1-store-clear.log`):

```
+ mise exec -- hf cache rm -y model/google/gemma-4-12B-it-qat-q4_0-gguf model/google/gemma-4-31B-it-qat-q4_0-gguf model/google/gemma-4-E4B-it-qat-q4_0-gguf model/ibm-granite/granite-embedding-english-r2
+ grep -v Hint
About to delete 4 repo(s) totalling 32.5G.
✓ Deleted 4 repo(s) and 4 revision(s); freed 32.5G.
```

Both stores now hold set A's four repos and nothing else: gpt-oss-120b GGUF 63.4G, gemma-4-26B-A4B
QAT 15.6G, gemma-4-E4B Q8_0 8.6G, granite-embedding GGUF 299.9M.

**gb10-1's drift removed** (`.state/hosts/align/gb10-1-drift.log`, as run):

```
+ rm -rf /home/jaime/.config/gh /home/jaime/.config/byobu /home/jaime/.config/nvidia-ai-workbench /home/jaime/.config/NVIDIA /home/jaime/.config/vllm /home/jaime/.nvwb /home/jaime/.nv /home/jaime/.tilelang /home/jaime/.humming /home/jaime/bench
+ sed -i -e '/#byobu-prompt#$/d' -e '/^# PATH config$/,/^export PATH="$HOME\/.local\/bin:$PATH"$/d' /home/jaime/.bashrc
+ sed -i '120{/^$/d}' /home/jaime/.bashrc
```

That is: the gh login (its token was invalid), byobu's config and its `.bashrc` prompt line, a
duplicate PATH block (dotfiles already puts `~/.local/bin` on PATH), AI Workbench state
(`~/.nvwb`, `~/.config/NVIDIA`, `~/.config/nvidia-ai-workbench`), vLLM leftovers
(`~/.config/vllm`, `~/.tilelang`, `~/.humming`), the `~/.nv` compute cache, and `~/bench`. The
six files in `~/bench` were raw llama-bench output behind spike-model-engines' llama-gb10-native
finding, kept here as they were (`.state/hosts/align/gb10-1-bench.txt`):

```
=== /home/jaime/bench/container-gemma26b.md
| gemma4 26B.A4B Q4_0            |  13.43 GiB |    25.23 B | CUDA       |  99 |   1 |           pp512 |      3303.30 ± 86.34 |
| gemma4 26B.A4B Q4_0            |  13.43 GiB |    25.23 B | CUDA       |  99 |   1 |           tg256 |         79.42 ± 0.08 |
build: 620d2225c (11669)
=== /home/jaime/bench/container-gptoss.md
| gpt-oss 120B MXFP4 MoE         |  59.02 GiB |   116.83 B | CUDA       |  99 |   1 |           pp512 |      2006.80 ± 30.08 |
| gpt-oss 120B MXFP4 MoE         |  59.02 GiB |   116.83 B | CUDA       |  99 |   1 |           tg256 |         58.02 ± 0.04 |
build: 620d2225c (11669)
=== /home/jaime/bench/native-gemma26b.md
(table header only, no rows)
=== /home/jaime/bench/native-gptoss.md
| gpt-oss 120B MXFP4 MoE         |  59.02 GiB |   116.83 B | CUDA       |  99 |   1 |           pp512 |      2021.93 ± 27.11 |
| gpt-oss 120B MXFP4 MoE         |  59.02 GiB |   116.83 B | CUDA       |  99 |   1 |           tg256 |         58.13 ± 0.04 |
build: 620d2225c (11669)
=== /home/jaime/bench/walk-native-gemma26b.err
ggml_cuda_init: found 1 CUDA devices (Total VRAM: 124544 MiB):
  Device 0: NVIDIA GB10, compute capability 12.1, VMM: yes, VRAM: 124544 MiB
load_backend: loaded CUDA backend from /opt/llama.cpp/b11669/libggml-cuda.so
load_backend: loaded RPC backend from /opt/llama.cpp/b11669/libggml-rpc.so
load_backend: loaded CPU backend from /opt/llama.cpp/b11669/libggml-cpu-armv8.6_2.so
=== /home/jaime/bench/walk-native-gemma26b.md
| gemma4 26B.A4B Q4_0            |  13.43 GiB |    25.23 B | CUDA       |  99 |   1 |           pp512 |      3343.04 ± 75.65 |
| gemma4 26B.A4B Q4_0            |  13.43 GiB |    25.23 B | CUDA       |  99 |   1 |           tg256 |         80.18 ± 0.13 |
build: 620d2225c (11669)
```

Each table's header rows are omitted above; the record holds them.

**Result.** `.bashrc` is identical on the two GB10s. Their home directories' top-level entries
differ only in `.lesshst` and `.viminfo`, and the router containers' settings (the after-inspects
in `.state/hosts/align/`) differ only in the tailnet address each binds. Deeper per-host app state
(dconf, btop, eog, gtk-4.0, yelp, the pnpm and fastfetch caches, and gb10-2's lazygit) is left as
each host's own use.

**Pending, the architect's root step:** gb10-2 has no drop-caches sudoers rule yet. The architect
was given:

```
echo "jaime ALL=(root) NOPASSWD: /usr/sbin/sysctl vm.drop_caches=3" | sudo tee /etc/sudoers.d/drop-caches.new >/dev/null && sudo visudo -cf /etc/sudoers.d/drop-caches.new && sudo install -m 0440 -o root -g root /etc/sudoers.d/drop-caches.new /etc/sudoers.d/drop-caches && sudo rm /etc/sudoers.d/drop-caches.new
```

Result: PENDING at the time of writing.

## E. Parity: gb10-2 against gb10-1

**Decision it informs:** whether cells measured on gb10-2 compare with cells measured on gb10-1.

**Configuration (R5–R12).** As section C on both GB10s, with the memory floor at 12.2 GiB. Order:
gb10-1 A, gb10-2 A, gb10-1 B, gb10-2 B, twice. Each run freshly loaded `gpt-oss-120b-MXFP4-set-a`
as the only section (44.4–47.7 s per load).

**Criterion (decided in the plan round).** gb10-2's mean output tok/s and mean ITL each within run
noise of gb10-1's. Run noise is the larger of gb10-1's within-session spread from
spike-hosting-upgrades (2.2%, `docs/hosts/gb10-1.md`) and this session's spread, where spread is
(highest − lowest) / lowest. TTFT is recorded, not judged.

| Run | Host | Anchor | Duration | Output tok/s | ITL median (ms) | TTFT median (ms) |
| --- | --- | --- | --- | --- | --- | --- |
| R5 | gb10-1 | A | 54 s | 49.33 | 18.16 | 466 |
| R6 | gb10-2 | A | 54 s | 48.75 | 18.14 | 477 |
| R7 | gb10-1 | B | 118 s | 82.13 | 43.09 | 1320 |
| R8 | gb10-2 | B | 119 s | 81.09 | 43.64 | 1334 |
| R9 | gb10-1 | A | 65 s | 48.38 | 18.61 | 461 |
| R10 | gb10-2 | A | 65 s | 47.62 | 18.79 | 490 |
| R11 | gb10-1 | B | 118 s | 82.09 | 42.97 | 1327 |
| R12 | gb10-2 | B | 119 s | 81.51 | 43.40 | 1324 |

Every run was full, with 0 errored and 0 incomplete requests; available memory stayed between
51.78 and 51.99 GiB, far above the floor.

| Anchor | Measure | gb10-1 mean | gb10-2 mean | Difference | Run noise | Within |
| --- | --- | --- | --- | --- | --- | --- |
| A | output tok/s | 48.86 | 48.19 | −1.37% | 2.37% | yes |
| A | ITL (ms) | 18.39 | 18.47 | +0.44% | 2.37% | yes |
| B | output tok/s | 82.11 | 81.30 | −0.99% | 2.2% | yes |
| B | ITL (ms) | 43.03 | 43.52 | +1.14% | 2.2% | yes |

This session's output tok/s spreads: A gb10-1 1.96%, gb10-2 2.37%; B gb10-1 0.05%, gb10-2 0.52%.
So A's run noise is 2.37% (this session's, on gb10-2) and B's is 2.2% (the earlier gb10-1 figure).

**Verdict: parity holds.** Cells measured on gb10-1 and gb10-2 compare.

Single runs do not: on anchor A the extremes, R5 49.33 and R10 47.62 tok/s, differ by 3.6%,
beyond either host's noise. That is why the criterion judges means over repeats, not single runs.

For context only, not judged (a different session): gb10-1's history at b12098 in
spike-hosting-upgrades (`docs/screens/gb10-1/2026-11-05.md`) reads A 49.71 and 50.66, B 80.02
and 78.06 tok/s.

**After.** gb10-2 serves set A: granite loaded in 3.6 s, E4B in 10.0 s, 26B-A4B in 13.3 s,
gpt-oss in 44.7 s. gb10-1 has nothing loaded. On a GB10 the set-A gpt-oss section loads in about
44–48 s (every load in this section).

### Commands as run (gb10-1 and gb10-2)

From `.state/measure/gb10-1/2026-11-09.log` and `.state/measure/gb10-2/2026-11-09.log`, merged
in time order; filters and helper internals left out as in section C. The list is rebuilt from
the logs' xtrace lines, one helper call a line, so a typed pipeline shows as its parts and a call
inside `$( )` as the bare call; the clearing step, for one, was typed as
`(source scripts/measure-lib.sh gb10-1 2>/dev/null; unload --all >/dev/null; echo "gb10-1: $(loaded)") ; (source scripts/measure-lib.sh gb10-2 2>/dev/null; unload --all >/dev/null; echo "gb10-2: $(loaded)")`.

```
gb10-2  11:45:39  loaded
gb10-2  11:45:40  for m in mrutkows/granite-embedding-english-r2-GGUF:BF16 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 gpt-oss-120b-MXFP4-set-a
gb10-2  11:45:40  load mrutkows/granite-embedding-english-r2-GGUF:BF16
gb10-2  11:45:43  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
gb10-2  11:45:53  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
gb10-2  11:46:09  load gpt-oss-120b-MXFP4-set-a
gb10-2  11:46:54  loaded
gb10-2  11:46:55  curl -s http://gb10-2:8080/models
gb10-2  11:46:55  memory
gb10-2  11:46:56  curl -s http://gb10-2:8080/models
gb10-1  11:47:02  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
gb10-1  11:47:15  curl -s http://gb10-1:8080/models
gb10-1  11:47:15  unload google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
gb10-1  11:47:19  loaded
gb10-1  11:47:19  ssh gb10-2 'sudo -n -l 2>&1 | grep drop_caches || echo "gb10-2: no drop_caches rule yet"'
gb10-1  11:47:34  unload --all
gb10-1  11:47:34  loaded
gb10-2  11:47:34  unload --all
gb10-2  11:47:49  loaded
gb10-1  11:47:52  load gpt-oss-120b-MXFP4-set-a
gb10-1  11:48:37  MEASURE_FLOOR_GIB=12.2
gb10-1  11:48:37  cell hosts-par-r5-gb10-1-a anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
gb10-1  11:49:33  unload gpt-oss-120b-MXFP4-set-a
gb10-2  11:49:40  load gpt-oss-120b-MXFP4-set-a
gb10-2  11:50:28  MEASURE_FLOOR_GIB=12.2
gb10-2  11:50:28  cell hosts-par-r6-gb10-2-a anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
gb10-2  11:51:23  unload gpt-oss-120b-MXFP4-set-a
gb10-1  11:51:31  load gpt-oss-120b-MXFP4-set-a
gb10-1  11:52:16  MEASURE_FLOOR_GIB=12.2
gb10-1  11:52:16  cell hosts-par-r7-gb10-1-b anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
gb10-1  11:54:16  unload gpt-oss-120b-MXFP4-set-a
gb10-2  11:54:23  load gpt-oss-120b-MXFP4-set-a
gb10-2  11:55:08  MEASURE_FLOOR_GIB=12.2
gb10-2  11:55:08  cell hosts-par-r8-gb10-2-b anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
gb10-2  11:57:09  unload gpt-oss-120b-MXFP4-set-a
gb10-1  11:57:16  load gpt-oss-120b-MXFP4-set-a
gb10-1  11:58:03  MEASURE_FLOOR_GIB=12.2
gb10-1  11:58:03  cell hosts-par-r9-gb10-1-a anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
gb10-1  11:59:10  unload gpt-oss-120b-MXFP4-set-a
gb10-2  11:59:17  load gpt-oss-120b-MXFP4-set-a
gb10-2  12:00:02  MEASURE_FLOOR_GIB=12.2
gb10-2  12:00:02  cell hosts-par-r10-gb10-2-a anchor-a gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
gb10-2  12:01:08  unload gpt-oss-120b-MXFP4-set-a
gb10-1  12:01:14  load gpt-oss-120b-MXFP4-set-a
gb10-1  12:02:00  MEASURE_FLOOR_GIB=12.2
gb10-1  12:02:00  cell hosts-par-r11-gb10-1-b anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
gb10-1  12:04:00  unload gpt-oss-120b-MXFP4-set-a
gb10-2  12:04:07  load gpt-oss-120b-MXFP4-set-a
gb10-2  12:04:54  MEASURE_FLOOR_GIB=12.2
gb10-2  12:04:54  cell hosts-par-r12-gb10-2-b anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
gb10-2  12:06:55  unload gpt-oss-120b-MXFP4-set-a
gb10-2  12:07:14  for m in mrutkows/granite-embedding-english-r2-GGUF:BF16 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 gpt-oss-120b-MXFP4-set-a
gb10-2  12:07:14  load mrutkows/granite-embedding-english-r2-GGUF:BF16
gb10-2  12:07:18  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
gb10-2  12:07:28  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
gb10-2  12:07:42  load gpt-oss-120b-MXFP4-set-a
gb10-2  12:08:27  loaded
gb10-2  12:08:27  ssh gb10-2 'cd ~/repos/spike-model-engines && MISE_ENV=host HF_HUB_CACHE=/srv/models mise exec -- hf cache ls --format json 2>/dev/null'
gb10-2  12:08:28  cat .state/hosts/align/gb10-2-repos-store-before.txt
gb10-2  12:08:28  ssh gb10-2 'du -sb /srv/models/models--*'
gb10-2  12:08:29  ssh gb10-2 'sudo -n -l 2>&1 | grep drop_caches || echo "gb10-2: no drop_caches rule yet"'
```

### Commands not in a step log

The stack read and the alignment steps in section D ran from the laptop, outside the step helpers,
from this project's root. As run, grouped by step (output went to the session and, where named, to
`.state/hosts/`):

```sh
# the stack read and the ping (.state/hosts/stack-2026-11-09.txt)
for h in gb10-1 gb10-2; do echo "== $h"; timeout 60 ssh -o BatchMode=yes $h 'apt list --upgradable 2>/dev/null | grep -vc "^Listing"; uname -r; nvidia-smi --query-gpu=driver_version --format=csv,noheader; nvidia-smi | grep -o "CUDA Version: [0-9.]*"; docker --version; nvidia-ctk --version | head -1; . /etc/os-release; echo $PRETTY_NAME; cat /etc/dgx-release 2>/dev/null | grep -i version | head -2; docker ps --format "{{.Names}} {{.Image}} {{.Status}}"'; done; echo "== framework"; timeout 60 ssh -o BatchMode=yes framework 'checkupdates 2>/dev/null | wc -l; uname -r; pacman -Q mesa docker 2>/dev/null; docker ps --format "{{.Names}} {{.Image}} {{.Status}}"'; for h in gb10-1 gb10-2 framework; do tailscale ping -c 1 $h; done

# gb10-2's clone, and the hosts branch on both GB10s
ssh gb10-2 'cd ~/repos && git clone -q https://github.com/JaimeStill/spike-model-engines.git && cd spike-model-engines && git log --oneline -1 && git status -sb | head -1'
for h in gb10-1 gb10-2; do git -C ~/experiments/spike-model-engines push $h:repos/spike-model-engines hosts:hosts-next 2>&1 | tail -1; ssh $h 'cd ~/repos/spike-model-engines && git switch -c hosts hosts-next 2>&1 | tail -1 && git log --oneline -1'; done

# gb10-2's preset mount moved, gb10-1's router restarted on the hosts preset
ssh gb10-2 'cd ~/repos/spike-model-engines && host/engines llama update; echo "exit $?"' 2>&1 | tee .state/hosts/align/gb10-2-update.log; for i in $(seq 1 60); do curl -sf http://gb10-2:8080/health >/dev/null && break; sleep 3; done; curl -s http://gb10-2:8080/health; echo; ssh gb10-1 'docker restart llama' ; for i in $(seq 1 60); do curl -sf http://gb10-1:8080/health >/dev/null && break; sleep 3; done; curl -s http://gb10-1:8080/health; echo

# spike-ai-pipeline's leftovers on gb10-2
ssh gb10-2 'set -x; mise trust --untrust ~/repos/spike-ai-pipeline; rm -rf ~/repos/spike-ai-pipeline; mise uninstall golangci-lint@2.15.0; rm ~/qat-download.log; set +x; ls ~/repos; ls ~/.local/state/mise/trusted-configs/; mise ls | grep -c golangci' 2>&1

# the engines host tools on both GB10s, gh, and the prune (the prune and gb10-2's gh in ~)
for h in gb10-1 gb10-2; do echo "== $h"; ssh $h 'cd ~/repos/spike-model-engines && MISE_ENV=host mise install 2>&1 | tail -3; [ "$(hostname)" = gb10-1 ] && mise upgrade gh 2>&1 | tail -2; MISE_ENV=host mise ls --current 2>/dev/null; mise ls gh 2>/dev/null' ; done
ssh gb10-2 'mise upgrade gh 2>&1 | tail -1'; for h in gb10-1 gb10-2; do echo "== $h"; ssh $h 'cd ~ && mise prune --dry-run 2>&1 | tail -8'; done
for h in gb10-1 gb10-2; do echo "== $h"; ssh $h 'cd ~ && mise prune -y 2>&1 | grep -E "uninstall$|is prunable" ; mise ls gh uv pipx:huggingface_hub 2>/dev/null'; done

# the before state, and the two files quoted before removal (.state/hosts/align/)
for h in gb10-1 gb10-2; do ssh $h 'docker inspect llama' > .state/hosts/align/$h-inspect-before.json; ssh $h 'ls -A ~ | sort' > .state/hosts/align/$h-home-before.txt; ssh $h 'ls -A ~/repos; ls /srv/models' > .state/hosts/align/$h-repos-store-before.txt; done; ssh gb10-2 'cat ~/qat-download.log' > .state/hosts/align/gb10-2-qat-download.log; ssh gb10-1 'for f in ~/bench/*; do echo "=== $f"; cat "$f"; done' > .state/hosts/align/gb10-1-bench.txt; wc -l .state/hosts/align/*; diff .state/hosts/align/gb10-1-home-before.txt .state/hosts/align/gb10-2-home-before.txt; cat .state/hosts/align/*repos-store-before.txt
ssh gb10-1 'ls -la ~/.humming; file ~/.humming/* 2>/dev/null | head; du -sh ~/.humming'

# gb10-1's store: listed, then the four repositories outside set A removed
ssh gb10-1 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; mise exec -- hf cache --help 2>&1 | sed -n 1,25p; mise exec -- hf cache ls 2>&1 | head -20'
ssh gb10-1 'cd ~/repos/spike-model-engines && export MISE_ENV=host HF_HUB_CACHE=/srv/models; set -x; mise exec -- hf cache rm -y model/google/gemma-4-12B-it-qat-q4_0-gguf model/google/gemma-4-31B-it-qat-q4_0-gguf model/google/gemma-4-E4B-it-qat-q4_0-gguf model/ibm-granite/granite-embedding-english-r2 2>&1 | grep -v Hint; set +x; ls /srv/models; df -h /srv/models | tail -1' 2>&1 | tee .state/hosts/align/gb10-1-store-clear.log

# gb10-1's drift: compared, then removed
diff <(ssh gb10-1 cat ~/.bashrc) <(ssh gb10-2 cat ~/.bashrc); ssh gb10-1 'sed -n 110,130p ~/.bashrc'; grep -rn "local/bin" ~/dotfiles/platforms/dgx/*.sh ~/dotfiles/shell/env.sh 2>/dev/null | head -5
ssh gb10-2 'bash -ic "echo \$PATH" 2>/dev/null | tr : "\n" | grep -n local/bin'; grep -rn "local/bin" ~/dotfiles/platforms/dgx/bashrc ~/dotfiles/shell 2>/dev/null | head -3
diff <(ssh gb10-1 'ls -A ~/.config | sort') <(ssh gb10-2 'ls -A ~/.config | sort'); diff <(ssh gb10-1 'ls -A ~/.local/share ~/.cache 2>/dev/null') <(ssh gb10-2 'ls -A ~/.local/share ~/.cache 2>/dev/null')
ssh gb10-1 'ls -laR ~/.config/NVIDIA | head -15; du -sh ~/.config/NVIDIA'
ssh gb10-1 'set -x
rm -rf ~/.config/gh ~/.config/byobu ~/.config/nvidia-ai-workbench ~/.config/NVIDIA ~/.config/vllm ~/.nvwb ~/.nv ~/.tilelang ~/.humming ~/bench
sed -i -e "/#byobu-prompt#\$/d" -e "/^# PATH config\$/,/^export PATH=\"\$HOME\/.local\/bin:\$PATH\"\$/d" ~/.bashrc
set +x' 2>&1 | tee .state/hosts/align/gb10-1-drift.log; diff <(ssh gb10-1 cat ~/.bashrc) <(ssh gb10-2 cat ~/.bashrc) && echo "bashrc identical"; diff <(ssh gb10-1 'ls -A ~ | sort') <(ssh gb10-2 'ls -A ~ | sort'); ssh gb10-1 'bash -ic "echo \$PATH" 2>/dev/null | tr : "\n" | grep -c local/bin'
ssh gb10-1 'sed -n 117,121p ~/.bashrc | cat -A | head -5'; ssh gb10-1 'set -x; sed -i "120{/^\$/d}" ~/.bashrc; set +x' 2>&1 | tee -a .state/hosts/align/gb10-1-drift.log; diff <(ssh gb10-1 cat ~/.bashrc) <(ssh gb10-2 cat ~/.bashrc) && echo "bashrc identical"

# the containers compared after (.state/hosts/align/*-inspect-after.json)
for h in gb10-1 gb10-2; do ssh $h 'docker inspect llama' | jq '.[0] | {Image: .Config.Image, Cmd: .Config.Cmd, Entrypoint: .Config.Entrypoint, Env: .Config.Env, Healthcheck: .Config.Healthcheck, User: .Config.User, Restart: .HostConfig.RestartPolicy, Network: .HostConfig.NetworkMode, Ports: .HostConfig.PortBindings, DeviceRequests: .HostConfig.DeviceRequests, Devices: .HostConfig.Devices, Log: .HostConfig.LogConfig, Mounts: [.Mounts[] | {Type, Source, Destination, RW}], ShmSize: .HostConfig.ShmSize, Ulimits: .HostConfig.Ulimits}' > .state/hosts/align/$h-inspect-after.json; done; diff .state/hosts/align/gb10-1-inspect-after.json .state/hosts/align/gb10-2-inspect-after.json | sed -E 's/100\.[0-9]+\.[0-9]+\.[0-9]+/<tailnet address>/g'
```

`mise upgrade gh` moved gb10-1 from 2.102.1 and gb10-2 from 2.103.0 to 2.103.3, then the latest;
the prune removed uv 0.13.5 and 0.13.6 on both. The golangci-lint check's exit 1 is `grep -c`
counting none.

## F. Carried forward

- gb10-2 has no host descriptor and no run-noise figure in spike-hosting-upgrades. This session's
  within-session spread on gb10-2 (A 2.37%, B 0.52% output tok/s) is the first.
- gb10-2's drop-caches sudoers rule, pending above.
- The spike-model-engines `hosts` pull request is open; each host's clone returns to `main` once
  it merges.
