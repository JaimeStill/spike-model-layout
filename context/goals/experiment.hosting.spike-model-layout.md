# goal · experiment.hosting.spike-model-layout

- **State:** idle
- **Task:** none
- **Branch:** none

## Tasks

1. [x] hosts
2. [x] footprint
3. [x] role-split
4. [x] framework
5. [x] agent-vllm
6. [x] capability-vllm
7. [ ] vllm-layout

## Task brief · capability-vllm

```
Problem       Vision and audio miss their floors on both capability hosts
              under llama.cpp. gb10-2's 16-slot sections hold 1 vision
              request and 1 audio request. The Framework's capped 4-slot
              sections hold 1 and 2. At the targets (vision 4, audio 4,
              embedding 16) the two hosts together held 0 of 4 vision and
              0 of 4 audio, with 57-71 GiB free above their floors. The
              server encodes one image at a time. vLLM batches, so it may
              lift that ceiling. On v0.32.0 it led llama.cpp on GB10 vision
              at 4 streams (3.25 against 4.55 s) and on embeddings at 16
              (295 against 55.5 req/s). On ROCm it trailed on every
              generative cell (22-88%) and returned 500 on audio, since
              its image shipped no audio decoder. Nothing has run the
              three capability models on vLLM at once, each in its own
              process with its own memory fraction. The suite runs one
              vllm container, on port 8000, at 0.80. This spike hasn't
              measured the Framework's vLLM starts. v0.33.0's default ROCm
              image is ROCm 10.0, which AMD supports on gfx1151 but which
              hasn't run here.
Behaviors     1. Every host has no pending OS updates at the session's
                 start: the architect applies the root updates on gb10-1,
                 gb10-2 and the Framework. Each host's stack is recorded:
                 OS, kernel, GPU stack, Docker, engine, clone. Nothing
                 else changes on gb10-1: no load, request or clone move.
                 `tailscale ping` to each host the run drives is recorded
                 with the date before every run, and the finding names
                 each run's path.
              2. A pull request to spike-model-engines' host/ lets one
                 host run three vLLM processes:
                 - Each row may name its container, its port and its
                   image. The suite installs, updates, stops and
                   uninstalls one row's container without touching the
                   others. Several vLLM containers may run on a host.
                   vLLM still refuses while llama runs, and llama refuses
                   while any vLLM container runs.
                 - Six new rows, each with max-model-len 8192 and no
                   attention or MoE backend named:
                   - gb10-2 (cuda): vision, nvidia/Gemma-4-26B-A4B-NVFP4,
                     16 seqs, 0.40, BF16 KV, gemma4 parsers, container
                     vllm-vision on 8000;
                   - gb10-2: audio, google/gemma-4-E4B-it, 16 seqs, 0.20,
                     BF16 KV, gemma4 parsers, vllm-audio on 8001;
                   - gb10-2: embedding,
                     ibm-granite/granite-embedding-english-r2, pooling,
                     16 seqs, 0.05, vllm-embed on 8002;
                   - Framework (rocm): vision, google/gemma-4-26B-A4B-it
                     BF16, 16 seqs, 0.60, the same keys, on 8000;
                   - Framework: audio, google/gemma-4-E4B-it, 16 seqs,
                     0.18, on 8001, served from the audio image;
                   - Framework: embedding, granite, pooling, 16 seqs,
                     0.03, on 8002.
                 - The rocm flavor serves v0.33.0's default image
                   (ROCm 10.0, -rocm100). v0.33.0's -rocm72 is a named
                   fallback, chosen for one run without an edit.
                 - The audio-extra image is rebuilt on -rocm100's digest
                   with av 19.0.2, soundfile 0.14.0 and soxr 1.1.0. A
                   -rocm72 counterpart is named for the fallback. The
                   suite still serves official images for every other
                   row.
                 - The rows file's 0.80 comment is rewritten. llama.env's
                   hold note reads "unrestored through b12282".
                 The PR reaches gb10-2 and the Framework before merge by
                 a push to hosts-next and a local `hosts` branch on each.
                 gb10-1's clone stays where agent-vllm left it. The
                 check passes in both repositories.
              3. The Framework's root steps, the architect's:
                 - ufw route rules on tailscale0 for ports 8001 and 8002;
                 - the exact-command drop-caches sudoers rule, as on the
                   GB10s, checked with `visudo -cf`.
                 From the laptop, ports 8000 to 8002 answer on both
                 capability hosts once a container publishes them. A
                 gb10-2 port that doesn't answer is an escalation.
              4. Before any start or cell, each capability host holds its
                 images and weights, staged in parallel:
                 - gb10-2: vLLM's v0.33.0 CUDA image; NVFP4 26B-A4B,
                   E4B BF16 and granite safetensors, each with every JSON
                   file its start reads;
                 - Framework: v0.33.0's -rocm100 image, the rebuilt
                   audio image, and the 26B-A4B BF16, E4B BF16 and
                   granite safetensors.
                 One read-only check per image is recorded:
                 - -rocm100's rocminfo names gfx1151;
                 - the official -rocm100 image lacks the audio decoders,
                   and the rebuilt image imports av, soundfile and soxr.
                 No vLLM start fetches a model file, which the start log
                 shows.
              5. The step helpers read several vLLM containers.
                 - Sourced for ports 8000 to 8002, footprint and readout
                   read the vLLM container that publishes that port.
                   MEASURE_CONTAINER still overrides.
                 - On an amdgpu host, vLLM's footprint prints each
                   process's GTT and RSS beside the pool's GTT and system
                   memory.
                 - A llama.cpp host and watch read as before. The check
                   passes.
              6. llama.cpp phase, both capability hosts. Each unloads
                 everything, drops the page cache, and loads its sections
                 fresh:
                 - gb10-2: the 16-slot 26B-A4B, the 16-slot E4B, granite;
                 - Framework: set A's capped 26B-A4B and E4B, granite.
                 After 30 s idle each host's pools and processes are
                 read. Then each host's cells (Behavior 9) and the
                 two-host cell (Behavior 10) run.
              7. vLLM phase. Each capability host stops llama and installs
                 its three rows in the order vision, audio, embedding.
                 - These first starts fill the compile cache and are
                   recorded apart.
                 - Each row's container is then restarted alone, from a
                   dropped page cache, while the other two serve. Each
                   timed start runs to "Application startup complete."
                   and /health 200, with MemAvailable sampled every 10 s.
                   These are the rows' cold starts.
                 - /version reads 0.33.0.
                 - Each row answers one probe of its kind (an image, a
                   LibriSpeech clip, two embeddings), with the reply
                   recorded.
                 - After one warm-up request a row, 30 s idle and a
                   cache drop, each host's pools and each row's
                   footprint are read: weights, KV memory and tokens,
                   graphs, backends.
              8. The gates.
                 - A host that reads under its floor idle stops its vLLM
                   phase and escalates. The floors are gb10-2 12.2 GiB;
                   the Framework GTT 11.2 and system 12.5 GiB.
                 - On the Framework, a Gemma row whose start log names
                   ROCM_ATTN stops the phase and escalates before any
                   cell (#62697).
                 - If the -rocm100 image fails to start or serve there
                   (start error, /health never 200, probes or cells
                   erroring), the Framework's vLLM phase reruns on
                   -rocm72 with the -rocm72 audio image. The failure and
                   its log are recorded as a finding.
              9. Per-host cells run one host at a time, on each engine,
                 with each host's role-split files unchanged. Each
                 purpose runs alone, with the other two loaded and idle:
                 - gb10-2: vision knee [1,4,8,12,16], 90 s a level;
                   audio knee [1,4,8,12,16], 30 s or 64 requests a level;
                   embedding concurrent [1,2,4,8,16], 30 s;
                 - Framework: vision knee [1,2,3,4,8], 60 s; audio knee
                   [1,2,3,4,8], 30 s or 64 requests; embedding as gb10-2.
                 Then one mixed cell per host at the targets (vision 4,
                 audio 4, embedding 16), started together, 240 s.
                 - Each level records:
                   - vision: output tok/s, TTFT, ITL and latency (median,
                     p90, minimum, count ≤10 s);
                   - audio: RTFx (median, minimum, count ≥5);
                   - embedding: prompt tok/s and latency;
                   - for every purpose: ok, errored and incomplete
                     counts, and GuideLLM's knee.
                 - Each purpose is judged by its floor (vision ≤10 s,
                   audio RTFx ≥5, embedding ≥4,300 prompt tok/s) under
                   role-split's rule for "holds".
             10. One two-host cell per engine: vision 2+2, audio 2+2,
                 embedding 8+8 across gb10-2 and the Framework at once,
                 240 s. It is read as framework's P-target was, against
                 the targets.
             11. Every cell runs under watch with its host's floors,
                 sampled every 10 s and capped at 10 min. A cell under a
                 floor is stopped and recorded as a finding. Memory and
                 footprint are read after every cell. Every vLLM cell
                 records the server log's errors and Gemma 4
                 output-parser errors, and every cell GuideLLM's errored
                 count.
             12. The capability-vllm finding names every run: tool,
                 configuration, load, duration, path, and the decision
                 it informs. It quotes every command behind a figure,
                 and every command that changes a host, from the step
                 log. It answers evidence 3 and 5 on vLLM against
                 llama.cpp, same session, per host:
                 - each purpose's holds and figures per level and at the
                   target;
                 - the mixed cells and the two-host cell;
                 - memory and the margin above each floor, idle and
                   lowest;
                 - KV tokens per row;
                 - cold starts per row, the first starts apart, with the
                   Framework's vLLM start answering the roadmap's item;
                 - backends, probes and errors;
                 - the ROCm 10.0 outcome and the audio image check.
                 The living layout document gains vLLM's capability rows
                 beside llama.cpp's for gb10-2 and the Framework.
             13. At the session's end gb10-2 and the Framework serve
                 their llama.cpp capability sections, freshly loaded and
                 read. The six vLLM containers are stopped, with their
                 images, compile caches and weights kept. Both clones
                 are on `hosts` at the PR's head until the merge, then
                 on main. gb10-1 serves as agent-vllm left it.
Test seams    Each capability host's router API on 8080 (/health,
              /models, load and unload). vLLM's APIs on 8000, 8001 and
              8002 (/health, /version, /v1/models, /metrics), driven by
              the step helpers one step at a time. The vLLM containers'
              state and start logs. The memory, footprint, readout and
              watch read-outs, with the step log as their record.
              GuideLLM's result files for every cell, the knee
              conclusion among them.
Slices        1. Hosts, the pull request, root steps, staging, helpers and
                 the llama.cpp phase.
                 - The architect applies the root updates on all three
                   hosts, and the Framework's ufw and sudoers steps.
                 - Write the host/ PR branch and push it to gb10-2's and
                   the Framework's hosts-next; their clones move to
                   local `hosts`.
                 - Stage images and weights in parallel; build the audio
                   image; run the image checks.
                 - Make footprint and readout read vLLM containers by
                   port, with GTT on amdgpu.
                 Then the llama.cpp phase (Behavior 6), each cell
                 GuideLLM 0.8.1 from the laptop, run by `cell` under
                 watch, hosts in turn:
                   gb10-2: vision ~7.5 min, audio ~2.6, embedding ~2.5,
                     mixed 4 min
                   Framework: vision ~5 min, audio ~3, embedding ~2.5,
                     mixed 4 min
                   two-host cell, 4 min
                 About 50 min of cells and reloads (c).
                 Demo: the PR's six rows on both hosts' branches, the
                 Framework's rocminfo and audio import checks, footprint
                 printing a llama-server row with GTT, and the llama.cpp
                 tables per host with the two-host cell.
              2. The vLLM phase and the restore. On each host `docker
                 stop llama`, then the three rows installed (first
                 starts, recorded apart), then each row's timed restart
                 from a dropped cache. Then probes, warm-up, 30 s idle
                 and the read, with the gates applied (Behavior 8). From
                 here the helpers are sourced per port. Then the same
                 cells as slice 1, hosts in turn, and the two-host cell.
                 Then on each host stop the vLLM containers, `docker
                 start llama`, load the capability sections, idle 30 s
                 and read (Behavior 13). About 1 h 10 min on the hosts
                 (c).
                 Demo: each row's start log (KV line, backend), each
                 host's idle read against its floors, and vision and
                 audio at the target on both engines per host, with the
                 two-host cells side by side.
              3. The finding and docs. Write the capability-vllm finding:
                 - evidence 3 and 5 per host and engine;
                 - memory and KV rows, measured and computed, each
                   marked;
                 - cold starts, backends, probes, errors, the ROCm 10.0
                   outcome;
                 - every run with its path, and the commands quoted.
                 Update the layout document's capability rows.
                 Demo: the comparison table, and one placement read from
                 it (combined vision against the target of 4 on each
                 engine).
              4. The architect's walkthrough on the Framework: `docker
                 stop llama`; start the three stopped vLLM containers on
                 the ROCm 10.0 image (warm compile cache), timing the
                 vision row's start; read both pools against the
                 finding. Then rerun the vision sweep's level 1 as its
                 own cell (60 s) under watch against the session's, and
                 restore llama.cpp as Behavior 13 states. About 25 min.
Out of scope  Any new tool, Docker Compose and llama-swap among them.
              Any load, request or clone move on gb10-1, and the agent
              row. Anchors on any engine. Attention or MoE backend flags,
              unless an escalation names one. FP8 weights, the E4B QAT
              w4a16, NVFP4 on ROCm, and KV-scale calibration. Accuracy
              evals beyond the probes. Mixed cells at the held levels,
              and the 10-minute WAV probe. The Framework's Vulkan
              sections past 4 slots. llama.cpp past b12098. vLLM past
              v0.33.0, v0.34.0rc0 among them. Native vLLM. Changes
              outside host/ in spike-model-engines, its vLLM docs and
              currency.sh among them (intake notes). Routing
              (spike-model-gateway). Removing vLLM's images, containers
              or weights.
Door          two-way: the rows, suite changes and audio image revert by
              a commit to host/, and before merge by checking each
              clone out at main. The helper edits revert by commit.
              vLLM's containers, images, compile caches and weights come
              off with `docker rm`, `docker rmi` and `hf cache rm`.
              llama.cpp's sections return with `docker start llama` and a
              load. Root is the architect's: the OS updates; the
              Framework's ufw rules, removed with `ufw route delete`; and
              its sudoers rule, removed by deleting the file. Nothing in
              the task can't be undone.
```

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
- agent-vllm (BUILD): the FP8 row keeps `--gpu-memory-utilization 0.80` beside its byte size: the 0.80 still gates vLLM's startup free-memory check, and the bytes size the cache (v0.33.0 source, `vllm/v1/worker/utils.py`, `gpu_worker.py`).
- agent-vllm (BUILD): the capacity file carries `max_duration` 570 s, so a slow cell still writes its JSON under `cell`'s 10 min cap.
- agent-vllm (BUILD): the step helpers choose the engine by port (8000 reads vLLM, any other llama.cpp), and `MEASURE_ENGINE` overrides the choice; vLLM's `footprint` reads the start log since the container's current start.
- agent-vllm (BUILD): idle reads drop the page cache first, as slice 1's baseline did; each vLLM start is timed on gb10-1's clock to "Application startup complete."; MemAvailable is sampled every 10 s during each start.
- agent-vllm (BUILD): the premise changed: v0.33.0's BF16 cache held 846,411 tokens, not ~494,000, so the capacity cell didn't force BF16 to queue; the FP8 row held 1,733,910 tokens, not the computed 1,179,648. Both are reported as found, not rerun.
- agent-vllm (BUILD): "meets the floor through" (llama.cpp 4, BF16 8, FP8 12) and "holds" by role-split's rule (4, 4, 12) are reported side by side.
- agent-vllm (BUILD): `bench/capacity.jq` and `bench/readouts.awk` are tracked readers for the capacity cell, analysis files and not a new tool; the standards review made them report data they can't read instead of reading it as 0.
- agent-vllm (BUILD): the FP8 row's byte size is reproduced by a quoted awk command (half the mean of v0.32.0's two logged accountings, times 1,179,648), in place of the planner's unquoted scratch computation.
- agent-vllm (BUILD): v0.32.0's start and load times stand beside v0.33.0's as a record across versions, not a comparison.
- agent-vllm (BUILD): every vLLM start contacted the Hugging Face hub for metadata and downloaded no model file; the finding records it, and Behavior 3 holds for files.
- agent-vllm (BUILD): the comment wording in host/vllm-rows stays as is, so the pull request's head stays at c5251be, which gb10-1 runs and the finding cites.
- agent-vllm (BUILD): for the agent, a longer cold start is accepted in exchange for better concurrency and overall performance (the architect).
- agent-vllm (BUILD): vLLM is the more attractive engine for the agent, chiefly for its concurrency (the architect).
- agent-vllm (BUILD): the finding's conclusion is framed as evidence: vLLM is the stronger agent engine on gb10-1, the FP8 row leads the BF16 row if its output quality matches, and FP8's uncalibrated KV cache is the one open item (the architect).
- agent-vllm: the architect's walkthrough reproduced the FP8 row's sizing (1,733,910 tokens) and its level 4 (ITL 49.85 against 49.55 ms; every-token 74.28 against 74.38 tok/s); its pool read (15.19 GiB) came straight after the start, without the finding's warm-up, idle and cache drop, and is recorded as that, not isolated (docs/findings/agent-vllm.md, L.4).
- plan: added capability-vllm between agent-vllm and on-demand (the architect, after agent-vllm); applied the record's three roadmap edits for it (agent-vllm's two widening edits and the new-task edit) in the coordinator; no next brief, its rounds run at its start.
- capability-vllm: held llama.cpp (gb10) and (strix-halo) at b12098: the QAT -hf tag matching (#31620, #31639) is unchanged through b12282, since common/download.cpp hasn't changed since 2026-11-05; the host/ PR's hold note reads "unrestored through b12282".
- capability-vllm: the Framework runs v0.33.0's default ROCm 10.0 image (-rocm100), the most recent vLLM and ROCm the hardware supports (the architect); rejected: holding -rocm72, and moving ROCm 10.0 to a later task.
- capability-vllm: the 26B-A4B on gb10-2 is nvidia/Gemma-4-26B-A4B-NVFP4 (publisher-evaluated within ~1% of BF16, 18.13 GiB); rejected: RedHatAI FP8-dynamic, BF16.
- capability-vllm: the 26B-A4B on the Framework is Google's BF16, the only format vLLM has served on gfx1151; rejected: FP8-dynamic, unproven on gfx1151, which has no FP8 hardware.
- capability-vllm: E4B is BF16 on both hosts, the same precision class as llama.cpp's Q8_0 audio and clear of the floor's ASR clause; rejected: Google's QAT w4a16-ct.
- capability-vllm: the Framework's audio row serves from the audio-extra image rebuilt on v0.33.0's ROCm image, after a check that the official image lacks the decoders; rejected: leaving audio off vLLM there.
- capability-vllm: each host's three processes come from the engines suite's rows, each naming its container, port (8000 vision, 8001 audio, 8002 embedding) and fraction, by a host/ PR; vLLM still refuses beside llama; rejected: Docker Compose as the task's one new tool.
- capability-vllm: vision and audio rows serve 16 seqs of 8192 on both hosts; rejected: mirroring llama.cpp's 4 slots on the Framework.
- capability-vllm: llama.cpp's capability cells rerun in this session on both hosts, so every comparison is same-session; no anchors (b12098 unchanged); rejected: citing role-split and framework after anchors.
- capability-vllm: each host's role-split files run unchanged (gb10-2 [1,4,8,12,16]; the Framework [1,2,3,4,8]; embedding concurrent [1,2,4,8,16]), one purpose at a time with the other two loaded and idle, plus one mixed cell per host at the targets, 240 s; rejected: new shared levels.
- capability-vllm: one two-host cell per engine (vision 2+2, audio 2+2, embedding 8+8, 240 s), so both hosts switch engines together: llama.cpp on both, then vLLM on both.
- capability-vllm: the architect installs the exact-command drop-caches sudoers rule on the Framework, so its vLLM starts are timed cold; rejected: warm-cache starts.
- capability-vllm: the session ends with llama.cpp restored on gb10-2 and the Framework, the vLLM containers stopped with images, compile caches and weights kept.
- capability-vllm: if v0.33.0's ROCm 10.0 image fails to start or serve on gfx1151, the Framework's vLLM phase falls back to -rocm72, with the failure recorded as a finding; the host/ PR names the fallback and its audio image; rejected: stopping to escalate.
- capability-vllm: gb10-2's fractions are vision 0.40, audio 0.20, embedding 0.05 of 121.63 GiB, ~42 GiB left available idle (c); an idle read under 12.2 GiB stops the phase and escalates.
- capability-vllm: the Framework's fractions are vision 0.60, audio 0.18, embedding 0.03 of the 112 GiB GTT ceiling, 0.81 in all; an idle read under either floor (GTT 11.2, system 12.5 GiB) stops and escalates.
- capability-vllm: no attention backend named on the Framework's Gemma rows; the backend vLLM picks is recorded, and a start log naming ROCM_ATTN (#62697) escalates before any cell; rejected: naming TRITON_ATTN now.
- capability-vllm: each row's cold start is its container restarted alone from a dropped page cache while the other two serve, after first starts recorded apart; rejected: restarting all three together.
- capability-vllm: per-purpose sweeps run one host at a time; rejected: both hosts at once from the laptop.
- capability-vllm: slices are (1) hosts, PR, root steps, staging, helpers and the llama.cpp phase with its two-host cell; (2) the vLLM phase, its two-host cell and the restore; (3) the finding and layout document; (4) the architect's walkthrough; rejected: the llama.cpp phase in slice 2.
- capability-vllm: the walkthrough runs on the Framework (three vLLM rows started on ROCm 10.0, the vision start timed, both pools read, vision level 1 rerun as its own cell, llama.cpp restored); rejected: gb10-2.
- capability-vllm (BUILD, escalation 1): Claude Code on the laptop reaped the llama.cpp two-host cell's background shell about a minute in, for low laptop memory, before any result was written; the architect freed memory and answered "b": rerun once with the reaper left on, and drop the cell on both engines if it is reaped again. The rerun completed. The reaped run's partial logs are kept apart in `.state/measure/<host>/reaped-two-2026-11-11/` (the architect).
- capability-vllm (BUILD): the vLLM two-host cell ran after a check of the laptop's memory (20.76 GiB available, 9.49 GiB at its lowest during the cell) and was not reaped.
- capability-vllm (BUILD, spec gap): the audio probe's rerun at 22:18:10Z recorded no `tailscale ping` of its own; the probes' pings at 22:17:16Z, 54 s earlier, stand as its path.
- capability-vllm (BUILD, spec gap): the `-rocm72` fallback image and its audio image were staged and checked ahead of need, beyond Behavior 4's list, so Behavior 8's fallback could run without a download. The fallback didn't run, and both images stay on the Framework.
- capability-vllm (BUILD): the steps outside the cells (starts, probes, loads, idle reads, the restore) ran on both hosts at once; the cells ran one host at a time, except the two-host cells.
- capability-vllm (BUILD): the warm-up is one short request a row ("Say hello in one sentence." or one embedding input), sent after the probes.
- capability-vllm (BUILD): granite chose ROCM_ATTN on the Framework, for encoder-only attention. The #62697 gate names the Gemma rows only, so it didn't stop the phase; the finding records the backend.
- capability-vllm (BUILD): the Framework's idle and after-cell reads now follow a page-cache drop, through the new sudoers rule at `/usr/bin/sysctl` (the GB10s' names `/usr/sbin/sysctl`); the framework task read the Framework without one.
- capability-vllm (BUILD): the engines PR (4ad76e6) pins the official images by tag, with their digests only in the audio Dockerfile, which builds on them, and in a `vllm.env` comment; it serves the rocm flavor's default tag, the same image as `-rocm100`, rather than naming `-rocm100`; `VLLM_ROCM_BUILD` accepts only the named fallback, `rocm72`; and "any vLLM container" means every container a row names, plus `vllm`.
- capability-vllm (BUILD, standards review): `vllm_remove_images` keeps every image a container was created from and removes the other official images, so an update removes a `-rocm72` staged ahead of need. bb68cbd says so in a comment and leaves the behavior unchanged.
- capability-vllm (BUILD): two measure-lib fixes: c881c29 (slice 2) stops vLLM's readout counting "parse" inside "sparse", which ROCm's `sparse_attn_indexer` warning names, as a parser line; 88c6b2f (standards review) makes a GPU or host the helpers can't read report none or an error, never 0 or no container.
- capability-vllm (BUILD, standards review): throwaway Python helpers (`imports.py`, `mkprobes.py` and an inline `python3 -` edit) ran untracked, against STANDARDS.md's rule that no Python is authored; nothing tracked depends on them, and the finding says so (760cfc7).
- capability-vllm (BUILD): after the reviews, gb10-2's and the Framework's clones moved to bb68cbd, a comment-only change; every figure was measured at 4ad76e6.
- capability-vllm (BUILD): the Framework's system memory came closest to its floor during the vLLM vision sweep, 0.76 GiB above 12.5 GiB, under the 0.60, 0.18 and 0.03 fractions. It is reported as found; nothing was rerun or changed.
- capability-vllm (accept): queueing the capability host by GPU compute pressure, not free memory, is the gateway's: admit on the engines' live latency and queue signals against each purpose's floor (vLLM and llama.cpp `/metrics`), since gb10-2's mixed cell missed vision with ~19 GiB free above its floor; carried to the answer task's routing requirements for spike-model-gateway (the architect).
- plan: on-demand is dropped: the capabilities are designated and their memory layouts essentially optimized; GPU compute, not memory, is the bottleneck; and loading and unloading add compute on top of inference (the architect, 2026-11-12).
- plan: two-node is dropped: vLLM instances, one model each, spread across gb10-1 and gb10-2 replace pooling the GB10s for the agent, with the Framework as backup compute; one final task, vllm-layout, replaces on-demand and two-node and absorbs answer (the architect, 2026-11-12).
- plan: vLLM is the preferred engine, for concurrency first, and manages model loads better; vllm-layout removes llama.cpp from the workstations and leaves the hosts on the vLLM layout as their standing state; spike-model-engines keeps its llama.cpp features (the architect, 2026-11-12).
- plan: model management stays off the serving API, since a user client such as Pi changing a workstation's model configuration through llama.cpp's server API is a vulnerability; the gateway as the single secure point of model management for the vLLM instances is welcome, and spike-model-gateway's roadmap entry carries it as a comment (the architect, 2026-11-12).
- plan: vllm-layout tunes the capability pool's concurrent sessions across vision, audio and embedding together, with a strategy that keeps them from competing for compute; rejected: an isolation cell (the architect, 2026-11-12).
- plan: the FP8 KV against BF16 accuracy check is vllm-layout's one new tool; a lever that needs another tool, such as CUDA MPS, competes for that slot in its plan round (the architect, 2026-11-12).
- plan: vllm-layout identifies a lighter Gemma 4 vision model for the Framework that its vLLM ROCm engine serves within the quantization floor and the model-origin rule, and measures it against the BF16 26B-A4B row at the vision floor (the architect, 2026-11-12).
- plan: vllm-layout may take up to five slices, the last a walkthrough, an exception to the experiment's four that its brief states; v0.34's source and the next brief are left to its own rounds (the architect, 2026-11-12).

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
- coordinator · intake note (ai-hosting.md, experiment.hosting, the rules' "Benchmarks"): production clients sit on the same direct network as the GPUs, so the layout is sized on LAN figures (the architect). A cell run from the laptop over a Tailscale relay carries the relay's trip in its client-side figures (TTFT, request latency, RTFx), about 0.4 s for a 6 s audio clip, and its server-side figures are unaffected (spike-model-layout `docs/findings/role-split.md`, "Stack, engine and network path" and L.7). The `tailscale ping` each run records shows which path it took.
- spike-model-engines · intake note: host/llama.env's hold comment says "checked still unrestored through b12211"; the framework task found it unchanged through b12242. The next pull request to host/ (agent-vllm's vLLM pin) can carry the new build number.
- spike-model-engines · intake note: the preset's `gemma-4-26B-A4B-it-qat-Q4_0-16-slots` comment (host/llama-preset/models.ini:217, "GB10 only: on Vulkan (the Framework) the section aborts past 4 slots") is broader than measured: aborts were at 16 x 131,072 (#29082) and 15 x 131,072 (#29221); 4 x 8,192 runs; 5-14 slots and 16 x 8,192 never ran on Vulkan; #29221's report crashes at -np 4 with 262,144-token slots; the E4B past 4 slots never ran on Vulkan either. The framework task left both untested, since the fix (#25584) is in no build and more slots add no vision throughput (spike-model-layout `docs/findings/framework.md`, K.4).
- coordinator · intake note (ai-hosting.md, experiment.hosting, "Gaps in the answer"): on the Framework, vision and audio each met their floor alone at 1 stream (6.82 s; RTFx 8.81) and missed beside each other and embedding (11.94 s; RTFx 4.03) with 82.27 GiB of GTT and at least 84.41 GiB of system memory free; on gb10-2 they missed together at 1 stream with 69 GiB free. The finding reads the purposes' sharing of one GPU's compute and bandwidth, not memory capacity, as what holds them under their floors; no cell isolated it. Two capability hosts held 0 of 4 vision and 0 of 4 audio streams at the load target, and at most 2 vision requests with nothing else running (spike-model-layout `docs/findings/framework.md`, F, J, L.1).
- coordinator · intake note (ai-hosting.md, experiment.hosting, the host descriptors' load targets): gb10-1's agent-only section (c 1,179,648 over 16 slots) met the agent's 4-session target in every cell but ran 0.30 to 0.36 GiB above its 12.2 GiB floor at its lowest, after role-split's 0.27 GiB (spike-model-layout `docs/findings/framework.md`, H, L.5).
- spike-model-engines · intake note: `scripts/currency.sh` compares `VLLM_RELEASE` with GitHub's latest release, which is still named v0.33.0rc3, though the v0.33.0 tag and Docker images are the same commit; currency reports the pin against rc3 until GitHub publishes a v0.33.0 release. The fix is outside host/.
- spike-model-engines · intake note (housekeeping): agent-vllm's pull request to host/ carries llama.env's hold note through b12271, which supersedes the b12211 -> b12242 note above; drop that note once the pull request merges.
- coordinator · intake note (ai-hosting.md, experiment.hosting): for the agent, the architect accepts a longer cold start in exchange for better concurrency and overall performance, and finds vLLM the more attractive agent engine, chiefly for its concurrency (spike-model-layout `docs/findings/agent-vllm.md`, the conclusion and N).
- spike-model-engines · intake note: `docs/engines/vllm/models.md` and `docs/engines/vllm/api.md` (outside host/) still describe v0.32.0 and list neither the `gpt-oss-120b-agent` nor the `gpt-oss-120b-agent-fp8` row (spike-model-layout `docs/findings/agent-vllm.md`, N).
- coordinator · intake note (ai-hosting.md, experiment.hosting): gpt-oss-120b's FP8 KV cache on vLLM runs uncalibrated at scale 1.0, and an accuracy check of the FP8 row against the BF16 row would settle the agent row. That check is vllm-layout's one new tool (spike-model-layout `docs/findings/agent-vllm.md`, E, N).
- spike-model-engines · intake note: the vLLM guides in `docs/engines/vllm/` (README.md, setup.md, models.md, api.md, update.md, uninstall.md; outside host/) still describe one `vllm` container on port 8000. They don't cover a row's own container, port and image (capability-vllm's host/ change, 4ad76e6), `VLLM_ROCM_BUILD` and the `-rocm72` fallback, building the Framework's audio image, or the Framework's ufw route rules for ports 8001 and 8002, and they list none of the six capability rows (spike-model-layout `docs/findings/capability-vllm.md`, A.2, A.3, N).
