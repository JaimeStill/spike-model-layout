# goal · experiment.hosting.spike-model-layout

- **State:** building
- **Task:** role-split
- **Branch:** role-split

## Tasks

1. [x] hosts
2. [x] footprint
3. [ ] role-split
4. [ ] framework
5. [ ] agent-vllm
6. [ ] on-demand
7. [ ] two-node
8. [ ] answer

## Task brief · role-split

```
Problem       Set A on one GB10 can't hold its floor under vision load:
              its Gemma sections leave llama.cpp's host prompt cache at
              8192 MiB a process, which took gb10-1 to 10.39 GiB under
              L2. Every computed placement assumes the cap that fixes
              it, and the cap hasn't landed. Nothing has measured how
              many sessions or requests each placed model holds at its
              context before its knee or speed floor. Nothing has
              measured whether splitting the roles across both GB10s
              (one serving the agent alone, the other vision, audio and
              embedding) holds more, faster, and with more memory left
              than set A on one. The framework, agent-vllm and two-node
              tasks all start from that comparison.
Behaviors     1. Every GB10 has no pending OS updates at the session's
                 start; each GB10's stack and tailscale ping are
                 recorded with the date. The Framework is read only:
                 no update, load, unload, request or clone change.
              2. A pull request to spike-model-engines' host/, citing
                 the footprint finding (sections G, I.4, K), changes the
                 shared preset:
                 - set A's 26B-A4B QAT and E4B sections gain
                   cache-ram 0, cache-idle-slots false and
                   ctx-checkpoints 2;
                 - a new gpt-oss-120b agent-only section: one unified
                   KV pool of c 1,179,648 over 16 slots, with set-a's
                   keys (checkpoint-min-step 4096, cache-ram 0,
                   cache-idle-slots false, its sampling);
                 - a new 16-slot 26B-A4B QAT section (c 131072, 8,192
                   a slot) with set A's vision keys and the cap keys;
                 - a new 16-slot E4B Q8_0 section (c 131072, 8,192 a
                   slot) with the cap keys.
                 The engines suite's check passes, and its currency
                 reports only held items. Before merge the branch
                 reaches gb10-1 and gb10-2 by a push to each host's
                 hosts-next and a local hosts branch, and each router
                 restarts to read it. The Framework's clone is never
                 touched. Each section's loaded arguments, as `load`
                 prints them, show its keys.
              3. Before either arm, anchors A and B run once each on
                 each GB10, each on a freshly loaded set-a section
                 alone. Each host's output tok/s and ITL fall within
                 the hosts finding's run noise of each other (A 2.37%,
                 B 2.2%). A miss is repeated once; a second miss is a
                 finding and blocks comparing cells across the GB10s.
              4. Full-set arm, on gb10-2. Set A with the capped Gemma
                 sections is loaded fresh from a dropped page cache;
                 after 30 s idle, each process and the pool are read.
                 L2 reruns unchanged and completes all 32 requests
                 with the pool above 12.2 GiB throughout. The 26B-A4B's
                 RSS growth is set against footprint's 1217 -> 10397
                 MiB.
              5. Each knee sweep records every level's output tok/s,
                 TTFT, ITL and errors, and GuideLLM's knee estimate.
                 Agent, vision and audio are each judged by the
                 policy's purpose floor for every stream: agent decode
                 >=10 tok/s (ITL <=100 ms); vision <=10 s an image
                 question; audio RTFx >=5. Granite is judged at
                 >=4,300 prompt tok/s. A model "holds" the highest
                 level that meets its floor at or below its knee.
              6. The 10-minute WAV probe sends one request to gb10-2's
                 set A E4B (8,192 tokens a slot). The finding quotes
                 either its usage (input tokens, against 15,028) and
                 time, or its error as returned. No section changes on
                 its result in this task.
              7. Each mixed cell starts four GuideLLM processes
                 together, each capped at 240 s. For each purpose it
                 records the per-stream figures against that purpose's
                 floor, the pool's lowest during the cell, and each
                 process after it.
              8. Split arm. gb10-1 loads the agent-only section alone
                 from a dropped cache; its figure is set against the
                 computation (4.1 GiB above the floor if compute stays
                 at its c 131,072 figure, ~1.9 GiB if the mask grows).
                 gb10-2 loads the 16-slot 26B-A4B, the 16-slot E4B and
                 granite. Every section's logged buffers are recorded,
                 the Gemma compute at 16 slots and gpt-oss's unified
                 compute at c 1,179,648 among them.
              9. Every cell runs under `watch`, memory sampled every
                 10 s, with the floor at 12.2 GiB on both GB10s and a
                 10 min cap. Memory is read after every cell. Within an
                 arm nothing reloads after its fresh load, except as
                 slice 1 states. A cell that falls under the floor is
                 stopped and recorded as a finding.
             10. The role-split finding names every run (tool,
                 configuration, load, duration, the decision it
                 informs) and quotes every command as run from the
                 step log. It answers evidence 3: per placed model, the
                 sessions or requests held at its context, by output
                 tok/s, TTFT and ITL. It answers evidence 4: full set
                 against split, with each arrangement's holding at the
                 load targets and at its knees, per-stream speed, and
                 memory left on each host.
             11. The finding adds the capacity rows it measured, each
                 marked measured: the capped Gemma sections' warmed and
                 under-load figures; Gemma compute at 16 slots;
                 gpt-oss's unified compute and pool at c 1,179,648. It
                 states which of footprint's section K items it closes.
                 The living layout document gives each GB10 its
                 measured role figures, and its sizing cites these rows
                 beside footprint's table.
             12. At the session's end gb10-1 serves the agent-only
                 section, and gb10-2 the 16-slot 26B-A4B, the 16-slot
                 E4B and granite. Both clones stay on the hosts branch
                 until the pull request merges, then return to main.
                 The Framework is unchanged, serving set A from main.
Test seams    Each GB10's router API (/health, /models, load and
              unload), driven by the step helpers one step at a time;
              the `footprint` and `memory` read-outs and the router's
              load log, the step log their record; GuideLLM's result
              files for every cell, the knee conclusion among them; the
              probe's HTTP response.
Slices        1. The pull request, the anchors, and the full-set arm on
                 gb10-2. The architect runs any root updates the hosts
                 need. Write the pull request and push it to both GB10s'
                 hosts-next, then restart both routers. Add the cell
                 scenarios. Then, every cell GuideLLM 0.8.1 from the
                 laptop, run by `cell` under `watch`:
                   AA/AB  anchors A and B on gb10-1, then gb10-2, each
                      on a fresh set-a load alone, ~9 min in all: whether
                      cells compare across the GB10s
                 gb10-2: unload all, drop the cache, load capped set A,
                 idle 30 s, read. Then:
                   F-L2 L2 unchanged: vision at 1440p, 4 streams x 32,
                      200 text tokens, 64 out, ~2.5 min: whether the
                      cap holds set A above the floor
                   F-agent gpt-oss set-a, knee [1,2,3,4,8], 110 s a
                      level, 4-turn sessions (8,192 first turn, then
                      3 x 512 in; 512 out each turn), ~9.5 min: the
                      agent's sessions held beside the rest of set A
                   F-vision 26B-A4B, knee [1,2,3,4,8], 60 s a level,
                      one 1440p JPEG + 200 text tokens, 100 out,
                      ~5.5 min: vision requests held in the full set
                   F-audio E4B, knee [1,2,3,4,8], 30 s a level, at most
                      64 requests a level, the 73 LibriSpeech clips,
                      ~3 min: audio requests held in the full set
                   F-embed granite, concurrent [1,2,4,8,16], 30 s each,
                      512-token inputs, ~3 min: embedding throughput
                      against its floor
                   F-probe the first 10 minutes of AMI ES2002a (16 kHz
                      mono WAV, cut on the laptop) to E4B's
                      /v1/audio/transcriptions by curl, once, ~1 min:
                      whether an 8,192-token slot takes 15,028 tokens
                   F-mixed agent 4 sessions, vision 4, audio 4,
                      embedding 16, all at once, 240 s each, ~5 min:
                      what the full set holds at its load targets
                 Demo: the anchors' parity, F-L2 above the floor, and
                 the full set's levels held per purpose.
              2. The split. gb10-2: unload all, drop the cache, load
                 the 16-slot 26B-A4B, the 16-slot E4B and granite.
                 gb10-1: drop the cache, load the agent-only section.
                 Read both hosts. Then:
                   S-agent gb10-1 agent-only, knee [1,4,8,12,16], 110 s
                      a level, F-agent's sessions, ~9.5 min: the agent's
                      sessions held alone on a GB10
                   S-vision gb10-2 16-slot 26B-A4B, knee [1,4,8,12,16],
                      90 s a level, F-vision's requests, ~7.5 min
                   S-audio gb10-2 16-slot E4B, knee [1,4,8,12,16], 30 s
                      a level, at most 64 requests a level, ~3 min
                   S-mixed F-mixed's load, gb10-1 and gb10-2 at once,
                      240 s, ~5 min: the split at the full set's targets
                   S-knee each purpose at its split knee from S-agent,
                      S-vision and S-audio (granite at 16), both hosts
                      at once, 240 s, ~5 min: what the split holds
                 Both GB10s end serving as Behavior 12 states.
                 Demo: the agent-only load against its computation, and
                 S-mixed against F-mixed.
              3. The finding and docs. Write the role-split finding:
                 evidence 3's per-model table, evidence 4's comparison,
                 the probe's result, the new capacity rows marked
                 measured, every run named, the commands quoted. Update
                 the layout document's hosts and sizing.
                 Demo: the comparison table, and one placement read
                 from it (the agent-only GB10's sessions held against
                 footprint's computed 9).
              4. The architect's walkthrough: the agent-only section's
                 footprint read reproduced on gb10-1 from the finding's
                 commands; one S-agent level (4 streams, 110 s) rerun as
                 its own cell and read against the finding; the
                 comparison table read for one placement.
Out of scope  Any new tool; any step on the Framework, its clone or its
              preset; sections beyond the five named; the E4B's slot
              size, whatever the probe shows; adaptive knee refinement;
              agent sessions deeper than the 4-turn shape (131,072-token
              sessions stay computed); granite's sweep in the split;
              llama.cpp past b12098; vLLM; on-demand loading; routing
              (each cell targets its host directly); speed comparisons
              with earlier sessions beyond the anchors.
Door          two-way: the pull request reverts by commit, and its
              sections are additions or keys on existing ones. Hosts
              change only through the router's load and unload, the
              clone's branch and a router restart, none needing root.
              The page-cache drop uses the existing sudoers rule. The
              Framework is untouched. No pin, image or store changes.
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
- role-split: each generative sweep uses GuideLLM's knee profile with adaptive refinement off, 5 levels up to the section's slots.
- role-split: the speed floors are spike-hosting-upgrades' purpose floors (agent >=10 tok/s a stream, vision <=10 s an image question, audio RTFx >=5, embedding >=4,300 tok/s).
- role-split: the agent-only section is gpt-oss-120b with one unified pool of c 1,179,648 over 16 slots, with set-a's keys; rejected: 9 per-slot sessions of 131,072, and the existing 16-slot section.
- role-split: the full-set arm's agent is set-a as served (c 131,072, 4 slots, unified).
- role-split: the split's vision and audio are new 16-slot 26B-A4B and E4B sections (8,192 a slot) with the cap keys; granite unchanged.
- role-split: E4B keeps 8,192 tokens a slot, and audio past 30 s goes windowed; one 10-minute WAV probe records what an 8,192-token slot does with 15,028 tokens.
- role-split: each arrangement gets a mixed cell with every purpose at once.
- role-split: no new tool; multi-turn sessions and the knee profile are features of GuideLLM 0.8.1.
- role-split: knee levels are [1,2,3,4,8] in the full-set arm and [1,4,8,12,16] in the split, for the agent, vision and audio.
- role-split: per-level durations: agent 110 s; vision 60 s (full set) and 90 s (split); audio 30 s with at most 64 requests a level over the 73 LibriSpeech clips; rampup 0.
- role-split: granite is swept only in the full-set arm, concurrent [1,2,4,8,16], 30 s each, 512-token inputs, read against 4,300 prompt tok/s.
- role-split: vision sweep requests take 100 output tokens (the floor's measure); the L2 rerun keeps 64 so its memory compares with footprint's.
- role-split: the probe is AMI ES2002a's first 10 minutes as 16 kHz mono WAV, sent once by curl to E4B's /v1/audio/transcriptions.
- role-split: the mixed cells use today's load targets in both arms (agent 4 sessions, vision 4, audio 4, embedding 16).
- role-split: the split adds a second mixed cell at its own measured knees.
- role-split: the split's mixed cells drive gb10-1 and gb10-2 at once from the laptop.
- role-split: each mixed cell's processes start together, 240 s each, under the 10 min cap.
- role-split: no reload between cells within an arm after its fresh load; the L2 rerun starts from set A's fresh load.
- role-split: the session ends with the split serving (gb10-1 agent-only; gb10-2 16-slot 26B-A4B, 16-slot E4B, granite), the arrangement framework and agent-vllm start from; rejected: returning to set A on gb10-2.
- role-split: docs: the finding at `docs/findings/role-split.md` carries its measured capacity rows; footprint's dated finding stays as written, and the layout document cites both.
- role-split (BUILD): the new sections are `gpt-oss-120b-MXFP4-agent-only`, `gemma-4-26B-A4B-it-qat-Q4_0-16-slots` and `gemma-4-E4B-it-Q8_0-16-slots`, after the existing `-16-slots` pattern (spike-model-engines 2d7ae32).
- role-split (BUILD): the mixed and S-knee cells set streams through `GUIDELLM__SPEC__PROFILE__STREAMS`, which GuideLLM reads only when the file leaves `streams` out, so `cell` runs them unchanged; the load targets live in `bench/README.md` and each file's header.
- role-split (BUILD): the mixed audio file reads the 73 clips 12 times (876 rows), since GuideLLM doesn't reuse a source and 73 clips last ~70 s at 4 streams; the knee files keep 73 rows, capped at 64 requests a level.
- role-split (BUILD): F-L2 reuses `bench/footprint-l2.yaml` unchanged; the F-probe recipe lives in `bench/README.md`, its WAV cut locally to `.state/role-split/ami-es2002a-first10min.wav` (600.000 s, 16 kHz mono).

## Pending edits

- coordinator · ai-hosting.md "Hosts and access": the drop-caches rule on both GB10s.
- coordinator · ai-hosting.md "gb10-2 serves set A": spike-ai-pipeline's llama.env and host-update are stale; gb10-2 serves from spike-model-engines' engines suite and shared preset, whose 26B-A4B QAT section carries `ub = 1120` and `image-min-tokens = 560` on every host, so "The Framework's set A likely has the same 512 cap" no longer holds.
- coordinator · intake note (ai-hosting.md, experiment.hosting): gb10-1's descriptor there still says gb10-2 is reserved for spike-ai-pipeline.
- coordinator · intake note (ai-hosting.md, experiment.hosting): spike-model-engines' llama.cpp setup guide ("GB10, in a container") says gb10-2 is reserved and puts the clone in the home directory, not ~/repos (outside host/).
- coordinator · intake note (ai-hosting.md, experiment.hosting): spike-ai-pipeline's laptop-side `mise run host-update` fails at its clone pull once the clone is gone; it touches nothing first.
- coordinator · intake note (ai-hosting.md, experiment.hosting): the Framework holds the same store extras as gb10-1 (its framework task can weigh them).
- coordinator · intake note (ai-hosting.md, experiment.hosting): gb10-2 has no host descriptor in spike-hosting-upgrades, and this task's within-session spread on gb10-2 (output tok/s: A 2.37%, B 0.52%) is its first run-noise figure; spike-hosting-upgrades' descriptor work can take both.
- spike-model-engines · intake note: docs outside host/ still name strix-halo's pin as b11960 (context/README.md "Held pins", docs/engines/llama.cpp/README.md:14, update.md:35, setup.md:303 and :591); this spike changes only host/.
- coordinator · intake note (ai-hosting.md, experiment.hosting, "Gaps in the answer": the vision section's prompt-cache keys still to verify): the shared preset's 26B-A4B QAT and E4B sections set no `cache-ram`, so each process's host prompt cache defaults to 8192 MiB; under vision load it took gb10-1 under its floor, and on the Framework it sits in system memory, outside the GTT floor (spike-model-layout `docs/findings/footprint.md`, sections G and K). Capping it is role-split's pull request to spike-model-engines' `host/`.
- coordinator · intake note (roadmap.toml, the comment "Inputs to sizing set A's slots"): the vision line's ~477 tokens a page is the model's default image-max-tokens on ggml-org's weights; on the QAT section, `image-min-tokens = 560` and `ub = 1120` put an image at 560 to 1,120 tokens. The audio line's 32,768-token context is the E4B section's total; each of its 4 slots holds 8,192 tokens, under the 10-minute WAV's 15,028 (spike-model-layout `docs/findings/footprint.md`, section I.6; sizing that request is role-split's).
- spike-model-engines · intake note: `docs/engines/llama.cpp/models.md` (outside host/) does not list role-split's three new sections or the Gemma cap keys; measure-lib's `gate` on a Framework clone carrying them would load the 16-slot 26B-A4B section, which aborts on Vulkan past 4 slots.
