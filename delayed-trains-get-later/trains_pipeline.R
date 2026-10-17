# trains_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline for story #006 "Does a late train get even later?".
# Pitch with every choice fixed before the analysis: content/pitches/006-delayed-trains-get-later.md
#
# Inputs:
#   notebooks/raw/trains/runs_de.csv.gz, runs_ch.csv.gz  (one row per train run, written by
#                                                         trains_extract.py)
#   notebooks/claims/delayed-trains-get-later.json      (claim and fork texts, hand-written)
# Outputs:
#   data/delayed-trains-get-later.json
#   data/delayed-trains-get-later.output.txt  (this script's console output via sink(), with
#                                              sessionInfo(); not edited afterwards)
#   The result table of the main calculation (key `estimation`) is built with
#   notebooks/estimation_table.R.
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/trains_pipeline.R
#
# Requires: base R, jsonlite, lme4 and lmerTest.
#
# Method
#   Late at stop A: departure delay at the middle stop >= threshold; on time: < 6 minutes.
#   y = arrival delay at the end minus delay at A (additional delay, minutes). Linear mixed model
#   y ~ late + (1 | train pattern and stop A) + (1 | day), fitted by REML: crossed random
#   intercepts, one per train pattern with its stop A (the same train on different days) and one
#   per day (a disrupted day affects all trains). Effect = coefficient of "late"; t-test with
#   Satterthwaite degrees of freedom (lmerTest), 95% interval from the same t distribution.
# ──────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(jsonlite)
  library(lme4)
  library(lmerTest)
})
source(file.path("notebooks", "estimation_table.R"))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

RAW <- c(de = file.path("notebooks", "raw", "trains", "runs_de.csv.gz"),
         ch = file.path("notebooks", "raw", "trains", "runs_ch.csv.gz"))
CLAIM <- file.path("notebooks", "claims", "delayed-trains-get-later.json")
OUT <- file.path("data", "delayed-trains-get-later.json")
LOG <- file.path("data", "delayed-trains-get-later.output.txt")

ALPHA <- 0.05
ONTIME <- 6      # on time at A: delay < 6 minutes (Deutsche Bahn's definition)
RUN_TIME <- Sys.time()
# The run in the opening paragraph: ICE 599 Berlin–München on 1 September 2026 (stop A: Fulda)
EXAMPLE_RUN <- "8510695562531992552-2609011109"

FORK_OPTIONS <- list(
  country = c("de", "ch"),
  trains = c("all", "long", "regional"),
  threshold = c("6", "11", "16"),
  cancel = c("drop", "lastserved")
)
LONG <- list(de = c("ICE", "IC", "EC", "ECE", "RJ", "RJX", "NJ", "EN", "FLX", "TGV"),
             ch = c("IC", "IR", "EC", "ICE", "TGV", "RJX", "NJ", "EN"))

read_runs <- function(path) {
  d <- read.csv(gzfile(path), stringsAsFactors = FALSE,
                colClasses = c(day = "character", run = "character", pattern = "character",
                               a_station = "character", train_type = "character"))
  d$stratum <- paste(d$pattern, d$a_station, sep = "|")
  d
}

# Runs of one path with y (additional delay) and late (TRUE/FALSE).
path_data <- function(runs, country, trains, threshold, cancel) {
  d <- runs[[country]]
  if (trains == "long") d <- d[d$train_type %in% LONG[[country]], ]
  if (trains == "regional") d <- d[!d$train_type %in% LONG[[country]], ]
  if (cancel == "drop") {
    d <- d[d$cancelled_after == 0 & !is.na(d$delay_end), ]
    d$y <- d$delay_end - d$delay_a
  } else {
    d <- d[!is.na(d$delay_last), ]
    d$y <- d$delay_last - d$delay_a
  }
  t <- as.numeric(threshold)
  d <- d[d$delay_a >= t | d$delay_a < ONTIME, ]
  d$late <- d$delay_a >= t
  d
}

