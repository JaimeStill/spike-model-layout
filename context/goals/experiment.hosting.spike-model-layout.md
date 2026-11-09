# goal · experiment.hosting.spike-model-layout

- **State:** building
- **Task:** footprint
- **Branch:** footprint

## Tasks

1. [x] hosts
2. [ ] footprint
3. [ ] role-split
4. [ ] framework
5. [ ] agent-vllm
6. [ ] on-demand
7. [ ] two-node
8. [ ] answer

## Task brief · footprint

```
Problem       Every placement the layout weighs needs to know what each set A model
              costs in memory on each host class: its weights, its KV for each 1,000
              tokens of context, its compute buffers, and how far it grows from idle
              to its warmed peak and under load. The only measured figures are from
              older builds, other quantizations, the Framework alone, and the
              ub-512 vision section. A GB10 has none, and nothing turns the figures
              into a capacity table a placement can be computed from.
Behaviors     1. Every host has no pending OS updates at the session's start; each
                 host's stack and tailscale ping are recorded with the date. If the
                 update moves a host's kernel, driver or Mesa, anchor A runs once on
                 that host before its cells, and the finding compares it with the
                 hosts finding's figure. Otherwise no anchor runs.
              2. The step helpers gain a read-only `footprint` helper. For each
                 llama-server process, named by its --alias, it prints the GPU memory
                 from nvidia-smi's compute-apps list and the RSS from ps on a GB10,
                 or VRAM + GTT from amdgpu_top -p on the Framework; also the pool
                 (MemAvailable, or GTT used and total) and the router log's
                 buffer-size lines since a given time. Its output lands in the step
                 log; it changes nothing on the host. The spike's check passes.
              3. On gb10-1 and on the Framework, each set A section is loaded alone,
                 with nothing else loaded, and recorded: the pool before and after
                 (on a GB10, MemAvailable just after dropping the page cache); the
                 load time; each process's figure; and the logged weight (GPU,
                 host), KV (full-attention, sliding-window), compute (GPU, host)
                 and projector buffers. On a GB10 a process's GPU figure equals its
                 logged GPU buffers plus a CUDA context; the finding states it.
              4. On gb10-1 only, gpt-oss-120b's two other existing sections (c 32768
                 x 4 slots, c 131072 x 16 slots) are each loaded alone and recorded
                 as in 3. Full-attention KV equals 36,864 B/token x c within 1 MiB
                 at all three c values; sliding-window KV and compute at 16 slots
                 are recorded against 4.
              5. Set A's four sections loaded together on each host class, after
                 30 s idle: each process's figure, and the pool left against the
                 floor (GB10 12.2 GiB, Framework 11.2 GiB).
              6. The warmed peak on each host class, set A freshly loaded and idle
                 30 s: each process's figure and the pool after cells P1-P4; each
                 model's growth over idle stated. Under the floor is a finding, and
                 the watch stops the cell.
              7. Under load on each host class, after the warmed peak: each
                 process's highest figure and the pool's lowest during L1-L4, and
                 the growth over the warmed peak. Speed recorded, not judged.
              8. gb10-2's router log for its current set A load is quoted; its
                 logged buffers match gb10-1's for every section. gb10-2 isn't
                 loaded, unloaded or sent a request.
              9. The capacity table, every column marked measured or computed:
                 - per model x host class (measured): weights (GPU, host,
                   projector), full-attention KV per 1,000 tokens (B/token beside
                   it), sliding-window KV per slot, compute (GPU, host, projector),
                   idle alone, idle in the set, warmed peak, under load;
                 - per host (measured): ceiling, floor, base use;
                 - computed: the largest c and the number of 131,072-token
                   sessions each model holds above the floor, alone and beside the
                   rest of set A; each input's token cost (images 560-1120 tokens,
                   audio ~25 tokens/s);
                 - a constraint row for Gemma 4 26B-A4B on Vulkan: each
                   full-attention K layer under 4 GiB, so c < 2,097,152 (#29082);
                   the second request aborts at 15 slots (#29221 open, fix #25584
                   unmerged).
             10. The footprint finding names every run (tool, configuration, load,
                 duration, the decision it informs) and quotes every command as run
                 from the step log. The living layout document cites the table as
                 its sizing input.
             11. The session ends with the Framework serving set A, all four
                 loaded; gb10-1 with nothing loaded, as hosts left it (role-split
                 loads what it compares); gb10-2 unchanged.
Test seams    Each host's router API (/health, /models, load and unload), driven by
              the step helpers one step at a time; the `footprint` and `memory`
              read-outs and the router's load log, the step log their record;
              GuideLLM's result files for every cell.
Slices        1. gb10-1. The architect runs any root updates the hosts need. Add the
                 `footprint` helper and the cell scenarios (P1-P4; L2 at 1440p; L3
                 and L4 from spike-model-engines' audio-b and embed). On gb10-1:
                 - each set A section and gpt-oss-120b's two other sections, each
                   loaded alone from a dropped page cache;
                 - set A loaded together, 30 s idle;
                 - P1-P4, then a fresh reload of set A, 30 s idle, then L1-L4.
                 Every cell is GuideLLM 0.8.1 from the laptop, run by `cell` under
                 `watch`, memory sampled every 10 s, capped at 10 min:
                   P1 gpt-oss set-a, 1 request, ~100,000-token prompt, 256 out,
                      ~1-2 min: the agent's high-water mark at session depth
                   P2 26B-A4B, one 1440p image (capped to 1120 tokens), then two
                      1440p images in one request, then a 7,900-token text
                      request, 64 out, ~20 s: the vision model's high-water mark
                   P3 E4B, the 29.4 s librispeech clip, then a 7,900-token text
                      request, ~15 s: the audio model's high-water mark
                   P4 granite, one 8,000-token embedding input, ~5 s: the
                      embedding model's high-water mark
                   L1 anchor B on gpt-oss set-a, 4 streams x 32, 512/256, ~2 min:
                      memory with the agent at its load target
                   L2 vision-b at 1440p, 4 streams x 32, 64 out, ~1 min
                   L3 audio-b, 4 streams x 32, librispeech, ~1 min
                   L4 embed, 1 then 16 streams, 30 s each, ~1 min
                 Quote gb10-2's log. gb10-1 ends with nothing loaded.
                 Demo: gb10-1's rows, the three gpt-oss KV figures against c, and
                 gb10-2's matching buffers.
              2. The Framework. Slice 1's steps without the two extra gpt-oss
                 sections, reading GTT in place of a dropped cache. P1 ~4-6 min,
                 L1 ~2.3 min, L2 ~2 min, the rest as slice 1. The Framework then
                 serves set A, all four loaded.
                 Demo: the Framework's rows, and the pool at the warmed peak and
                 under load against the 11.2 GiB floor.
              3. The capacity table and docs. Write the footprint finding: the
                 table with its measured and computed columns, the 26B-A4B Vulkan
                 constraint row, every run named, the commands quoted. Point the
                 layout document's sizing at it.
                 Demo: the table, and one computed placement (the agent's
                 131,072-token sessions on an agent-only GB10) worked out from it.
              4. The architect's walkthrough: one model's alone load and its
                 footprint read-out reproduced from the finding's commands; P2
                 rerun on a fresh 26B-A4B load, showing its growth; the capacity
                 table read for one placement.
Out of scope  Any new tool; preset or pull-request changes to spike-model-engines;
              sections outside set A; any load or request on gb10-2; a 26B-A4B
              section with more slots or a larger c on the Framework (the framework
              task); llama.cpp past b12098; speed comparisons with earlier tasks;
              the audio-request sizing against E4B's 8192-token slot (role-split);
              vLLM; routing.
Door          two-way: the helper and scenarios revert by commit; hosts change only
              through the router's load and unload, and end as stated; the page-cache
              drop uses the existing sudoers rule; no preset, pin, image or store
              changes.
```

