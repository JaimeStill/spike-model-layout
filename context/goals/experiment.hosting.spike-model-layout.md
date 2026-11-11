# goal · experiment.hosting.spike-model-layout

- **State:** building
- **Task:** agent-vllm
- **Branch:** agent-vllm

## Tasks

1. [x] hosts
2. [x] footprint
3. [x] role-split
4. [x] framework
5. [ ] agent-vllm
6. [ ] on-demand
7. [ ] two-node
8. [ ] answer

## Task brief · agent-vllm

```
Problem       vLLM leads gpt-oss-120b from 4 streams on gb10-1 (v0.32.0:
              168.2 against llama.cpp's 129.0 tok/s at 16), but nothing
              has measured it at the agent's load target or in the
              agent's multi-turn sessions. Nothing has compared its memory
              with the agent-only section's: one unified pool of
              1,179,648 tokens over 16 slots, 1.39 GiB above gb10-1's
              floor idle and 0.27 GiB under load. At 0.80 of the pool,
              vLLM's BF16 KV cache held 493,523 tokens, about 3.8 sessions
              of 131,072 against llama.cpp's 9. An FP8 KV cache could
              hold llama.cpp's 1,179,648 tokens in about 30.73 GiB, but
              that is unproven for gpt-oss's attention sinks on SM121.
              Its cold start took 546-577 s against llama.cpp's 48 s. The
              pin is held at v0.32.0. vLLM v0.33.0 is out as a tag and
              images on the same commit as v0.33.0rc3, which is still the
              name of GitHub's release.
Behaviors     1. Every host has no pending OS updates at the session's
                 start: the architect applies the root updates on gb10-1,
                 gb10-2 and the Framework. Each host's stack is recorded.
                 Nothing else changes on gb10-2 or the Framework: no load,
                 request, clone move or anchor. `tailscale ping` to
                 gb10-1 is recorded with the date before every run, and
                 the finding names each run's path.
              2. A pull request to spike-model-engines' host/ moves vLLM
                 to v0.33.0 and adds two agent rows. Each row serves
                 openai/gpt-oss-120b with max-model-len 131072,
                 max-num-seqs 16, the openai_gptoss reasoning parser,
                 auto tool choice and the openai tool-call parser:
                 - gpt-oss-120b-agent: gpu-memory-utilization 0.80, KV
                   in the checkpoint's BF16;
                 - gpt-oss-120b-agent-fp8: kv-cache-dtype fp8 (e4m3),
                   kv-cache-memory-bytes 32993476982.
                 Neither row names an attention or MoE backend. The pin's
                 hold comment is rewritten: the v0.33.0 tag and images
                 are rc3's commit, and currency keeps reporting rc3 until
                 GitHub's release object moves. llama.env's hold note
                 reads "unrestored through b12271". The PR reaches gb10-1
                 before merge by a push to hosts-next and a local `hosts`
                 branch there. gb10-2's and the Framework's clones stay
                 on main at 21b5e8c. The check passes in both
                 repositories.
              3. Before any start or cell, gb10-1 holds vLLM's v0.33.0
                 CUDA image and gpt-oss-120b's safetensors with every
                 JSON file its start reads (original/*.safetensors and
                 metal/ excluded). Both are staged in parallel. No vLLM
                 start fetches a file, which the start log shows.
              4. The step helpers read a vLLM container.
                 - footprint prints the vllm container's GPU memory and
                   RSS, and the start log's sizing lines: model loading
                   and its time, available KV cache memory, KV cache
                   tokens, maximum concurrency, CUDA graphs, the
                   kv_cache_memory_bytes line, the startup free memory,
                   and the attention and MoE backends chosen.
                 - readout prints vLLM's /metrics counters: requests,
                   prompt and generation tokens, preemptions, KV cache
                   usage, and running and waiting requests. It also
                   counts the server log's Harmony and output-parser
                   errors since a time.
                 - A llama.cpp host reads as before. watch and memory
                   are unchanged. The check passes.
              5. llama.cpp baseline. gb10-1 unloads everything, drops the
                 page cache, and loads the agent-only section. The
                 load's time is its cold start. After 30 s idle the pool,
                 the process and the buffers are read and set against
                 role-split's G (13.59 GiB available). Its S-agent sweep
                 then runs.
              6. The BF16 row on vLLM. The llama container stops, and
                 vLLM installs serving gpt-oss-120b-agent. This first
                 start fills the compile cache and is recorded apart.
                 The page cache is dropped, and the container's
                 restart is timed from its start to "Application startup
                 complete." and /health 200. That timed start is the
                 row's cold start. /version reads 0.33.0. After one
                 warm-up request and 30 s idle, the pool and footprint
                 are read: weights, KV memory and tokens, graphs,
                 backends. They are set against v0.32.0's 25.71 GiB and
                 493,523 tokens, read as a record across versions.
              7. Anchors A and B run once each on the BF16 row. Their
                 output tok/s and ITL are read against vLLM v0.32.0's
                 34.0 and 86.7 tok/s (spike-model-engines'
                 bench-gb10-container) as a record, not a gate; the
                 row's 131,072 max-model-len is noted beside them.
                 A move beyond the two runs' difference is a finding.
              8. Each vLLM row answers the vLLM API page's reasoning
                 probe and tool-call probe once, with the reply and its
                 parse recorded. For every cell on a vLLM row, the cell
                 records the server log's Harmony and output-parser
                 errors and GuideLLM's errored count.
              9. S-agent runs unchanged on llama.cpp's agent-only
                 section, the BF16 row and the FP8 row: knee levels
                 [1,4,8,12,16], 110 s each, the 4-turn sessions. Each
                 level records output tok/s, TTFT, ITL (median, p95),
                 turns ok, errored and incomplete, and GuideLLM's knee.
                 Each level is judged by the agent floor (ITL ≤100 ms)
                 under role-split's rule for "holds". The three are
                 compared at the target of 4 and at every level.
             10. The capacity cell runs once on each vLLM row: 8
                 concurrent sessions, each one request of 65,536 prompt
                 tokens and exactly 256 out, 524,288 tokens in all,
                 capped at 10 min. It records:
                 - per-request TTFT, latency and completion;
                 - preemptions;
                 - the highest KV cache usage and waiting count from
                   readouts every 30 s;
                 - the pool's lowest.
                 It answers whether each row holds all 8 at once.
             11. The FP8 row. The page cache is dropped, and vLLM
                 updates to gpt-oss-120b-agent-fp8. Its one start, which
                 compiles afresh, is its cold start, and its weight load
                 is set against the BF16 row's. After a warm-up request
                 and 30 s idle, footprint and memory are read. If
                 gb10-1 reads under 12.2 GiB, the container is
                 stopped and the session escalates, with 28 GiB
                 (30064771072 bytes) prepared as the fallback. The start
                 log names the attention backend, and the finding records
                 it.
             12. Every cell runs under watch with gb10-1's floor of
                 12.2 GiB, sampled every 10 s and capped at 10 min. A
                 cell that falls under the floor is stopped and recorded
                 as a finding. Memory and footprint are read after every
                 cell.
             13. The agent-vllm finding names every run: tool,
                 configuration, load, duration, path, and the decision it
                 informs. It quotes every command behind a figure, and
                 every command that changes a host, from the step log.
                 It answers evidence 6: per engine and row, speed and
                 ITL at the target and per level, TTFT under multi-turn
                 load, memory and the margin above the floor, KV tokens
                 per GiB, 131,072-token sessions per host (the capacity
                 cell measured, the rest computed and marked), cold
                 start, and errors. It records the FP8 row's backend,
                 probes and error counts. The living layout document
                 gains vLLM's agent rows beside llama.cpp's.
             14. At the session's end gb10-1 serves the agent-only
                 section, freshly loaded and read. The vllm container
                 is stopped on the FP8 row, with vLLM's v0.33.0 image,
                 the compile cache and gpt-oss's safetensors kept.
                 gb10-1's clone is on `hosts` at the PR's head until the
                 merge, then on main. gb10-2 and the Framework serve as
                 the framework task left them.
Test seams    gb10-1's router API on 8080 (/health, /models, load and
              unload) and vLLM's API on 8000 (/health, /version,
              /v1/models, /metrics), driven by the step helpers one step
              at a time. The vllm container's state and start log. The
              memory, footprint, readout and watch read-outs, with the
              step log as their record. GuideLLM's result files for
              every cell, the knee conclusion among them.
Slices        1. Hosts, the pull request, the helpers and the llama.cpp
                 baseline.
                 - The architect applies the root updates on all three
                   hosts.
                 - Write the host/ PR branch and push it to gb10-1's
                   hosts-next. Its clone moves to the local `hosts`
                   branch.
                 - Stage the image and the weights in parallel.
                 - Make footprint and readout read a vllm container.
                 - Write the capacity cell's file,
                   `bench/agent-vllm-capacity.yaml`, adapted from
                   footprint-p1 (8 streams, 1 request each, 65,536 in,
                   256 out).
                 Then on gb10-1 (source measure-lib.sh gb10-1),
                 `unload --all`, drop the cache, `load
                 gpt-oss-120b-MXFP4-agent-only`, idle 30 s, read. Then:
                   L-agent  S-agent (`role-split-agent-split`) on the
                      agent-only section, [1,4,8,12,16], 110 s a level,
                      ~9.5 min: llama.cpp's figures this session
                 Demo: the PR's two rows on gb10-1's hosts branch, the
                 baseline's idle read against role-split G, L-agent's
                 table, and footprint printing an llama-server row.
              2. vLLM's two rows. The session runs `docker stop llama`,
                 then `VLLM_MODEL=gpt-oss-120b-agent host/engines vllm
                 install` (first start, recorded apart). It drops the
                 cache, restarts the container (timed start), warms up,
                 idles 30 s and reads. From here the helpers are sourced
                 for port 8000. Then, each cell GuideLLM 0.8.1 from the
                 laptop, run by `cell` under watch:
                   VA/VB  anchors A and B (`anchor-a`, `anchor-b`) on
                      the BF16 row, ~3 min in all: v0.33.0 against
                      v0.32.0's 34.0 and 86.7
                   probes  reasoning and tool call, <1 min
                   B-agent  S-agent on the BF16 row, ~9.5 min
                   B-cap  the capacity cell on the BF16 row
                      (`agent-vllm-capacity`), readouts every 30 s,
                      ~7.5 min (c), cap 10 min: whether 8 long
                      sessions fit in ~494k tokens
                 Drop the cache, `VLLM_MODEL=gpt-oss-120b-agent-fp8
                 host/engines vllm update` (its one start, timed), warm
                 up, idle 30 s, read. Under the floor: stop and escalate.
                 Then:
                   probes  reasoning and tool call, <1 min
                   F-agent  S-agent on the FP8 row, ~9.5 min
                   F-cap  the capacity cell on the FP8 row, as B-cap:
                      whether all 8 run at once in ~1.18M tokens
                 `docker stop vllm`, `docker start llama`, `load
                 gpt-oss-120b-MXFP4-agent-only`, idle 30 s, read
                 (Behavior 14). About 1 h 50 min on the host (c).
                 Demo: each row's start log and idle read against the
                 floor, VA/VB against v0.32.0, and L-agent, B-agent and
                 F-agent at 4 streams, with B-cap set against F-cap.
              3. The finding and docs. Write the agent-vllm finding:
                 - evidence 6's comparison across the three;
                 - the KV and session capacity rows, measured and
                   computed, each marked;
                 - cold starts, the backends, probes and error counts;
                 - every run with its path, and the commands quoted.
                 Update the layout document's agent rows.
                 Demo: the comparison table, and one placement read from
                 it (131,072-token sessions per agent host on each row).
              4. The architect's walkthrough on gb10-1: `docker stop
                 llama`, `docker start vllm` (the FP8 row, warm compile
                 cache), time the start, and read the start log's KV
                 line and the pool against the finding. Then rerun
                 S-agent's level 4 as its own cell (110 s) under watch
                 against F-agent's, and restore llama.cpp as Behavior 14
                 states, ~20 min.
Out of scope  Any new tool, llama-swap among them. Vision, audio or
              embedding on vLLM on any host (the new capability task).
              Any load, request, clone move or anchor on gb10-2 or the
              Framework. Anchors on llama.cpp or on the FP8 row. A
              second timed start for the FP8 row. The capacity cell on
              llama.cpp. Attention or MoE backend flags, speculative
              decoding, MTP, NVFP4 or KV-scale calibration. Accuracy
              evals beyond the two probes. An FP8 KV cache on llama.cpp.
              Rows other than the two, or the 28 GiB fallback without
              an escalation. llama.cpp past b12098. Changes outside
              host/ in spike-model-engines, currency.sh among them (an
              intake note). Routing (spike-model-gateway). Two-node and
              Ray. Removing vLLM's image, container or weights. Speed
              comparisons with earlier sessions beyond the anchors'
              record and citing role-split.
Door          two-way: the pin and rows revert by a commit to host/, and
              before merge by checking gb10-1's clone out at main
              21b5e8c. The helper edit and the bench file revert by
              commit. vLLM's container, image, compile cache and weights
              come off with `docker rm vllm`, `docker rmi` and `hf cache
              rm`. llama.cpp's agent-only section returns with `docker
              start llama` and a load. Root is the architect's (the OS
              updates); the page-cache drop uses gb10-1's existing
              sudoers rule. Nothing in the task can't be undone.
```

