# rain_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline for story #007 "Does rain lower turnout?".
# Pitch with every choice fixed before the analysis: content/pitches/007-rain-lowers-turnout.md
#
# Inputs:
#   notebooks/raw/rain/turnout.csv, rain.csv     (written by rain_extract.py)
#   notebooks/claims/rain-lowers-turnout.json    (claim and fork texts, hand-written)
# Outputs:
#   data/rain-lowers-turnout.json
#   data/rain-lowers-turnout.output.txt  (this script's console output via sink(), with
#                                         sessionInfo(); not edited afterwards)
#   The result table of the main calculation (key `estimation`) is built with
#   notebooks/estimation_table.R.
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/rain_pipeline.R
#
# Requires: base R and jsonlite.
#
# Method (pitch §1b)
#   One observation per Wahlkreis and election 2005–2025: y = change in turnout from the previous
#   election (percentage points, previous result on the current boundaries), x = change in rain on
#   the two election days (mm / 10, mean over the Wahlkreis). Effect beta = least-squares slope of
#   y on x with one constant per group (Land and election, or election), optionally weighted.
#   Permutation test (as in Cooperman 2017): a placebo replicate replaces the rain field of every
#   election date by the field of the same calendar date in another year 1995–2025 (one draw per
#   date). Test of beta = b: |beta_hat - b| against |a_r - b c_r|, with a_r the placebo slope of
#   y and c_r the placebo slope of the observed x. p = p(0); 95% interval = all b with p(b) >= 0.05.
# ──────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages(library(jsonlite))
source(file.path("notebooks", "estimation_table.R"))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

TURNOUT <- file.path("notebooks", "raw", "rain", "turnout.csv")
RAIN <- file.path("notebooks", "raw", "rain", "rain.csv")
CLAIM <- file.path("notebooks", "claims", "rain-lowers-turnout.json")
OUT <- file.path("data", "rain-lowers-turnout.json")
LOG <- file.path("data", "rain-lowers-turnout.output.txt")
PLACEBO_OUT <- file.path("static", "data", "rain-lowers-turnout-placebo.json")

R <- 10000L     # placebo replicates per calculation path
SEED <- 7100L   # path i (1..16, fork order) uses set.seed(SEED + i)
ALPHA <- 0.05
YEARS <- 1995:2025
ELECTIONS <- c(2002L, 2005L, 2009L, 2013L, 2017L, 2021L, 2025L)
DATES <- c("2002-09-22", "2005-09-18", "2009-09-27", "2013-09-22", "2017-09-24", "2021-09-26",
           "2025-02-23")
RUN_TIME <- Sys.time()

FORK_OPTIONS <- list(
  rain = c("day", "anomaly"),
  within = c("land", "election"),
  elections = c("all", "pre2021"),
  weight = c("none", "voters")
)

# One row per Wahlkreis and election with y, the observed rain change and, for the placebo, the
# rain of every year on the two calendar dates (matrices this / prev, one column per year).
read_data <- function() {
  t <- read.csv(TURNOUT, stringsAsFactors = FALSE)
  t$y <- 100 * (t$voters / t$eligible - t$voters_prev / t$eligible_prev)
  drop <- (t$election == 2005 & t$name == "Dresden I") | (t$election == 2025 & t$land == 11)
  cat(sprintf("Left out: %s\n", paste(sprintf("%d %s", t$election[drop], t$name[drop]),
                                      collapse = ", ")))
  t <- t[!drop, ]
  r <- read.csv(RAIN, stringsAsFactors = FALSE)
  key <- function(g, w, k) paste(g, w, k)
  mat <- function(which) {
    s <- r[r$which == which, ]
    full <- tapply(s$mm, list(key(s$geometry, s$which, s$wkr), s$year), identity)
    m <- full[key(t$election, which, t$wkr), as.character(YEARS), drop = FALSE]
    stopifnot(!anyNA(m))
    unname(m)
  }
  this <- mat("this")
  prev <- mat("prev")
  e_i <- match(t$election, ELECTIONS)             # date index of this election
  col <- function(year) match(year, YEARS)
  t$rain_this <- this[cbind(seq_len(nrow(t)), col(t$election))]
  t$rain_prev <- prev[cbind(seq_len(nrow(t)), col(ELECTIONS[e_i - 1]))]
  t$clim <- rowMeans(this) - rowMeans(prev)      # normal difference of the two dates
  list(t = t, this = this, prev = prev, date_this = e_i, date_prev = e_i - 1L)
}

