# Benchmark scenarios

GuideLLM 0.8.1 scenarios, one file a cell, run from the repository root by the step helpers'
`cell` ([`scripts/measure-lib.sh`](../scripts/measure-lib.sh)) under `watch`, from the bench
environment ([`mise.bench.toml`](../mise.bench.toml)). The scenarios are engine-neutral: `cell`
gives the section and its tokenizer on the command line, and sourcing the helpers for a host sets
the target in `GUIDELLM__SPEC__BACKEND__TARGET`. Each file's header gives its load.

- `anchor-a.yaml`, `anchor-b.yaml`: the anchors, copied from spike-model-engines.
- `footprint-*.yaml`: the footprint task's cells
  ([`docs/findings/footprint.md`](../docs/findings/footprint.md)).
- `role-split-*.yaml`: the role-split task's cells, below.

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

F-L2 reruns footprint's L2 unchanged, so it reads `footprint-l2.yaml` itself rather than a copy.

The full set's sweeps use levels 1, 2, 3, 4 and 8, and the split's 1, 4, 8, 12 and 16, each
through GuideLLM's knee profile with adaptive refinement off and no ramp-up.

### Streams in the mixed cells

Each mixed cell is four GuideLLM processes started together, one a purpose, each from its
`role-split-mixed-*.yaml` at a constant concurrency for 240 s. The mixed scenarios set no stream
count, so one file serves every mixed cell: each `cell` call gives its streams in
`GUIDELLM__SPEC__PROFILE__STREAMS`, which GuideLLM reads into the profile when the file leaves
`streams` out (a value in the file would win over the variable). F-mixed and S-mixed take the load
targets, agent 4, vision 4, audio 4 and embedding 16; S-knee takes each purpose's split knee from
S-agent, S-vision and S-audio, and granite 16. For example, F-mixed's agent process on gb10-2:

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
ffmpeg -nostdin -hide_banner -n -i ~/docs/audio/long/ami-es2002a-mix-headset.wav -t 600 \
  -ac 1 -ar 16000 -c:a pcm_s16le .state/role-split/ami-es2002a-first10min.wav
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
