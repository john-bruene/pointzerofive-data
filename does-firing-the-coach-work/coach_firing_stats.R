# coach_firing_stats.R
# ──────────────────────────────────────────────────────────────────────
# Estimators and the cluster bootstrap for story #004 (relaunch spec §7.1). The pipeline and the
# notebook use the same procedure and the same seeds, so they produce identical numbers.
#
# All three comparisons share one formula. For treated rows i with outcome y_i and match bin b_i,
# and control groups g with outcome sums S[g, b] and counts C[g, b]:
#
#     effect = mean over i of ( y_i - S[., b_i] / C[., b_i] ) / k
#
# over the treated rows whose bin has at least one control. A bootstrap draw resamples treated
# rows and control groups (club-seasons) with replacement and is stored as count weights.
#
#   matched:    y = post-window points, b = pre-window points, S/C = control post by pre
#   before:     y = post - pre, one bin, S = 0 and C = 1 (no comparison group)
#   all_slumps: y = post - pre, one bin, S/C = control (post - pre) over slump windows
#
# Requires: base R only. Bins are 1-based here (bin = points before + 1).
# ──────────────────────────────────────────────────────────────────────

ALPHA <- 0.05

# A design: k, y (n_t), bins (n_t, 1-based), s and c (n_g x n_bins).
design <- function(k, y, bins, s, c) list(k = k, y = y, bins = bins, s = s, c = c)

# Effect in points per game for treated weights u (b x n_t) and group weights w (b x n_g).
effects <- function(d, u, w) {
  cp <- (w %*% d$s) / (w %*% d$c)
  cpi <- cp[, d$bins, drop = FALSE]
  valid <- is.finite(cpi)
  diff <- matrix(d$y, nrow(cpi), ncol(cpi), byrow = TRUE) - cpi
  diff[!valid] <- 0
  rowSums(u * diff) / rowSums(u * valid) / d$k
}

point_estimate <- function(d) {
  effects(d, matrix(1, 1, length(d$y)), matrix(1, 1, nrow(d$s)))
}

# Per replicate: resample treated rows, then control groups.
draw_weights <- function(n_t, n_g, b) {
  u <- matrix(0, b, n_t)
  w <- matrix(0, b, n_g)
  for (r in seq_len(b)) {
    u[r, ] <- tabulate(sample.int(n_t, n_t, replace = TRUE), n_t)
    w[r, ] <- tabulate(sample.int(n_g, n_g, replace = TRUE), n_g)
  }
  list(u = u, w = w)
}

# Replicates from the current random stream (set.seed() before the call).
bootstrap <- function(d, b, chunk = 1000) {
  reps <- unlist(lapply(seq(1, b, by = chunk), function(start) {
    dw <- draw_weights(length(d$y), nrow(d$s), min(chunk, b - start + 1))
    effects(d, dw$u, dw$w)
  }))
  if (anyNA(reps)) stop("a replicate had no comparison case at all")
  reps
}

# 95% range from order statistics and the matching two-sided bootstrap p-value.
# With m = alpha/2 * B, the range is the m-th to the (B + 1 - m)-th smallest replicate and
# p = 2 * min(#{<= 0}, #{>= 0}) / B. Then p < alpha exactly when the range excludes 0.
summarize <- function(reps, alpha = ALPHA) {
  b <- length(reps)
  m <- round(alpha / 2 * b)
  stopifnot("alpha/2 * B must be a whole number" = abs(alpha / 2 * b - m) < 1e-9)
  s <- sort(reps)
  lo <- s[m]
  hi <- s[b + 1 - m]
  p <- min(1, 2 * min(sum(reps <= 0), sum(reps >= 0)) / b)
  stopifnot((p < alpha) == (lo > 0 || hi < 0))
  list(ci_low = lo, ci_high = hi, p = p)
}

# Matrix (n_g x n_bins) of sums of v by group g and bin.
sum_by <- function(n_g, n_bins, g, bin, v) {
  out <- matrix(0, n_g, n_bins)
  if (length(v)) {
    sums <- rowsum(v, g + (bin - 1) * n_g)
    out[as.integer(rownames(sums))] <- sums
  }
  out
}

# All comparison x opponents designs for one window length k, named "comparison|opponents".
build_designs <- function(treated, control, k) {
  key <- paste(control$season, control$club, sep = "\r")
  groups <- unique(key[order(control$season, control$club, method = "radix")])
  gidx <- match(key, groups)
  n_g <- length(groups)
  cpre <- as.integer(control$pre)
  slump <- cpre <= (2 * k) %/% 3
  # all_slumps compares changes made in a slump with all slump windows; changes after a
  # better run would otherwise face controls that rebound more by chance alone.
  t_slump <- as.integer(treated$pre) <= (2 * k) %/% 3
  ones <- rep(1L, nrow(treated))
  out <- list()
  cols <- list(no = c("pre", "post"), yes = c("pre_adj", "post_adj"))
  for (opponents in names(cols)) {
    pre_col <- cols[[opponents]][1]
    post_col <- cols[[opponents]][2]
    t_post <- as.numeric(treated[[post_col]])
    t_diff <- t_post - as.numeric(treated[[pre_col]])
    c_post <- as.numeric(control[[post_col]])
    c_diff <- c_post - as.numeric(control[[pre_col]])

    s <- sum_by(n_g, 3 * k + 1, gidx, cpre + 1, c_post)
    c <- sum_by(n_g, 3 * k + 1, gidx, cpre + 1, rep(1, length(c_post)))
    out[[paste("matched", opponents, sep = "|")]] <-
      design(k, t_post, as.integer(treated$pre) + 1L, s, c)

    out[[paste("before", opponents, sep = "|")]] <-
      design(k, t_diff, ones, matrix(0, n_g, 1), matrix(1, n_g, 1))

    s1 <- sum_by(n_g, 1, gidx[slump], rep(1, sum(slump)), c_diff[slump])
    c1 <- sum_by(n_g, 1, gidx[slump], rep(1, sum(slump)), rep(1, sum(slump)))
    out[[paste("all_slumps", opponents, sep = "|")]] <-
      design(k, t_diff[t_slump], ones[t_slump], s1, c1)
  }
  out
}
