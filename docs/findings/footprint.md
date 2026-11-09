# Finding: set A's footprint on each host class, and the capacity table

Measured 2026-11-09, task `footprint`. This finding is dated: every figure holds for the versions,
stack, preset and network path below, on that day, and nothing after it.

**What it establishes.** What each set A model costs in memory on a GB10 and on the Framework:
its weights, its KV for each 1,000 tokens of context, its sliding-window KV per slot, its compute
buffers, and how far it grows from idle to its warmed peak and under load. Section I turns those
figures into a capacity table a placement can be computed from, and works one placement: the
agent's 131,072-token sessions on an agent-only GB10 (9 sessions). On the way it found that set A's
Gemma sections leave llama.cpp's host prompt cache at its default (8192 MiB a process), which took
gb10-1 under its floor under vision load (section G).

| Host | Serves at the end of the session |
| --- | --- |
| gb10-1 | nothing loaded, as the hosts task left it (117.61 GiB available) |
| gb10-2 | set A (4 sections), unchanged: no load, unload or request this task |
| framework | set A (4 sections), freshly reloaded after L4 (19.08 GiB available, GTT) |

## Stack, engine and network path

Read by the session over SSH, read-only, at 2026-11-09T14:31:40-05:00 (19:31:40Z), before the root
updates (`.state/footprint/stack-2026-11-09.txt`):

| Host | Pending updates | OS | Kernel | GPU stack | Docker | Engine |
| --- | --- | --- | --- | --- | --- | --- |
| gb10-1 | 4 (apt) | DGX OS 7.6.0 (`DGX_OTA_VERSION`), Ubuntu 24.04.5 LTS | 7.0.0-1025-nvidia | driver 580.178.04, CUDA 13.0, NVIDIA Container Toolkit 1.20.1 | 29.6.2 | llama.cpp `server-cuda13-b12098` |
| gb10-2 | 4 (apt) | as gb10-1 | 7.0.0-1025-nvidia | as gb10-1 | 29.6.2 | llama.cpp `server-cuda13-b12098` |
| framework | 0 (`checkupdates`) | Omarchy | 7.2.15-1-omarchy | mesa 1:26.2.5-1 | 1:29.9.2-1 | llama.cpp `server-vulkan-b12098` |

The stack is the hosts finding's ([hosts](hosts.md), "Stack, engine and network path") in every
column. The root updates (section A) moved no kernel, driver or Mesa.

**Network path.** At the stack read, `tailscale ping -c 1` from the laptop: gb10-1 via DERP(nyc)
56 ms, gb10-2 via DERP(nyc) 62 ms, framework via DERP(nyc) 57 ms, no direct connection to any
host. After the architect's pause the path turned direct: gb10-1 direct, 3 ms, at
21:02:53Z; the Framework direct, 3 ms, at 21:09:21Z. So gb10-1's alone loads, set A and P1-P4
(19:40-19:51Z) ran over the relay, and gb10-1's L1-L4 (21:03-21:08Z) and every Framework step
(21:09Z on) ran direct on the LAN. Speed is recorded, not judged, in this task; TTFT here compares
only within one host and one path.

**Engine and preset.** llama.cpp b12098 on both host classes, its router serving spike-model-engines'
shared preset (`host/llama-preset/models.ini`; the hosts task's sections). Set A is four sections:

| Section id | Model | c | Slots | KV | Other keys that change memory |
| --- | --- | --- | --- | --- | --- |
| `gpt-oss-120b-MXFP4-set-a` | gpt-oss-120b MXFP4 (agent) | 131072 | 4 | unified | `cache-ram = 0`, `cache-idle-slots = false`, `checkpoint-min-step = 4096` |
| `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` | Gemma 4 26B-A4B QAT Q4_0 (vision) | 32768 | 4 | per slot (8192 each) | `ub = 1120`, `image-min-tokens = 560`, `mtmd-batch-max-tokens = 512`; no `cache-ram`, so the default 8192 MiB |
| `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` | Gemma 4 E4B Q8_0 (audio) | 32768 | 4 | per slot (8192 each) | no `cache-ram`, so the default 8192 MiB |
| `mrutkows/granite-embedding-english-r2-GGUF:BF16` | granite-embedding-english-r2 BF16 (embedding) | 131072 | 16 | none logged | `embeddings = true`, `batch-size = ubatch-size = 8192` |

On gb10-1 two more gpt-oss-120b sections were loaded alone (section D):
`ggml-org/gpt-oss-120b-GGUF:MXFP4` (c 32768, 4 slots, per slot) and `gpt-oss-120b-MXFP4-16-slots`
(c 131072, 16 slots, per slot). Neither sets `cache-ram`.

**Tools.** The `footprint` step helper in `scripts/measure-lib.sh` (slice 1, commit 288b73a):
for each llama-server process, named by its `--alias`, the GPU memory from nvidia-smi's
compute-apps list and the RSS from `ps` on a GB10, or VRAM and GTT from `amdgpu_top -p` on the
Framework; the pool (MemTotal, MemAvailable and Cached, or GTT used of total); and the router log's
buffer-size lines since a given time. It changes nothing on the host. Every cell is GuideLLM 0.8.1
from the laptop (`mise.bench.toml`), run by `cell` under `watch`: the pool sampled every 10 s into
`<cell>.watch.tsv`, the cell stopped under the floor, capped at 10 min. Each cell's GuideLLM JSON,
`.watch.tsv`, `.exit` and `.log` are under `.state/measure/<host>/`, named `footprint-gb10-1-*` and
`footprint-fw-*`.

**Reading the figures.** On a GB10 the pool is MemAvailable, read just after dropping the page
cache (`ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3`, the existing sudoers rule), against a
floor of 12.2 GiB (10% of MemTotal 121.63 GiB). On the Framework the pool is GTT, against a floor of
11.2 GiB (10% of the 112 GiB GTT), per spike-hosting-upgrades `docs/policy.md`, "Memory headroom".
The logs give buffers in MiB; pools are in GiB (1 GiB = 1024 MiB). The command lists below show the
step logs' local times (UTC−5); the prose gives UTC.

## A. Hosts brought current (Behavior 1)

From `.state/footprint/root-updates.md`. **gb10-2:** the architect ran this command and pasted its output in full:

```
sudo apt update && sudo apt full-upgrade -y && sudo apt autoremove -y && cat /var/run/reboot-required 2>/dev/null; echo "exit $?"
```

It upgraded 4 packages: gir1.2-soup-3.0, libsoup-3.0-0 and libsoup-3.0-common 3.4.4-5ubuntu0.10 →
.11; python3-pyasn1 0.4.8-4ubuntu0.3 → .4. needrestart found the running kernel up to date,
restarted cups.service, and no container needed restarting; autoremove removed nothing; no reboot
required (`exit 1`). **gb10-1:** the architect reports it ran clean with the same command; its
output was not pasted, so this record has only the session's check afterwards. **framework:** 0
pending (`checkupdates`), no root step.

The session's check afterwards (read-only; the command is under "Commands not in a step log"):
both GB10s 0 upgradable, libsoup-3.0-0 3.4.4-5ubuntu0.11 and python3-pyasn1 0.4.8-4ubuntu0.4
installed, no `/var/run/reboot-required`, kernel 7.0.0-1025-nvidia, the llama container up 3 hours
(healthy).

No kernel, driver or Mesa moved, so **anchor A did not run** on any host (the brief's rule).

## B. Method

Each `footprint` read prints every llama-server process: on gb10-1 `gpu` (nvidia-smi) and `rss`; on
the Framework `vram`, `gtt` and `rss`. The router itself is a process: on gb10-1 170 MiB GPU and
341 MiB RSS before any load; on the Framework 0 MiB VRAM, 2 MiB GTT and 97 MiB RSS.

Process figures are read after each step and after each cell; the pool is also sampled every 10 s
during a cell by `watch`. So "highest under load" is the highest of the reads after L1-L4, and the
pool's lowest is the watch's.

## C. Each section alone (Behavior 3)

**Decision it informs:** what each model costs on its own, the input to any placement.

**Configuration.** Each set A section loaded alone with nothing else loaded (`unload --all` first),
on gb10-1 from a dropped page cache before and after, on the Framework from GTT. Load: no requests;
each section read once, idle. Duration: the load time below, plus about 5 s of reads.

### gb10-1

| Section | Load | MemAvailable before → after (GiB) | Taken (GiB) | Process GPU / RSS (MiB) | Cached after (GiB) |
| --- | --- | --- | --- | --- | --- |
| gpt-oss set-a | 47.8 s | 117.70 → 52.37 | 65.33 | 64911 / 1265 | 1.37 |
| 26B-A4B | 12.8 s | 117.73 → 98.78 | 18.95 | 18015 / 1217 | 1.28 |
| E4B | 9.8 s | 117.62 → 107.22 | 10.40 | 6530 / 4143 | 4.15 |
| granite | 3.4 s | 117.66 → 116.14 | 1.52 | 863 / 829 | 1.06 |

The "before" figure is the `memory` or `footprint` read just before each load (117.70 is the
footprint read with nothing loaded; the others are `memory`).

Logged buffers (MiB), from each load's own lines in the router log:

| Section | Weights GPU (CUDA0) | Weights host (CUDA_Host) | Projector | Full-attention KV | Sliding-window KV | Compute GPU | Compute host | Projector compute GPU / CPU | Output (host) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gpt-oss set-a | 59851.68 | 586.82 | – | 4608.00 (131072 cells, 18 layers, 4/1 seqs) | 36.00 (1024 cells, 18 layers, 4/1 seqs) | 221.04 | 153.54 | – | 3.07 |
| 26B-A4B | 13755.42 | 577.50 | 1139.46 (gemma4v) | 640.00 (8192 cells, 5 layers, 4/4 seqs) | 1800.00 (2304 cells, 25 layers, 4/4 seqs) | 335.29 | 70.61 | 150.63 / 6.77 | 4.00 |
| E4B | 4788.12 | 3536.00 | 533.83 (one file, logged for gemma4v and for gemma4a) | 512.00 (8192 cells, 4 layers, 4/4 seqs) | 160.00 (1024 cells, 20 layers, 4/4 seqs) | 137.02 | 50.03 | 101.27 + 101.19 / 6.77 + 1.58 | 4.00 |
| granite | 210.51 | 73.78 | – | none logged | none logged | 460.13 | 352.19 | – | 3.12 |

The router also logged each projector's estimated worst case at load: 26B-A4B 1296.85 MiB, E4B
746.89 MiB.

**On a GB10 a process's GPU figure is its logged GPU buffers plus a CUDA context of about
194 MiB.** The GPU buffers are the CUDA0 model, KV and compute buffers and, for a Gemma, the
projector's weights and its CUDA0 compute buffer (the E4B's projector counted once: it is one
file):

| Section | Logged GPU buffers (MiB) | nvidia-smi (MiB) | Difference (MiB) |
| --- | --- | --- | --- |
| gpt-oss set-a | 59851.68 + 4608 + 36 + 221.04 = 64716.72 | 64911 | 194.28 |
| gpt-oss c 32768 × 4 | 59851.68 + 1152 + 108 + 98.77 = 61210.45 | 61405 | 194.55 |
| gpt-oss c 131072 × 16 | 59851.68 + 4608 + 432 + 98.77 = 64990.45 | 65185 | 194.55 |
| 26B-A4B | 13755.42 + 640 + 1800 + 335.29 + 1139.46 + 150.63 = 17820.80 | 18015 | 194.20 |
| E4B | 4788.12 + 512 + 160 + 137.02 + 533.83 + 101.27 + 101.19 = 6333.43 | 6530 | 196.57 |
| granite | 210.51 + 460.13 = 670.64 | 863 | 192.36 |

The context runs 192.36 to 196.57 MiB. The host buffers (CUDA_Host) are not in the GPU figure; they
sit in the process's RSS.

**The E4B's host weights stay in the page cache.** Its 3536.00 MiB CUDA_Host model buffer is mapped
from the GGUF: after the drop, Cached read 4.15 GiB with the E4B loaded alone, against 1.06 to
1.37 GiB for every other alone load, and its RSS (4143 MiB) carries the same pages. Set A's Cached
after a drop reads 6.06 GiB, the E4B's mapped weights among it.

### Framework

| Section | Load | GTT used before → after (GiB) | Taken (GiB) | Process VRAM / GTT / RSS (MiB) |
| --- | --- | --- | --- | --- |
| gpt-oss set-a | 18.2 s | 0.28 → 64.20 | 63.92 | 3 / 65459 / 219 |
| 26B-A4B | 6.1 s | 0.28 → 18.23 | 17.95 | 1 / 18380 / 240 |
| E4B | 3.1 s | 0.28 → 9.98 | 9.70 | 1 / 9929 / 247 |
| granite | 3.1 s | 0.28 → 1.36 | 1.08 | 0 / 1102 / 123 |

`memory` read 111.72 GiB available (GTT) before each load. The logged buffers are gb10-1's, with
`Vulkan0` and `Vulkan_Host` for `CUDA0` and `CUDA_Host`, except:

| Section | Weights GPU (Vulkan0) | Compute GPU | Compute host |
| --- | --- | --- | --- |
| gpt-oss set-a | 59851.64 | 219.02 | 151.54 |
| 26B-A4B | 13755.36 | 239.04 | 70.64 |
| E4B | 4788.10 | 137.02 | 50.04 |
| granite | 210.51 | 460.13 | 352.19 |

KV, projector and host weight buffers read the same as gb10-1's on every section.

**On the Framework a process's GTT figure is every logged buffer, device and host, within 6 MiB:**
gpt-oss 65456.09 against 65459; 26B-A4B 18376.63 against 18380; E4B 9923.45 against 9929 (its
3536 MiB host weights included); granite 1099.73 against 1102. Host buffers are in GTT here, so the
Framework's RSS stays near 120 to 250 MiB a process where a GB10's runs 829 to 4143 MiB.

## D. gpt-oss-120b's KV against c (Behavior 4, gb10-1 only)

**Decision it informs:** whether KV per 1,000 tokens can be taken from one load and scaled, the
basis of every computed column in section I.

**Configuration.** Each of gpt-oss-120b's two other sections loaded alone as in section C (no
load, read once).

