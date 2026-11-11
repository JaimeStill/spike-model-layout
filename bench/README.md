# Benchmark scenarios

GuideLLM 0.8.1 scenarios, one file a cell, run from the repository root by the step helpers'
`cell` ([`scripts/measure-lib.sh`](../scripts/measure-lib.sh)) under `watch`, from the bench
environment ([`mise.bench.toml`](../mise.bench.toml)). The scenarios are engine-neutral: `cell`
gives the section and its tokenizer on the command line, and sourcing the helpers for a host sets
the target in `GUIDELLM__SPEC__BACKEND__TARGET`. Each file's header gives its load.

- `anchor-a.yaml`, `anchor-b.yaml`: the anchors, copied from spike-model-engines.
- `footprint-*.yaml`: the footprint task's cells
  ([`docs/findings/footprint.md`](../docs/findings/footprint.md)).
- `role-split-*.yaml`: the role-split task's cells, below, which the framework task's cells reuse
  unchanged.
- `agent-vllm-capacity.yaml`: the agent-vllm task's capacity cell, B-cap and F-cap: 8 streams of
  one request each, 65,536 prompt tokens and 256 out, on each of vLLM's agent rows, run with the
  helpers sourced for port 8000 and `MEASURE_READOUT_EVERY=30` (the agent-vllm finding,
  `docs/findings/agent-vllm.md`).

## Role-split's cells

| Cell | Scenario | Section | Tokenizer |
| --- | --- | --- | --- |
| F-L2 | `footprint-l2.yaml`, unchanged | `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` | `google/gemma-4-26B-A4B-it` |
| F-agent | `role-split-agent-full.yaml` | `gpt-oss-120b-MXFP4-set-a` | `openai/gpt-oss-120b` |
| F-vision | `role-split-vision-full.yaml` | `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` | `google/gemma-4-26B-A4B-it` |
| F-audio | `role-split-audio-full.yaml` | `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` | `google/gemma-4-E4B-it` |
| F-embed | `role-split-embed.yaml` | `mrutkows/granite-embedding-english-r2-GGUF:BF16` | `ibm-granite/granite-embedding-english-r2` |
| S-agent | `role-split-agent-split.yaml` | `gpt-oss-120b-MXFP4-agent-only` | `openai/gpt-oss-120b` |
| S-vision | `role-split-vision-split.yaml` | `gemma-4-26B-A4B-it-qat-Q4_0-16-slots` | `google/gemma-4-26B-A4B-it` |
| S-audio | `role-split-audio-split.yaml` | `gemma-4-E4B-it-Q8_0-16-slots` | `google/gemma-4-E4B-it` |
| F-mixed, S-mixed, S-knee | `role-split-mixed-agent.yaml`, `-vision`, `-audio`, `-embed` | each arm's section for the purpose, as above | as above |
| Walkthrough (slice 4) | `role-split-walk-agent.yaml` | `gpt-oss-120b-MXFP4-agent-only` on gb10-1, 4 streams, 110 s | `openai/gpt-oss-120b` |
| Walkthrough (framework, slice 4) | `framework-walk-vision.yaml` | `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` on the Framework, 1 stream, 60 s | `google/gemma-4-26B-A4B-it` |
| D1, D2 | `role-split-diag-audio.yaml`: 1 concurrent stream, 60 s, the 73 clips twice | D1 `ggml-org/gemma-4-E4B-it-GGUF:Q8_0`, D2 `gemma-4-E4B-it-Q8_0-16-slots`, each loaded alone | `google/gemma-4-E4B-it` |

F-L2 reruns footprint's L2 unchanged, so it reads `footprint-l2.yaml` itself rather than a copy.

The full set's knee sweeps use levels 1, 2, 3, 4 and 8, and the split's 1, 4, 8, 12 and 16, each
through GuideLLM's knee profile with adaptive refinement off and no ramp-up. F-embed is a
concurrent sweep at 1, 2, 4, 8 and 16 streams.

### Streams in the mixed cells

