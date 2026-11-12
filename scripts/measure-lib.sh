#!/usr/bin/env bash
# Copied from spike-hosting-upgrades (2e64fe5) and adapted by this spike's hosts task: its root is
# this repository, and tier and conform are dropped, since this spike runs no BFCL tier or conform
# run. measure.md and rules.md, cited below, are spike-hosting-upgrades' files (its measure skill's),
# not this repository's.
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
# `footprint`, `routing`, `image`) without adding to the day's log. The helpers that load the host
# (load, unload, watch, cell, gate) refuse there.
#
# No helper runs a benchmark on its own or chains cells: `cell` runs one GuideLLM scenario under
# `watch`, and `gate` only loads and unloads.
# The helpers that change the host (load, unload, gate) do so only through the router's API.
#
#   loaded                          the sections the router has loaded or loading
#   load <section>                  load one section, wait until loaded, print its time and args
#   unload <section>|--all          unload one section (or every loaded one), wait until unloaded
#   cell <name> <scenario> [<section> <tokenizer>]
#                                   one GuideLLM cell from bench/<scenario>.yaml, under watch
#   summarize <name>                a result's figures: a cell's and its watch's
#   memory                          one memory read-out on the host, and the floor (on an amdgpu
#                                   host, GTT and system memory, each with its floor)
#   routing                         rules.md's routing check: the host's .lan records, what the bare
#                                   name resolves to, and 50 connects to the router's /health
#   readout [<since>]               the router's log since a time (default 5 minutes ago), and memory;
#                                   on vLLM, its /metrics and its log's errors since the time
#   footprint [<since>]             each llama-server's GPU memory and RSS by alias, the pool, and
#                                   the load lines that size its buffers (default 10 minutes ago);
#                                   on vLLM, the container's processes (on an amdgpu host each
#                                   one's GTT and RSS), the pool (GTT and system memory there), and
#                                   the start log's sizing lines (default since the container's
#                                   start)
#   watch <name> <command...>       run one command with GPU clocks and memory sampled, readouts
#                                   at an interval, and the run stopped under the memory floor (on
#                                   an amdgpu host, under either the GTT or the system floor)
#   image <class> <build>           whether the class's engine image exists for a build (ghcr.io)
#   gate                            the build gate's loads: every preset section, one at a time
#
# Settings, each an environment variable read when a helper runs:
#   MEASURE_FLOOR_GIB      the memory floor (required by watch): the policy's headroom on the
#                          probed ceiling, e.g. 12.2 on gb10-1, 11.2 on framework (GTT there)
#   MEASURE_SYSTEM_FLOOR_GIB  the system-memory floor on an amdgpu host (required by watch there):
#                          llama.cpp's host prompt cache sits in system memory outside GTT, which
#                          the GTT floor can't see (footprint finding), e.g. 12.5 on framework
#                          (10% of its 128,075 MiB)
#   MEASURE_SAMPLE_EVERY   seconds between watch's samples (default 10)
#   MEASURE_READOUT_EVERY  seconds between watch's readouts (default 300)
#   MEASURE_CELL_CAP       a cell's cap (default 10m)
#   MEASURE_LOAD_WAIT      seconds a load or unload may take (default 600)
#   MEASURE_ENGINE         the engine the port serves, llama or vllm: readout and footprint read
#                          it (default vllm on ports 8000, 8001 and 8002, vLLM's, and llama on any
#                          other)
#   MEASURE_CONTAINER      the engine's container on the host (default llama for llama.cpp, and
#                          for vLLM the container that publishes the port, read on the host, or
#                          vllm on port 8000 when none does)

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
MEASURE_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
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
# temperature and power on a Strix Halo. On an amdgpu card a fourth field follows, system
# MemAvailable in MiB, the pool the GPU's GTT doesn't cover; a GB10's line has three fields, its
# first already MemAvailable. It reads only what an unprivileged user can.
# The script runs on the host, so its expansions are meant to stay unexpanded here.
# shellcheck disable=SC2016
_MEASURE_SAMPLE='
mem=$(awk "/^MemAvailable/{print int(\$2/1024)}" /proc/meminfo); avail=$mem; src=MemAvailable; sys=; gpu=
for d in /sys/class/drm/card*/device; do
  [ -r "$d/mem_info_gtt_total" ] || continue
  avail=$(( ($(cat "$d/mem_info_gtt_total") - $(cat "$d/mem_info_gtt_used")) / 1048576 )); src=GTT; sys=$mem
  h=$(ls -d "$d"/hwmon/hwmon* 2>/dev/null | head -n 1)
  p=$(cat "$h/power1_average" 2>/dev/null || cat "$h/power1_input" 2>/dev/null)
  gpu="sclk $(awk "/\\*/{print \$2}" "$d/pp_dpm_sclk" 2>/dev/null), busy $(cat "$d/gpu_busy_percent" 2>/dev/null)%, edge $(( $(cat "$h/temp1_input" 2>/dev/null || echo 0) / 1000 )) C, power $(( ${p:-0} / 1000000 )) W"
  break
