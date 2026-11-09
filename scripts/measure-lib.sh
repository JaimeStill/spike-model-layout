#!/usr/bin/env bash
# Copied from spike-hosting-upgrades (2e64fe5), where measure.md and rules.md are its skill's files;
# this spike's hosts task adapts it to the layout's runs.
# The measure mode's step helpers (measure.md, "Step helpers"), sourced from the project root, one
# host a shell, and called one step at a time in the architect's view:
#
#   source scripts/measure-lib.sh <host> [<port>]
#
# Sourcing only defines the helpers and starts the command log: it creates
# .state/measure/<host>/, appends xtrace's lines to .state/measure/<host>/<YYYY-MM-DD>.log
# (BASH_XTRACEFD, with PS4 '+ <ISO time> <helper>: '), and turns xtrace on in the calling shell,
# so every command after it, the caller's own and each helper's, is logged with its time and the
# helper it ran in. What a helper prints to standard output lands in the same log as well, each
# line as the terminal shows it after '= <ISO time> <helper>: ' (the helper the caller called), so
# the record quotes a load's time, a cell's figures and a readout from the log. The record's
# "Commands as run" quotes that log. A poll or a sampling loop logs one line saying what it does,
# not each pass. `set +x` stops the log, printed results included; sourcing resumes it.
#
# MEASURE_LOG=off, set for the `source` line, sources the helpers read-only: no log, no xtrace,
# nothing appended, for reading a finished run (`summarize`, `loaded`, `memory`, `readout`,
# `routing`, `image`) without adding to the day's log. The helpers that load the host (load,
# unload, watch, cell, tier, conform, gate) refuse there.
#
# No helper runs a benchmark on its own or chains cells: `cell` runs one GuideLLM scenario, `tier`
# one agent tier, `conform` one conform run, each under `watch`, and `gate` only loads and unloads.
# The helpers that change the host (load, unload, gate) do so only through the router's API.
#
#   loaded                          the sections the router has loaded or loading
#   load <section>                  load one section, wait until loaded, print its time and args
#   unload <section>|--all          unload one section (or every loaded one), wait until unloaded
#   cell <name> <scenario> [<section> <tokenizer>]
#                                   one GuideLLM cell from bench/<scenario>.yaml, under watch
#   tier <name> <bfcl-single|bfcl-multi> <section> [<first N>]
#                                   one spike-model-hosting BFCL tier, under watch
#   conform <name> <class> [<k>]    one conform run through Pi, under watch
#   summarize <name>                a result's figures: a cell's, a tier's, and its watch's
#   memory                          one memory read-out on the host, and the floor
#   routing                         rules.md's routing check: the host's .lan records, what the bare
#                                   name resolves to, and 50 connects to the router's /health
#   readout [<since>]               the router's log since a time (default 5 minutes ago), and memory
#   watch <name> <command...>       run one command with GPU clocks and memory sampled, readouts
#                                   at an interval, and the run stopped under the memory floor
#   image <class> <build>           whether the class's engine image exists for a build (ghcr.io)
#   gate                            the build gate's loads: every preset section, one at a time
#
# Settings, each an environment variable read when a helper runs:
#   MEASURE_FLOOR_GIB      the memory floor (required by watch): the policy's headroom on the
#                          probed ceiling, e.g. 12.2 on gb10-1, 11.2 on framework
#   MEASURE_SAMPLE_EVERY   seconds between watch's samples (default 10)
#   MEASURE_READOUT_EVERY  seconds between watch's readouts (default 300)
#   MEASURE_CELL_CAP       a cell's cap (default 10m); MEASURE_TIER_CAP a tier's (default 15m);
#                          MEASURE_CONFORM_CAP conform's (default 10m)
#   MEASURE_LOAD_WAIT      seconds a load or unload may take (default 600)
#   MEASURE_HOSTING        spike-model-hosting's checkout (default ~/experiments/spike-model-hosting)
#   MEASURE_CONTAINER      the engine's container on the host (default llama)

if ! (return 0 2>/dev/null); then
  echo 'measure-lib.sh is sourced, not run: source it with a host' >&2
  exit 2
