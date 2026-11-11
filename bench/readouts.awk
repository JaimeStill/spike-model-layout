# The highest of vLLM's readouts over a run, for the agent-vllm capacity cell, from the lines the
# step helpers' readout prints on vLLM (scripts/measure-lib.sh, _measure_vllm_readout): a step's
# output, or the measure log's lines for the cell, cut to the cell's window:
#
#   awk -f bench/readouts.awk <step output or log lines>
#
# readout prints, each readout, "metrics: running <n>, waiting <n>, kv cache usage <x>%" and
# "counters: ... preemptions <n>". This prints the number of metrics lines, the highest running,
# waiting and KV cache usage with the readout each was first reached at (its ordinal, and its time
# when the line is the measure log's, which starts "= <ISO time> <helper>: "), and the preemptions
# counter at the first and the last counters line with their difference, the preemptions between
# them, since the counter runs from the server's start.

function at(   s) { s = "readout " n; if (t != "") s = s " at " t; return s }

{ t = ($1 == "=") ? $2 : "" }

/metrics: running [0-9]+, waiting [0-9]+, kv cache usage / {
  n++
  match($0, /running [0-9]+/); r = substr($0, RSTART + 8, RLENGTH - 8) + 0
  match($0, /waiting [0-9]+/); w = substr($0, RSTART + 8, RLENGTH - 8) + 0
  match($0, /kv cache usage [0-9.]+%/); k = substr($0, RSTART + 15, RLENGTH - 16) + 0
  if (n == 1 || r > mr) { mr = r; ar = at() }
  if (n == 1 || w > mw) { mw = w; aw = at() }
  if (n == 1 || k > mk) { mk = k; ak = at() }
}

/counters: .*preemptions [0-9]+/ {
  match($0, /preemptions [0-9]+/); p = substr($0, RSTART + 12, RLENGTH - 12) + 0
  if (!c++) p0 = p
  p1 = p
}

END {
  if (!n) { print "readouts: no metrics lines"; exit }
  printf "readouts: %d metrics lines; highest running %d (%s), waiting %d (%s), kv cache usage %.1f%% (%s)\n",
    n, mr, ar, mw, aw, mk, ak
  if (c) printf "preemptions: %d at the first counters line, %d at the last, %d between\n", p0, p1, p1 - p0
}