done
if command -v nvidia-smi >/dev/null; then
  gpu=$(nvidia-smi --query-gpu=clocks.sm,clocks.max.sm,clocks_throttle_reasons.active,temperature.gpu,power.draw,utilization.gpu --format=csv,noheader 2>&1 | head -n 1)
  gpu="sm, max sm, throttle, temp, power, util: $gpu"
fi
if [ -n "$sys" ]; then
  printf "%s\t%s\t%s\t%s\n" "$avail" "$src" "${gpu:-no GPU read}" "$sys"
else
  printf "%s\t%s\t%s\n" "$avail" "$src" "${gpu:-no GPU read}"
fi
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

# The engine the helpers read, llama or vllm (MEASURE_ENGINE), and its container on the host
# (MEASURE_CONTAINER). The port tells them apart by default: vLLM's containers publish 8000, 8001
# and 8002 (spike-model-engines' host/, one container a row, each row naming its port), llama.cpp's
# router 8080. llama.cpp's container is llama. vLLM's is the one that publishes the port, read on
# the host from each container's port bindings, so a stopped container is found too: the running
# one when one runs, else the newest. When none publishes it, port 8000's is vllm, the suite's
# default container, and any other port's is none, which the helper prints, returning 1.
_measure_engine() {
  if [[ -n ${MEASURE_ENGINE-} ]]; then
    echo "$MEASURE_ENGINE"
  elif [[ $MEASURE_PORT == 800[012] ]]; then
    echo vllm
  else
    echo llama
  fi
}
_measure_container() {
  local listed name
  if [[ -n ${MEASURE_CONTAINER-} ]]; then
    echo "$MEASURE_CONTAINER"
    return
  elif [[ $(_measure_engine) != vllm ]]; then
    echo llama
    return
  fi
  # Each container as `<running> /<name> <host port>...`, the newest first, as docker lists them.
  # A host that can't be read is an error, never a host with no container on the port.
  if ! listed=$(ssh "$MEASURE_HOST" 'set -o pipefail; docker container ls --all --quiet | xargs -r docker container inspect --format "{{.State.Running}} {{.Name}}{{range .HostConfig.PortBindings}}{{range .}} {{.HostPort}}{{end}}{{end}}"'); then
    echo "$MEASURE_HOST's containers could not be read" >&2
    return 1
  fi
  name=$(printf '%s\n' "$listed" | awk -v p="$MEASURE_PORT" '{ for (i = 3; i <= NF; i++) if ($i == p) { n = substr($2, 2)
        if ($1 == "true") { print n; found = 1; exit }; if (first == "") first = n } }
      END { if (!found && first != "") print first }')
  if [[ -n $name ]]; then
    echo "$name"
  elif [[ $MEASURE_PORT == 8000 ]]; then
    echo vllm
  else
    echo "no container on $MEASURE_HOST publishes port $MEASURE_PORT" >&2
    return 1
  fi
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
  local line avail src sys
  line=$(ssh "$MEASURE_HOST" bash -s <<<"$_MEASURE_SAMPLE") || return 1
  IFS=$'\t' read -r avail src _ sys <<<"$line"
  awk -v h="$MEASURE_HOST" -v a="$avail" -v s="$src" \
    'BEGIN { printf "memory %s: %.2f GiB available (%s)", h, a / 1024, s }'
  if [[ -n ${MEASURE_FLOOR_GIB-} ]]; then
    printf ', floor %s GiB' "$MEASURE_FLOOR_GIB"
  fi
  # An amdgpu host's second pool, system memory, with its own floor.
  if [[ -n $sys ]]; then
    awk -v a="$sys" 'BEGIN { printf "; system %.2f GiB available (MemAvailable)", a / 1024 }'
    if [[ -n ${MEASURE_SYSTEM_FLOOR_GIB-} ]]; then
      printf ', floor %s GiB' "$MEASURE_SYSTEM_FLOOR_GIB"
    fi
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
  if [[ $(_measure_engine) == vllm ]]; then
    _measure_vllm_readout "$since"
    return
  fi
  log=$(mktemp)
  ssh "$MEASURE_HOST" docker logs --since "$since" "$(_measure_container)" >"$log" 2>&1
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