fi
if [[ -z ${1-} || $1 == -* ]]; then
  echo 'usage: source scripts/measure-lib.sh <host> [<port>]' >&2
  return 2
fi

MEASURE_HOST=$1
MEASURE_PORT=${2:-8080}
MEASURE_URL=http://$1:$MEASURE_PORT
MEASURE_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)
MEASURE_STATE=$MEASURE_ROOT/.state/measure/$MEASURE_HOST
MEASURE_LOG_FILE=$MEASURE_STATE/$(date +%F).log
export GUIDELLM__SPEC__BACKEND__TARGET=$MEASURE_URL

# The flags a loaded instance's arguments print, which name how the section serves (slots,
# context, the prompt cache and its checkpoints).
_MEASURE_ARGS='--(ctx-size|parallel|cache-ram|swa-checkpoints|ctx-checkpoints|checkpoint-min-step) [0-9]+|--(no-)?cache-idle-slots|--(no-)?kv-unified'

# One sample on the host, one line: the memory available to the GPU in MiB and where it is read
# (GTT free on an amdgpu card, MemAvailable otherwise), then the GPU's clocks and limits:
# nvidia-smi's SM clock, its maximum, the active throttle reasons (a bitmask; 0x0 is none),
# temperature, power and utilization on a GB10; amdgpu's current sclk level, busy percent, edge
# temperature and power on a Strix Halo. It reads only what an unprivileged user can.
# The script runs on the host, so its expansions are meant to stay unexpanded here.
# shellcheck disable=SC2016
_MEASURE_SAMPLE='
avail=$(awk "/^MemAvailable/{print int(\$2/1024)}" /proc/meminfo); src=MemAvailable; gpu=
for d in /sys/class/drm/card*/device; do
  [ -r "$d/mem_info_gtt_total" ] || continue
  avail=$(( ($(cat "$d/mem_info_gtt_total") - $(cat "$d/mem_info_gtt_used")) / 1048576 )); src=GTT
  h=$(ls -d "$d"/hwmon/hwmon* 2>/dev/null | head -n 1)
  p=$(cat "$h/power1_average" 2>/dev/null || cat "$h/power1_input" 2>/dev/null)
  gpu="sclk $(awk "/\\*/{print \$2}" "$d/pp_dpm_sclk" 2>/dev/null), busy $(cat "$d/gpu_busy_percent" 2>/dev/null)%, edge $(( $(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000 )) C, power $(( ${p:-0} / 1000000 )) W"
  break
done
if command -v nvidia-smi >/dev/null; then
  gpu=$(nvidia-smi --query-gpu=clocks.sm,clocks.max.sm,clocks_throttle_reasons.active,temperature.gpu,power.draw,utilization.gpu --format=csv,noheader 2>&1 | head -n 1)
  gpu="sm, max sm, throttle, temp, power, util: $gpu"
fi
printf "%s\t%s\t%s\n" "$avail" "$src" "${gpu:-no GPU read}"
'

