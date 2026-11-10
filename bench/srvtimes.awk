# Per-request server timings from llama-server's router log, `docker logs --timestamps llama`, for
# one child port, for the findings:
#
#   awk -v port=<port> -f bench/srvtimes.awk <log> | sort -k1,1n -k3,3g | awk -f bench/stats.awk
#
# A task starts at the child's `processing task` line. For each task that logged a total time it
# prints one line a figure, "<order> <figure> <value>", in task order:
#   1 n_ctx_slot                 the slot's context, from the task's `new prompt` line
#   2 audio_encode_ms            the sum of its `audio decoded` times (none if it decoded no audio)
#   3 prompt_eval_ms, 4 prompt_tokens, 5 prompt_eval_tok/s (tokens over ms, x1000)
#   6 eval_ms, 7 eval_tokens, 8 eval_ms/token
#   9 total_ms
#   10 proxy_to_slot_start_ms    from the router's last `proxying request ... on port <port>` line
#                                before the task to the task's start
#   11 release_to_next_proxy_ms  from the previous `stop processing` to that proxy line, when both
#                                were seen; the first timed task's is left out
# Times are each line's docker timestamp, to the microsecond; a window stays within one UTC day.

function ts(s) { return substr(s, 12, 2) * 3600 + substr(s, 15, 2) * 60 + substr(s, 18, 9) }

function flush(   i) {
  if (!cur || !("tot" in T)) return
  timed++
  if ("ctx" in T) print 1, "n_ctx_slot", T["ctx"]
  if (T["nenc"]) print 2, "audio_encode_ms", T["enc"]
  if ("pe" in T) { print 3, "prompt_eval_ms", T["pe"]; print 4, "prompt_tokens", T["pe_n"] }
  if (T["pe"]) print 5, "prompt_eval_tok/s", T["pe_n"] / T["pe"] * 1000
  if ("ev" in T) { print 6, "eval_ms", T["ev"]; print 7, "eval_tokens", T["ev_n"] }
  if (T["ev_n"]) print 8, "eval_ms/token", T["ev"] / T["ev_n"]
  print 9, "total_ms", T["tot"]
  if (T["proxy"]) print 10, "proxy_to_slot_start_ms", (T["start"] - T["proxy"]) * 1000
  if (timed > 1 && ("gap" in T)) print 11, "release_to_next_proxy_ms", T["gap"] * 1000
}

$1 ~ /^[0-9][0-9][0-9][0-9]-/ && NF >= 2 {
  t = ts($1)
  rest = substr($0, length($1) + 2)
  if (index(rest, "proxying request to model") && index(rest, "on port " port)) { last_proxy = t; next }
  if (index(rest, "[" port "]") != 1) next
  if (match(rest, /task [0-9]+ \| processing task/)) {
    flush()
    delete T
    cur = 1
    T["proxy"] = last_proxy; T["start"] = t; T["nenc"] = 0
    if (last_proxy && last_release) T["gap"] = last_proxy - last_release
    next
  }
  if (!cur) next
  if (match(rest, /n_ctx_slot = [0-9]+/)) T["ctx"] = substr(rest, RSTART + 13, RLENGTH - 13)
  if (match(rest, /audio decoded \(batch [0-9]+\/[0-9]+\) in [0-9]+ ms/)) {
    split(substr(rest, RSTART, RLENGTH), a, " "); T["enc"] += a[6]; T["nenc"]++
  }
  if (match(rest, /prompt eval time = +[0-9.]+ ms \/ +[0-9]+ tokens/)) {
    split(substr(rest, RSTART, RLENGTH), a, /[ \/]+/); T["pe"] = a[5]; T["pe_n"] = a[7]
  }
  if (match(rest, /\|[ \t]+eval time = +[0-9.]+ ms \/ +[0-9]+ tokens/)) {
    split(substr(rest, RSTART, RLENGTH), a, /[ \t\/|]+/); T["ev"] = a[5]; T["ev_n"] = a[7]
  }
  if (match(rest, /total time = +[0-9.]+ ms/)) { split(substr(rest, RSTART, RLENGTH), a, / +/); T["tot"] = a[4] }
  if (index(rest, "stop processing")) { T["release"] = t; last_release = t }
}

END { flush() }
