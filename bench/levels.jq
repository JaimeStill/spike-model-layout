# Per-level figures from GuideLLM 0.8.1 result JSON, one table per file, for the findings.
#
#   jq -r --arg purpose <agent|vision|audio|embed> -f bench/levels.jq <result.json>...
#   jq -r --arg purpose client [--argjson level <i>] -f bench/levels.jq <result.json>...
#
# A purpose prints the knee GuideLLM concluded, then one row a level: streams, requests ok /
# errored / incomplete, output tok/s, requests/s, TTFT median, ITL median and p95 (GuideLLM's
# own), request latency median and p90, prompt tok/s, RTFx median and min and the count at RTFx
# >=5, the level's duration, and its floor verdict. Latency and RTFx are computed here from each
# successful request: latency is request_end_time - request_start_time, RTFx is
# input_metrics.audio_seconds over that latency. The floors: agent ITL median <=100 ms, vision
# latency median <=10 s, audio RTFx median >=5, embed mean prompt tok/s >=4300; a level with no
# successful request misses.
#
# `client` prints GuideLLM's own per-request timings for one level (index `level`, default 0),
# successful requests in order of request_start: the gap from the previous request's end to this
# one's start, dequeued to request_start, request_start to the first streamed chunk, first to last
# chunk (each in ms), and audio bytes, each as median, min and max.
#
# Medians and percentiles interpolate linearly between the two nearest ranks. Numbers are rounded
# half to even at the printed digits.

# Linear interpolation at fraction $p of the sorted values; nan when there are none.
def pct($p):
  sort as $xs | ($xs | length) as $n
  | if $n == 0 then nan
    else (($n - 1) * $p) as $k | ($k | floor) as $lo | ([$lo + 1, $n - 1] | min) as $hi
    | $xs[$lo] + ($xs[$hi] - $xs[$lo]) * ($k - $lo)
    end;
def median: pct(0.5);

# The number with $d decimals, rounded half to even; "-" for null, "nan" for nan.
def fixed($d):
  if . == null then "-"
  elif isnan then "nan"
  else (if . < 0 then "-" else "" end) as $sign
    | (fabs * pow(10; $d)) as $y | ($y | floor) as $f | ($y - $f) as $r
    | (if $r > 0.5 then $f + 1 elif $r < 0.5 then $f elif ($f % 2) == 0 then $f else $f + 1 end
       | tostring) as $s
    | if $d == 0 then $sign + $s
      else ([range(0; $d + 1 - ($s | length))] | map("0") | join("") + $s) as $p
      | $sign + $p[:-$d] + "." + $p[-$d:]
      end
    end;

def name: input_filename | split("/") | last;

def knee:
  (.conclusions // [])[] | (.initial.throughput // {})
  | "knee: \(.status) knee \(.knee) breakpoint \(.breakpoint_concurrency) saturation \(.saturation_concurrency) (\(.reason))";

def level($purpose):
  .metrics as $m | $m.request_totals as $rt
  | [.requests.successful[] | .request_end_time - .request_start_time] as $lat
  | [.requests.successful[] | select(.input_metrics.audio_seconds // 0 > 0)
     | .input_metrics.audio_seconds / (.request_end_time - .request_start_time)] as $rtfx
  | $m.inter_token_latency_ms.successful as $itl
  | $m.prompt_tokens_per_second.successful.mean as $ptps
  | ($lat | median) as $latm
  | ((if $purpose == "agent" then $itl.median <= 100
     elif $purpose == "vision" then ($lat | length) > 0 and $latm <= 10
     elif $purpose == "audio" then ($rtfx | length) > 0 and ($rtfx | median) >= 5
     else $ptps >= 4300 end) and $rt.successful > 0) as $ok
  | [ (.config.strategy.streams | tostring),
      "\($rt.successful)/\($rt.errored)/\($rt.incomplete)",
      ($m.output_tokens_per_second.successful.mean | fixed(2)),
      ($m.requests_per_second.successful.mean | fixed(3)),
      ($m.time_to_first_token_ms.successful.median | fixed(0)),
      ($itl.median | fixed(2)),
      ($itl.percentiles.p95 | fixed(2)),
      ($latm | fixed(2)),
      ($lat | pct(0.9) | fixed(2)),
      ($ptps | fixed(0)),
      (if ($rtfx | length) > 0
       then "\($rtfx | median | fixed(2)) | \($rtfx | min | fixed(2)) | \([$rtfx[] | select(. >= 5)] | length)/\($rtfx | length)"
       else "- | - | -" end),
      (.duration | fixed(0)),
      (if $ok then "meets" else "MISSES" end) ]
  | join(" | ");

def table($purpose):
  "## \(name)",
  knee,
  "streams | ok/err/inc | out tok/s | req/s | TTFT med ms | ITL med ms | ITL p95 ms | lat med s | lat p90 s | prompt tok/s | RTFx med | RTFx min | RTFx>=5 | dur s | floor",
  (.benchmarks[] | level($purpose));

def spread: if length == 0 then "none"
  else "median \(median | fixed(0)), min \(min | fixed(0)), max \(max | fixed(0)) (n \(length))" end;

def client($i):
  .benchmarks[$i] as $b
  | [$b.requests.successful[]] | sort_by(.info.timings.request_start) as $rs
  | [$rs[].info.timings] as $t
  | "\(name) level \($b.config.strategy.streams): \($rs | length) ok, start \($t[0].request_start | fixed(3))",
    "previous end -> request_start ms: \([range(1; $t | length) | ($t[.].request_start - $t[. - 1].request_end) * 1000] | spread)",
    "dequeued -> request_start ms: \([$t[] | (.request_start - .dequeued) * 1000] | spread)",
    "request_start -> first chunk ms: \([$t[] | (.first_request_iteration - .request_start) * 1000] | spread)",
    "first -> last chunk ms: \([$t[] | (.last_request_iteration - .first_request_iteration) * 1000] | spread)",
    "audio bytes: \([$rs[].input_metrics.audio_bytes] | spread)";

$ARGS.named.purpose as $purpose
| if $purpose == "client" then client($ARGS.named.level // 0)
  elif $purpose == "agent" or $purpose == "vision" or $purpose == "audio" or $purpose == "embed"
  then table($purpose)
  else error("purpose must be agent, vision, audio, embed or client") end