# Weighted slope of y on x within groups g, for one x vector or the columns of a matrix X.
within_slope <- function(y, X, g, w) {
  X <- as.matrix(X)
  sw <- rowsum(w, g)
  xm <- rowsum(w * X, g) / as.vector(sw)
  ym <- rowsum(w * y, g) / as.vector(sw)
  gi <- match(g, rownames(sw))
  Xt <- X - xm[gi, , drop = FALSE]
  yt <- y - ym[gi]
  list(slope = colSums(w * Xt * yt) / colSums(w * Xt^2), Xt = Xt)
}

path_obs <- function(d, elections) {
  if (elections == "pre2021") which(d$t$election <= 2017) else seq_len(nrow(d$t))
}

# Effect, placebo slopes and the inverted test for one path.
test_path <- function(d, rain, within, elections, weight, r = R) {
  i <- path_obs(d, elections)
  t <- d$t[i, ]
  x <- (t$rain_this - t$rain_prev - if (rain == "anomaly") t$clim else 0) / 10
  g <- if (within == "land") paste(t$election, t$land) else as.character(t$election)
  w <- if (weight == "voters") t$eligible / mean(t$eligible) else rep(1, nrow(t))
  beta <- within_slope(t$y, x, g, w)$slope
  # placebo: one random year per election date, the same draw for every Wahlkreis
  a <- cc <- numeric(r)
  n_dates <- length(ELECTIONS)
  xt <- within_slope(x, x, g, w)$Xt[, 1]
  chunk <- 500L
  for (start in seq(1L, r, by = chunk)) {
    m <- min(chunk, r - start + 1L)
    yrs <- vapply(seq_len(n_dates), function(k)
      sample(setdiff(seq_along(YEARS), match(ELECTIONS[k], YEARS)), m, replace = TRUE),
      integer(m))
    yrs <- matrix(yrs, nrow = m)
    Xp <- vapply(seq_len(m), function(j) {
      d$this[cbind(i, yrs[j, d$date_this[i]])] - d$prev[cbind(i, yrs[j, d$date_prev[i]])]
    }, numeric(length(i)))
    Xp <- (Xp - if (rain == "anomaly") t$clim else 0) / 10
    fit <- within_slope(t$y, Xp, g, w)
    a[start:(start + m - 1)] <- fit$slope
    cc[start:(start + m - 1)] <- colSums(w * fit$Xt * xt) / colSums(w * fit$Xt^2)
  }
  p_of <- function(b) mean(abs(a - b * cc) >= abs(beta - b))
  ci <- invert(p_of, beta, sd(a))
  p <- p_of(0)
  stopifnot((p < ALPHA) == (ci[1] > 0 || ci[2] < 0))
  list(effect = beta, ci_low = ci[1], ci_high = ci[2], p = p, n = length(i),
       se = sd(a), placebo = a)
}

# The set {b : p(b) >= alpha} on a fine grid around the estimate, ends refined by bisection.
invert <- function(p_of, beta, s) {
  grid <- seq(beta - 10 * s, beta + 10 * s, length.out = 4001)
  ok <- vapply(grid, function(b) p_of(b) >= ALPHA, TRUE)
  stopifnot(ok[2001], !ok[1], !ok[4001])
  inside <- which(ok)
  if (any(diff(inside) != 1)) cat("  note: the accepted set has gaps; reporting its hull\n")
  edge <- function(out, inn) {
    for (k in 1:40) {
      mid <- (out + inn) / 2
      if (p_of(mid) >= ALPHA) inn <- mid else out <- mid
    }
    inn
  }
  lo <- edge(grid[min(inside) - 1], grid[min(inside)])
  hi <- edge(grid[max(inside) + 1], grid[max(inside)])
  c(lo, hi)
}