# Turns xtrace off for a poll or a sampling loop, leaving one traced line that says what it does;
# _measure_trace_on turns it back on if it was.
_measure_quiet() {
  : "$@"
  _measure_was_tracing=${-//[^x]/}
  { set +x; } 2>/dev/null
}
_measure_trace_on() {
  [[ -n ${_measure_was_tracing-} ]] && set -x
  return 0
}

# Every helper opens with the same case on the shell's flags and _measure_marking, so that what
# it prints lands in the log once, under the outermost helper's name:
#   *x*:   the log is on and no helper is marking: run the helper again under _measure_marked,
#          in a pipe's subshell (no helper sets state its caller reads);
#   *:on   that rerun, entered with xtrace off: mark it inside, turn xtrace back on, and go on;
#   *:off  (the helpers that load the host) sourced with MEASURE_LOG=off: refuse;
#   other  a helper inside a marked one, or the log stopped: just run.
# Of the marking, the log holds the case's first line, _measure_marked's call and its two lines,
# and the helper's return; _measure_lines runs untraced. `local -` turns xtrace back on when
# _measure_marked returns, an interrupt included.
_measure_marked() {
  local - _measure_marking=on
  set +x
  "$@" | _measure_lines "$1"
  return "${PIPESTATUS[0]}"
}

# Copies its input to standard output unchanged, and each non-empty line to the log after
# '= <ISO time> <helper>: ', through the xtrace descriptor, so it sits among the commands in order.
_measure_lines() {
  local line t nl
  while :; do
    nl=$'\n'
    IFS= read -r line || { [[ -n $line ]] || break; nl=; }
    printf '%s%s' "$line" "$nl"
    if [[ -n $line ]]; then
      printf -v t '%(%FT%T%z)T' -1
      printf '= %s %s: %s\n' "${t:0:-2}:${t: -2}" "$1" "$line" >&"$MEASURE_XTRACE_FD"
    fi
    [[ -n $nl ]] || break
  done
}

_measure_refuse() {
  echo "$1: refused, the helpers are sourced read-only (MEASURE_LOG=off); source them without it" >&2
  return 2
}

# Prints a section's status by the router's /models: loaded, loading, unloaded, or failed.
_measure_status() {
  curl -s --max-time 10 "$MEASURE_URL/models" |
    jq -r --arg m "$1" '.data[] | select(.id == $m) | .status | if .failed then "failed" else .value end'
}

# Waits until a section reaches a status, polling every 3 s; returns 1 on a failed load or after
# MEASURE_LOAD_WAIT seconds.
_measure_wait() {
  local section=$1 want=$2 i s
  _measure_quiet "polling $MEASURE_URL/models every 3 s until $section is $want"
  for ((i = 0; i < ${MEASURE_LOAD_WAIT:-600}; i += 3)); do
    s=$(_measure_status "$section")
    if [[ $s == "$want" ]]; then
      _measure_trace_on
      return 0
    fi
    if [[ $s == failed && $want == loaded ]]; then
      echo "load failed: $section" >&2
      _measure_trace_on
      return 1
    fi
    sleep 3
  done
  echo "timeout: $section not $want after ${MEASURE_LOAD_WAIT:-600} s (status ${s:-none})" >&2
  _measure_trace_on
  return 1
}

loaded() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked loaded; return ;;
    *:on) _measure_marking=in; set -x ;;
  esac
  curl -s --max-time 10 "$MEASURE_URL/models" |
    jq -c '[.data[] | select(.status.value != "unloaded") | {id, status: .status.value}]'
}

load() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked load "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
    *:off) _measure_refuse load; return ;;
  esac
  local section=${1:?usage: load <section>} t0 rc
  t0=$(date +%s%N)
  curl -s --max-time 30 -X POST "$MEASURE_URL/models/load" -H 'Content-Type: application/json' \
    -d "$(jq -cn --arg m "$section" '{model: $m}')"
  echo
  _measure_wait "$section" loaded
  rc=$?
  printf 'load %s: %s in %.1f s\n' "$section" "$([[ $rc == 0 ]] && echo loaded || echo FAILED)" \
    "$(($(date +%s%N) - t0))e-9"
  curl -s --max-time 10 "$MEASURE_URL/models" |
    jq -r --arg m "$section" '.data[] | select(.id == $m) | .status.args // [] | join(" ")' |
    grep -oE -- "$_MEASURE_ARGS" | paste -sd' ' | sed 's/^/args: /'
  return "$rc"
}

unload() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked unload "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
    *:off) _measure_refuse unload; return ;;
  esac
  local section=${1:?usage: unload <section>|--all} s rc=0
  if [[ $section == --all ]]; then
    for s in $(curl -s --max-time 10 "$MEASURE_URL/models" |
      jq -r '.data[] | select(.status.value != "unloaded") | .id'); do
      unload "$s" || rc=1
    done
    return "$rc"
  fi
  curl -s --max-time 30 -X POST "$MEASURE_URL/models/unload" -H 'Content-Type: application/json' \
    -d "$(jq -cn --arg m "$section" '{model: $m}')"
  echo
  _measure_wait "$section" unloaded
}

memory() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked memory; return ;;
    *:on) _measure_marking=in; set -x ;;
  esac
  local line avail src
  line=$(ssh "$MEASURE_HOST" bash -s <<<"$_MEASURE_SAMPLE") || return 1
  IFS=$'\t' read -r avail src _ <<<"$line"
  awk -v h="$MEASURE_HOST" -v a="$avail" -v s="$src" \
    'BEGIN { printf "memory %s: %.2f GiB available (%s)", h, a / 1024, s }'
  if [[ -n ${MEASURE_FLOOR_GIB-} ]]; then
    printf ', floor %s GiB' "$MEASURE_FLOOR_GIB"
  fi
  echo
}

