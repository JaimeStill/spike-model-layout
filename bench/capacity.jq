# Per-request figures from a GuideLLM 0.8.1 result JSON of one level, for the agent-vllm
# capacity cell (agent-vllm-capacity.yaml), which levels.jq reads only as a level's medians:
#
#   jq -r -f bench/capacity.jq <result.json>...
#
# For each file and each benchmark in it: a header, then one row a request, successful, errored
# and incomplete together, in order of request start: its status, its start in seconds from the
# level's first request's start, its TTFT in ms (GuideLLM's, to the first token of any kind,
# reasoning included), its latency in s (request_end_time - request_start_time, or to the cut for
# an incomplete one, "-" when GuideLLM recorded no end), its prompt tokens, and its completion:
# the output tokens over the scenario's output_tokens when the data names them. Then a summary
# line: counts by status; TTFT median, min and max of the successful; latency median and max of
# the successful; and the spread of the starts, the last request's start from the first's, which
# reads whether every stream's request was sent at once.
#
# Medians interpolate linearly between the two nearest ranks. Numbers are rounded half away from
# zero at the printed digits (jq's round); "-" marks a figure GuideLLM did not record.

def median:
  sort as $xs | ($xs | length) as $n
  | if $n == 0 then null
    else (($n - 1) / 2) as $k | ($k | floor) as $lo | ([$lo + 1, $n - 1] | min) as $hi
    | $xs[$lo] + ($xs[$hi] - $xs[$lo]) * ($k - $lo)
    end;

# The number with $d decimals, or "-" for null.
def fixed($d): if . == null then "-" else (. * pow(10; $d) | round) / pow(10; $d) | tostring end;

def name: input_filename | split("/") | last;

def capacity($spec_out):
  $spec_out as $want | (.config.strategy.streams // "-") as $streams
  | [ (.requests.successful[] | {s: "ok"} + .),
      (.requests.errored[] | {s: "errored"} + .),
      (.requests.incomplete[] | {s: "incomplete"} + .) ]
  | map(select(.request_start_time != null)) | sort_by(.request_start_time) as $rs
  | ($rs[0].request_start_time // 0) as $t0
  | [$rs[] | select(.s == "ok")] as $ok
  | "streams \($streams): requests in order of start",
    "status | start s | TTFT ms | latency s | prompt tok | output tok",
    ($rs[]
     | [ .s,
         (.request_start_time - $t0 | fixed(2)),
         (.time_to_first_token_ms | fixed(0)),
         (if .request_end_time then .request_end_time - .request_start_time | fixed(2) else "-" end),
         (.prompt_tokens // "-" | tostring),
         ((.output_tokens // 0 | tostring) + (if $want then "/\($want)" else "" end)) ]
     | join(" | ")),
    "summary: ok \($ok | length), errored \([$rs[] | select(.s == "errored")] | length), incomplete \([$rs[] | select(.s == "incomplete")] | length)"
    + (if $want then ", complete \([$ok[] | select(.output_tokens == $want)] | length)/\($rs | length)" else "" end)
    + "; TTFT ms median \([$ok[].time_to_first_token_ms] | median | fixed(0)), min \([$ok[].time_to_first_token_ms] | min | fixed(0)), max \([$ok[].time_to_first_token_ms] | max | fixed(0))"
    + "; latency s median \([$ok[] | .request_end_time - .request_start_time] | median | fixed(2)), max \([$ok[] | .request_end_time - .request_start_time] | max | fixed(2))"
    + "; starts spread \(($rs[-1].request_start_time // $t0) - $t0 | fixed(2)) s";

(.config.spec.data[0].output_tokens // null) as $spec_out | "## \(name)", (.benchmarks[] | capacity($spec_out))