# readout on vLLM, in three lines and memory's:
#   1. /metrics, read from here on the API's port: the running and waiting requests and the KV
#      cache's usage, as they stand, and the counters since the server started: requests finished
#      (by reason), prompt and generation tokens, and preemptions. A metric is summed over its
#      label sets (one engine here, and one set a finish reason). The KV cache's usage is
#      kv_cache_usage_perc, a fraction, or gpu_cache_usage_perc where an older release names it so.
#      A metric the server doesn't report prints "-", so bench/readouts.awk never reads it as 0.
#   2. the server log since <since>, on the host, of the container that publishes the port
#      (_measure_container), named on the line (or "not read" with the first line of the reason,
#      when no container publishes it or the logs can't be read, rather than counts of
#      nothing): its ERROR lines, those of them, and the WARNING lines, that name Harmony, a parser
#      or parsing, or a tool call (the output parsers' errors: the openai tool-call parser logs
#      "Error in extracting tool call from response."), "parse" not read inside "sparse", which
#      ROCm's compilation warnings name (`Op 'sparse_attn_indexer' not present`), the
#      lines naming HarmonyError (a traceback's last line among them), and the responses its
#      access log gives a status of 400 or more. vLLM's lines read `(<process> pid=<n>) <LEVEL>
#      <MM-DD> <time> [<file>:<line>] <message>`.
#   3. memory.
_measure_vllm_readout() {
  local since=$1 log container
  curl -s --max-time 10 "$MEASURE_URL/metrics" | awk '
    # A metric the server does not report prints "-", never 0.
    function f(m, fmt) { return (m in v) ? sprintf(fmt, v[m]) : "-" }
    /^vllm:/ { n = $1; sub(/\{.*/, "", n); v[n] += $NF
      if (n == "vllm:request_success_total" && match($1, /finished_reason="[^"]*"/))
        r[substr($1, RSTART + 17, RLENGTH - 18)] += $NF }
    END {
      if (!length(v)) { print "metrics: none read"; exit }
      if (!("vllm:kv_cache_usage_perc" in v) && ("vllm:gpu_cache_usage_perc" in v))
        v["vllm:kv_cache_usage_perc"] = v["vllm:gpu_cache_usage_perc"]
      if ("vllm:kv_cache_usage_perc" in v) v["vllm:kv_cache_usage_perc"] *= 100
      printf "metrics: running %s, waiting %s, kv cache usage %s\n", f("vllm:num_requests_running", "%d"),
        f("vllm:num_requests_waiting", "%d"), f("vllm:kv_cache_usage_perc", "%.1f%%")
      reasons = ""
      for (k in r) reasons = reasons (reasons == "" ? "" : ", ") k " " r[k]
      printf "counters: requests ok %s%s, prompt tokens %s, generation tokens %s, preemptions %s\n",
        f("vllm:request_success_total", "%d"), reasons == "" ? "" : " (" reasons ")",
        f("vllm:prompt_tokens_total", "%d"), f("vllm:generation_tokens_total", "%d"),
        f("vllm:num_preemptions_total", "%d") }'
  log=$(mktemp)
  if ! container=$(_measure_container 2>"$log") ||
    ! ssh "$MEASURE_HOST" docker logs --since "$since" "$container" >"$log" 2>&1; then
    printf 'log since %s: not read: %s\n' "$since" "$(head -n 1 "$log")"
  else
    printf 'log since %s (%s): ERROR lines %s, Harmony or parser errors and warnings %s, HarmonyError lines %s, responses >=400 %s\n' \
      "$since" "$container" "$(grep -cE ' ERROR [0-9]{2}-[0-9]{2} ' "$log")" \
      "$(grep -E ' (ERROR|WARNING) [0-9]{2}-[0-9]{2} ' "$log" | grep -ciE 'harmony|(^|[^s])pars(e|er|ing)|tool.call')" \
      "$(grep -c 'HarmonyError' "$log")" "$(grep -cE '" [4-5][0-9]{2} ' "$log")"
  fi
  rm -f "$log"
  memory
}

# What each loaded model holds, the pool they share, and what their loads allocated, in three
# parts, read on the host in one ssh call:
#   1. one line a llama-server process, named by its --alias (the router's own process, which has
#      none, is `router`): its pid, its resident set from ps, and its GPU memory, nvidia-smi's
#      used_memory on a GB10 or amdgpu_top's VRAM and GTT on a Strix Halo. Both report host pids,
#      the ones ps gives (read on gb10-2 and framework with set A loaded), so they join on the pid.
#   2. the pool: MemTotal, MemAvailable and Cached on a GB10, whose GPU allocates from system
#      memory; GTT used and total on a Strix Halo, from amdgpu's sysfs.
#   3. the router's log since <since>: each child's load lines that size an allocation (weights,
#      KV, compute and output buffers, the KV cache's cells and layers, the multimodal projector,
#      the slots and their context), each under the router's line that spawned it. The router
#      prefixes a child's lines with its [port], which this names by the section that spawning
#      line gives the port, by the live child's alias for a spawn before <since>, or else
#      `port <n> (gone)`.
footprint() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked footprint "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
  esac
  if [[ $(_measure_engine) == vllm ]]; then
    _measure_vllm_footprint "$@"
    return
  fi
  local since=${1:-$(date -u -d '-10 min' +%FT%TZ)}
  # The script runs on the host, its expansions unexpanded here (the quoted here-document); its
  # two arguments, the time and the container, are expanded here and quoted for the host's shell.
  # shellcheck disable=SC2029
  ssh "$MEASURE_HOST" "bash -s -- $(printf '%q ' "$since" "$(_measure_container)")" <<'EOF'
since=$1 container=$2
# pid, RSS KiB, port and alias of every llama-server process.
procs=$(ps -eo pid=,rss=,args= | awk '$3 ~ /(^|\/)llama-server$/ {
  a = "router"; p = "-"
  for (i = 4; i < NF; i++) { if ($i == "--alias") a = $(i + 1); if ($i == "--port") p = $(i + 1) }
  print $1, $2, p, a }')
card=
for d in /sys/class/drm/card*/device; do
  [ -r "$d/mem_info_gtt_total" ] && [ -r "$d/mem_info_gtt_used" ] && { card=$d; break; }
done
if command -v nvidia-smi >/dev/null; then
  kind=nvidia
  gpu=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits | tr -d ' ' | tr , ' ')
elif [ -n "$card" ] && command -v amdgpu_top >/dev/null; then
  kind=amdgpu
  # amdgpu_top -p prints a process as `<name> (<pid>), ctxs <n>, VRAM <n> MiB (<pct>), GTT ...`.
  gpu=$(timeout 30 amdgpu_top -p 2>/dev/null |
    sed -nE 's/.*\( *([0-9]+)\), ctxs +[0-9]+, VRAM +([0-9]+) MiB.*GTT +([0-9]+) MiB.*/\1 \2 \3/p')
else
  kind=none gpu=
fi
echo "processes ($kind):"
awk -v kind="$kind" 'NR == FNR { v[$1] = $2; g[$1] = $3; next }
  { if (kind == "nvidia") m = ($1 in v) ? sprintf("gpu %d MiB", v[$1]) : "gpu none"
    else if (kind == "amdgpu") m = ($1 in v) ? sprintf("vram %d MiB, gtt %d MiB", v[$1], g[$1]) : "vram none, gtt none"
    else m = "no GPU read"
    printf "  %s: pid %s, %s, rss %d MiB\n", $4, $1, m, $2 / 1024 }' \
  <(printf '%s\n' "$gpu") <(printf '%s\n' "$procs")
if [ "$kind" = amdgpu ]; then
  # GTT, and beside it system memory, where llama.cpp's host prompt cache sits outside GTT.
  awk -v u="$(cat "$card/mem_info_gtt_used")" -v t="$(cat "$card/mem_info_gtt_total")" \
    '/^MemAvailable:/ { m = $2 / 2^20 }
    END { printf "pool: GTT used %.2f GiB of %.2f GiB; system MemAvailable %.2f GiB\n", u / 2^30, t / 2^30, m }' /proc/meminfo
else
  awk '/^(MemTotal|MemAvailable|Cached):/ { m[$1] = $2 / 2^20 }
    END { printf "pool: MemTotal %.2f GiB, MemAvailable %.2f GiB, Cached %.2f GiB\n", m["MemTotal:"], m["MemAvailable:"], m["Cached:"] }' /proc/meminfo
fi
echo "load lines since $since:"
docker logs --since "$since" "$container" 2>&1 |
  grep -E 'spawning server instance with name=|buffer size|llama_kv_cache: size =|initializing, n_slots|load_hparams: +(projector|model size)|memory usage of mmproj' |
  awk 'NR == FNR { if ($3 != "-") a[$3] = $4; next }
    match($0, /with name=[^ ]+ on port [0-9]+/) {
      n = split(substr($0, RSTART + 10, RLENGTH - 10), w, " "); a[w[n]] = w[1] }
    { who = "router"
      if (match($0, /^\[[0-9]+\] [0-9.]+ [A-Z] /)) {
        p = substr($0, 2, index($0, "]") - 2); $0 = substr($0, RLENGTH + 1)
        who = (p in a) ? a[p] : "port " p " (gone)" }
      else sub(/^[0-9.]+ [A-Z] /, "")
      gsub(/ +/, " "); print "  " who ": " $0 }' <(printf '%s\n' "$procs") -
EOF
}