| Section | Load | c × slots, KV mode | MemAvailable before → after (GiB) | Taken (GiB) | GPU / RSS (MiB) | Full-attention KV (MiB) | B/token | Sliding-window KV (MiB) | Compute GPU / host (MiB) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `ggml-org/gpt-oss-120b-GGUF:MXFP4` | 47.4 s | 32768 × 4, per slot | 117.71 → 55.93 | 61.78 | 61405 / 1144 | 1152.00 (8192 cells, 4/4 seqs) | 36,864 | 108.00 (768 cells, 4/4 seqs): 27 a slot | 98.77 / 31.28 |
| `gpt-oss-120b-MXFP4-set-a` | 47.8 s | 131072 × 4, unified | 117.70 → 52.37 | 65.33 | 64911 / 1265 | 4608.00 (131072 cells, 4/1 seqs) | 36,864 | 36.00 (1024 cells, 4/1 seqs) | 221.04 / 153.54 |
| `gpt-oss-120b-MXFP4-16-slots` | 48.0 s | 131072 × 16, per slot | 117.70 → 52.16 | 65.54 | 65185 / 1156 | 4608.00 (8192 cells, 16/16 seqs) | 36,864 | 432.00 (768 cells, 16/16 seqs): 27 a slot | 98.77 / 31.28 |

**Full-attention KV is exactly 36,864 B/token × c** at all three: 36,864 × 32,768 = 1152 MiB and
36,864 × 131,072 = 4608 MiB, whether the 131,072 tokens are one unified pool over 4 slots or 16
slots of 8,192. That is 35.16 MiB per 1,000 tokens.

**Sliding-window KV and compute follow the KV mode and the slot count, not c.** Per slot, the SWA
cache is 27 MiB (768 cells) at 4 slots and at 16; the unified pool keeps one 1024-cell window for
all 4 slots, 36 MiB. Compute is 98.77 MiB GPU and 31.28 MiB host per slot at both 4 and 16 slots,
against 221.04 and 153.54 MiB unified. The output buffer grows with slots: 3.07 MiB at 4, 12.27 MiB
at 16.

## E. Set A together (Behavior 5)

**Decision it informs:** whether set A fits one host above its floor, at idle.

**Configuration.** The four sections loaded in turn after `unload --all` (gb10-1 from a dropped
page cache), then left idle and read.

| Host | Loads (gpt-oss, 26B-A4B, E4B, granite) | Read at | Pool left | Floor | Above floor |
| --- | --- | --- | --- | --- | --- |
| gb10-1 | 44.4, 13.2, 9.8, 3.4 s; last at 19:45:57Z | 19:46:44Z, 47 s idle | 21.45 GiB (MemAvailable) | 12.2 GiB | 9.25 GiB |
| framework | 18.1, 6.1, 6.1, 3.1 s; last at 21:11:15Z | 21:11:48Z, 33 s idle | 19.08 GiB (GTT); GTT used 92.92 of 112.00 GiB | 11.2 GiB | 7.88 GiB |

gb10-1's first read came 8 s after the last load (19:46:05Z, 21.46 GiB by `memory`); the 47 s read
gave 21.45 GiB, the same within 0.01 GiB, so the 30 s read stands.

Each process in the set read the GPU or GTT figure it read alone, its RSS within 1 MiB, on both
hosts: gb10-1 64911, 18015, 6530 and 863 MiB GPU with RSS 1265, 1217, 4144 and 829 MiB; the Framework 65459, 18380, 9929 and 1102 MiB GTT
with RSS 219, 241, 246 and 122 MiB. The sum of the four alone figures is the set's:

- gb10-1: 65.33 + 18.95 + 10.40 + 1.52 = 96.20 GiB; 117.71 − 96.20 = 21.51 GiB, against 21.45
  measured (within 0.06 GiB).
- Framework: 0.28 + 63.92 + 17.95 + 9.70 + 1.08 = 92.93 GiB used, against 92.92 measured.