# Linear mixed model with crossed random intercepts for train pattern (with stop A) and day.
fit_lmm <- function(d) {
  lmer(y ~ late + (1 | stratum) + (1 | day), data = d, REML = TRUE)
}

# Effect = coefficient of "late" (minutes, late minus on time); Satterthwaite t-test.
test_path <- function(d) {
  fit <- fit_lmm(d)
  co <- summary(fit)$coefficients
  est <- co["lateTRUE", "Estimate"]
  se <- co["lateTRUE", "Std. Error"]
  df <- co["lateTRUE", "df"]
  q <- qt(1 - ALPHA / 2, df)
  list(effect = est, ci_low = est - q * se, ci_high = est + q * se,
       p = co["lateTRUE", "Pr(>|t|)"], n = nrow(d), se = se, df = df, fit = fit)
}

compute_specs <- function(runs, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  specs <- list()
  for (country in FORK_OPTIONS$country) for (trains in FORK_OPTIONS$trains)
    for (threshold in FORK_OPTIONS$threshold) for (cancel in FORK_OPTIONS$cancel) {
      i <- length(specs) + 1L
      choices <- list(country = country, trains = trains, threshold = threshold, cancel = cancel)
      key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
      s <- test_path(path_data(runs, country, trains, threshold, cancel))
      specs[[i]] <- c(list(choices = choices), s[c("effect", "ci_low", "ci_high", "p", "n")])
      if (i == 1L) main_fit <<- s
      cat(sprintf("  %s: n=%d, %+.3f [%+.3f, %+.3f] p=%.4f\n", key, s$n, s$effect,
                  s$ci_low, s$ci_high, s$p))
    }
  specs
}

# The result table of the main calculation (estimation_table.R), from the fit of path 1.
estimation <- function(d, s, sre) {
  co <- summary(s$fit)$coefficients
  row <- function(term) {
    q <- qt(1 - ALPHA / 2, co[term, "df"])
    c(co[term, "Estimate"], co[term, "Std. Error"], co[term, "Estimate"] - q * co[term, "Std. Error"],
      co[term, "Estimate"] + q * co[term, "Std. Error"], co[term, "Pr(>|t|)"])
  }
  vc <- as.data.frame(VarCorr(s$fit))
  sd_of <- function(g) vc$sdcor[vc$grp == g]
  est_table(RUN_TIME,
    dependent = txt("Additional delay from stop A to the final stop, minutes",
                    "Zusätzliche Verspätung von Halt A bis zum Endhalt, Minuten"),
    method = txt("Linear mixed model (REML), random intercepts for train pattern and day, t-test (Satterthwaite)",
                 "Lineares gemischtes Modell (REML), zufällige Konstanten je Zuglauf und Tag, t-Test (Satterthwaite)"),
    sample = txt("Deutsche Bahn, all trains, September 2026",
                 "Deutsche Bahn, alle Züge, September 2026"),
    observations = nrow(d),
    rows = list(
      est_row("Constant (on time at A)", "Konstante (pünktlich an A)", row("(Intercept)")),
      est_row("Late at A (≥ 6 min)", "Verspätet an A (ab 6 Min.)", row("lateTRUE"))
    ),
    left = list(
      est_stat("Runs late at A", "Fahrten verspätet an A", sum(d$late), 0),
      est_stat("Runs on time at A", "Fahrten pünktlich an A", sum(!d$late), 0),
      est_stat("Train patterns with stop A", "Zugläufe mit Halt A", length(unique(d$stratum)), 0),
      est_stat("Mean delay at A, late runs", "Mittlere Verspätung an A, verspätet",
               mean(d$delay_a[d$late]), 6)
    ),
    right = list(
      est_stat("S.D. train pattern effect", "Std.-Abw. Zuglauf-Effekt", sd_of("stratum"), 6),
      est_stat("S.D. day effect", "Std.-Abw. Tages-Effekt", sd_of("day"), 6),
      est_stat("Significance level", "Signifikanzniveau", ALPHA, 2),
      est_stat("Smallest relevant effect", "Kleinster relevanter Effekt", sre, 2)
    )
  )
}