## Progress

slices 3/4 committed (4 is the architect's walkthrough) · standards — · spec — · editor —

## Decisions

- setup: kind context; check `mise run check`, currency `mise run currency`, no gate; public GitHub with `gh pr create` and `gh pr merge --merge --delete-branch`, no CI — copied from spike-hosting-upgrades.
- setup: held python at 3.14.10 in the bench environment: torchcodec 0.17.0, needed by GuideLLM 0.8.1's audio extra, has no cp315 wheel; declines 3.15.2.
- setup: load tool GuideLLM 0.8.1 from the laptop, its multi-turn datasets for agent sessions; anchors A and B copied into `bench/`.
- setup: gb10-2 joins the host set now (spike-ai-pipeline complete); it moves onto spike-model-engines' engines suite and shared preset, carrying spike-ai-pipeline's vision keys (ub 1120, image-min-tokens 560) by PR; spike-ai-pipeline's repo stays untouched.
- setup: spike-model-engines joins repos; its `host/` changes only through PRs citing a finding.
- setup: native features first: on-demand loading through llama.cpp's router (autoload, LRU `--models-max`, `--models-memory-margin`, `--sleep-idle-seconds`); llama-swap only in front of vLLM.
- setup: vLLM runs in containers, never bare metal (spike-model-engines `docs/findings/vllm-gb10-native.md`: within run noise, same memory, starts 137 s sooner); agent-vllm moves the pin to v0.33.0.
- setup: routing stays on paper; each workload targets its host directly; stickiness and overflow go to spike-model-gateway as requirements. Rejected: a stand-in router this spike would throw away.
- setup: role-split compares set A on one GB10 against the roles split across both GB10s (one agent-only, the other vision, audio and embedding), requests directed by capability; it absorbs the planned capability-host task. Either GB10 may take either role.
- setup: the Framework's role is chosen from role-split's findings in framework's plan round.
- setup: two-node is measured (gb10-2 available): gpt-oss-120b with vLLM and Ray in containers against one node; it weighs both GB10s pooled for the agent with the Framework serving the capability models. Rejected: llama.cpp RPC, with no documented two-node run.
- setup: docs: `docs/findings/<task>.md`, one living `docs/layout.md`, `bench/`, `scripts/` with `measure-lib.sh` copied from spike-hosting-upgrades, raw output under `.state/`.

- hosts: held llama.cpp (gb10) at b12098: b12100+ match an -hf quantization tag only after `-`, `.` or `/` (#31620, #31639), so Google's QAT sections don't resolve; still broken through b12211.
- hosts: held llama.cpp (strix-halo) at b12098, the same QAT tag matching; the Framework moves b11960 -> b12098 now, with anchors A and B before and after there.
- hosts: held python (bench) 3.14.10 in spike-model-engines: torchcodec 0.17.0 has no cp315 wheel.
- hosts: held vLLM v0.32.0: v0.33.0rc3 is a release candidate; agent-vllm moves the pin to v0.33.0.
- hosts: held native Python 3.12: native vLLM is retired.
- hosts: ub 1120 and image-min-tokens 560 go in the shared 26B-A4B QAT section for every host (~800 MiB more per host); rejected: a gb10-2-only section.
- hosts: mtmd-batch-max-tokens 512 carried as a third key.
- hosts: anchors run on the set-a gpt-oss-120b section (131072, unified KV) through the helper's section override, only that section loaded, freshly loaded per run.
- hosts: two repetitions per host, alternating (8 runs).
- hosts: parity is output tok/s and ITL within max(2.2%, the session's spread); TTFT recorded, not judged; a miss is a finding and blocks cross-GB10 comparison.
- hosts: gb10-2 ends serving set A from the shared preset; its store stays with set A's four files.
- hosts: gb10-2's spike-ai-pipeline clone removed; gb10-2 aligned to gb10-1 (the architect).
- hosts: the drop-caches sudoers rule installed on gb10-2, as on gb10-1.
- hosts: slice 4's walkthrough waived by the architect: the hosts only need to be set up for the tasks that follow, where the measurements count.
- hosts: gb10-2 aligned only to what dotfiles and the engines suite set up; gb10-1's drift outside them removed (the architect).
- hosts: gb10-1's store extras (12B, 31B, E4B QAT GGUFs; granite safetensors; 32.45 GB) cleared: nothing this spike or a planned goal runs reads them, and each task downloads what it serves.
- hosts: measure-lib.sh drops tier and conform and fixes MEASURE_ROOT.
- hosts (BUILD): host/ changes reach the hosts before merge by `git push <host>:repos/spike-model-engines hosts:hosts-next` and a local `hosts` branch on each host (spike-hosting-upgrades' precedent), never through GitHub before the architect accepts the session brief.
- hosts (BUILD): the Framework's `engines llama update` needs `LLAMA_FLAVOR=vulkan`, because the script defaults an AMD GPU to rocm. A first run without it moved the Framework to server-rocm-b12098 and removed the vulkan b11960 image; the rerun with the flag corrected it before R3.
- hosts (BUILD): `LLAMA_RELEASE=v0.8.0` stays in host/llama.env as a record. Neither host class runs it, and removing it would change llama-release.sh's message and docs outside host/.
- hosts (BUILD): parity's session spread is taken from output tok/s for both measures. ITL's own spread is wider, so the verdict holds either way.
- hosts (BUILD): gb10-1's deeper app state (dconf, btop, eog, gtk-4.0, yelp, the pnpm and fastfetch caches) and gb10-2's lazygit stay as each host's own use, not drift. ~/.humming and ~/.config/NVIDIA counted as vLLM and AI Workbench leftovers and were removed.
- hosts (BUILD): gb10-2 uses gb10-1's memory floor of 12.2 GiB: the hardware is the same, and gb10-2 has no host descriptor.

- footprint: measures set A's four sections only; the GB10 stores hold set A alone and the shared preset sets `offline = true` (models.ini:21), so the router downloads nothing and the extras can't be measured on both host classes.
- footprint: the GB10 measured is gb10-1, idle with nothing loaded; gb10-2's current load log is quoted as a cross-check, with no load or request on gb10-2.
- footprint: per-process memory comes from a new read-only `footprint` step helper (nvidia-smi compute-apps and ps RSS on a GB10, amdgpu_top -p on the Framework, by --alias, plus the pool and the load log's buffer lines), logged to the step log; no new tool.
- footprint: each set A model is loaded alone (on a GB10 from a dropped page cache, on the Framework read by GTT), then set A together after 30 s idle.
- footprint: KV per 1,000 tokens comes from each section's logged KV buffers, with linearity checked on gb10-1 by loading gpt-oss-120b's existing c 32768 x 4 and c 131072 x 16 sections; no preset change.
- footprint: the warmed peak comes from GuideLLM warm-up cells P1-P4 on freshly loaded set A after 30 s idle, under `watch` every 10 s (spike-model-hosting's method).
- footprint: P1 sends gpt-oss-120b a ~100,000-token prompt (256 out, cap 10 min), not 8,192, so the peak reflects the agent's session depth.
- footprint: memory under load is read with in-flight cells L1-L4 at each model's load target after the warmed peak; speed is recorded, not judged.
- footprint: no anchor rerun, since footprint compares no speed figure and the engines are held at b12098; anchor A runs once on a host first only if the session-start update moves its kernel, driver or Mesa.
- footprint: the capacity table carries measured and computed columns, each marked (largest c and 131,072-token sessions above the floor; input token costs for images and audio).
- footprint: Gemma 4 26B-A4B's Vulkan aborts are recorded as a constraint row (K layer under 4 GiB, so c < 2,097,152; #29221 at 15 slots), not tested; testing is the framework task's.
- footprint: the session ends with the Framework serving set A and gb10-1 with nothing loaded, as hosts left it, since role-split loads what it compares.
- footprint (BUILD): set A's first idle read on gb10-1 came 8 s after the last load (21.46 GiB); a second read at 47 s gave 21.45 GiB, the same within 0.01 GiB, so the brief's 30 s read stands; the reload before L1-L4 was read again after the architect's pause.
- footprint (BUILD): L2 (vision-b at 1440p) stopped under gb10-1's floor at 61 s (10.39 GiB): the 26B-A4B's RSS grew 1217 -> 10397 MiB with its GPU memory flat, llama.cpp's host prompt cache filling toward its `cache-ram` default (8192 MiB), which set A's Gemma sections leave on. Recorded as a finding; L2 not rerun; capping it is a preset change, outside this task.
- footprint (BUILD): after L2's stop, only the 26B-A4B was reloaded (unload, load) to return above the floor before L3 and L4, which measure the E4B and granite.
- footprint (BUILD): gb10-1's network path turned direct (LAN, 3 ms) after the architect's pause, from DERP(nyc) 56 ms; L1-L4's TTFT ran on it. Speed isn't judged in this task.
- footprint (BUILD): on the Framework, llama.cpp's host prompt cache sits in system RAM outside GTT, so the GTT floor watch can't see it; L2 grew the 26B-A4B's RSS 239 -> 9867 MiB with GTT nearly flat (92.97 -> 93.61 GiB used), system RAM available 23,639 -> 13,660 MiB (free -m). The session read `free` beside each Framework cell.
- footprint (BUILD): one of L2's 32 requests on the Framework errored in llama.cpp's Gemma 4 output parser ("does not match the expected peg-gemma4 format"), not on memory; recorded, not rerun.
- footprint (BUILD): the Framework ends with set A reloaded fresh after L4, dropping the 26B-A4B's prompt cache from L2 (RSS 9867 MiB).
- footprint (BUILD): per-process figures under load are read once after each cell, not as each process's highest during L1-L4: `watch` samples only the pool, so the pool's lowest is a during-cell figure and the process figures are after-cell reads. The prompt cache that drives the finding holds its size until reload, so its after-read is its peak.
- footprint (BUILD): the Framework's `free -m` outputs, which the step log doesn't hold, are kept in `.state/footprint/framework-free.txt` as the session's tool output showed them; no read was taken at set A idle before P1.
- footprint (BUILD): the architect's walkthrough reproduced section C's 26B-A4B row and P2a's growth (+811 MiB GPU, +772 MiB RSS) exactly; a cache drop typed with /usr/bin/sysctl was refused by the exact-path sudoers rule and rerun on gb10-1 with /usr/sbin/sysctl. Recorded in the finding's section L.

- role-split: the Gemma 26B-A4B QAT and E4B sections take cache-ram 0, cache-idle-slots false and ctx-checkpoints 2 (gb10-1's measured Gemma config; cache-ram 0 alone leaves checkpoints unbounded on b12098); rejected: cache-ram 0 alone, a size cap.
- role-split: the Framework keeps its clone and set A on main until the framework task, which gives the section changes room to evolve; its starting state gets one adjustment then (the architect).
- role-split: gb10-1 takes the agent-only role, gb10-2 vision, audio and embedding.
- role-split: the full-set arm runs on gb10-2, the capability host, so the split step only drops the agent.
- role-split: anchors A and B run once each on each GB10 at session start, judged against the hosts finding's run noise; repeated once on a miss.
- role-split: agent sessions are GuideLLM 0.8.1 multi-turn synthetic, 4 turns (8,192-token first turn, then 3 x 512 in, 512 out each turn), no think time.
- role-split: the agent, vision and audio sweeps use GuideLLM's knee profile with adaptive refinement off, at levels [1,2,3,4,8] in the full-set arm and [1,4,8,12,16] in the split.
- role-split: per-level durations: agent 110 s; vision 60 s (full set) and 90 s (split); audio 30 s with at most 64 requests a level over the 73 LibriSpeech clips; rampup 0.
- role-split: granite is swept only in the full-set arm, concurrent [1,2,4,8,16], 30 s each, 512-token inputs, read against 4,300 prompt tok/s.
- role-split: the speed floors are spike-hosting-upgrades' purpose floors (agent >=10 tok/s a stream, vision <=10 s an image question, audio RTFx >=5, embedding >=4,300 tok/s).
- role-split: vision sweep requests take 100 output tokens (the floor's measure); the L2 rerun keeps 64 so its memory compares with footprint's.
- role-split: the agent-only section is gpt-oss-120b with one unified pool of c 1,179,648 over 16 slots, with set-a's keys; rejected: 9 per-slot sessions of 131,072, and the existing 16-slot section.
- role-split: the full-set arm's agent is set-a as served (c 131,072, 4 slots, unified).
- role-split: the split's vision and audio are new 16-slot 26B-A4B and E4B sections (8,192 a slot) with the cap keys; granite unchanged.
- role-split: E4B keeps 8,192 tokens a slot, and audio past 30 s goes windowed; one 10-minute WAV probe records what an 8,192-token slot does with 15,028 tokens.
- role-split: the probe is AMI ES2002a's first 10 minutes as 16 kHz mono WAV, sent once by curl to E4B's /v1/audio/transcriptions.
- role-split: each arrangement gets a mixed cell with every purpose at once at today's load targets (agent 4 sessions, vision 4, audio 4, embedding 16), its processes started together, 240 s each, under the 10 min cap.
- role-split: the split adds a second mixed cell at its own measured knees.
- role-split: the split's mixed cells drive gb10-1 and gb10-2 at once from the laptop; in BUILD each host's processes ran from its own step script, both launched together.
- role-split: no new tool; multi-turn sessions and the knee profile are features of GuideLLM 0.8.1.
- role-split: no reload between cells within an arm after its fresh load; the L2 rerun starts from set A's fresh load.
- role-split: the session ends with the split serving (gb10-1 agent-only; gb10-2 16-slot 26B-A4B, 16-slot E4B, granite), the arrangement framework and agent-vllm start from; rejected: returning to set A on gb10-2.
- role-split: docs: the finding at `docs/findings/role-split.md` carries its measured capacity rows; footprint's dated finding stays as written, and the layout document cites both.
- role-split (BUILD): the new sections are `gpt-oss-120b-MXFP4-agent-only`, `gemma-4-26B-A4B-it-qat-Q4_0-16-slots` and `gemma-4-E4B-it-Q8_0-16-slots`, after the existing `-16-slots` pattern (spike-model-engines 2d7ae32).
- role-split (BUILD): the mixed and S-knee cells set streams through `GUIDELLM__SPEC__PROFILE__STREAMS`, which GuideLLM reads only when the file leaves `streams` out, so `cell` runs them unchanged; the load targets live in `bench/README.md` and each file's header.
- role-split (BUILD): the mixed audio file reads the 73 clips 12 times (876 rows), since GuideLLM doesn't reuse a source and 73 clips last ~70 s at 4 streams; the knee files keep 73 rows, capped at 64 requests a level.
- role-split (BUILD): F-L2 reuses `bench/footprint-l2.yaml` unchanged; the F-probe recipe lives in `bench/README.md`, its WAV cut locally to `.state/role-split/ami-es2002a-first10min.wav` (600.000 s, 16 kHz mono).
- role-split (BUILD): where GuideLLM found no knee (S-agent, S-audio), "holds" is the highest level meeting the floor; vision and audio floors are judged on each level's median (latency; per-request RTFx = audio seconds / request time), with p90, minimum and the count meeting the floor reported beside them.
- role-split (BUILD): the jq and awk programs behind the finding's figures are tracked under bench/ (`levels.jq`, `srvtimes.awk`, `stats.awk`) and called with `-f` from the quoted commands; they are analysis files over the pinned tools, not a new tool.
- role-split (BUILD, escalation): granite stays unchanged in both arms; its idle-slot prompt-cache saves (177,657 in F-embed, 43,743 in F-mixed; RSS 827 -> 965 MiB) are recorded as a finding and its cap as an intake note (the architect).
- role-split (BUILD, escalation): F-L2's 31 of 32 meets Behavior 4 on memory (lowest 17.80 GiB); the one Gemma 4 output-parser error ("does not match the expected peg-gemma4 format") is recorded as a finding, not caused by the cap, and F-L2 isn't rerun (the architect).
- role-split (BUILD, escalation 2): the split's single-stream audio slowdown is diagnosed in this task by a back-to-back pair on gb10-2 (set A's 4-slot E4B alone, then the 16-slot E4B alone, 1 stream, 60 s each, fresh loads), then gb10-2 returns to Behavior 12's state; the finding gains the pair (the architect).
- role-split (BUILD, escalation 2): agent-vllm widens to the vision, audio and embedding models on vLLM, each in its own process, alone and together on the capability GB10, as a pending roadmap edit decided in its plan round (the architect).
- role-split (BUILD, escalation 2): several llama.cpp vision processes in place of more slots are not pursued, since more processes add load on the shared GPU's compute and bandwidth (the architect).
- role-split (BUILD, escalation 3): the split's cells and D1/D2 ran from the laptop over Tailscale relays (gb10-1 DERP(nyc) 56 ms, gb10-2 DERP(iad) 61-112 ms at 10:23 local), slice 1 direct on the LAN (1-2 ms); no rerun on the LAN, since network latency is not the bottleneck; the finding records each arm's path (the architect).
- role-split (BUILD, review escalation): the finding's figures are redone with jq and awk, quoted in the finding, in place of the session's untracked Python (STANDARDS.md, "No Python is authored") (the architect).
- role-split (BUILD, review escalation): "every command ... exactly as run" covers the commands behind each figure and every command that changes a host; exploratory reads stay out, as footprint's practice left filters and loop lines in the step log (the architect).
- role-split (BUILD, review escalation): S-knee ran each purpose's held level (agent 4, vision 1, audio 1, embedding 16), not GuideLLM's knee (vision 11.56); accepted as meeting the brief, since the held level is what Behavior 5 defines the split as holding (the architect).
- role-split (BUILD, review escalation): the audio gap was timed by curl, one 6 s clip (192 KB WAV) to gb10-2's 16-slot E4B: from gb10-1 (direct, 2 ms) 0.38-0.42 s; from the laptop (DERP(iad), 61 ms) 0.77-0.92 s, the first 1.19 s. The 0.4 s difference is the request's trip over the relay, not inference.
- role-split (BUILD): production clients sit on the same direct network as the GPUs in the datacenter, so the layout is sized on LAN figures; the split arm's client-side figures (relay) read as pessimistic and its server-side figures stand; the relay cost measured in L.7 is a fact of off-network use, not a requirement for spike-model-gateway or something the layout optimizes (the architect).


- framework: the Framework takes the capability-host role, chosen from role-split's findings: vision and audio missed together on gb10-2's one GPU with 68.85 GiB free, the agent met its target alone, and Vulkan's 4-slot limit on the 26B-A4B costs vision nothing (one image encode at a time); rejected: overflow for the agent (stays computed, 9 sessions of 131,072 alone), overflow for the full set.
- framework: the Framework serves vision, audio and embedding as added capacity beside gb10-2, which keeps its 16-slot 26B-A4B, 16-slot E4B and granite; each capability purpose has two hosts (the architect).
- framework: the Framework's one starting-state adjustment: its clone moves from 3260dd0 to main at 21b5e8c and its router restarts, giving set A's Gemma sections the prompt-cache cap; no step loads the 16-slot or agent-only sections there.
- framework: watch samples system MemAvailable beside GTT on an amdgpu host, with a system floor of 12.5 GiB (10% of 128,075 MiB) beside GTT's 11.2 GiB, and stops a cell under either; an edit to the step helpers, not a new tool.
- framework: Gemma 4 26B-A4B past 4 slots on Vulkan stays untested: the fix (#25584) is in no build, and more slots add no vision throughput on b12098 (role-split L.1); footprint's open item closes with both reasons.
- framework: the baseline (the split as it serves now) reruns in this session; role-split's figures are cited, not compared.
- framework: runs go on whatever path the laptop has, with `tailscale ping` recorded for every run; the finding notes that off-LAN latency may slightly affect client-side timing figures (the architect).
- framework: held llama.cpp (gb10) and (strix-halo) at b12098: the -hf tag matching (#31620, #31639, in common/download.cpp) is unchanged through b12242; common/download.cpp and hf-cache.cpp untouched since 2026-11-05.
- framework: the Framework's store extras (Gemma 4 12B, 31B and E4B QAT GGUFs; granite's safetensors) cleared, as gb10-1's were: nothing this spike or a planned goal runs reads them.
- framework: the Framework serves set A's 26B-A4B and E4B at 4 x 8,192 (capped) and granite at 16 x 8,192; no pull request to host/; rejected: Framework sections with other slot counts.
- framework: the Framework is swept per purpose at role-split's full-set levels (vision [1,2,3,4,8] 60 s; audio [1,2,3,4,8] 30 s, at most 64 requests; embedding concurrent [1,2,4,8,16] 30 s), one purpose at a time with the other two idle.
- framework: in the Framework arm's mixed cells each capability purpose's streams split evenly between gb10-2 and the Framework (vision 2+2, audio 2+2, embedding 8+8 at the targets); rejected: a split by footprint's speed ratios.
- framework: mixed cells at the load targets and at role-split's held levels, each on the baseline and on the Framework arm, 240 s each.
- framework: gpt-oss-120b set-a on the Framework is loaded only for the anchors, then unloaded.
- framework: anchors A and B once each on the Framework only, read against the hosts finding's R3/R4 within its across-days 2.8% as a record, not a gate; no GB10 anchors; the Framework's figures are compared with the GB10s' as arrangements, never as host parity.
- framework: the session ends with the split plus the Framework serving (gb10-1 agent-only; gb10-2 its 16-slot sections and granite; the Framework its three capped capability sections); all three clones on main at 21b5e8c.
- framework: when agent-vllm runs, the Framework runs gb10-2's capability workload and configuration on vLLM as well; a pending roadmap edit, not this task's work (the architect).
- framework: the walkthrough reloads the Framework's capability sections from the finding's commands, reads both pools, and reruns one level of the sweep for the purpose it holds least of, as its own cell.
- framework (BUILD): each GB10's 3 listed updates (distro-info, python3-distro-info, snapd 2.78) are Ubuntu-phased (10%), so `apt upgrade` holds them back; the architect's run upgraded 15 packages, and the phased three count as no pending updates; recorded in `.state/framework/phased-2026-11-10.txt`.
- framework (BUILD): `watch` refuses to start a cell on an amdgpu host when `MEASURE_SYSTEM_FLOOR_GIB` is unset, so no Framework cell runs with system memory unwatched; the new sample column goes last, so older watch files still summarize; `footprint` reads both pools too.
- framework (BUILD): the Framework's store extras were removed with `hf cache rm` (32,450,885,380 bytes), as gb10-1's were; its first `mise exec -- hf` installed the engines suite's huggingface_hub 2.4.0 at user level.
- framework (BUILD): slice 1 ran direct on the LAN (0-2 ms) on every host, not over a relay.
- framework (BUILD): slice 2 ran direct on the LAN too and made no tracked change (role-split's bench files unchanged); the Framework's after-cell read takes no page-cache drop, since it has no drop-caches sudoers rule, and stops the arm under either floor.
- framework (BUILD): `bench/levels.jq` gains the request latency's minimum and, for vision, the count at ≤10 s, which slice 2 read with an inline jq, so every figure comes from a tracked reader; an analysis file, as role-split decided, not a new tool.
- framework (BUILD): the per-level tables were reread at 22:16:53Z into `.state/framework/jq-figures-slice3.txt` by one quoted command, each table headed by its host path, since the P-cells' file names repeat across gb10-2 and the Framework.
- framework (BUILD): a GB10's after-cell pool is `memory`'s read, as role-split's tables give it, not `footprint`'s, up to 0.02 GiB apart; gb10-1's lowest margin is reported as 0.30 to 0.36 GiB (P-held's watch read 12,798 MiB, 0.298 GiB above 12.2).
- framework (BUILD): the finding's summary repeats computed figures without (c), following role-split's accepted summary; the sections they come from mark them.
- framework (BUILD): the layout document's GB10 rows read the shared preset on `main` at 21b5e8c (role-split's 2d7ae32, merged), as all three hosts serve it.
- framework (BUILD, standards review): the finding drops the hosts' LAN addresses (STANDARDS.md, Docs: no LAN identifier is committed), and quotes eight launch commands as run, each step file's heredoc write shown with its body elided to the copy in `.state/framework/step-files/`, and the table command with its compare step.
- framework (BUILD, spec review): the 84.25 GiB system-memory low is scoped to the capability arrangement, with the anchors' 52.04 / 52.17 GiB beside it; X-embed's table gains its errored count; the anchors' pings are dated by the step log's trace, since their pongs carry no date.
- framework (BUILD, escalation): the branch was rewritten before publishing so the hosts' LAN addresses, committed in the finding's first commit and removed by the standards review, never reach the public history: the removal folded into that commit with a non-interactive fixup rebase over origin/main, the tree unchanged (the architect).
- framework: slice 4's walkthrough waived by the architect, as in hosts; `bench/framework-walk-vision.yaml` stays as the one-level cell for a later rerun (the architect).

- agent-vllm: scope is gpt-oss-120b on vLLM v0.33.0 against llama.cpp's agent-only section, on gb10-1 alone; the capability models on vLLM become a new task placed next, and the two widening edits move into it; rejected: widening this task to the capability GB10 or to the Framework.
- agent-vllm: the vLLM pin moves to v0.33.0 from its tag and images (the same commit as v0.33.0rc3), by a pull request to host/ that also rewrites the hold comment and carries llama.env's hold note through b12271; currency keeps reporting rc3 until GitHub's release object moves.
- agent-vllm: the engines run one after the other on gb10-1 (llama.cpp's baseline, then vLLM's two rows, then llama.cpp restored); rejected: vLLM on gb10-2 beside llama.cpp on gb10-1.
- agent-vllm: two vLLM rows are evaluated, not one discarded on paper: gpt-oss-120b-agent (BF16 KV, gpu-memory-utilization 0.80) and gpt-oss-120b-agent-fp8 (fp8 e4m3, kv-cache-memory-bytes 32993476982, 1,179,648 tokens computed), each max-model-len 131072, max-num-seqs 16, no backend named; an FP8 idle read under 12.2 GiB stops it and escalates, with 28 GiB as the fallback (the architect).
- agent-vllm: role-split's S-agent sweep runs unchanged on llama.cpp and on both vLLM rows ([1,4,8,12,16], 110 s a level).
- agent-vllm: a capacity cell (8 concurrent sessions, one 65,536-token request each, 256 out, cap 10 min) runs on both vLLM rows; rejected: running it on llama.cpp as well.
- agent-vllm: anchors A and B run on the BF16 row only, read against v0.32.0's 34.0 and 86.7 tok/s as a record; none on llama.cpp (b12098 unchanged) or on the FP8 row.
- agent-vllm: the reasoning and tool-call probes run once on each vLLM row, and every vLLM cell counts the server log's Harmony and parser errors, since the quantization floor doesn't cover KV precision and FP8 KV runs at scale 1.0.
- agent-vllm: one cold start per engine: llama.cpp's load and vLLM's BF16 timed start from a dropped page cache (its first start recorded apart); the FP8 row's one start, which compiles afresh because the KV dtype is part of vLLM's compile hash.
- agent-vllm: no new tool and no llama-swap: routing above the engine layer is spike-model-gateway's, the goal after layout (the architect).
- agent-vllm: measure-lib's footprint and readout read a vllm container (GPU memory, RSS, start-log sizing and backends, /metrics, Harmony and parser errors); an edit to the step helpers, not a new tool.
- agent-vllm: one session in the order hosts and staging, llama.cpp baseline, BF16 row, FP8 row, llama.cpp restored, about 1 h 50 min on the host (c); rejected: the vLLM rows in a second session.
- agent-vllm: the session ends with gb10-1 serving llama.cpp's agent-only section and the vllm container stopped on the FP8 row, its image, compile cache and gpt-oss weights kept for two-node.
- agent-vllm: the walkthrough starts the stopped FP8 row, reads its KV line and the pool against the finding, reruns S-agent's level 4 as its own cell, and restores llama.cpp.
- agent-vllm: all three hosts take their pending OS updates (the architect), and only gb10-1 is measured or changed.

## Pending edits

- coordinator · ai-hosting.md "Hosts and access": the drop-caches rule on both GB10s.
- coordinator · ai-hosting.md "gb10-2 serves set A": spike-ai-pipeline's llama.env and host-update are stale; gb10-2 serves from spike-model-engines' engines suite and shared preset, whose 26B-A4B QAT section carries `ub = 1120` and `image-min-tokens = 560` on every host, so "The Framework's set A likely has the same 512 cap" no longer holds.
- coordinator · intake note (ai-hosting.md, experiment.hosting): gb10-1's descriptor there still says gb10-2 is reserved for spike-ai-pipeline.
- coordinator · intake note (ai-hosting.md, experiment.hosting): spike-model-engines' llama.cpp setup guide ("GB10, in a container") says gb10-2 is reserved and puts the clone in the home directory, not ~/repos (outside host/).
- coordinator · intake note (ai-hosting.md, experiment.hosting): spike-ai-pipeline's laptop-side `mise run host-update` fails at its clone pull once the clone is gone; it touches nothing first.
- coordinator · intake note (ai-hosting.md, experiment.hosting): the Framework held the same store extras as gb10-1 (Gemma 4 12B, 31B and E4B QAT GGUFs; granite's safetensors); the framework task cleared them with `hf cache rm` (32.45 GB), so both stores hold set A's four models only (spike-model-layout `docs/findings/framework.md`, section A).
- coordinator · intake note (ai-hosting.md, experiment.hosting): gb10-2 has no host descriptor in spike-hosting-upgrades, and this task's within-session spread on gb10-2 (output tok/s: A 2.37%, B 0.52%) is its first run-noise figure; spike-hosting-upgrades' descriptor work can take both.
- spike-model-engines · intake note: docs outside host/ still name strix-halo's pin as b11960 (context/README.md "Held pins", docs/engines/llama.cpp/README.md:14, update.md:35, setup.md:303 and :591); this spike changes only host/.
- coordinator · intake note (ai-hosting.md, experiment.hosting, "Gaps in the answer": the vision section's prompt-cache keys still to verify): the shared preset's 26B-A4B QAT and E4B sections set no `cache-ram`, so each process's host prompt cache defaults to 8192 MiB; under vision load it took gb10-1 under its floor, and on the Framework it sits in system memory, outside the GTT floor (spike-model-layout `docs/findings/footprint.md`, sections G and K). Capping it is role-split's pull request to spike-model-engines' `host/`.
- coordinator · intake note (roadmap.toml, the comment "Inputs to sizing set A's slots"): the vision line's ~477 tokens a page is the model's default image-max-tokens on ggml-org's weights; on the QAT section, `image-min-tokens = 560` and `ub = 1120` put an image at 560 to 1,120 tokens. The audio line's 32,768-token context is the E4B section's total; each of its 4 slots holds 8,192 tokens, under the 10-minute WAV's 15,028 (spike-model-layout `docs/findings/footprint.md`, section I.6; sizing that request is role-split's).
- spike-model-engines · intake note: `docs/engines/llama.cpp/models.md` (outside host/) does not list role-split's three new sections or the Gemma cap keys; measure-lib's `gate` on a Framework clone carrying them would load the 16-slot 26B-A4B section, which aborts on Vulkan past 4 slots.
- spike-model-engines · intake note: granite's section sets no cache keys, so every embedding request saves its idle slot to the prompt cache (177,657 saves in one 2.5-min sweep on gb10-2); `cache-idle-slots = false` and `cache-ram = 0` would stop it (spike-model-layout `docs/findings/role-split.md`).
- coordinator · roadmap.toml, experiment.hosting.spike-model-layout task agent-vllm (and context/README.md, Path 5 and the Capabilities line "The vLLM agent comparison"): widen it from gpt-oss-120b alone to the vision (Gemma 4 26B-A4B), audio (E4B) and embedding (granite) models on vLLM in containers, each in its own process, alone and together on the capability GB10, against llama.cpp; role-split found llama-server b12098 encodes images one slot at a time (~0.23 req/s whatever the slots) and vision and audio missing their floors together (`docs/findings/role-split.md`, L.1, N).
- coordinator · intake note (ai-hosting.md, experiment.hosting, the rules' "Benchmarks"): production clients sit on the same direct network as the GPUs, so the layout is sized on LAN figures (the architect). A cell run from the laptop over a Tailscale relay carries the relay's trip in its client-side figures (TTFT, request latency, RTFx), about 0.4 s for a 6 s audio clip, and its server-side figures are unaffected (spike-model-layout `docs/findings/role-split.md`, "Stack, engine and network path" and L.7). The `tailscale ping` each run records shows which path it took.
- coordinator · roadmap.toml, experiment.hosting.spike-model-layout task agent-vllm (and context/README.md, Path 5 and the Capabilities line "The vLLM agent comparison"), beside the widening edit: the Framework also runs gb10-2's capability workload and configuration (vision, audio and embedding, each in its own process) on vLLM, in a container, against its llama.cpp figures from the framework task (the architect). spike-model-engines' official vLLM ROCm image ships no audio decoder, so an audio request returns 500; the audio-extra probe image covers that (spike-model-engines context/README.md:287-288).
- spike-model-engines · intake note: host/llama.env's hold comment says "checked still unrestored through b12211"; the framework task found it unchanged through b12242. The next pull request to host/ (agent-vllm's vLLM pin) can carry the new build number.
- spike-model-engines · intake note: the preset's `gemma-4-26B-A4B-it-qat-Q4_0-16-slots` comment (host/llama-preset/models.ini:217, "GB10 only: on Vulkan (the Framework) the section aborts past 4 slots") is broader than measured: aborts were at 16 x 131,072 (#29082) and 15 x 131,072 (#29221); 4 x 8,192 runs; 5-14 slots and 16 x 8,192 never ran on Vulkan; #29221's report crashes at -np 4 with 262,144-token slots; the E4B past 4 slots never ran on Vulkan either. The framework task left both untested, since the fix (#25584) is in no build and more slots add no vision throughput (spike-model-layout `docs/findings/framework.md`, K.4).
- coordinator · intake note (ai-hosting.md, experiment.hosting, "Gaps in the answer"): on the Framework, vision and audio each met their floor alone at 1 stream (6.82 s; RTFx 8.81) and missed beside each other and embedding (11.94 s; RTFx 4.03) with 82.27 GiB of GTT and at least 84.41 GiB of system memory free; on gb10-2 they missed together at 1 stream with 69 GiB free. The finding reads the purposes' sharing of one GPU's compute and bandwidth, not memory capacity, as what holds them under their floors; no cell isolated it. Two capability hosts held 0 of 4 vision and 0 of 4 audio streams at the load target, and at most 2 vision requests with nothing else running (spike-model-layout `docs/findings/framework.md`, F, J, L.1).
- coordinator · intake note (ai-hosting.md, experiment.hosting, the host descriptors' load targets): gb10-1's agent-only section (c 1,179,648 over 16 slots) met the agent's 4-session target in every cell but ran 0.30 to 0.36 GiB above its 12.2 GiB floor at its lowest, after role-split's 0.27 GiB (spike-model-layout `docs/findings/framework.md`, H, L.5).
- coordinator · roadmap.toml, experiment.hosting.spike-model-layout: a new task after agent-vllm and before on-demand puts the capability models on vLLM in containers: vision (Gemma 4 26B-A4B), audio (E4B) and embedding (granite), each in its own process, alone and together, on the capability GB10 and on the Framework (vLLM ROCm), against llama.cpp. It carries three notes: the official ROCm image shipped no audio decoder at v0.32.0, and the audio-extra probe image covered that (spike-model-engines context/README.md:287-288); v0.33.0's default ROCm image is ROCm 10.0, with `-rocm72` beside it; and the suite runs one `vllm` container on port 8000. This edit replaces the two agent-vllm widening edits above. agent-vllm's summary becomes gpt-oss-120b on vLLM v0.33.0 in two rows (BF16 KV at 0.80; FP8 KV sized to 1,179,648 tokens) against llama.cpp's agent-only section on gb10-1. context/README.md's Path and its Capabilities line change to match (the architect, agent-vllm plan round).
- spike-model-engines · intake note: `scripts/currency.sh` compares `VLLM_RELEASE` with GitHub's latest release, which is still named v0.33.0rc3, though the v0.33.0 tag and Docker images are the same commit; currency reports the pin against rc3 until GitHub publishes a v0.33.0 release. The fix is outside host/.
- spike-model-engines · intake note (housekeeping): agent-vllm's pull request to host/ carries llama.env's hold note through b12271, which supersedes the b12211 -> b12242 note above; drop that note once the pull request merges.