## F. Warmed peak, P1-P4 (Behavior 6)

**Decision it informs:** each model's high-water mark at its section's depth, the growth a
placement must reserve over idle.

**Configuration.** Set A freshly loaded and idle 30 s (section E's load), then P1-P4 in turn, one
model each, nothing reloaded between them. Tool GuideLLM 0.8.1 from the laptop, helper `cell`,
1 stream, 1 request each:

| Cell | Section | Load | Duration gb10-1 / Framework |
| --- | --- | --- | --- |
| P1 | gpt-oss set-a | 100,000 synthetic prompt tokens, exactly 256 out (`bench/footprint-p1.yaml`) | 108 s / 242 s |
| P2a | 26B-A4B | one synthetic 1440p JPEG (2560 × 1440) beside 200 text tokens, 64 out | 22 s / 20 s |
| P2b | 26B-A4B | two 1440p JPEGs in one request beside 200 text tokens, 64 out | 22 s / 20 s |
| P2c | 26B-A4B | 7,900 synthetic prompt tokens, 64 out | 21 s / 20 s |
| P3a | E4B | the 29.4 s LibriSpeech clip (1272-128104-0004) with the card's transcription prompt, up to 256 out | 21 s / 20 s |
| P3b | E4B | 7,900 synthetic prompt tokens, 64 out | 22 s / 20 s |
| P4 | granite | one 8,000-token input to `/v1/embeddings` | 22 s / 20 s |

Every cell completed its request (`requests ok 1, errored 0, incomplete 0 of 1, full yes`) on both
hosts. Speed, recorded, not judged:

| Cell | gb10-1: TTFT median / ITL median / output tok/s | Framework: TTFT median / ITL median / output tok/s |
| --- | --- | --- |
| P1 | 85315 ms / 33.67 ms / 2.73 | 217439 ms / 36.24 ms / 1.13 |
| P2a | 3149 ms / 14.11 ms / 15.85 | 5793 ms / 15.64 ms / 9.44 |
| P2b | 2999 ms / 14.7 ms / 16.3 | 5209 ms / 15.81 ms / 10.31 |
| P2c | 2618 ms / 14.96 ms / 17.98 | 4467 ms / 16.31 ms / 11.65 |
| P3a | 1400 ms / 22.43 ms / 25 | 865 ms / 25.73 ms / 27.46 |
| P3b | 1974 ms / 22.23 ms / 18.97 | 3943 ms / 25.77 ms / 11.5 |
| P4 | an embedding: no TTFT or ITL | as gb10-1 |

**Each process at the warmed peak** (after P4), against set A idle:

| Model | gb10-1 GPU idle → peak (MiB) | gb10-1 RSS idle → peak (MiB) | Framework GTT idle → peak (MiB) | Framework RSS idle → peak (MiB) |
| --- | --- | --- | --- | --- |
| gpt-oss set-a | 64911 → 65015 (+104) | 1265 → 1539 (+274) | 65459 → 65686 (+227) | 219 → 258 (+39) |
| 26B-A4B | 18015 → 18828 (+813) | 1217 → 3353 (+2136) | 18380 → 19062 (+682) | 241 → 2012 (+1771) |
| E4B | 6530 → 6758 (+228) | 4144 → 4670 (+526) | 9929 → 10007 (+78) | 246 → 432 (+186) |
| granite | 863 → 977 (+114) | 829 → 962 (+133) | 1102 → 1140 (+38) | 122 → 131 (+9) |

**The pool at the warmed peak:** gb10-1 21.45 → 17.23 GiB (−4.22), 5.03 GiB above its floor; the
Framework 19.08 → 18.08 GiB (GTT used 92.92 → 93.92, −1.00), 6.88 GiB above its floor. On gb10-1 the
four processes' growth sums to 4328 MiB (4.23 GiB), the pool's drop; on the Framework the GTT growth
sums to 1025 MiB (1.00 GiB), the GTT drop. Neither host went under its floor in P1-P4.

Each step's figures, gb10-1 (pool MemAvailable, after a drop) and Framework (GTT available):

| After | gb10-1 pool (GiB) | gb10-1 changed process | Framework pool (GiB) | Framework changed process |
| --- | --- | --- | --- | --- |
| set A idle | 21.45 | – | 19.08 | – |
| P1 | 21.07 (watch low 21.07) | gpt-oss 65015 GPU, 1539 RSS | 18.86 (watch low 18.86) | gpt-oss 65686 GTT, 258 RSS |
| P2a | 19.52 | 26B-A4B 18826 GPU, 1989 RSS | 18.22 | 26B-A4B 19032 GTT, 679 RSS |
| P2b | 19.24 | 26B-A4B 18828 GPU, 2265 RSS | 18.20 | 26B-A4B 19048 GTT, 962 RSS |
| P2c | 18.17 | 26B-A4B 18828 GPU, 3353 RSS | 18.19 | 26B-A4B 19062 GTT, 2012 RSS |
| P3a | 17.56 | E4B 6758 GPU, 4575 RSS | 18.15 | E4B 9968 GTT, 338 RSS |
| P3b | 17.47 | E4B 6758 GPU, 4670 RSS | 18.11 | E4B 10007 GTT, 432 RSS |
| P4 | 17.23 | granite 977 GPU, 962 RSS | 18.08 | granite 1140 GTT, 131 RSS |

The 26B-A4B's RSS growth through P2 is its host prompt cache starting to fill: `watch`'s
`readout` lines count 3 idle-slot saves in each P2 cell and 1 prompt save in P2c. Section G shows where that cache goes.

## G. Under load, L1-L4 (Behavior 7)

**Decision it informs:** whether set A holds its floor with each model at its load target, the
question role-split's comparison starts from.

**Configuration.** Set A unloaded and freshly reloaded after P4 (gb10-1 at 19:53:23Z; the
Framework at 21:19:21Z), idle 30 s or more, then L1-L4 in turn. gb10-1's reload stood idle through
the architect's pause and was read again at 21:02:54Z (21.45 GiB) before L1. Tool GuideLLM 0.8.1,
helper `cell`:

| Cell | Section | Load | Duration gb10-1 / Framework |
| --- | --- | --- | --- |
| L1 | gpt-oss set-a | anchor B: 4 streams × 32 requests, 512 prompt tokens, exactly 256 out (`bench/anchor-b.yaml`) | 122 s / 131 s |
| L2 | 26B-A4B | vision-b at 1440p: 4 streams × 32 requests, one 1440p JPEG beside 200 text tokens, 64 out (`bench/footprint-l2.yaml`) | 61 s, stopped / 201 s |
| L3 | E4B | audio-b: 4 streams × 32 LibriSpeech clips (1.7 to 29.4 s), up to 256 out (`bench/footprint-l3.yaml`) | 31 s / 30 s |
| L4 | granite | embed: 512-token inputs, 1 stream then 16, 30 s each (`bench/footprint-l4.yaml`) | 81 s / 80 s |

Speed, recorded, not judged:

| Cell | gb10-1 | Framework |
| --- | --- | --- |
| L1 | 32 ok, 0 errored, full; 81.61 tok/s; TTFT 1290 ms; ITL 43.9 ms | 32 ok, 0 errored, full; 72.77 tok/s; TTFT 2292 ms; ITL 45.73 ms |
| L2 | stopped by `watch` (exit 143) | 31 ok, 1 errored, full NO; 11.04 tok/s; TTFT 20615 ms; ITL 29.49 ms |
| L3 | 32 ok, 0 errored, full; 58.71 tok/s; TTFT 396 ms; ITL 44.94 ms; audio 22.93 s/s | 32 ok, 0 errored, full; 45.47 tok/s; TTFT 499 ms; ITL 58.37 ms; audio 17.66 s/s |
| L4 | 1 stream 1609 ok; 16 streams 1779 ok, 11 of 1790 incomplete | 1 stream 745 ok; 16 streams 1190 ok, 16 of 1206 incomplete |

L4's incomplete requests are those in flight when its 30 s level ended.

**gb10-1's L2 went under the floor, and `watch` stopped it.** MemAvailable fell about 2 GiB every
10 s from the first image request (`footprint-gb10-1-l2.watch.tsv`: 21545, 19446, 16953, 14902,
12690, 10636 MiB at 21:05:19 to 21:06:10Z), and at 21:06:10Z, 61 s into the cell, `watch` printed
`memory floor: 10636 MiB available under 12.2 GiB at 21:06:10; stopping footprint-gb10-1-l2` (10.39
GiB; `memory` read 10.38 GiB just after). GuideLLM's last progress line, at 52.8 s, counted 12 of
32 requests complete; stopped, it wrote no JSON.

The 26B-A4B's GPU memory stayed flat (18828 MiB) while its **RSS grew 1217 → 10397 MiB**:
llama.cpp's host prompt cache, `cache-ram`, filling toward its default of 8192 MiB (`watch`'s
`readout` line counts 30 idle-slot saves and 40 prompt saves). Set A's two Gemma sections leave `cache-ram` at that default;
gpt-oss set-a sets `cache-ram = 0`. Recorded as a finding; L2 was not rerun, since capping the cache
is a preset change outside this task. Only the 26B-A4B was then reloaded (unload, load, 12.2 s),
which returned the pool to 20.68 GiB before L3 and L4, the cells that measure the E4B and granite.

