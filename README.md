# spike-model-layout

How are models placed across the three workstations' memory pools (gb10-1, gb10-2 and the
Framework) to make the best use of memory, and what context and how many concurrent sessions does
each placed model hold? A spike of `experiment.hosting` in the Standards Lab reference
architecture; it gives evidence and decides nothing.

Its working context starts at [`context/README.md`](context/README.md).

## The answer

The answer is evidence; the architect chose the layout. Each model runs in its own vLLM v0.33.0
instance, one heavy purpose to a GPU, and the standing layout met every purpose's floor at the
load targets with all three hosts at once
([`docs/findings/vllm-layout.md`](docs/findings/vllm-layout.md), J):

| Host | Purpose and model | Sequences, context | Load target | Measured at the target, all hosts at once | Holds alone |
| --- | --- | --- | --- | --- | --- |
| gb10-1 | agent: gpt-oss-120b, FP8 KV | 12 × 131,072 | 4 sessions | ITL 48.13 ms | 12 sessions |
| gb10-2 | vision: Gemma 4 26B-A4B NVFP4 | 16 × 8,192 | 4 requests | 4.49 s | 16 requests |
| framework | audio: Gemma 4 E4B BF16 | 4 × 8,192 | 4 requests | RTFx 5.78 | 4, beside embedding |
| framework | embedding: granite-embedding-english-r2 | 128 × 8,192 | at most 34 req/s | 17,442 prompt tok/s | knee at 16 streams, 98,325 tok/s |

The evidence behind each placement:

- **Purposes apart, not memory, decide the layout.** Every miss the spike measured was purposes
  sharing one GPU's compute and bandwidth, with memory far above the floors: set A on one GB10, the
  capability hosts on llama.cpp and on vLLM, and audio beside vision on gb10-2 at every pair level
  ([role-split](docs/findings/role-split.md), [framework](docs/findings/framework.md),
  [capability-vllm](docs/findings/capability-vllm.md), vllm-layout E).
- **vLLM over llama.cpp** for concurrency: the agent's floor through 12 sessions against 4, and
  vision 16 requests against 1 on gb10-2 ([agent-vllm](docs/findings/agent-vllm.md),
  capability-vllm).
- **The agent's FP8 KV row**: no significant loss against BF16 at 95% on GPQA diamond or RULER,
  though 198 questions can't exclude a few points (vllm-layout, C).
- **NVFP4 vision**: no significant loss against Google's BF16 on mmmu_val (vllm-layout, G).
- **Audio beside embedding on the Framework**: it holds beside embedding at a steady 34 requests
  a second and not beside embedding run flat out, nor beside vision on gb10-2 (vllm-layout, E, F).

What the layout needs from spike-model-gateway (admission on live latency and queue signals,
queueing past each row's cap, embedding held to 34 requests a second, overflow to cloud models,
model management only through the gateway, no failover, the Framework's console after a reboot)
and from the intake's host descriptors is in [`docs/layout.md`](docs/layout.md), with on-demand
loading and two-node serving recorded as not pursued.

Four items stay open (vllm-layout, N): FP8's uncalibrated KV scale, where the accuracy test can't
exclude a loss of up to about 10 points on GPQA; audio's zero headroom above its target; the
Framework's reboot, which needs a person at its console to unlock its disk; and vLLM v0.34.0,
unreleased.

