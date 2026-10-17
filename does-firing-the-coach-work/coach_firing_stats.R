# coach_firing_stats.R
# ──────────────────────────────────────────────────────────────────────
# The test of story #001 for one calculation path: a linear model with a t-test. The pipeline and
# the notebook use the same function, so they produce identical numbers.
#
#   matched:    post points per game ~ coach change (dummy) + one dummy per points before.
#               Changes and control stretches with the same points before are compared, the
#               coefficient of the change dummy is the effect.
#   before:     (post - pre) points per game of the changes alone, t-test against 0
#               (an intercept-only model).
#   all_slumps: (post - pre) points per game ~ coach change (dummy), changes in a slump and all
#               control stretches in a slump (at most 2k/3 points in k games).
#
# With opponents = "yes" the outcome is points above an expectation from the opponent's strength
# (pre_adj, post_adj); the matching dummies stay on the raw points before.
#
# Requires: base R only.
# ──────────────────────────────────────────────────────────────────────

ALPHA <- 0.05

# Effect (points per game), standard error, residual degrees of freedom, 95% interval and
# two-sided p-value of the t-test, the number of coach changes and the fitted model.
test_path <- function(treated, control, comparison, opponents, k) {
  pre <- if (opponents == "yes") "pre_adj" else "pre"
  post <- if (opponents == "yes") "post_adj" else "post"
  if (comparison == "before") {
    d <- data.frame(y = (treated[[post]] - treated[[pre]]) / k)
    fit <- lm(y ~ 1, data = d)
    term <- "(Intercept)"
  } else if (comparison == "matched") {
    d <- rbind(
      data.frame(y = treated[[post]] / k, change = 1, bin = treated$pre),
      data.frame(y = control[[post]] / k, change = 0, bin = control$pre)
    )
    d <- d[d$bin %in% control$pre, ]
    fit <- lm(y ~ change + factor(bin), data = d)
    term <- "change"
  } else {
    slump <- function(df) df[df$pre <= (2 * k) %/% 3, ]
    t <- slump(treated)
    c <- slump(control)
    d <- rbind(
      data.frame(y = (t[[post]] - t[[pre]]) / k, change = 1),
      data.frame(y = (c[[post]] - c[[pre]]) / k, change = 0)
    )
    fit <- lm(y ~ change, data = d)
    term <- "change"
  }
  co <- summary(fit)$coefficients
  est <- co[term, "Estimate"]
  se <- co[term, "Std. Error"]
  df <- fit$df.residual
  q <- qt(1 - ALPHA / 2, df)
  n <- if (comparison == "before") nrow(d) else sum(d$change == 1)
  list(effect = est, se = se, df = df, ci_low = est - q * se, ci_high = est + q * se,
       p = co[term, "Pr(>|t|)"], n = n, fit = fit)
}