compute_specs <- function(d, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  specs <- list()
  placebo <- NULL
  for (rain in FORK_OPTIONS$rain) for (within in FORK_OPTIONS$within)
    for (elections in FORK_OPTIONS$elections) for (weight in FORK_OPTIONS$weight) {
      i <- length(specs) + 1L
      choices <- list(rain = rain, within = within, elections = elections, weight = weight)
      key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
      set.seed(SEED + i)
      s <- test_path(d, rain, within, elections, weight)
      if (i == 1L) placebo <- s
      specs[[i]] <- c(list(choices = choices), s[c("effect", "ci_low", "ci_high", "p", "n")])
      cat(sprintf("  %s: n=%d, %+.3f [%+.3f, %+.3f] p=%.4f\n", key, s$n, s$effect,
                  s$ci_low, s$ci_high, s$p))
    }
  list(specs = specs, main = placebo)
}

estimation <- function(d, main, sre) {
  t <- d$t
  x <- (t$rain_this - t$rain_prev) / 10
  est_table(RUN_TIME,
    dependent = txt("Change in turnout from the previous election, percentage points",
                    "Veränderung der Wahlbeteiligung gegenüber der Vorwahl, Prozentpunkte"),
    method = txt("Least squares, constants per Land and election; permutation test with rain of other years, R = 10,000",
                 "Kleinste Quadrate, Konstanten je Land und Wahl; Permutationstest mit Regen anderer Jahre, R = 10.000"),
    sample = txt("Bundestag elections 2005–2025, Wahlkreise",
                 "Bundestagswahlen 2005–2025, Wahlkreise"),
    observations = nrow(t),
    rows = list(
      est_row("Rain change, per 10 mm", "Regenänderung, pro 10 mm",
              c(main$effect, main$se, main$ci_low, main$ci_high, main$p))
    ),
    left = list(
      est_stat("Elections (changes)", "Wahlen (Veränderungen)", length(unique(t$election)), 0),
      est_stat("Groups (Land × election)", "Gruppen (Land × Wahl)",
               length(unique(paste(t$election, t$land))), 0),
      est_stat("Mean rain on election day, mm", "Mittlerer Regen am Wahltag, mm",
               mean(t$rain_this), 6),
      est_stat("S.D. of rain change, mm", "S.D. der Regenänderung, mm", sd(10 * x), 6)
    ),
    right = list(
      est_stat("Placebo replicates", "Placebo-Wiederholungen", R, 0),
      est_stat("Seed", "Seed", SEED + 1L, 0),
      est_stat("Significance level", "Signifikanzniveau", ALPHA, 2),
      est_stat("Smallest relevant effect", "Kleinster relevanter Effekt", sre, 2)
    )
  )
}