**On the Framework the same cache sits outside GTT.** L2 ran to its end there: GTT used rose only
92.97 → 93.61 GiB, while the 26B-A4B's RSS grew 239 → 9867 MiB. The prompt cache is ordinary
system memory, which the GTT watch can't see. The session read `free` on the Framework after each
cell from P1 on: `free -g` after P1, `free -m` from P2a on; no read was taken at set A idle before
P1. The figures are from `.state/footprint/framework-free.txt`, the raw output (untracked, like the
step logs). The full line is `Mem:` total, used, free, shared, buff/cache and available; the
table's second column is `available`, in MiB, of a 128,075 MiB total:

| After | available (MiB) | Full line |
| --- | --- | --- |
| P1 (`free -g`) | 23 GiB | `125 102 3 0 25 23` |
| P2a | 22576 | `128075 105499 3569 29 24598 22576` |
| P2b | 22466 | `128075 105608 3459 29 24598 22466` |
| P2c | 21340 | `128075 106735 3371 29 23559 21340` |
| P3a | 21223 | `128075 106852 3254 29 23559 21223` |
| P3b | 21018 | `128075 107057 4065 29 22543 21018` |
| P4 | 20900 | `128075 107175 3947 29 22543 20900` |
| fresh set A, idle before L1 | 23965 | `128075 104110 3680 29 25873 23965` |
| L1 | 23639 | `128075 104436 3699 29 25528 23639` |
| L2 | 13660 | `128075 114415 3404 28 15844 13660` |
| L3 | 12789 | `128075 115286 2532 28 15844 12789` |
| L4 | 12658 | `128075 115417 6334 25 11899 12658` |
| final fresh set A | 23829 | `128075 104245 5030 19 24367 23829` |

So the Framework's system memory available fell 23,639 → 13,660 MiB through L2 and to 12,658 MiB
after L4, while the GTT pool never fell under 18.31 GiB. No floor is set on the Framework's system
memory (section K).

**The Framework's L2 errored request** was the output parser, not memory. GuideLLM's JSON records
it as `ValueError('Streaming response returned an error: The model produced output that does not
match the expected peg-gemma4 format')`; the router log from 21:22:10Z held no matching error line.
Recorded, not rerun.

**Each process's highest figure under load, read after the cell** (the reads after L1-L4; no
process figure is read during a cell), against its warmed peak:

| Model | gb10-1 GPU / RSS after the cell (MiB) | over warmed peak | Framework GTT / RSS after the cell (MiB) | over warmed peak |
| --- | --- | --- | --- | --- |
| gpt-oss set-a | 65015 / 1572 (after L1) | 0 / +33 | 65507 / 269 (after L1) | −179 / +11 |
| 26B-A4B | 18828 / 10397 (after L2, stopped) | 0 / +7044 | 19042 / 9867 (after L2) | −20 / +7855 |
| E4B | 6760 / 5333 (after L3) | +2 / +663 | 9983 / 1049 (after L3) | −24 / +617 |
| granite | 975 / 968 (after L4) | −2 / +6 | 1129 / 129 (after L4) | −11 / −2 |

L1-L4 started from a fresh reload, so a figure under the warmed peak is a model that L1-L4 grew less
than P1-P4 did. The E4B's RSS growth under L3 is its prompt cache too (34 prompt saves on gb10-1, 32
on the Framework).

**The pool's lowest during the cell** (watch, every 10 s): gb10-1 L1 21.03, L2 10.39 (stopped), L3 19.57, L4 19.35 GiB; the
Framework L1 19.03, L2 18.39, L3 18.33, L4 18.31 GiB (GTT). Over the warmed peak: gb10-1 −6.84 GiB
(17.23 → 10.39, all of it L2's prompt cache); the Framework's GTT stayed above its warmed peak
(18.08), since L1-L4 began from a fresh reload.

## H. gb10-2 cross-check (Behavior 8)

**Decision it informs:** whether gb10-1's figures stand for both GB10s.

At 21:08:49Z the session read gb10-2's current set A load (loaded during the hosts task, at
12:07-12:08 local) with `footprint`, read-only: no drop, load, unload or request.

| Process | gb10-2 GPU / RSS (MiB) | gb10-1 in set A (MiB) |
| --- | --- | --- |
| router | 170 / 334 | 170 / 341 |
| gpt-oss set-a | 64911 / 1264 | 64911 / 1265 |
| 26B-A4B | 18015 / 1215 | 18015 / 1217 |
| E4B | 6530 / 4142 | 6530 / 4144 |
| granite | 863 / 828 | 863 / 829 |

gb10-2's pool read MemAvailable 21.42 GiB, Cached 26.24 GiB (no cache drop on gb10-2). **Its router
log's buffer lines match gb10-1's line for line for every section**: the weight, KV (both caches,
with the same cells, layers and seqs), compute, projector and output figures in section C's table,
and the same `n_slots` and `n_ctx_slot`. The projector estimates differ only in the time they took.
So gb10-1's rows stand for a GB10, as the hosts finding's parity did for speed.

The lines, as the `footprint 2026-11-09T00:00:00Z` read printed them
(`.state/measure/gb10-2/2026-11-09.log`, 16:08:49 local). The read prints every load line since
midnight UTC, so it also printed the day's eight earlier loads (granite, E4B, 26B-A4B and gpt-oss
set-a once each, then gpt-oss set-a four more times at 11:49-12:04 local, the hosts task's); quoted
here are only the four spawns of the current load (12:07:14-12:07:42 local) and every line after
them, in log order. As in the hosts finding's quotes of helper output, each line's step-log prefix
(`= 2026-11-09T16:08:49-05:00 footprint: `) is left out; nothing else is trimmed, the `took N ms`
of the projector estimates included:

```
  router: srv load: spawning server instance with name=mrutkows/granite-embedding-english-r2-GGUF:BF16 on port 46569
  mrutkows/granite-embedding-english-r2-GGUF:BF16: load_tensors: CUDA0 model buffer size = 210.51 MiB
  mrutkows/granite-embedding-english-r2-GGUF:BF16: load_tensors: CUDA_Host model buffer size = 73.78 MiB
  mrutkows/granite-embedding-english-r2-GGUF:BF16: llama_context: CUDA_Host output buffer size = 3.12 MiB
  mrutkows/granite-embedding-english-r2-GGUF:BF16: sched_reserve: CUDA0 compute buffer size = 460.13 MiB
  mrutkows/granite-embedding-english-r2-GGUF:BF16: sched_reserve: CUDA_Host compute buffer size = 352.19 MiB
  mrutkows/granite-embedding-english-r2-GGUF:BF16: srv load_model: initializing, n_slots = 16, n_ctx_slot = 8192, kv_unified = 'false'
  router: srv load: spawning server instance with name=ggml-org/gemma-4-E4B-it-GGUF:Q8_0 on port 35083
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: srv load_model: [mtmd] estimated worst-case memory usage of mmproj is 746.89 MiB (took 55.75 ms)
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: load_tensors: CUDA0 model buffer size = 4788.12 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: load_tensors: CUDA_Host model buffer size = 3536.00 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: llama_context: CUDA_Host output buffer size = 4.00 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: llama_kv_cache: CUDA0 KV buffer size = 512.00 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: llama_kv_cache: size = 512.00 MiB ( 8192 cells, 4 layers, 4/4 seqs), K (f16): 256.00 MiB, V (f16): 256.00 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: llama_kv_cache: CUDA0 KV buffer size = 160.00 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: llama_kv_cache: size = 160.00 MiB ( 1024 cells, 20 layers, 4/4 seqs), K (f16): 80.00 MiB, V (f16): 80.00 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: sched_reserve: CUDA0 compute buffer size = 137.02 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: sched_reserve: CUDA_Host compute buffer size = 50.03 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: load_hparams: projector: gemma4v
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: load_hparams: model size: 533.83 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: reserve_compute_meta: CUDA0 compute buffer size = 101.27 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: reserve_compute_meta: CPU compute buffer size = 6.77 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: load_hparams: projector: gemma4a
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: load_hparams: model size: 533.83 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: reserve_compute_meta: CUDA0 compute buffer size = 101.19 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: reserve_compute_meta: CPU compute buffer size = 1.58 MiB
  ggml-org/gemma-4-E4B-it-GGUF:Q8_0: srv load_model: initializing, n_slots = 4, n_ctx_slot = 8192, kv_unified = 'false'
  router: srv load: spawning server instance with name=google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 on port 50115
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: srv load_model: [mtmd] estimated worst-case memory usage of mmproj is 1296.85 MiB (took 60.99 ms)
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: load_tensors: CUDA0 model buffer size = 13755.42 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: load_tensors: CUDA_Host model buffer size = 577.50 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: llama_context: CUDA_Host output buffer size = 4.00 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: llama_kv_cache: CUDA0 KV buffer size = 640.00 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: llama_kv_cache: size = 640.00 MiB ( 8192 cells, 5 layers, 4/4 seqs), K (f16): 320.00 MiB, V (f16): 320.00 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: llama_kv_cache: CUDA0 KV buffer size = 1800.00 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: llama_kv_cache: size = 1800.00 MiB ( 2304 cells, 25 layers, 4/4 seqs), K (f16): 900.00 MiB, V (f16): 900.00 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: sched_reserve: CUDA0 compute buffer size = 335.29 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: sched_reserve: CUDA_Host compute buffer size = 70.61 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: load_hparams: projector: gemma4v
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: load_hparams: model size: 1139.46 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: reserve_compute_meta: CUDA0 compute buffer size = 150.63 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: reserve_compute_meta: CPU compute buffer size = 6.77 MiB
  google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0: srv load_model: initializing, n_slots = 4, n_ctx_slot = 8192, kv_unified = 'false'
  router: srv load: spawning server instance with name=gpt-oss-120b-MXFP4-set-a on port 39315
  gpt-oss-120b-MXFP4-set-a: load_tensors: CUDA0 model buffer size = 59851.68 MiB
  gpt-oss-120b-MXFP4-set-a: load_tensors: CUDA_Host model buffer size = 586.82 MiB
  gpt-oss-120b-MXFP4-set-a: llama_context: CUDA_Host output buffer size = 3.07 MiB
  gpt-oss-120b-MXFP4-set-a: llama_kv_cache: CUDA0 KV buffer size = 4608.00 MiB
  gpt-oss-120b-MXFP4-set-a: llama_kv_cache: size = 4608.00 MiB (131072 cells, 18 layers, 4/1 seqs), K (f16): 2304.00 MiB, V (f16): 2304.00 MiB
  gpt-oss-120b-MXFP4-set-a: llama_kv_cache: CUDA0 KV buffer size = 36.00 MiB
  gpt-oss-120b-MXFP4-set-a: llama_kv_cache: size = 36.00 MiB ( 1024 cells, 18 layers, 4/1 seqs), K (f16): 18.00 MiB, V (f16): 18.00 MiB
  gpt-oss-120b-MXFP4-set-a: sched_reserve: CUDA0 compute buffer size = 221.04 MiB
  gpt-oss-120b-MXFP4-set-a: sched_reserve: CUDA_Host compute buffer size = 153.54 MiB
  gpt-oss-120b-MXFP4-set-a: srv load_model: initializing, n_slots = 4, n_ctx_slot = 131072, kv_unified = 'true'
```

