# goal · experiment.hosting.spike-model-layout

- **State:** building
- **Task:** hosts
- **Branch:** hosts

## Tasks

1. [ ] hosts
2. [ ] footprint
3. [ ] role-split
4. [ ] framework
5. [ ] agent-vllm
6. [ ] on-demand
7. [ ] two-node
8. [ ] answer

## Task brief · hosts

```
Problem       The layout needs all three memory pools, but gb10-2 still runs
              spike-ai-pipeline's copy of the engines scripts and preset, the
              Framework trails the GB10s' llama.cpp build, the two GB10s have drifted
              apart, and nothing shows the two GB10s perform alike. Until then no
              cross-GB10 layout figure means anything.
Behaviors     1. All three hosts have no pending OS updates after the architect's root
                 updates; each host's stack (OS or kernel and Mesa, driver, CUDA,
                 Docker, toolkit, llama.cpp build) and its tailscale ping are recorded
                 with the date.
              2. spike-model-engines' currency reports only held items, and each one
                 has a hold Decision in the goal record.
              3. The shared preset's Gemma 4 26B-A4B QAT section carries ub 1120,
                 image-min-tokens 560 and mtmd-batch-max-tokens 512, through a merged
                 spike-model-engines pull request citing spike-ai-pipeline's preset as
                 its finding; the router's listing of that model on every host shows
                 the three keys.
              4. The Framework serves at b12098; anchors A and B ran there on the set-a
                 gpt-oss-120b section at b11960 before the move and at b12098 after,
                 and the finding compares them.
              5. The step helpers log to the spike's own state directory and no longer
                 offer tier or conform; the spike's check passes.
              6. gb10-2's llama container runs server-cuda13-b12098 with its preset
                 mounted from a spike-model-engines clone at the same path as gb10-1's;
                 the two containers' inspect output differs only in the tailnet address.
              7. gb10-2 has no spike-ai-pipeline clone and none of its leftovers (its
                 lint tool, mise trust entries, download log, quoted in the finding
                 first); both GB10s hold the same clones, the engines host
                 environment's tools, and the same gh version.
              8. gb10-2 has the same page-cache drop rule as gb10-1, which
                 `sudo -n -l` lists on both.
              9. gb10-1 carries no drift that neither dotfiles nor the engines suite
                 sets up: no dead gh login, byobu prompt config and its .bashrc line,
                 duplicate PATH line, AI Workbench install and logs, vLLM usage stats,
                 tilelang or CUDA compute caches, or ~/bench (its six files quoted in
                 the finding first). gb10-1's and gb10-2's home directories hold the
                 same set of top-level entries, apart from history files.
             10. gb10-1's model store holds set A's four repositories only, the same as
                 gb10-2's; gb10-2's store lists the same files and sizes before and
                 after the task.
             11. Parity: anchors A and B on the set-a gpt-oss-120b section, only that
                 section loaded and freshly loaded before each run, twice per host,
                 alternating gb10-1 and gb10-2 (8 runs). Output tok/s and ITL agree
                 within max(2.2%, this session's spread); TTFT is recorded, not judged.
                 A miss is a finding and blocks cross-GB10 comparison until explained.
             12. gb10-2 ends serving set A from the shared preset, all four sections
                 loaded.
             13. The hosts finding names every benchmark run (tool, configuration,
                 load, duration, the decision it informs) and quotes every command as
                 run from the helpers' log; the living layout document has a host row
                 for each of the three hosts.
Test seams    Each host's router API (/health, /models, load and unload), driven by the
              step helpers one step at a time, their log the record; container
              settings from docker inspect; host state from read-only listings.
Slices        1. Upgrade and hosts current. The architect runs the root updates on all
                 three hosts. Adapt the step helpers. A spike-model-engines pull
                 request adds the three vision keys and moves the Framework to b12098;
                 hold Decisions logged. Framework runs, GuideLLM 0.8.1 from the laptop
                 on the set-a gpt-oss-120b section, alone and freshly loaded, 512
                 prompt / 256 output tokens, informing whether the move regresses:
                   R1 anchor A (1 stream x 8) at b11960, ~45 s
                   R2 anchor B (4 streams x 32) at b11960, ~105 s
                   R3 anchor A at b12098, ~45 s
                   R4 anchor B at b12098, ~105 s
                 The Framework then serves set A again. Demo: engines currency reports
                 only held items; the Framework's build and its 26B-A4B args.
              2. Align the GB10s. Clone spike-model-engines on gb10-2 at gb10-1's path,
                 move the container with `engines llama update`, then remove the
                 pipeline clone and its leftovers; install the engines host tools on
                 both GB10s and align gh; the architect installs the drop-caches rule
                 on gb10-2; clear gb10-1's store extras and its drift. Demo: the two
                 containers' inspect diff, the home and store listings side by side,
                 set A loading on gb10-2 with the three keys.
              3. Parity cells and docs. R5-R12, GuideLLM 0.8.1 on the set-a
                 gpt-oss-120b section, alone and freshly loaded, in the order gb10-1 A,
                 gb10-2 A, gb10-1 B, gb10-2 B, then again (A ~45 s, B ~105 s, ~25 min
                 with loads), informing the parity verdict cross-GB10 comparison
                 depends on. gb10-2 then serves set A. Write the hosts finding and the
                 layout document's host rows. Demo: the parity table and verdict.
              4. The architect's walkthrough: stack and ping per host, the container
                 and home comparisons, one anchor run reproduced from the finding's
                 commands, and the parity verdict.
Out of scope  Any new tool; gb10 llama.cpp past b12098; downloads to gb10-2's store;
              the Framework's store extras; spike-ai-pipeline's repository;
              spike-model-engines outside host/; host descriptors in
              spike-hosting-upgrades; vLLM.
Door          two-way: pins and preset revert by pull request; the container is
              recreated by `engines llama update`; the removed clone holds nothing
              not on origin; cleared models re-download (~23 min); removed home
              entries are caches, logs, a dead login, or quoted in the finding; the
              sudoers rule goes with its file.
```