# rules.md's routing check, its three commands as rules.md gives them, for this host and port.
# The 50 connects log one line, not one each.
routing() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked routing; return ;;
    *:on) _measure_marking=in; set -x ;;
  esac
  local h=$MEASURE_HOST t ty i a
  for ty in A AAAA; do echo "$h.lan $ty: $(resolvectl query -t "$ty" "$h.lan" >/dev/null 2>&1 && echo PRESENT || echo none)"; done
  # The host's tailnet addresses stay out of the log, which a record quotes (STANDARDS.md rules
  # out committing tailnet identifiers): the lookup and its comparisons run untraced, and only
  # their labels print.
  _measure_quiet "matching the bare name against the host's tailnet addresses"
  t=$(tailscale ip "$h"); echo "bare name: $(getent ahosts "$h" | cut -d' ' -f1 | sort -u | while read -r a; do echo "$t" | grep -qxF "$a" && echo tailnet || echo NOT-TAILNET; done | paste -sd' ')"
  _measure_trace_on
  _measure_quiet "connecting to http://$h:$MEASURE_PORT/health 50 times"
  for i in $(seq 1 50); do curl -s -o /dev/null -w '%{time_connect} %{exitcode}\n' --connect-timeout 5 "http://$h:$MEASURE_PORT/health"; done | awk '{n++; if($NF!=0)f++; else {if($(NF-1)>0.05)s++; if($(NF-1)>m)m=$(NF-1)}} END{print n" connects, "f+0" failed, "s+0" over 50 ms, max "m+0" s"}'
  _measure_trace_on
}

readout() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked readout "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
  esac
  local since=${1:-$(date -u -d '-5 min' +%FT%TZ)} log
  log=$(mktemp)
  ssh "$MEASURE_HOST" docker logs --since "$since" "${MEASURE_CONTAINER:-llama}" >"$log" 2>&1
  printf 'readout since %s: idle-slot saves %s, prompt saves %s, checkpoints %s, ' "$since" \
    "$(grep -c 'saving idle slot' "$log")" "$(grep -c 'prompt_save:  - saving' "$log")" \
    "$(grep -c 'created context checkpoint' "$log")"
  # The decode rate of replies of 90 tokens or more, from the router's per-request timings.
  grep 'eval time' "$log" | grep -v 'prompt eval' |
    sed -E 's/.*= +([0-9.]+) ms \/ +([0-9]+) (tokens|runs).*\( *([0-9.]+) ms per token, +([0-9.]+) tokens per second.*/\2 \5/' |
    awk '$1 >= 90 { n++; s += $2; if (n == 1 || $2 < mn) mn = $2; if ($2 > mx) mx = $2 }
      END { if (n) printf "replies >=90 tokens: n %d, mean %.1f, min %.1f, max %.1f tok/s\n", n, s / n, mn, mx
            else print "replies >=90 tokens: none" }'
  rm -f "$log"
  memory
}

# Kills a process and every descendant, deepest first.
_measure_kill_tree() {
  local c
  for c in $(pgrep -P "$1"); do _measure_kill_tree "$c"; done
  kill "$1" 2>/dev/null
}