## I. The capacity table (Behavior 9)

Every column is marked **(m)** measured, from the step logs above, or **(c)** computed from
measured figures by the formula given. Host classes: **GB10** (gb10-1, matched by gb10-2) and
**Framework**.

### I.1 Per model × host class: buffers (m, MiB, logged at load)

| Model | Host | Weights GPU (m) | Weights host (m) | Projector (m) | Full-attention KV per 1,000 tokens (m) | Sliding-window KV per slot (m) | Compute GPU (m) | Compute host (m) | Projector compute GPU / CPU (m) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gpt-oss-120b | GB10 | 59851.68 | 586.82 | – | 35.16 (36,864 B/token) | 27 per slot; 36 for the unified pool at 4 slots | 221.04 unified; 98.77 per slot (4 or 16) | 153.54 unified; 31.28 per slot | – |
| gpt-oss-120b | Framework | 59851.64 | 586.82 | – | 35.16 (36,864 B/token) | 36 for the unified pool at 4 slots | 219.02 unified | 151.54 unified | – |
| 26B-A4B | GB10 | 13755.42 | 577.50 | 1139.46 | 19.53 (20,480 B/token) | 450 | 335.29 | 70.61 | 150.63 / 6.77 |
| 26B-A4B | Framework | 13755.36 | 577.50 | 1139.46 | 19.53 (20,480 B/token) | 450 | 239.04 | 70.64 | 150.63 / 6.77 |
| E4B | GB10 | 4788.12 | 3536.00 | 533.83 | 15.63 (16,384 B/token) | 40 | 137.02 | 50.03 | 202.46 / 8.35 |
| E4B | Framework | 4788.10 | 3536.00 | 533.83 | 15.63 (16,384 B/token) | 40 | 137.02 | 50.04 | 202.46 / 8.35 |
| granite | GB10 | 210.51 | 73.78 | – | none (no KV logged) | none | 460.13 | 352.19 | – |
| granite | Framework | 210.51 | 73.78 | – | none (no KV logged) | none | 460.13 | 352.19 | – |

B/token is each section's logged full-attention KV divided by its c (sections C and D); the
gpt-oss figure holds at three c values (section D). The E4B's projector compute is the vision and
audio encoders' buffers together.

### I.2 Per model × host class: process and pool (m)

GB10: pool taken in GiB (MemAvailable, dropped cache) and the process's GPU / RSS in MiB. Framework:
GTT taken in GiB and the process's GTT / RSS in MiB.

| Model | Host | Idle alone (m) | Idle in the set (m) | Warmed peak (m) | Under load, highest after the cell (m) |
| --- | --- | --- | --- | --- | --- |
| gpt-oss-120b set-a | GB10 | 65.33 GiB; 64911 / 1265 | 64911 / 1265 | 65015 / 1539 | 65015 / 1572 |
| gpt-oss-120b set-a | Framework | 63.92 GiB; 65459 / 219 | 65459 / 219 | 65686 / 258 | 65507 / 269 |
| 26B-A4B | GB10 | 18.95 GiB; 18015 / 1217 | 18015 / 1217 | 18828 / 3353 | 18828 / 10397 (prompt cache; under the floor) |
| 26B-A4B | Framework | 17.95 GiB; 18380 / 240 | 18380 / 241 | 19062 / 2012 | 19042 / 9867 (prompt cache, outside GTT) |
| E4B | GB10 | 10.40 GiB; 6530 / 4143 | 6530 / 4144 | 6758 / 4670 | 6760 / 5333 |
| E4B | Framework | 9.70 GiB; 9929 / 247 | 9929 / 246 | 10007 / 432 | 9983 / 1049 |
| granite | GB10 | 1.52 GiB; 863 / 829 | 863 / 829 | 977 / 962 | 975 / 968 |
| granite | Framework | 1.08 GiB; 1102 / 123 | 1102 / 122 | 1140 / 131 | 1129 / 129 |

### I.3 Per host (m)

| Host class | Ceiling (m) | Floor | Base use, nothing loaded (m) | Set A idle (m) | Set A warmed peak (m) | Set A under load, lowest during the cell (m) |
| --- | --- | --- | --- | --- | --- | --- |
| GB10 | 121.63 GiB (MemTotal) | 12.2 GiB (10% of the ceiling) | 3.93 GiB (121.63 − 117.70 MemAvailable; router 170 MiB GPU, 341 MiB RSS) | 21.45 GiB | 17.23 GiB | 10.39 GiB (L2, stopped); 19.35 GiB without L2 |
| Framework | 112.00 GiB (GTT total); system memory 128,075 MiB | 11.2 GiB (10% of the GTT ceiling) | 0.28 GiB GTT used (router 2 MiB GTT, 97 MiB RSS) | 19.08 GiB | 18.08 GiB | 18.31 GiB GTT; system memory 12,658 MiB available |

### I.4 Computed: largest c and 131,072-token sessions above the floor (c)

**The prompt cache.** A Gemma section at the preset's default holds up to 8192 MiB of host prompt
cache a process, two processes in set A: up to 16 GiB, more than a GB10's 5.03 GiB above the floor
at set A's warmed peak. With the default, set A itself doesn't hold a GB10's floor under vision
load (section G), so no session count beside it would be true. **This table assumes `cache-ram`
capped at 0 on the Gemma sections, as gpt-oss set-a already sets.** That cap is a preset change,
outside this task; until it lands, subtract up to 8 GiB per Gemma process from any GB10 figure
beside set A, and from the Framework's system memory. The 26B-A4B's measured warmed growth on a
GB10 (+2.88 GiB) already includes its cache's first fill, so the figures alone err low under the
cap.

**Formula.** With P the pool available (GiB) with the model at its section, F the floor, R the
model's warmed growth over idle, b its full-attention KV in B/token, K its section's loaded KV
(full-attention + sliding-window), and w its sliding-window KV per slot:

- headroom H = P − F − R. **Alone**, P is the host's pool with nothing loaded less the model's idle
  alone figure, and R the model's warmed growth from section F (GB10: GPU + RSS; Framework: GTT).
  **Beside the rest of set A**, P is set A's warmed-peak pool (17.23 or 18.08 GiB), which already
  holds every model at its warmed peak, and R = 0.
- **largest c** = the section's c + ⌊H × 2³⁰ / b⌋, the slots and KV mode unchanged.
- **131,072-token sessions** N = ⌊(H + K) / (131,072 × b + w)⌋: one slot a session, per slot,
  each holding 131,072 tokens of full-attention KV and its own window.

Both assume compute buffers don't grow with c or slots: measured for gpt-oss per slot (98.77 MiB at
4 and at 16 slots, at c 32768 and 131072), not for the Gemma sections. The largest c is a memory
bound only: each slot is also bounded by the model's trained context (131,072 for gpt-oss-120b,
per the preset), which this table doesn't read for the Gemma models. Granite has no KV, so neither
applies; its slots are 8,192 tokens.