# footprint on vLLM, read on the host in one ssh call (after _measure_container's, which finds the
# container that publishes the port), in three parts:
#   1. the container's state and start time, then one line a process in it (docker top gives
#      their host pids: the API server and the engine core): its pid, its name, its GPU memory,
#      nvidia-smi's used_memory on a GB10 or amdgpu_top's VRAM and GTT on a Strix Halo, both by
#      host pid as on llama.cpp, and its resident set from ps, then the container's totals.
#   2. the pool, as on llama.cpp: MemTotal, MemAvailable and Cached on a GB10; GTT used and total
#      on a Strix Halo, with system MemAvailable beside it, the pool the GTT doesn't cover.
#   3. the container's log since <since>, by default since its current start (a restart's
#      StartedAt), so a timed restart reads its own lines and not the first start's: the lines
#      that size the start, matched loosely, as v0.32.0 logged them (spike-model-engines,
#      docs/findings/bench-gb10-container.md) and as a later release may reword them. They are
#      the version; the weights and their load time (`Model loading took`); the startup's free
#      memory (`Free memory on device`); the profile's peak activation; the KV cache's memory
#      (`Available KV cache memory`, or the bytes asked for, any line naming kv_cache_memory or
#      kv-cache-memory) and tokens (`GPU KV cache size`, `KV cache size`); the maximum
#      concurrency; the compile and the CUDA graphs (`Directly load`, read from the compile cache;
#      `torch.compile take(s)`; `Graph capturing finished`); the attention and MoE backends
#      chosen (`Using ... backend`, `attention backend`, `MoE backend`); and startup's end. The
#      non-default args line, which lists every flag the row gives, is cut to its sizing flags.
#      Each line is cut at 300 characters.
_measure_vllm_footprint() {
  local container
  container=$(_measure_container) || return 1
  # The script runs on the host, its expansions unexpanded here (the quoted here-document); its
  # two arguments, the time (empty for the container's start) and the container, are expanded
  # here and quoted for the host's shell.
  # shellcheck disable=SC2029
  ssh "$MEASURE_HOST" "bash -s -- $(printf '%q ' "${1-}" "$container")" <<'EOF'
since=$1 container=$2
if ! state=$(docker container inspect --format '{{.State.Status}} {{.State.StartedAt}}' "$container" 2>/dev/null); then
  echo "container $container: none"
  exit 1
fi
read -r status started <<<"$state"
since=${since:-$started}
echo "container $container: $status, started $started"
pids=$(docker top "$container" -eo pid 2>/dev/null | awk 'NR > 1 { print $1 }' | paste -sd,)
procs=
[ -z "$pids" ] || procs=$(ps -o pid=,rss=,comm= -p "$pids")
card=
for d in /sys/class/drm/card*/device; do
  [ -r "$d/mem_info_gtt_total" ] && [ -r "$d/mem_info_gtt_used" ] && { card=$d; break; }
done
if command -v nvidia-smi >/dev/null; then
  kind=nvidia
  gpu=$(nvidia-smi --query-compute-apps=pid,used_memory --format=csv,noheader,nounits | tr -d ' ' | tr , ' ')
elif [ -n "$card" ] && command -v amdgpu_top >/dev/null; then
  kind=amdgpu
  # amdgpu_top -p prints a process as `<name> (<pid>), ctxs <n>, VRAM <n> MiB (<pct>), GTT ...`.
  gpu=$(timeout 30 amdgpu_top -p 2>/dev/null |
    sed -nE 's/.*\( *([0-9]+)\), ctxs +[0-9]+, VRAM +([0-9]+) MiB.*GTT +([0-9]+) MiB.*/\1 \2 \3/p')
else
  kind=none gpu=
fi
echo "processes ($kind):"
if [ -z "$procs" ]; then
  echo "  none: the container runs no process"
else
  awk -v kind="$kind" 'NR == FNR { if ($1 != "") { v[$1] = $2; g[$1] = $3 }; next }
    { n += ($1 in v)
      if (kind == "nvidia") { m = ($1 in v) ? sprintf("gpu %d MiB", v[$1]) : "gpu none"; tg += v[$1] }
      else if (kind == "amdgpu") {
        m = ($1 in v) ? sprintf("vram %d MiB, gtt %d MiB", v[$1], g[$1]) : "vram none, gtt none"
        tv += v[$1]; tg += g[$1] }
      else m = "no GPU read"
      tr += $2
      printf "  %s: pid %s, %s, rss %d MiB\n", $3, $1, m, $2 / 1024 }
    END { # No process in the GPU read is none, never 0 MiB.
          if (kind == "nvidia") m = n ? sprintf("gpu %d MiB", tg) : "gpu none"
          else if (kind == "amdgpu") m = n ? sprintf("vram %d MiB, gtt %d MiB", tv, tg) : "vram none, gtt none"
          else m = "no GPU read"
          printf "  container: %s, rss %d MiB\n", m, tr / 1024 }' \
    <(printf '%s\n' "$gpu") <(printf '%s\n' "$procs")
fi
if [ "$kind" = amdgpu ]; then
  # GTT, and beside it system memory, the pool the GTT doesn't cover, as llama.cpp's footprint.
  awk -v u="$(cat "$card/mem_info_gtt_used")" -v t="$(cat "$card/mem_info_gtt_total")" \
    '/^MemAvailable:/ { m = $2 / 2^20 }
    END { printf "pool: GTT used %.2f GiB of %.2f GiB; system MemAvailable %.2f GiB\n", u / 2^30, t / 2^30, m }' /proc/meminfo
else
  awk '/^(MemTotal|MemAvailable|Cached):/ { m[$1] = $2 / 2^20 }
    END { printf "pool: MemTotal %.2f GiB, MemAvailable %.2f GiB, Cached %.2f GiB\n", m["MemTotal:"], m["MemAvailable:"], m["Cached:"] }' /proc/meminfo
fi
echo "start log since $since:"
docker logs --since "$since" "$container" 2>&1 |
  grep -E 'API server version|non-default args|Model loading took|Free memory on device|peak activation|Available KV cache memory|[Kk][Vv][_ -][Cc]ache[_ -][Mm]emory|KV cache size|Maximum concurrency|Directly load|torch\.compile take|Graph capturing finished|[Uu]sing .*[Bb]ackend|[Aa]ttention backend|MoE backend|Application startup complete' |
  awk -v q="'" '/non-default args/ {
      s = $0; out = ""
      re = q "(max_model_len|max_num_seqs|gpu_memory_utilization|kv_cache_dtype|kv_cache_memory_bytes)" q ": [^,}]+"
      while (match(s, re)) { out = out (out == "" ? "" : ", ") substr(s, RSTART, RLENGTH); s = substr(s, RSTART + RLENGTH) }
      print "  non-default args, sizing: " (out == "" ? "none" : out); next }
    { gsub(/ +/, " "); print "  " substr($0, 1, 300) }'