watch() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked watch "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
    *:off) _measure_refuse watch; return ;;
  esac
  local name=${1:?usage: watch <name> <command...>} floor_mib pid rc t0 next line avail stopped=
  shift
  (($#)) || { echo 'usage: watch <name> <command...>' >&2; return 2; }
  if [[ -z ${MEASURE_FLOOR_GIB-} ]]; then
    echo 'watch: set MEASURE_FLOOR_GIB to the policy headroom on the probed ceiling first' >&2
    return 2
  fi
  floor_mib=$(awk -v g="$MEASURE_FLOOR_GIB" 'BEGIN { printf "%d", g * 1024 }')
  t0=$(date -u +%FT%TZ)
  printf 'time\tavailable MiB\tread\tgpu\n' >"$MEASURE_STATE/$name.watch.tsv"
  "$@" >"$MEASURE_STATE/$name.log" 2>&1 &
  pid=$!
  _measure_quiet "sampling $MEASURE_HOST every ${MEASURE_SAMPLE_EVERY:-10} s into $name.watch.tsv" \
    "(ssh $MEASURE_HOST bash -s <<< \$_MEASURE_SAMPLE), readout every" \
    "${MEASURE_READOUT_EVERY:-300} s, stop under $MEASURE_FLOOR_GIB GiB; output in $name.log"
  next=$(($(date +%s) + ${MEASURE_READOUT_EVERY:-300}))
  while kill -0 "$pid" 2>/dev/null; do
    sleep "${MEASURE_SAMPLE_EVERY:-10}"
    line=$(ssh "$MEASURE_HOST" bash -s <<<"$_MEASURE_SAMPLE" 2>/dev/null) || continue
    printf '%s\t%s\n' "$(date -u +%T)" "$line" >>"$MEASURE_STATE/$name.watch.tsv"
    avail=${line%%$'\t'*}
    if [[ $avail =~ ^[0-9]+$ ]] && ((avail < floor_mib)); then
      stopped="memory floor: ${avail} MiB available under $MEASURE_FLOOR_GIB GiB at $(date -u +%T)"
      echo "$stopped; stopping $name"
      _measure_kill_tree "$pid"
      break
    fi
    if (($(date +%s) >= next)) && kill -0 "$pid" 2>/dev/null; then
      readout "$(date -u -d "-${MEASURE_READOUT_EVERY:-300} sec" +%FT%TZ)"
      next=$(($(date +%s) + ${MEASURE_READOUT_EVERY:-300}))
    fi
  done
  wait "$pid"
  rc=$?
  _measure_trace_on
  case $rc in
    0) echo "exit 0" ;;
    124) echo "exit 124: cap hit" ;;
    *) echo "exit $rc${stopped:+: $stopped}" ;;
  esac
  echo "$rc${stopped:+ $stopped}" >"$MEASURE_STATE/$name.exit"
  echo "whole run:"
  readout "$t0"
  return "$rc"
}

cell() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked cell "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
    *:off) _measure_refuse cell; return ;;
  esac
  local name=${1:?usage: cell <name> <scenario> [<section> <tokenizer>]} scenario=${2:?usage: cell <name> <scenario> [<section> <tokenizer>]}
  local -a model=()
  if [[ -e $MEASURE_STATE/$name.json ]]; then
    echo "cell: $name.json exists; name each cell once (a rerun takes a new name)" >&2
    return 2
  fi
  if [[ -n ${3-} ]]; then
    model=(--backend "kind=openai_http,model=$3" --tokenizer "kind=huggingface_auto,model=${4:?cell: a section needs its tokenizer}")
  fi
  watch "$name" env -C "$MEASURE_ROOT" MISE_ENV=bench timeout "${MEASURE_CELL_CAP:-10m}" \
    mise exec -- guidellm run -c "bench/$scenario.yaml" "${model[@]}" \
    --output "kind=json,path=$MEASURE_STATE/$name.json"
  local rc=$?
  summarize "$name"
  return "$rc"
}

tier() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked tier "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
    *:off) _measure_refuse tier; return ;;
  esac
  local name=${1:?usage: tier <name> <bfcl-single|bfcl-multi> <section> [<first N>]} which=${2-} section=${3-} first=${4-}
  local hosting=${MEASURE_HOSTING:-$HOME/experiments/spike-model-hosting} list
  [[ $which == bfcl-single || $which == bfcl-multi ]] && [[ -n $section ]] ||
    { echo 'usage: tier <name> <bfcl-single|bfcl-multi> <section> [<first N>]' >&2; return 2; }
  list=$hosting/evaluation/tiers/agent-$which.txt
  if [[ -n $first ]]; then
    # The tier's list cut to its first N samples, with its header (tier, dataset, seed) kept.
    { grep '^#' "$list"; grep -v '^#' "$list" | head -n "$first"; } >"$MEASURE_STATE/$name-list.txt"
    list=$MEASURE_STATE/$name-list.txt
  fi
  watch "$name" env -C "$hosting/evaluation" PYTHONDONTWRITEBYTECODE=1 \
    UV_PROJECT_ENVIRONMENT="$MEASURE_STATE/../suites-venv" HF_HOME="$MEASURE_STATE/../cache/huggingface" \
    INSPECT_EVALS_CACHE_DIR="$MEASURE_STATE/../cache/inspect_evals" MISE_ENV=consumers \
    timeout "${MEASURE_TIER_CAP:-15m}" mise exec -- uv run --project suites --locked --no-python-downloads \
    python suites/agent_quality.py eval --router "$MEASURE_URL" --model "$section" --tier "$which" \
    --list "$list" --slots 4 --output "$MEASURE_STATE/$name"
  local rc=$?
  summarize "$name"
  return "$rc"
}

