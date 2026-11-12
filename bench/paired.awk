# The paired test between two runs of one lm-evaluation-harness task, question by question: the
# vllm-layout task's BF16 and FP8 agent rows. Each run is given as "<doc_id> <tab> <prompt_hash>
# <tab> <score>" lines, one a question, which jq cuts from the run's samples file; the first file
# is the reference (BF16), the second the candidate (FP8):
#
#   awk -f bench/paired.awk <(jq -r '<cut>' <reference samples>) <(jq -r '<cut>' <candidate samples>)
#
# with, for GPQA, `select(.filter == "flexible-extract") | [.doc_id, .prompt_hash, .exact_match]
# | @tsv`, and for RULER at a length, `[.doc_id, .prompt_hash, .["32768"]] | @tsv` (the length's
# key). A score is 1 (right) or 0 (wrong); any other value is counted apart and left out.
#
# Questions pair on doc_id. A pair whose prompt_hash differs asked the two rows different prompts:
# each one is printed and counted, and still paired. It prints each run's accuracy over the pairs,
# b (right on the reference, wrong on the candidate) and c (the reverse), and McNemar's exact
# two-sided p-value: the binomial probability, at p = 0.5 over the b + c discordant pairs, of a
# split at least as uneven as the one seen, 2 * P(X <= min(b, c)), capped at 1. The candidate's loss
# is significant at 95% when p < 0.05 and b > c. Unpaired questions on either side are counted.

BEGIN { FS = "\t" }

FNR == NR {
  if ($3 != 0 && $3 != 1) { badref++; next }
  ref[$1] = $3; hash[$1] = $2
  next
}

{
  if ($3 != 0 && $3 != 1) { badcand++; next }
  if (!($1 in ref)) { onlycand++; next }
  seen[$1] = 1; n++
  if ($2 != hash[$1]) { mismatch++; printf "prompt_hash differs at doc_id %s: %s, %s\n", $1, hash[$1], $2 }
  r += ref[$1]; k += $3
  if (ref[$1] == 1 && $3 == 0) b++
  if (ref[$1] == 0 && $3 == 1) c++
}

END {
  for (id in ref) if (!(id in seen)) onlyref++
  m = b + c; lo = (b < c) ? b : c
  # P(X <= lo) for X ~ Binomial(m, 1/2), term by term from 0.5^m.
  t = 0.5 ^ m; s = 0
  for (i = 0; i <= lo; i++) { s += t; t = t * (m - i) / (i + 1) }
  p = (m == 0) ? 1 : 2 * s
  if (p > 1) p = 1
  printf "pairs %d; prompt_hash mismatches %d; unpaired: reference only %d, candidate only %d; scores neither 0 nor 1: reference %d, candidate %d\n", \
    n, mismatch, onlyref, onlycand, badref, badcand
  if (!n) { print "no pairs"; exit 1 }
  printf "accuracy: reference %.4f (%d/%d), candidate %.4f (%d/%d)\n", r / n, r, n, k / n, k, n
  printf "discordant: b %d (reference right, candidate wrong), c %d (candidate right, reference wrong)\n", b, c
  printf "McNemar exact two-sided p %.4g; candidate's loss significant at 95%%: %s\n", p, (p < 0.05 && b > c) ? "yes" : "no"
}