| Model | Host | Session cost (c) | Alone: H (c) | Alone: largest c (c) | Alone: sessions (c) | Beside set A: H (c) | Beside set A: largest c (c) | Beside set A: sessions (c) |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| gpt-oss-120b | GB10 | 4635 MiB (4608 + 27) | 117.70 − 65.33 − 12.2 − 0.37 = 39.80 GiB | 1,290,356 | 9 (9.80) | 17.23 − 12.2 = 5.03 GiB | 277,581 | 2 (2.11) |
| gpt-oss-120b | Framework | 4635 MiB | 111.72 − 63.92 − 11.2 − 0.22 = 36.38 GiB | 1,190,667 | 9 (9.04) | 18.08 − 11.2 = 6.88 GiB | 331,466 | 2 (2.52) |
| 26B-A4B | GB10 | 3010 MiB (2560 + 450) | 117.70 − 18.95 − 12.2 − 2.88 = 83.67 GiB | 4,419,491 | 29 (29.28) | 5.03 GiB | 296,484 | 2 (2.52) |
| 26B-A4B | Framework | 3010 MiB | 111.72 − 17.95 − 11.2 − 0.67 = 81.90 GiB | 4,326,895; held under 2,097,152 by I.5 | 28 (28.67); none proven above 4 slots, by I.5 | 6.88 GiB | 393,478 | 3 (3.15); unproven, by I.5 |
| E4B | GB10 | 2088 MiB (2048 + 40) | 117.70 − 10.40 − 12.2 − 0.74 = 94.36 GiB | 6,216,985 | 46 (46.60) | 5.03 GiB | 362,414 | 2 (2.79) |
| E4B | Framework | 2088 MiB | 111.72 − 9.70 − 11.2 − 0.08 = 90.74 GiB | 5,979,755 | 44 (44.82) | 6.88 GiB | 483,655 | 3 (3.70) |
| granite | both | n/a (no KV) | | | | | | |

"Beside set A" means beside the other three, each at its section, with the model's own section
resized; it does not add sessions to two models at once. The H column's 117.70 and 111.72 GiB are
each host's pool with nothing loaded (section C).

### I.5 Constraint row: Gemma 4 26B-A4B on Vulkan (the Framework)

From spike-hosting-upgrades (`docs/screens/framework/2026-11-04.md`, "Phase 2, the Gemma set", and
`docs/blockers.md`, "Gemma 4 26B-A4B aborts on Vulkan with several slots"; not tested here, the
framework task's):

| Constraint | Bound | Source |
| --- | --- | --- |
| Each full-attention K layer under 4 GiB | K is 2,048 B/token a layer (320 MiB over 5 layers at 32,768 tokens), so c < 2,097,152 (16 × 131,072 is exactly 4 GiB a layer); at 16 slots the load aborted in auto-fit: "pre-allocated tensor (cache_k_l5) in a buffer (Vulkan0) that cannot run the operation (NONE)" | [#29082](https://github.com/ggml-org/llama.cpp/issues/29082) |
| The second request aborts at 15 slots | in prompt_save, `GGML_ASSERT(tensor->data != NULL && "tensor not allocated")`; 1 of 8 shape A requests completed on b11960 | [#29221](https://github.com/ggml-org/llama.cpp/issues/29221) open; fix [#25584](https://github.com/ggml-org/llama.cpp/pull/25584) unmerged (last checked 2026-11-06 by spike-hosting-upgrades) |

So on the Framework the 26B-A4B's computed rows above its served section (4 slots, c 32768) are
memory bounds, not configurations known to run.

### I.6 Computed: input token costs (c)

| Input | Tokens | Source | KV it takes (full attention) |
| --- | --- | --- | --- |
| Image, on the 26B-A4B section | 560 to 1,120 an image | the section's `image-min-tokens = 560` and `ub = 1120` (an image's tokens are capped at n_ubatch) | 10.94 to 21.88 MiB (× 20,480 B/token); P2b's two 1440p images are up to 2,240 tokens, 43.75 MiB |
| Audio, on the E4B | about 25 tokens a second | 15,028 input tokens for a 10-minute 16 kHz mono WAV on gb10-2's E4B Q8_0 (the roadmap note on spike-ai-pipeline-processing's audio finding): 15,028 / 600 s = 25.05 | 0.39 MiB a second (× 16,384 B/token); P3a's 29.4 s clip about 736 tokens, 11.5 MiB; a 10-minute WAV 234.81 MiB, against the section's 8,192-token slot (sizing that request is role-split's) |

The E4B section sets neither image key, so the 560 to 1,120 range is the 26B-A4B's only.

### I.7 Worked placement: the agent's 131,072-token sessions on an agent-only GB10 (c)

A GB10 serving gpt-oss-120b alone, one slot per session, each session the model's trained context
of 131,072 tokens, the KV per slot, with set-a's `cache-ram = 0`:

1. **The pool with nothing loaded** (m): 117.70 GiB MemAvailable (gb10-1, dropped cache); floor
   12.2 GiB.
2. **The model without its KV** (c): the 16-slot section took 65.54 GiB with 4608 + 432 MiB of KV,
   so weights, compute, CUDA context and process memory are 65.54 − 4.92 = 60.62 GiB. (The c 32768
   section gives 61.78 − 1.23 = 60.55 GiB; set-a, with its unified compute, 65.33 − 4.54 =
   60.79 GiB.)
3. **Room for sessions** (c): 117.70 − 12.2 − 60.62 = 44.88 GiB.
4. **A session** (c): 131,072 × 36,864 B = 4608 MiB of full-attention KV + 27 MiB of window =
   4635 MiB, 4.53 GiB. Reserving P1's warmed growth for every session as well (378 MiB, 0.37 GiB,
   measured for one session at 100,000 tokens) makes it 4.90 GiB.
5. **Sessions** (c): ⌊44.88 / 4.53⌋ = 9 (9.92); with the reserve, ⌊44.88 / 4.90⌋ = 9 (9.17).

**Nine 131,072-token sessions**, c = 9 × 131,072 = 1,179,648 with 9 slots, leaving 0.82 GiB above
the floor with the reserve (4.14 GiB without). The roadmap's estimate for this placement, about
49 GiB of KV and roughly 10 sessions (the architect, 2026-10-30), is 44.88 GiB and 9 sessions here. The
count assumes compute stays at 98.77 MiB per slot at 9 slots (measured at 4 and 16); it is a
computed placement, not a loaded one: role-split loads what it compares.

## J. Every run

| Run | Host | Tool and configuration | Load | Duration | Decision it informs |
| --- | --- | --- | --- | --- | --- |
| Alone loads (4) | gb10-1 | router load of each set A section, nothing else loaded; `footprint` after a cache drop | none | 3.4-47.8 s a load | each model's cost alone (C) |
| gpt-oss extra sections (2) | gb10-1 | router load of `ggml-org/gpt-oss-120b-GGUF:MXFP4` and `gpt-oss-120b-MXFP4-16-slots`, alone | none | 47.4 s, 48.0 s | KV linear in c; SWA and compute against slots (D) |
| Alone loads (4) | framework | as gb10-1, GTT | none | 3.1-18.2 s a load | each model's cost alone (C) |
| Set A | both | the four sections loaded in turn, 30 s idle | none | 71 s gb10-1, 33 s Framework (load to last) | set A against the floor at idle (E) |
| P1 | both | GuideLLM 0.8.1, `cell`, `bench/footprint-p1.yaml`, gpt-oss set-a | 1 request, 100,000 in, 256 out | 108 s / 242 s | the agent's high-water mark at session depth (F) |
| P2a, P2b, P2c | both | `bench/footprint-p2a.yaml`, `-p2b`, `-p2c`, 26B-A4B | one 1440p image; two in one request; 7,900 text tokens; 64 out | 20-22 s each | the vision model's high-water mark (F) |
| P3a, P3b | both | `bench/footprint-p3a.yaml`, `-p3b`, E4B | the 29.4 s clip; 7,900 text tokens | 20-22 s each | the audio model's high-water mark (F) |
| P4 | both | `bench/footprint-p4.yaml`, granite | one 8,000-token embedding input | 22 s / 20 s | the embedding model's high-water mark (F) |
| L1 | both | `bench/anchor-b.yaml`, gpt-oss set-a, fresh set A | 4 streams × 32, 512 in, 256 out | 122 s / 131 s | memory with the agent at its load target (G) |
| L2 | both | `bench/footprint-l2.yaml` (vision-b at 1440p), 26B-A4B | 4 streams × 32, one 1440p image, 64 out | 61 s (stopped under the floor) / 201 s | memory with vision at its load target (G) |
| L3 | both | `bench/footprint-l3.yaml` (audio-b), E4B | 4 streams × 32 clips | 31 s / 30 s | memory with audio at its load target (G) |
| L4 | both | `bench/footprint-l4.yaml` (embed), granite | 1 stream then 16, 30 s each | 81 s / 80 s | memory with embedding at its load target (G) |
| gb10-2 read | gb10-2 | `footprint`, read-only | none | one read | gb10-1's figures stand for a GB10 (H) |

Every cell ran under `watch`, memory sampled every 10 s, capped at 10 min, the floor
`MEASURE_FLOOR_GIB` 12.2 on gb10-1 and 11.2 on the Framework.

### Commands as run (gb10-1)

From `.state/measure/gb10-1/2026-11-09.log`, from the session's first footprint step (14:40:28
local); the hosts task's entries earlier in the file are left out. As in the hosts finding, the
filters (`grep`, `sed`, `tail`, `jq`), the repeated `for` lines of a loop and every line inside a
helper stay in the log. Every step sourced the helpers with `MEASURE_FLOOR_GIB=12.2` exported; that
line is left out too.