conform() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked conform "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
    *:off) _measure_refuse conform; return ;;
  esac
  local name=${1:?usage: conform <name> <class> [<k>]} class=${2:?usage: conform <name> <class> [<k>]}
  local hosting=${MEASURE_HOSTING:-$HOME/experiments/spike-model-hosting}
  watch "$name" env -C "$hosting/evaluation" MISE_ENV=consumers timeout "${MEASURE_CONFORM_CAP:-10m}" \
    mise exec -- go run ./cmd/evaluate conform -router "$MEASURE_URL" \
    -profile "$MEASURE_ROOT/bench/conform/$class.toml" -consumers pi -k "${3:-5}" -state "$MEASURE_STATE/$name"
  local rc=$?
  tail -n 8 "$MEASURE_STATE/$name.log"
  return "$rc"
}

summarize() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked summarize "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
  esac
  local name=${1:?usage: summarize <name>} f
  _measure_quiet "summarizing $name"
  if [[ -f $MEASURE_STATE/$name.json ]]; then
    # A GuideLLM cell, one line a benchmark (a sweep level). "completed" is the completed-request
    # figure, GuideLLM's successful mean: the output tokens of the requests that finished, over
    # the benchmark's time. "every-token" is its total mean: every token generated, by the
    # requests that finished and by those still in flight at the cutoff. "full" checks the
    # scenario's max_requests against the successful count.
    jq -r '.benchmarks[] | .metrics as $m | .config as $c
      | ($c.constraints.max_requests.args.count // null) as $want
      | "\($c.strategy.streams) stream(s): requests ok \($m.request_totals.successful), errored \($m.request_totals.errored), incomplete \($m.request_totals.incomplete) of \($m.request_totals.total)"
        + (if $want then ", full \(if $m.request_totals.successful == $want then "yes" else "NO (\($want) wanted)" end)" else "" end)
        + "; output tok/s completed \($m.output_tokens_per_second.successful.mean * 100 | round / 100), every-token \($m.output_tokens_per_second.total.mean * 100 | round / 100)"
        + "; TTFT median \($m.time_to_first_token_ms.successful.median | round) ms; ITL median \($m.inter_token_latency_ms.successful.median * 100 | round / 100) ms"
        + (($m.audio.seconds.input_per_second.successful.mean // 0) as $a | if $a > 0 then "; audio s/s \($a * 100 | round / 100)" else "" end)' \
      "$MEASURE_STATE/$name.json"
  fi
  # Inspect names its log by time and a random id, letters and digits only, so ls reads it safely.
  # shellcheck disable=SC2012
  f=$(ls -t "$MEASURE_STATE/$name"/*.json 2>/dev/null | head -n 1)
  if [[ -n $f ]]; then
    # An Inspect log (a BFCL tier): samples done and passing, the sample times, the largest
    # reply, and the replies that stopped at a token or context limit (cap hits).
    jq -r '[.samples[]?] as $s
      | [$s[] | .events[]? | select(.event == "model") | {id: null, out: (.output.usage.output_tokens // 0), stop: (.output.choices[0].stop_reason // "")}] as $calls
      | ([$s[] | . as $x | [.events[]? | select(.event == "model") | .output.usage.output_tokens // 0] | {id: $x.id, out: (max // 0)}] | max_by(.out)) as $big
      | "status \(.status); samples done \($s | length), passing \([$s[] | select((.scores | to_entries[0].value.value) == 1)] | length)"
        + "; sample secs \([$s[] | .total_time | floor])"
        + "; largest reply \($big.out // 0) tokens (\($big.id // "-"))"
        + "; cap hits (stop max_tokens or model_length) \([$calls[] | select(.stop == "max_tokens" or .stop == "model_length")] | length)"' "$f"
  fi
  if [[ -f $MEASURE_STATE/$name.exit ]]; then
    echo "exit: $(cat "$MEASURE_STATE/$name.exit")"
  fi
  if [[ -f $MEASURE_STATE/$name.watch.tsv ]]; then
    awk -F'\t' 'NR > 1 { n++; if (n == 1 || $2 < mn) { mn = $2; at = $1 }; src = $3; g[$4]++ }
      END { if (!n) { print "watch: no samples"; exit }
            printf "watch: %d samples, lowest available %.2f GiB (%s) at %s\n", n, mn / 1024, src, at }' \
      "$MEASURE_STATE/$name.watch.tsv"
    # The GPU readings, clocks and throttle reasons, each distinct reading with its count.
    tail -n +2 "$MEASURE_STATE/$name.watch.tsv" | cut -f4 | sort | uniq -c | sort -rn | head -n 8 |
      sed 's/^/  gpu /'
  fi
  _measure_trace_on
}

image() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked image "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
  esac
  local class=${1:?usage: image <gb10|strix-halo> <build>} build=${2:?usage: image <gb10|strix-halo> <build>} flavor token
  case $class in
    gb10) flavor=cuda13 ;;
    strix-halo) flavor=vulkan ;;
    *) echo "image: class $class is none of gb10, strix-halo" >&2; return 2 ;;
  esac
  # The registry's manifest check: an anonymous pull token, as fix-in-image.sh takes, then a HEAD
  # of the tag's manifest, 200 for a published image and 404 for none.
  token=$(curl -q -fsS --max-time 30 --proto =https \
    "https://ghcr.io/token?scope=repository:ggml-org/llama.cpp:pull" |
    sed -n 's/.*"token":"\([^"]*\)".*/\1/p')
  [[ -n $token ]] || { echo 'image: ghcr.io gives no pull token' >&2; return 1; }
  case $(curl -q -sS -o /dev/null -w '%{http_code}' --head --max-time 30 --proto =https \
    -H "Authorization: Bearer $token" \
    -H 'Accept: application/vnd.oci.image.index.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.oci.image.manifest.v1+json' \
    "https://ghcr.io/v2/ggml-org/llama.cpp/manifests/server-$flavor-$build") in
    200) echo "image: ghcr.io/ggml-org/llama.cpp:server-$flavor-$build exists" ;;
    404) echo "image: ghcr.io/ggml-org/llama.cpp:server-$flavor-$build NOT FOUND"; return 1 ;;
    *) echo "image: server-$flavor-$build can't be read" >&2; return 1 ;;
  esac
}