## Progress

slices 3/4 committed (slice 4 is the architect's walkthrough, after the session brief) · standards done (ce2fa1f, 8454a41) · spec done (3 gaps closed in e2587f3) · editor done

- Engines clones: gb10-1's, gb10-2's and the Framework's spike-model-engines clones are on local branch `hosts` at 3b60fa4, pushed as `hosts-next`. After SHIP merges the engines pull request, each host runs `git switch main && git pull --ff-only && git branch -D hosts hosts-next`, and its router is restarted only if the merge changed the preset.
- gb10-2's drop-caches sudoers rule is pending the architect (Behavior 8).

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
- hosts: gb10-2 aligned only to what dotfiles and the engines suite set up; gb10-1's drift outside them removed (the architect).
- hosts: gb10-1's store extras (12B, 31B, E4B QAT GGUFs; granite safetensors; 32.45 GB) cleared: nothing this spike or a planned goal runs reads them, and each task downloads what it serves.
- hosts: measure-lib.sh drops tier and conform and fixes MEASURE_ROOT.
- hosts (BUILD): host/ changes reach the hosts before merge by `git push <host>:repos/spike-model-engines hosts:hosts-next` and a local `hosts` branch on each host (spike-hosting-upgrades' precedent), never through GitHub before the architect accepts the session brief.
- hosts (BUILD): the Framework's `engines llama update` needs `LLAMA_FLAVOR=vulkan`, because the script defaults an AMD GPU to rocm. A first run without it moved the Framework to server-rocm-b12098 and removed the vulkan b11960 image; the rerun with the flag corrected it before R3.
- hosts (BUILD): `LLAMA_RELEASE=v0.8.0` stays in host/llama.env as a record. Neither host class runs it, and removing it would change llama-release.sh's message and docs outside host/.
- hosts (BUILD): parity's session spread is taken from output tok/s for both measures. ITL's own spread is wider, so the verdict holds either way.
- hosts (BUILD): gb10-1's deeper app state (dconf, btop, eog, gtk-4.0, yelp, the pnpm and fastfetch caches) and gb10-2's lazygit stay as each host's own use, not drift. ~/.humming and ~/.config/NVIDIA counted as vLLM and AI Workbench leftovers and were removed.
- hosts (BUILD): gb10-2 uses gb10-1's memory floor of 12.2 GiB: the hardware is the same, and gb10-2 has no host descriptor.

## Pending edits

- coordinator · ai-hosting.md "Hosts and access": the drop-caches rule on both GB10s.
- coordinator · ai-hosting.md "gb10-2 serves set A": spike-ai-pipeline's llama.env and host-update are stale; gb10-2 serves from spike-model-engines' engines suite and shared preset.
- coordinator · intake note (ai-hosting.md, experiment.hosting): gb10-1's descriptor there still says gb10-2 is reserved for spike-ai-pipeline.
- coordinator · intake note (ai-hosting.md, experiment.hosting): spike-model-engines' llama.cpp setup guide ("GB10, in a container") says gb10-2 is reserved and puts the clone in the home directory, not ~/repos (outside host/).
- coordinator · intake note (ai-hosting.md, experiment.hosting): spike-ai-pipeline's laptop-side `mise run host-update` fails at its clone pull once the clone is gone; it touches nothing first.
- coordinator · intake note (ai-hosting.md, experiment.hosting): the Framework holds the same store extras as gb10-1 (its framework task can weigh them).
- coordinator · intake note (ai-hosting.md, experiment.hosting): gb10-2 has no host descriptor in spike-hosting-upgrades, and this task's within-session spread on gb10-2 (output tok/s: A 2.37%, B 0.52%) is its first run-noise figure; spike-hosting-upgrades' descriptor work can take both.
- spike-model-engines · intake note: docs outside host/ still name strix-halo's pin as b11960 (context/README.md "Held pins", docs/engines/llama.cpp/README.md:14, update.md:35, setup.md:303 and :591); this spike changes only host/.