main <- function() {
  d <- read_data()
  t <- d$t
  cat(sprintf("%d observations (Wahlkreis and election), %d elections\n\n", nrow(t),
              length(unique(t$election))))
  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  cat("Calculation paths (effect = percentage points of turnout per 10 mm more rain):\n")
  res <- compute_specs(d, claim_file$forks)
  specs <- res$specs
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(rain = "day", within = "land", elections = "all",
                                    weight = "none")),
            identical(specs[[1]]$choices, primary))
  main_spec <- specs[[1]]
  est <- estimation(d, res$main, claim_file$claim$smallest_relevant_effect)
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)

  # Figure 1: rain and turnout on each election day (current Wahlkreise of that election; 2002 on
  # the 2005 Wahlkreise, from the previous-election columns of 2005)
  s02 <- t[t$election == 2005, ]
  first <- list(election = 2002L, date = DATES[1], rain = round(sort(s02$rain_prev), 2),
                wet = round(mean(s02$rain_prev >= 1), 4),
                turnout = round(100 * sum(s02$voters_prev) / sum(s02$eligible_prev), 2),
                turnoutPrev = NA)
  per_election <- lapply(seq_along(ELECTIONS)[-1], function(k) {
    s <- t[t$election == ELECTIONS[k], ]
    list(election = ELECTIONS[k], date = DATES[k],
         rain = round(sort(s$rain_this), 2),
         wet = round(mean(s$rain_this >= 1), 4),
         turnout = round(100 * sum(s$voters) / sum(s$eligible), 2),
         turnoutPrev = round(100 * sum(s$voters_prev) / sum(s$eligible_prev), 2))
  })
  per_election <- c(list(first), per_election)
  # Figure 2: residuals of the main calculation (after the Land-and-election constants)
  x <- (t$rain_this - t$rain_prev) / 10
  g <- paste(t$election, t$land)
  fx <- within_slope(t$y, x, g, rep(1, nrow(t)))
  ym <- ave(t$y, g)
  scatter <- data.frame(e = t$election, x = round(10 * fx$Xt[, 1], 2), y = round(t$y - ym, 2))
  # Figure 3: placebo slopes of the main calculation
  # (bins of 0.025 within the central 99%, rounded out to 0.1; the rest counted as outside)
  pl <- res$main$placebo
  edge <- ceiling(10 * max(abs(quantile(pl, c(0.005, 0.995))), abs(main_spec$effect))) / 10
  br <- seq(-edge, edge, by = 0.025)
  inside <- pl >= -edge & pl < edge
  counts <- as.vector(table(cut(pl[inside], br, right = FALSE)))
  placebo <- list(from = -edge, width = 0.025, counts = counts, below = sum(pl < -edge),
                  above = sum(pl >= edge), observed = main_spec$effect)
  # The example in the opening paragraph: the wettest Wahlkreis on any election day
  ex <- t[which.max(t$rain_this), ]
  example <- list(election = ex$election, date = DATES[match(ex$election, ELECTIONS)],
                  wkr = ex$wkr, name = ex$name, rain = round(ex$rain_this, 1),
                  rainPrev = round(ex$rain_prev, 1),
                  turnout = round(100 * ex$voters / ex$eligible, 2),
                  turnoutPrev = round(100 * ex$voters_prev / ex$eligible_prev, 2),
                  landChange = round(mean(t$y[t$election == ex$election & t$land == ex$land]), 2))

  # Inputs for the placebo draws in the reader's browser (main calculation only): y, group,
  # date indices and the rain of every year on both dates, row-major (Wahlkreis × year), 2 decimals.
  # The published p-value and interval are the ones above; the browser makes new draws.
  browser <- list(
    years = YEARS, elections = ELECTIONS, n = nrow(t),
    y = round(t$y, 4),
    g = as.integer(factor(paste(t$election, t$land))),
    dThis = d$date_this, dPrev = d$date_prev,
    this = round(as.vector(t(d$this)), 2), prev = round(as.vector(t(d$prev)), 2)
  )
  writeLines(toJSON(browser, auto_unbox = TRUE, digits = NA), PLACEBO_OUT, useBytes = TRUE)
  cat(sprintf("Wrote %s (%d bytes)\n", PLACEBO_OUT, file.size(PLACEBO_OUT)))

  data <- list(
    meta = list(
      source = "Die Bundeswahlleiterin; Deutscher Wetterdienst, HYRAS-DE-PR v6-1 (CC BY 4.0)",
      updated = format(Sys.Date()),
      period = "Bundestag elections 2002–2025",
      replicates = R,
      observations = nrow(t),
      years = range(YEARS)
    ),
    example = example,
    elections = per_election,
    scatter = scatter,
    placebo = placebo,
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null",
                    dataframe = "rows"), OUT, useBytes = TRUE)
  cat(sprintf("\nWrote %s\n", OUT))
  cat("Rain and turnout per election (median and max rain over Wahlkreise, mm):\n")
  for (p in per_election)
    cat(sprintf("  %d: median %.1f, max %.1f, wet (>= 1 mm) %.0f%%, turnout %.2f (before %s)\n",
                p$election, median(p$rain), max(p$rain), 100 * p$wet, p$turnout,
                format(p$turnoutPrev, nsmall = 2)))
  cat(sprintf("Example: %s %d, %.1f mm (previous election %.1f mm), turnout %.2f -> %.2f\n",
              ex$name, ex$election, ex$rain_this, ex$rain_prev, example$turnoutPrev,
              example$turnout))
  cat(sprintf("  main: %+.3f pp per 10 mm, 95%% CI [%+.3f, %+.3f], p = %.4f, n = %d\n",
              main_spec$effect, main_spec$ci_low, main_spec$ci_high, main_spec$p, main_spec$n))
  yes <- sum(vapply(specs, function(s) s$p < ALPHA && s$effect < 0, TRUE))
  cat(sprintf("  yes paths: %d of %d\n", yes, length(specs)))
}

if (sys.nframe() == 0L) {
  sink(LOG, split = TRUE)
  cat(sprintf("%s, run on %s\n\n", R.version.string,
              format(RUN_TIME, "%Y-%m-%d %H:%M %Z", tz = "UTC")))
  main()
  cat("\n")
  print(sessionInfo())
  sink()
}
