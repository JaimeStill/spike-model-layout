# Count, median, min and max of each figure in "<order> <figure> <value>" lines sorted by order,
# then value (`sort -k1,1n -k3,3g`), as bench/srvtimes.awk prints them. The median interpolates
# between the two middle values, as bench/levels.jq does; figures print to one decimal.

function out(   k, lo, hi) {
  if (!n) return
  k = (n - 1) * 0.5; lo = int(k); hi = (lo + 1 < n - 1) ? lo + 1 : n - 1
  printf "%s: n %d, median %.1f, min %.1f, max %.1f\n", name, n, v[lo] + (v[hi] - v[lo]) * (k - lo), v[0], v[n - 1]
}

$2 != name { out(); name = $2; n = 0 }
{ v[n++] = $3 }
END { out() }