EOF
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
  local name=${1:?usage: watch <name> <command...>} floor_mib sys_floor_mib="" pid rc t0 next line
  local avail src sys stopped="" floors
  shift
  (($#)) || { echo 'usage: watch <name> <command...>' >&2; return 2; }
  if [[ -z ${MEASURE_FLOOR_GIB-} ]]; then
    echo 'watch: set MEASURE_FLOOR_GIB to the policy headroom on the probed ceiling first' >&2
    return 2
  fi
  floor_mib=$(awk -v g="$MEASURE_FLOOR_GIB" 'BEGIN { printf "%d", g * 1024 }')
  # One sample before the run tells whether the host reads a second pool (an amdgpu host's system
  # memory), which then needs its own floor; it isn't written to the samples.
  line=$(ssh "$MEASURE_HOST" bash -s <<<"$_MEASURE_SAMPLE") || return 1
  IFS=$'\t' read -r _ src _ sys <<<"$line"
  floors="$MEASURE_FLOOR_GIB GiB ($src)"
  if [[ -n $sys ]]; then
    if [[ -z ${MEASURE_SYSTEM_FLOOR_GIB-} ]]; then
      echo "watch: $MEASURE_HOST reads system memory beside $src; set MEASURE_SYSTEM_FLOOR_GIB first" >&2
      return 2
    fi
    sys_floor_mib=$(awk -v g="$MEASURE_SYSTEM_FLOOR_GIB" 'BEGIN { printf "%d", g * 1024 }')
    floors+=" or $MEASURE_SYSTEM_FLOOR_GIB GiB (system MemAvailable)"
  fi
  t0=$(date -u +%FT%TZ)
  printf 'time\tavailable MiB\tread\tgpu%s\n' "${sys:+$'\t'system MiB}" >"$MEASURE_STATE/$name.watch.tsv"
  "$@" >"$MEASURE_STATE/$name.log" 2>&1 &
  pid=$!
  _measure_quiet "sampling $MEASURE_HOST every ${MEASURE_SAMPLE_EVERY:-10} s into $name.watch.tsv" \
    "(ssh $MEASURE_HOST bash -s <<< \$_MEASURE_SAMPLE), readout every" \
    "${MEASURE_READOUT_EVERY:-300} s, stop under $floors; output in $name.log"
  next=$(($(date +%s) + ${MEASURE_READOUT_EVERY:-300}))
  while kill -0 "$pid" 2>/dev/null; do
    sleep "${MEASURE_SAMPLE_EVERY:-10}"
    line=$(ssh "$MEASURE_HOST" bash -s <<<"$_MEASURE_SAMPLE" 2>/dev/null) || continue
    printf '%s\t%s\n' "$(date -u +%T)" "$line" >>"$MEASURE_STATE/$name.watch.tsv"
    IFS=$'\t' read -r avail src _ sys <<<"$line"
    if [[ $avail =~ ^[0-9]+$ ]] && ((avail < floor_mib)); then
      stopped="memory floor: ${avail} MiB available ($src) under $MEASURE_FLOOR_GIB GiB at $(date -u +%T)"
    elif [[ -n $sys_floor_mib && $sys =~ ^[0-9]+$ ]] && ((sys < sys_floor_mib)); then
      stopped="system floor: ${sys} MiB available (MemAvailable) under $MEASURE_SYSTEM_FLOOR_GIB GiB at $(date -u +%T)"
    fi
    if [[ -n $stopped ]]; then
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

summarize() {
  case $-:${_measure_marking-} in
    *x*:) _measure_marked summarize "$@"; return ;;
    *:on) _measure_marking=in; set -x ;;
  esac
  local name=${1:?usage: summarize <name>}
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
  if [[ -f $MEASURE_STATE/$name.exit ]]; then
    echo "exit: $(cat "$MEASURE_STATE/$name.exit")"
  fi
  if [[ -f $MEASURE_STATE/$name.watch.tsv ]]; then
    # The lowest of each pool: the first column's, and on an amdgpu host system memory's beside it.
    awk -F'\t' 'NR > 1 { n++; if (n == 1 || $2 < mn) { mn = $2; at = $1 }; src = $3; g[$4]++
                         if ($5 != "") { k++; if (k == 1 || $5 < ms) { ms = $5; sat = $1 } } }
      END { if (!n) { print "watch: no samples"; exit }
            printf "watch: %d samples, lowest available %.2f GiB (%s) at %s", n, mn / 1024, src, at
            if (k) printf "; lowest system %.2f GiB (MemAvailable) at %s", ms / 1024, sat
            print "" }' \
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