```
14:40:28  loaded
14:40:28  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:40:30  memory
14:40:30  footprint
14:40:37  t0=2026-11-09T19:40:37Z
14:40:37  load gpt-oss-120b-MXFP4-set-a
14:41:25  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:41:26  footprint 2026-11-09T19:40:37Z
14:41:33  unload --all
14:41:37  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:41:38  memory
14:41:38  t0=2026-11-09T19:41:38Z
14:41:38  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
14:41:51  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:41:52  footprint 2026-11-09T19:41:38Z
14:41:59  unload --all
14:42:02  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:42:03  memory
14:42:04  t0=2026-11-09T19:42:04Z
14:42:04  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
14:42:14  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:42:14  footprint 2026-11-09T19:42:04Z
14:42:22  unload --all
14:42:25  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:42:26  memory
14:42:27  t0=2026-11-09T19:42:27Z
14:42:27  load mrutkows/granite-embedding-english-r2-GGUF:BF16
14:42:30  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:42:31  footprint 2026-11-09T19:42:27Z
14:42:37  unload --all
14:42:40  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:42:41  memory
14:42:42  t0=2026-11-09T19:42:42Z
14:42:42  load ggml-org/gpt-oss-120b-GGUF:MXFP4
14:43:29  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:43:30  footprint 2026-11-09T19:42:42Z
14:43:36  unload --all
14:43:40  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:43:41  memory
14:43:41  t0=2026-11-09T19:43:41Z
14:43:41  load gpt-oss-120b-MXFP4-16-slots
14:44:29  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:44:30  footprint 2026-11-09T19:43:41Z
14:44:41  unload --all
14:44:44  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:44:45  memory
14:44:46  t0=2026-11-09T19:44:46Z
14:44:46  echo 't0 2026-11-09T19:44:46Z'
14:44:46  for s in gpt-oss-120b-MXFP4-set-a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16
14:44:46  load gpt-oss-120b-MXFP4-set-a
14:45:30  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
14:45:44  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
14:45:54  load mrutkows/granite-embedding-english-r2-GGUF:BF16
14:45:57  date -u +%FT%TZ
14:46:05  : 'set A loaded at 19:45:57Z; idle since, 30 s or more'
14:46:05  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:46:06  memory
14:46:06  footprint
14:46:42  : 'set A idle 30 s or more since its last read at 19:46:05Z (loaded 19:45:57Z)'
14:46:42  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:46:43  memory
14:46:44  footprint
14:46:54  cell footprint-gb10-1-p1 footprint-p1 gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
14:48:43  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:48:44  memory
14:48:45  footprint
14:48:53  cell footprint-gb10-1-p2a footprint-p2a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
14:49:17  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:49:17  footprint
14:49:24  cell footprint-gb10-1-p2b footprint-p2b google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
14:49:48  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:49:48  footprint
14:49:53  cell footprint-gb10-1-p2c footprint-p2c google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
14:50:16  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:50:17  footprint
14:50:24  cell footprint-gb10-1-p3a footprint-p3a ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
14:50:47  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:50:48  footprint
14:50:52  cell footprint-gb10-1-p3b footprint-p3b ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
14:51:16  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:51:17  footprint
14:51:21  cell footprint-gb10-1-p4 footprint-p4 mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
14:51:44  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:51:46  memory
14:51:46  footprint
14:51:54  unload --all
14:52:08  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:52:09  memory
14:52:09  for s in gpt-oss-120b-MXFP4-set-a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16
14:52:09  load gpt-oss-120b-MXFP4-set-a
14:52:57  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
14:53:10  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
14:53:20  load mrutkows/granite-embedding-english-r2-GGUF:BF16
14:53:23  date -u +%FT%TZ
14:53:28  : 'fresh set A loaded 19:53:23Z, idle 30 s or more, before L1-L4'
14:53:28  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
14:53:30  memory
14:53:30  footprint
16:02:53  : 'fresh set A loaded 19:53:23Z, idle since (session paused), before L1-L4'
16:02:53  loaded
16:02:53  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:02:54  memory
16:02:54  footprint
16:03:00  cell footprint-gb10-1-l1 anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
16:05:03  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:05:03  footprint
16:05:09  cell footprint-gb10-1-l2 footprint-l2 google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:06:11  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:06:11  footprint
16:06:24  : 'L2 stopped under the floor: reload the 26B-A4B alone to free its prompt cache, before L3-L4'
16:06:24  unload google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
16:06:27  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
16:06:39  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:06:40  memory
16:06:40  footprint
16:06:40  ls .state/measure/gb10-1/footprint-gb10-1-l2.exit .state/measure/gb10-1/footprint-gb10-1-l2.log .state/measure/gb10-1/footprint-gb10-1-l2.watch.tsv
16:06:44  cell footprint-gb10-1-l3 footprint-l3 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:07:16  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:07:16  footprint
16:07:20  cell footprint-gb10-1-l4 footprint-l4 mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:08:42  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:08:43  memory
16:08:43  footprint
16:08:53  unload --all
16:09:06  loaded
16:09:06  ssh gb10-1 sudo -n /usr/sbin/sysctl vm.drop_caches=3
16:09:06  memory
```

Each `cell` printed its summary line, for example P1's:

```
1 stream(s): requests ok 1, errored 0, incomplete 0 of 1, full yes; output tok/s completed 2.73, every-token 2.73; TTFT median 85315 ms; ITL median 33.67 ms
```

and L2's stop:

```
exit 143: memory floor: 10636 MiB available under 12.2 GiB at 21:06:10
```

### Commands as run (framework)

From `.state/measure/framework/2026-11-09.log`, from the session's first footprint step (16:09:21
local), left out as above; every step sourced the helpers with `MEASURE_FLOOR_GIB=11.2` exported.

```
16:09:21  loaded
16:09:21  unload --all
16:09:34  loaded
16:09:34  memory
16:09:34  footprint
16:09:38  t0=2026-11-09T21:09:38Z
16:09:38  load gpt-oss-120b-MXFP4-set-a
16:09:56  footprint 2026-11-09T21:09:38Z
16:10:01  unload --all
16:10:04  memory
16:10:04  t0=2026-11-09T21:10:04Z
16:10:04  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
16:10:10  footprint 2026-11-09T21:10:04Z
16:10:14  unload --all
16:10:17  memory
16:10:17  t0=2026-11-09T21:10:17Z
16:10:17  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
16:10:20  footprint 2026-11-09T21:10:17Z
16:10:25  unload --all
16:10:28  memory
16:10:28  t0=2026-11-09T21:10:28Z
16:10:28  load mrutkows/granite-embedding-english-r2-GGUF:BF16
16:10:31  footprint 2026-11-09T21:10:28Z
16:10:39  unload --all
16:10:42  memory
16:10:42  for s in gpt-oss-120b-MXFP4-set-a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16
16:10:42  load gpt-oss-120b-MXFP4-set-a
16:11:00  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
16:11:06  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
16:11:12  load mrutkows/granite-embedding-english-r2-GGUF:BF16
16:11:15  date -u +%FT%TZ
16:11:48  : 'set A loaded 21:11:15Z, idle 30 s'
16:11:48  memory
16:11:48  footprint
16:11:56  cell footprint-fw-p1 footprint-p1 gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
16:15:58  memory
16:15:58  footprint
16:15:58  ssh framework 'free -g | sed -n 2p'
16:16:03  cell footprint-fw-p2a footprint-p2a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:16:24  footprint
16:16:24  ssh framework 'free -m | sed -n 2p'
16:16:28  cell footprint-fw-p2b footprint-p2b google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:16:48  footprint
16:16:48  ssh framework 'free -m | sed -n 2p'
16:16:53  cell footprint-fw-p2c footprint-p2c google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:17:13  footprint
16:17:13  ssh framework 'free -m | sed -n 2p'
16:17:20  cell footprint-fw-p3a footprint-p3a ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:17:40  footprint
16:17:41  ssh framework 'free -m | sed -n 2p'
16:17:45  cell footprint-fw-p3b footprint-p3b ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:18:06  footprint
16:18:06  ssh framework 'free -m | sed -n 2p'
16:18:10  cell footprint-fw-p4 footprint-p4 mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:18:30  memory
16:18:30  footprint
16:18:30  ssh framework 'free -m | sed -n 2p'
16:18:35  unload --all
16:18:47  memory
16:18:47  for s in gpt-oss-120b-MXFP4-set-a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16
16:18:47  load gpt-oss-120b-MXFP4-set-a
16:19:06  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
16:19:12  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
16:19:18  load mrutkows/granite-embedding-english-r2-GGUF:BF16
16:19:21  date -u +%FT%TZ
16:19:54  : 'fresh set A loaded 21:19:21Z, idle 30 s, before L1-L4'
16:19:54  memory
16:19:54  footprint
16:19:54  ssh framework 'free -m | sed -n 2p'
16:19:58  cell footprint-fw-l1 anchor-b gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
16:22:09  footprint
16:22:10  ssh framework 'free -m | sed -n 2p'
16:22:16  cell footprint-fw-l2 footprint-l2 google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
16:25:38  footprint
16:25:38  ssh framework 'free -m | sed -n 2p'
16:25:49  cell footprint-fw-l3 footprint-l3 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 google/gemma-4-E4B-it
16:26:19  footprint
16:26:19  ssh framework 'free -m | sed -n 2p'
16:26:23  cell footprint-fw-l4 footprint-l4 mrutkows/granite-embedding-english-r2-GGUF:BF16 ibm-granite/granite-embedding-english-r2
16:27:44  memory
16:27:44  footprint
16:27:44  ssh framework 'free -m | sed -n 2p'
16:27:50  : 'end state: the Framework serves set A, freshly loaded'
16:27:50  unload --all
16:28:02  for s in gpt-oss-120b-MXFP4-set-a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 ggml-org/gemma-4-E4B-it-GGUF:Q8_0 mrutkows/granite-embedding-english-r2-GGUF:BF16
16:28:02  load gpt-oss-120b-MXFP4-set-a
16:28:23  load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0
16:28:29  load ggml-org/gemma-4-E4B-it-GGUF:Q8_0
16:28:35  load mrutkows/granite-embedding-english-r2-GGUF:BF16
16:28:39  loaded
16:28:39  memory
16:28:39  ssh framework 'free -m | sed -n 2p'
```