Each mixed cell is four GuideLLM processes started together, one a purpose, each from its
`role-split-mixed-*.yaml` at a constant concurrency for 240 s. The mixed scenarios set no stream
count, so one file serves every mixed cell: each `cell` call gives its streams in
`GUIDELLM__SPEC__PROFILE__STREAMS`, which GuideLLM reads into the profile when the file leaves
`streams` out (a value in the file would win over the variable). F-mixed and S-mixed take the load
targets, agent 4, vision 4, audio 4 and embedding 16; S-knee takes the level each purpose held in
its split sweep (the role-split finding, section I: S-agent 4, S-vision 1, S-audio 1), and
granite 16. For example, F-mixed's agent process on gb10-2:

```sh
GUIDELLM__SPEC__PROFILE__STREAMS=4 cell <name> role-split-mixed-agent gpt-oss-120b-MXFP4-set-a openai/gpt-oss-120b
```

With the variable unset, GuideLLM refuses to start. Run without `cell`, GuideLLM's
`--profile kind=concurrent,streams=<n>` sets the streams the same way.

### The audio probe, F-probe

One request: the first 10 minutes of AMI ES2002a as a 16 kHz mono WAV, sent once to the E4B's
`/v1/audio/transcriptions`, to see what its 8,192-token slot does with about 15,028 tokens of
audio ([`docs/findings/footprint.md`](../docs/findings/footprint.md), section I.6). The WAV is cut
on the laptop, from the repository root, into the untracked `.state/role-split/`:

```sh
ffmpeg -nostdin -hide_banner -loglevel error -n -i ~/docs/audio/long/ami-es2002a-mix-headset.wav \
  -t 600 -ac 1 -ar 16000 -c:a pcm_s16le .state/role-split/ami-es2002a-first10min.wav
```

The source is already 16 kHz mono PCM (1,272.64 s); the cut is 600.000 s, 19,200,078 bytes,
SHA-256 `41d76db00daa56053a07f2140bbfff74d97e30310a8119193240a3adffd3a75b`.

Then, from the repository root in a shell that sourced the helpers for gb10-2 (so `MEASURE_URL`
and `MEASURE_STATE` name it), under `watch` like every cell. The response body is saved beside the
cells' results, and `watch` keeps curl's output, the HTTP status and time, in
`role-split-f-probe.log` there:

```sh
watch role-split-f-probe curl -sS -o "$MEASURE_STATE/role-split-f-probe.response.json" \
  -w '%{http_code} %{time_total}s\n' "$MEASURE_URL/v1/audio/transcriptions" \
  -F model=ggml-org/gemma-4-E4B-it-GGUF:Q8_0 \
  -F file=@.state/role-split/ami-es2002a-first10min.wav
```

The finding quotes the saved body: its usage (input tokens, against 15,028) and the time, or its
error as returned.

## The framework task's cells

The framework task ([`docs/findings/framework.md`](../docs/findings/framework.md)) added no
scenario: every cell reads an existing file, and the mixed cells give their streams in
`GUIDELLM__SPEC__PROFILE__STREAMS`, as above. On the Framework, `cell` runs under `watch` with
both of its floors set, `MEASURE_FLOOR_GIB=11.2` (GTT) and `MEASURE_SYSTEM_FLOOR_GIB=12.5` (system
memory); `watch` refuses to start there without the second.