# Mean additional delay by delay at A in whole minutes (figure 1), no comparison within patterns.
by_delay <- function(d) {
  bin <- pmin(pmax(floor(d$delay_a), -2), 30)
  out <- lapply(sort(unique(bin)), function(b) {
    y <- d$y[bin == b]
    list(delayA = b, n = length(y), extra = round(mean(y), 3))
  })
  out
}

main <- function() {
  runs <- lapply(RAW, read_runs)
  for (cc in names(runs)) {
    r <- runs[[cc]]
    cat(sprintf("%s: %d runs, %d patterns, %d days; delay at A known for all, end known for %d\n",
                toupper(cc), nrow(r), length(unique(r$pattern)), length(unique(r$day)),
                sum(!is.na(r$delay_end))))
  }
  cat("\n")
  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  cat("Calculation paths (effect = extra minutes lost after stop A, late minus on time):\n")
  specs <- compute_specs(runs, claim_file$forks)
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(country = "de", trains = "all", threshold = "6",
                                    cancel = "drop")))
  main_i <- which(vapply(specs, function(s) identical(s$choices, primary), TRUE))
  main_spec <- specs[[main_i]]
  d_main <- path_data(runs, "de", "all", "6", "drop")
  stopifnot(main_i == 1L, abs(main_fit$effect - main_spec$effect) < 1e-12)
  est <- estimation(d_main, main_fit, claim_file$claim$smallest_relevant_effect)
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)

  # Figure 1: every run with a known end and no cancellation after A, Germany and Switzerland
  fig1 <- lapply(c("de", "ch"), function(cc) {
    d <- runs[[cc]]
    d <- d[d$cancelled_after == 0 & !is.na(d$delay_end), ]
    d$y <- d$delay_end - d$delay_a
    list(country = cc, bins = by_delay(d))
  })
  cancel_rate <- lapply(c("de", "ch"), function(cc) {
    d <- runs[[cc]]
    late <- d$delay_a >= 6
    list(country = cc, late = round(mean(d$cancelled_after[late] == 1), 4),
         ontime = round(mean(d$cancelled_after[d$delay_a < ONTIME] == 1), 4))
  })

  data <- list(
    meta = list(
      source = paste0("Deutsche Bahn Timetables API via piebro/deutsche-bahn-data (CC BY 4.0); ",
                      "opentransportdata.swiss Ist-Daten"),
      updated = format(Sys.Date()),
      period = "September 2026",
      runs = lapply(runs, nrow),
      patterns = lapply(runs, function(r) length(unique(r$pattern)))
    ),
    example = as.list(runs$de[runs$de$run == EXAMPLE_RUN,
                              c("day", "train_type", "n_stops", "delay_a", "delay_end")]),
    byDelay = fig1,
    cancelRate = cancel_rate,
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null"), OUT,
             useBytes = TRUE)
  cat(sprintf("\nWrote %s\n", OUT))
  cat("Mean additional delay by delay at A (Germany, no cancellation after A):\n")
  print(do.call(rbind, lapply(fig1[[1]]$bins, as.data.frame)), row.names = FALSE)
  cat("Share of runs with a cancellation after A:\n")
  print(do.call(rbind, lapply(cancel_rate, as.data.frame)), row.names = FALSE)
  cat(sprintf("  main: %+.3f minutes, 95%% CI [%+.3f, %+.3f], p = %.4f, n = %d\n",
              main_spec$effect, main_spec$ci_low, main_spec$ci_high, main_spec$p, main_spec$n))
  yes <- sum(vapply(specs, function(s) s$p < ALPHA && s$effect > 0, TRUE))
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