gate() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked gate; return ;;
    *:on) _measure_marking=in; set -x ;;
    *:off) _measure_refuse gate; return ;;
  esac
  local s rc=0
  local -a sections
  mapfile -t sections < <(curl -s --max-time 10 "$MEASURE_URL/models" | jq -r '.data[].id')
  ((${#sections[@]})) || { echo 'gate: the router lists no section' >&2; return 1; }
  echo "gate: ${#sections[@]} sections, each loaded alone"
  unload --all || return 1
  for s in "${sections[@]}"; do
    if ! load "$s"; then
      echo "gate: FAILED on $s; roll back now (measure.md, \"Build gate\")"
      rc=1
      break
    fi
    unload "$s" || { rc=1; break; }
  done
  ((rc == 0)) && echo 'gate: every section loaded'
  return "$rc"
}

# In an interactive shell, the prompt's hooks (PROMPT_COMMAND's entries and the functions they
# call, PS0's command substitutions) would otherwise run traced after every command, a hundred
# lines of them a prompt. _measure_prompt_hooks puts `set +x` first in PROMPT_COMMAND, its one
# line the only one the prompt logs, and _MEASURE_ARM last, which sets a DEBUG trap, after any
# DEBUG trap already set, for the first command of the next line typed. PS0, which bash expands
# only for a line with a command, marks that line (_measure_typed, set by an arithmetic expansion
# in the shell itself, as starship sets its start time), so the trap does nothing for the prompt's
# own hooks after an empty line. On the line's first command the trap puts the earlier trap back
# and _measure_resume turns xtrace on again while the log is on (_measure_logging). The prompt
# can't tell whether the line before it ended with xtrace off, so the log's state is the flag's:
# sourcing sets it, MEASURE_LOG=off clears it, and a line that starts with `set +x` or `set -x`
# stops or resumes it, as the same command does in a non-interactive shell.
#
# Both traps are set at the top level, not in a function: a function (without functrace) neither
# sees the DEBUG trap set outside it nor keeps one it sets over one that was.
# shellcheck disable=SC2016
_MEASURE_ARM='_measure_arm "$(trap -p DEBUG)" && trap -- "$_measure_trap" DEBUG'
_measure_prompt_hooks() {
  local pc
  pc=$(declare -p PROMPT_COMMAND 2>/dev/null)
  # PROMPT_COMMAND is an array (bash 5.1+, as starship sets it) or a string; the elif is the string.
  # shellcheck disable=SC2128,SC2178
  if [[ $pc == 'declare -a'* ]]; then
    [[ ${PROMPT_COMMAND[0]} == 'set +x' ]] || PROMPT_COMMAND=('set +x' "${PROMPT_COMMAND[@]}")
    [[ ${PROMPT_COMMAND[-1]} == "$_MEASURE_ARM" ]] || PROMPT_COMMAND+=("$_MEASURE_ARM")
  elif [[ $PROMPT_COMMAND != 'set +x'$'\n'* ]]; then
    PROMPT_COMMAND="set +x${PROMPT_COMMAND:+$'\n'$PROMPT_COMMAND}"$'\n'$_MEASURE_ARM
  fi
  # Expands to nothing; PS0 is never empty once this is in it, so the offset is evaluated.
  # shellcheck disable=SC2016
  [[ $PS0 == *_measure_typed* ]] || PS0+='${PS0:$((_measure_typed=1,0)):0}'
}
# Given `trap -p DEBUG`, sets _measure_trap to the trap _MEASURE_ARM sets, or returns 1 when it is
# still set (after an empty line).
_measure_arm() {
  local restore='trap - DEBUG'
  _measure_typed=
  [[ $1 != *_measure_resume* ]] || return 1
  # trap -p prints `trap -- '<command>' DEBUG`; set -- takes its words apart in this function only.
  eval "set -- $1"
  [[ -z ${3-} ]] || printf -v restore 'trap -- %q DEBUG' "$3"
  # It returns 0 either way: under extdebug a DEBUG trap that returns nonzero skips the command.
  _measure_trap="${3:+$3$'\n'}if [[ -n \$_measure_typed ]]; then $restore; _measure_resume; fi"
}
_measure_resume() {
  case $BASH_COMMAND in
    'set +x'*) _measure_logging= ;;
    'set -x'*) _measure_logging=on ;;
  esac
  # Last, so nothing after it is traced; a `set +x` is traced, so the log shows where it stopped.
  if [[ -n $_measure_logging || $BASH_COMMAND == 'set +x'* ]]; then set -x; fi
}

if [[ ${MEASURE_LOG-} == off ]]; then
  # Read-only: no log, and xtrace off if an earlier sourcing in this shell turned it on.
  _measure_logging=
  _measure_marking=off
  { set +x; } 2>/dev/null
  return 0
fi
unset _measure_marking
_measure_logging=on
[[ $- != *i* ]] || _measure_prompt_hooks
mkdir -p "$MEASURE_STATE"
exec {MEASURE_XTRACE_FD}>>"$MEASURE_LOG_FILE"
BASH_XTRACEFD=$MEASURE_XTRACE_FD
# Each line: its time, then the helper it ran inside (none for a command the caller typed).
# shellcheck disable=SC2016
PS4='+ $(date -Is) ${FUNCNAME[0]:+${FUNCNAME[0]}: }'
set -x
: "measure log for $MEASURE_HOST ($MEASURE_URL), project $MEASURE_ROOT"