| Cell | Host | Scenario | Section | Tokenizer | Streams |
| --- | --- | --- | --- | --- | --- |
| FA | framework | `anchor-a.yaml` | `gpt-oss-120b-MXFP4-set-a`, freshly loaded alone | `openai/gpt-oss-120b` | the file's: 1 |
| FB | framework | `anchor-b.yaml` | as FA | as FA | the file's: 4 |
| X-vision | framework | `role-split-vision-full.yaml`, knee [1,2,3,4,8] | `google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0` | `google/gemma-4-26B-A4B-it` | the file's levels |
| X-audio | framework | `role-split-audio-full.yaml`, knee [1,2,3,4,8] | `ggml-org/gemma-4-E4B-it-GGUF:Q8_0` | `google/gemma-4-E4B-it` | the file's levels |
| X-embed | framework | `role-split-embed.yaml`, concurrent [1,2,4,8,16] | `mrutkows/granite-embedding-english-r2-GGUF:BF16` | `ibm-granite/granite-embedding-english-r2` | the file's levels |
| B-target | gb10-1; gb10-2 | `role-split-mixed-agent.yaml`; `-vision`, `-audio`, `-embed` | gb10-1 `gpt-oss-120b-MXFP4-agent-only`; gb10-2 its 16-slot 26B-A4B and E4B and granite | as each section above | agent 4; vision 4, audio 4, embedding 16 |
| B-held | as B-target | as B-target | as B-target | as B-target | agent 4; vision 1, audio 1, embedding 16 |
| P-target | gb10-1; gb10-2; framework | as B-target, and `-vision`, `-audio`, `-embed` on the Framework | as B-target, and the Framework's three sections as in X-vision, X-audio, X-embed | as above | agent 4; on each capability host vision 2, audio 2, embedding 8 |
| P-held | as P-target | as P-target | as P-target | as P-target | agent 4; on each capability host vision 1, audio 1, embedding 8 |

Each mixed cell's processes start together, each host's from its own step file: four in B-target
and B-held, seven in P-target and P-held. For example, P-held's vision process on the Framework:

```sh
GUIDELLM__SPEC__PROFILE__STREAMS=1 cell framework-p-held-vision role-split-mixed-vision google/gemma-4-26B-A4B-it-qat-q4_0-gguf:Q4_0 google/gemma-4-26B-A4B-it
```

## Reading the results: `levels.jq`

[`levels.jq`](levels.jq) turns GuideLLM's result JSON into the findings' per-level tables, one
table a file, from the repository root:

```sh
jq -r --arg purpose agent -f bench/levels.jq .state/measure/gb10-2/role-split-f-agent.json
```

`purpose` is `agent`, `vision`, `audio` or `embed`, and sets the floor each level is judged by:
ITL median ≤100 ms, request latency median ≤10 s, RTFx median ≥5 (each request's clip seconds over
its request time), or mean prompt tok/s ≥4,300; a level with no successful request misses. Each
table starts with the knee GuideLLM concluded, when the profile reports one. Each row gives the
request latency's median, p90 and minimum, and, for `vision`, the count of requests at ≤10 s, as
it gives the count at RTFx ≥5 for audio: the per-request reading of the floor beside the median's
verdict. With `--arg purpose client`, it prints GuideLLM's own per-request timings for one level
instead (`--argjson level <i>`, default the first): the gap between requests, the time from
request start to the first streamed chunk, the streaming time, and the audio bytes. Medians and
percentiles interpolate linearly between the two nearest ranks.

## Reading the capacity cell: `capacity.jq` and `readouts.awk`

`levels.jq` reads the capacity cell (`agent-vllm-capacity.yaml`) as one level's medians.
[`capacity.jq`](capacity.jq) reads it a request at a time, in order of start: each request's
status, start from the first's, TTFT, latency, prompt tokens and output tokens against the
scenario's 256, then the counts, TTFT and latency medians and extremes, and the spread of the
starts. [`readouts.awk`](readouts.awk) reads the readouts `watch` printed every 30 s (a step's
output, or the measure log's lines for the cell): the highest running, waiting and KV cache usage,
and the preemptions between the first and last counters line, since vLLM counts from its start.

```sh
jq -r -f bench/capacity.jq .state/measure/gb10-1/agent-vllm-b-cap.json
awk -f bench/readouts.awk .state/agent-vllm/b-cap.out
```

## Reading the router log: `srvtimes.awk`

[`srvtimes.awk`](srvtimes.awk) reads llama-server's router log (`docker logs --timestamps llama`,
saved to a file) for one child port and prints each timed request's server figures: the audio
encode, prompt eval, eval and total, the time from the router's proxy line to the slot's start, and
the time from the previous request's release to the next proxy line. [`stats.awk`](stats.awk) gives each figure's count, median
(interpolated as `levels.jq` does), min and max:

```sh
awk -v port=<port> -f bench/srvtimes.awk <log> | sort -k1,1n -k3,3g | awk -f bench/stats.awk
```