## Progress

slices 1/4 done (slice 1: helper and scenarios 288b73a; gb10-1 measured, step log .state/measure/gb10-1/2026-11-09.log) · standards — · spec — · editor —

Next: slice 2, the Framework.

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

- footprint: measures set A's four sections only; the GB10 stores hold set A alone and the preset is offline, so the extras can't be measured on both host classes.
- footprint: the GB10 measured is gb10-1, idle with nothing loaded; gb10-2's current load log is quoted as a cross-check, with no load or request on gb10-2.
- footprint: per-process memory comes from a new read-only `footprint` step helper (nvidia-smi compute-apps and ps RSS on a GB10, amdgpu_top -p on the Framework, by --alias, plus the pool and the load log's buffer lines), logged to the step log; no new tool.
- footprint: each set A model is loaded alone from a dropped page cache, then set A together after 30 s idle.
- footprint: KV per 1,000 tokens comes from each section's logged KV buffers, with linearity checked on gb10-1 by loading gpt-oss-120b's existing c 32768 x 4 and c 131072 x 16 sections; no preset change.
- footprint: the warmed peak comes from GuideLLM warm-up cells P1-P4 on freshly loaded set A after 30 s idle, under `watch` every 10 s (spike-model-hosting's method).
- footprint: P1 sends gpt-oss-120b a ~100,000-token prompt (256 out, cap 10 min), not 8,192, so the peak reflects the agent's session depth.
- footprint: memory under load is read with in-flight cells L1-L4 at each model's load target after the warmed peak; speed is recorded, not judged.
- footprint: no anchor rerun, since footprint compares no speed figure and the engines are held at b12098; anchor A runs once on a host first only if the session-start update moves its kernel, driver or Mesa.
- footprint: the capacity table carries measured and computed columns, each marked (largest c and 131,072-token sessions above the floor; input token costs for images and audio).
- footprint: Gemma 4 26B-A4B's Vulkan aborts are recorded as a constraint row (K layer under 4 GiB, so c < 2,097,152; #29221 at 15 slots), not tested; testing is the framework task's.
- footprint: the session ends with the Framework serving set A and gb10-1 with nothing loaded, as hosts left it, since role-split loads what it compares.
- footprint (BUILD): set A's first idle read on gb10-1 came 8 s after the last load; a second read at 45 s gave the same figure (21.45 GiB), so the brief's 30 s read stands; the reload before L1-L4 was read again after the architect's pause.
- footprint (BUILD): L2 (vision-b at 1440p) stopped under gb10-1's floor at 66 s (10.39 GiB): the 26B-A4B's RSS grew 1.2 -> 10.4 GiB with its GPU memory flat, llama.cpp's host prompt cache filling to its cache-ram default (8192 MiB), which set A's Gemma sections leave on. Recorded as a finding; L2 not rerun; capping it is a preset change, outside this task.
- footprint (BUILD): after L2's stop, only the 26B-A4B was reloaded (unload, load) to return above the floor before L3 and L4, which measure the E4B and granite.
- footprint (BUILD): gb10-1's network path turned direct (LAN, 3 ms) after the architect's pause, from DERP(nyc) 56 ms; L1-L4's TTFT ran on it. Speed isn't judged in this task.

## Pending edits

- coordinator · ai-hosting.md "Hosts and access": the drop-caches rule on both GB10s.
- coordinator · ai-hosting.md "gb10-2 serves set A": spike-ai-pipeline's llama.env and host-update are stale; gb10-2 serves from spike-model-engines' engines suite and shared preset.
- coordinator · intake note (ai-hosting.md, experiment.hosting): gb10-1's descriptor there still says gb10-2 is reserved for spike-ai-pipeline.
- coordinator · intake note (ai-hosting.md, experiment.hosting): spike-model-engines' llama.cpp setup guide ("GB10, in a container") says gb10-2 is reserved and puts the clone in the home directory, not ~/repos (outside host/).
- coordinator · intake note (ai-hosting.md, experiment.hosting): spike-ai-pipeline's laptop-side `mise run host-update` fails at its clone pull once the clone is gone; it touches nothing first.
- coordinator · intake note (ai-hosting.md, experiment.hosting): the Framework holds the same store extras as gb10-1 (its framework task can weigh them).
- coordinator · intake note (ai-hosting.md, experiment.hosting): gb10-2 has no host descriptor in spike-hosting-upgrades, and this task's within-session spread on gb10-2 (output tok/s: A 2.37%, B 0.52%) is its first run-noise figure; spike-hosting-upgrades' descriptor work can take both.
- spike-model-engines · intake note: docs outside host/ still name strix-halo's pin as b11960 (context/README.md "Held pins", docs/engines/llama.cpp/README.md:14, update.md:35, setup.md:303 and :591); this spike changes only host/.