The `free` lines are in the step log; their output is not, since they ran outside a helper. Their
output is recorded in `.state/footprint/framework-free.txt` (untracked raw output, like the step
logs), the source of section G's table. The first read, after P1, was `free -g`; no read was
taken at set A idle before P1.

### Commands as run (gb10-2)

From `.state/measure/gb10-2/2026-11-09.log`, its one footprint step, read-only (its filters, a
`grep -E` of the buffer lines and a `tail -45`, left out):

```
16:08:49  : 'read-only cross-check: gb10-2'\''s current set A load, no load or request'
16:08:49  footprint 2026-11-09T00:00:00Z
```

### Commands not in a step log

Run from the laptop, from this project's root, outside the step helpers:

```sh
# stack read and pings, 19:31Z (.state/footprint/stack-2026-11-09.txt): the hosts finding's command, saved with { date -Is; ...; } 2>&1 | tee
{ date -Is; for h in gb10-1 gb10-2; do echo "== $h"; timeout 60 ssh -o BatchMode=yes $h 'apt list --upgradable 2>/dev/null | grep -vc "^Listing"; uname -r; nvidia-smi --query-gpu=driver_version --format=csv,noheader; nvidia-smi | grep -o "CUDA Version: [0-9.]*"; docker --version; nvidia-ctk --version | head -1; . /etc/os-release; echo $PRETTY_NAME; cat /etc/dgx-release 2>/dev/null | grep -i version | head -2; docker ps --format "{{.Names}} {{.Image}} {{.Status}}"'; done; echo "== framework"; timeout 60 ssh -o BatchMode=yes framework 'checkupdates 2>/dev/null | wc -l; uname -r; pacman -Q mesa docker 2>/dev/null; docker ps --format "{{.Names}} {{.Image}} {{.Status}}"'; for h in gb10-1 gb10-2 framework; do tailscale ping -c 1 $h; done; } 2>&1 | tee .state/footprint/stack-2026-11-09.txt

# the pending packages and the newest apt list, before the root updates
for h in gb10-1 gb10-2; do echo "== $h"; ssh -o BatchMode=yes $h 'apt list --upgradable 2>/dev/null | grep -v "^Listing"; ls -l --time-style=+%FT%T /var/lib/apt/lists/*_InRelease 2>/dev/null | awk "{print \$6}" | sort | tail -1'; done

# after the architect's updates
for h in gb10-1 gb10-2; do echo "== $h"; ssh -o BatchMode=yes $h 'apt list --upgradable 2>/dev/null | grep -vc "^Listing"; dpkg-query -W libsoup-3.0-0 python3-pyasn1; ls /var/run/reboot-required 2>&1 | tail -1; uname -r; docker ps --format "{{.Names}} {{.Status}}"'; done

# L2's errored request on the Framework
jq -r '[.. | objects | select(has("error")) | .error] | map(select(. != null)) | .[0:3][]' .state/measure/framework/footprint-fw-l2.json
ssh framework 'docker logs --since 2026-11-09T21:22:10Z llama 2>&1 | grep -iE "error|abort|fail|exceed|too (long|many)" | head -10'

# the network path after the pause
tailscale ping -c 1 gb10-1
tailscale ping -c 1 framework
```

Results: the stack read is the "Stack" section's table. The check after the updates is section A's
last paragraph. The `jq` printed the `peg-gemma4` error quoted in section G; the `docker logs`
search printed nothing. The pings, at 21:02:53Z: gb10-1 direct, 3 ms; at
21:09:21Z: framework direct, 3 ms.

## L. The architect's walkthrough (slice 4)

The architect ran slice 4 on gb10-1 at 18:07-18:14 local, from their own shell, sourcing the step
helpers, so every command is in gb10-1's step log (`.state/measure/gb10-1/2026-11-09.log`). It
reproduces section C's 26B-A4B row and section F's P2a growth.

```
# 18:07:43
source scripts/measure-lib.sh gb10-1
export MEASURE_FLOOR_GIB=12.2
# 18:10:45, refused: the sudoers rule names /usr/sbin/sysctl exactly, so `sudo -n` declines
# /usr/bin/sysctl (rc 1)
ssh gb10-1 sudo -n /usr/bin/sysctl vm.drop_caches=3
# 18:10:57, an interactive shell on gb10-1, where the architect ran
ssh gb10-1
sudo -n /usr/sbin/sysctl vm.drop_caches=3      # vm.drop_caches = 3
memory                                          # 117.63 GiB available (MemAvailable)
t0=$(date -u +%FT%TZ)
load google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0   # loaded in 15.2 s, --ctx-size 32768 --parallel 4
ssh gb10-1                                      # sudo -n /usr/sbin/sysctl vm.drop_caches=3 there
footprint 2026-11-09T23:11:28Z
cell footprint-walk-p2a footprint-p2a google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
ssh gb10-1                                      # sudo -n /usr/sbin/sysctl vm.drop_caches=3 there
footprint
unload --all
```

| | Section C / F (19:41-19:49Z) | Walkthrough (23:11-23:14Z) |
| --- | --- | --- |
| Load time | 12.8 s | 15.2 s |
| MemAvailable before → after load | 117.73 → 98.78 GiB (18.95 taken) | 117.63 → 98.73 GiB (18.90 taken) |
| Process GPU / RSS after load | 18015 / 1217 MiB | 18015 / 1217 MiB |
| Logged buffers | section C's row | the same lines, figure for figure |
| P2a, one 1440p image | 1 of 1 ok; TTFT 3149 ms; ITL 14.11 ms | 1 of 1 ok; TTFT 2893 ms; ITL 14.29 ms |
| Process GPU / RSS after P2a | 18826 / 1989 MiB (+811 / +772) | 18826 / 1989 MiB (+811 / +772) |
| Pool after P2a | 19.52 GiB, with set A loaded | 97.04 GiB, the 26B-A4B alone |

The figures that don't depend on what else is loaded reproduce exactly: the buffers, the process's
GPU memory, and P2a's growth. gb10-1 ends with nothing loaded. The architect then read section
I.7's worked placement.

## K. Open items for later tasks

- **The Gemma sections' prompt cache.** At the default `cache-ram` (8192 MiB a process), set A
  doesn't hold a GB10's floor under vision load (section G), and on the Framework the cache sits in
  system memory the GTT watch can't see. Capping it (as gpt-oss set-a's `cache-ram = 0` does) is a
  preset change to spike-model-engines' `host/`, by pull request citing this finding; section I.4
  assumes it.
- **The Framework's system memory has no floor.** The policy's floor reads GTT; a prompt cache, or
  anything else outside GTT, is invisible to it. Under L2-L4 system memory available fell to
  12,658 MiB.
- **The Framework's L2 parser error** (`peg-gemma4`), 1 of 32 requests, not rerun.
- **Unmeasured in the computed columns:** compute buffers at Gemma slot counts other than 4, and
  gpt-oss's unified compute at c past 131,072; the Gemma models' trained contexts.
- **The E4B's 8,192-token slot against a 15,028-token audio request** (section I.6): role-split's.
- **The 26B-A4B on Vulkan** past 4 slots or c 32768 (section I.5): the framework task's.
