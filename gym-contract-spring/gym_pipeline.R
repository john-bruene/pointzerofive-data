# gym_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline for story #010 "Do more people want out of their gym contract in spring?".
# Pitch with every choice fixed before the analysis: content/pitches/010-gym-contract-spring.md
#
# Inputs:
#   content/incoming/fitness/multiTimeline_fitnessstudio_kuendigen_2026-11-18.csv
#   content/incoming/fitness/multiTimeline_fitnessvertrag_kuendigen_2026-11-18.csv
#       Google Trends, web search, Germany, 2004 to November 2026, monthly, each term exported on
#       its own by John on 18 November 2026 (only needed once, see prep())
#   notebooks/raw/fitness/trends_monthly.csv       (written by prep(), committed)
#   notebooks/claims/gym-contract-spring.json      (claim and fork texts, hand-written)
# Outputs:
#   data/gym-contract-spring.json
#   data/gym-contract-spring.output.txt  (this script's console output via sink(), with
#                                         sessionInfo(); not edited afterwards)
#   The result table of the main calculation (key `estimation`) is built with
#   notebooks/estimation_table.R.
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/gym_pipeline.R
#
# Requires: base R, jsonlite and nlme (ships with R).
#
# Method (pitch §1b)
#   One row per month. A term's series starts in the first calendar year in which every month has
#   an index of at least 1 and ends in October 2026 (November is incomplete). Months with an index
#   of 0 after the start are left out: Google shows 0 when there are too few searches (rule added
#   after the pitch, see the pitch's outcome; only "Fitnessvertrag kündigen" has such months).
#   Model: log index on a spring dummy and one dummy per year, GLS with AR(1) errors over the
#   month number t (corAR1 uses the differences of t, so a left-out month is a gap), REML.
#   Effect = 100 · (exp(b) − 1), per cent more search interest in spring than in the other months
#   of the same year; t-test of b, 95% interval b ± t(0.975, df) · se, transformed the same way.
# ──────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(jsonlite)
  library(nlme)
})
source(file.path("notebooks", "estimation_table.R"))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

INCOMING <- c(
  fitnessstudio = file.path("content", "incoming", "fitness",
                            "multiTimeline_fitnessstudio_kuendigen_2026-11-18.csv"),
  vertrag = file.path("content", "incoming", "fitness",
                      "multiTimeline_fitnessvertrag_kuendigen_2026-11-18.csv")
)
TERMS <- c(fitnessstudio = "Fitnessstudio kündigen", vertrag = "Fitnessvertrag kündigen")
RAW <- file.path("notebooks", "raw", "fitness", "trends_monthly.csv")
CLAIM <- file.path("notebooks", "claims", "gym-contract-spring.json")
OUT <- file.path("data", "gym-contract-spring.json")
LOG <- file.path("data", "gym-contract-spring.output.txt")

LAST_MONTH <- "2026-10"
WINDOWS <- list(feb_apr = 2:4, jan_mar = 1:3, mar_may = 3:5)
ALPHA <- 0.05
RUN_TIME <- Sys.time()

FORK_OPTIONS <- list(
  window = c("feb_apr", "jan_mar", "mar_may"),
  term = c("fitnessstudio", "vertrag"),
  years = c("all", "without_covid", "since_2023")
)

# The two exports as one long table: term, month (YYYY-MM), value. Google writes "<1" for values
# between 0 and 1; these exports have none, and the script stops if one appears.
prep <- function() {
  rows <- lapply(names(INCOMING), function(id) {
    lines <- readLines(INCOMING[[id]], encoding = "UTF-8")
    stopifnot(lines[3] == sprintf("Monat,%s: (Deutschland)", TERMS[[id]]))
    body <- read.csv(text = paste(lines[-(1:3)], collapse = "\n"), header = FALSE,
                     colClasses = "character", col.names = c("month", "value"))
    stopifnot(all(grepl("^[0-9]+$", body$value)), body$month[1] == "2004-01")
    data.frame(term = id, month = body$month, value = as.integer(body$value))
  })
  d <- do.call(rbind, rows)
  dir.create(dirname(RAW), recursive = TRUE, showWarnings = FALSE)
  write.csv(d, RAW, row.names = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("prep: %d monthly values, %s\n\n", nrow(d),
              paste(sprintf("%s %s to %s", names(INCOMING), tapply(d$month, d$term, min)[names(INCOMING)],
                            tapply(d$month, d$term, max)[names(INCOMING)]), collapse = "; ")))
}

# One term's series: from the first year with every month at least 1 to LAST_MONTH, zeros after
# the start left out.
series <- function(raw, id) {
  d <- raw[raw$term == id & raw$month <= LAST_MONTH, ]
  d$year <- as.integer(substr(d$month, 1, 4))
  d$m <- as.integer(substr(d$month, 6, 7))
  full <- tapply(d$value >= 1, d$year, function(x) length(x) == 12 && all(x))
  start <- min(as.integer(names(full)[full]))
  d <- d[d$year >= start, ]
  attr_zero <- sum(d$value == 0)
  d <- d[d$value > 0, ]
  d$t <- (d$year - 2004L) * 12L + d$m
  d$log_value <- log(d$value)
  attr(d, "start") <- start
  attr(d, "zeros") <- attr_zero
  d
}

# The months of one calculation path, with the spring dummy.
path_data <- function(s, window, term, years) {
  d <- s[[term]]
  if (years == "without_covid") d <- d[!d$year %in% c(2020, 2021), ]
  if (years == "since_2023") d <- d[d$year >= 2023, ]
  d$spring <- as.integer(d$m %in% WINDOWS[[window]])
  d
}

gls_fit <- function(d) {
  d$year_f <- factor(d$year)
  gls(log_value ~ spring + year_f, data = d, correlation = corAR1(form = ~ t), method = "REML")
}

# Effect = 100 · (exp(b) − 1); t-test of the spring coefficient with N − p degrees of freedom.
test_path <- function(d) {
  fit <- gls_fit(d)
  tt <- summary(fit)$tTable
  b <- tt["spring", "Value"]
  se <- tt["spring", "Std.Error"]
  df <- fit$dims$N - fit$dims$p
  stopifnot(abs(tt["spring", "p-value"] - 2 * pt(-abs(b / se), df)) < 1e-12)
  q <- qt(1 - ALPHA / 2, df)
  pct <- function(x) 100 * (exp(x) - 1)
  list(effect = pct(b), ci_low = pct(b - q * se), ci_high = pct(b + q * se),
       p = tt["spring", "p-value"], n = nrow(d), b = b, se = se, df = df, fit = fit,
       phi = unname(coef(fit$modelStruct$corStruct, unconstrained = FALSE)))
}

compute_specs <- function(s, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  specs <- list()
  for (window in FORK_OPTIONS$window) {
    for (term in FORK_OPTIONS$term) {
      for (years in FORK_OPTIONS$years) {
        choices <- list(window = window, term = term, years = years)
        key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
        r <- test_path(path_data(s, window, term, years))
        specs[[length(specs) + 1L]] <- c(list(choices = choices),
                                         r[c("effect", "ci_low", "ci_high", "p", "n")])
        cat(sprintf("  %s: n=%d, %+.1f%% [%+.1f, %+.1f] p=%.4f\n", key, r$n, r$effect,
                    r$ci_low, r$ci_high, r$p))
      }
    }
  }
  specs
}

# The result table of the main calculation (estimation_table.R).
estimation <- function(d, r, sre) {
  q <- qt(1 - ALPHA / 2, r$df)
  co <- summary(r$fit)$tTable
  est_table(RUN_TIME,
    dependent = txt("Log of the Google Trends index, “Fitnessstudio kündigen”",
                    "Logarithmus des Google-Trends-Index, „Fitnessstudio kündigen“"),
    method = txt("GLS with AR(1) errors between months, REML; dummies for each year",
                 "GLS mit AR(1)-Fehlern zwischen Monaten, REML; Dummys für jedes Jahr"),
    sample = txt(sprintf("%s–%s (monthly)", min(d$month), max(d$month)),
                 sprintf("%s–%s (monatlich)", min(d$month), max(d$month))),
    observations = nrow(d),
    rows = list(
      est_row("Constant (2011)", "Konstante (2011)",
              c(co[1, "Value"], co[1, "Std.Error"], co[1, "Value"] - q * co[1, "Std.Error"],
                co[1, "Value"] + q * co[1, "Std.Error"], co[1, "p-value"])),
      est_row("Spring (Feb–Apr), log", "Frühjahr (Feb.–Apr.), log",
              c(r$b, r$se, r$b - q * r$se, r$b + q * r$se, r$p)),
      est_row("Spring, per cent", "Frühjahr, Prozent",
              c(r$effect, 100 * exp(r$b) * r$se, r$ci_low, r$ci_high, r$p))
    ),
    left = list(
      est_stat("Months", "Monate", nrow(d), 0),
      est_stat("Year dummies", "Jahres-Dummys", length(unique(d$year)) - 1, 0),
      est_stat("AR(1) coefficient", "AR(1)-Koeffizient", r$phi, 4),
      est_stat("Log likelihood (REML)", "Log-Likelihood (REML)", as.numeric(logLik(r$fit)), 4)
    ),
    right = list(
      est_stat("Degrees of freedom", "Freiheitsgrade", r$df, 0),
      est_stat("Residual S.E.", "Std.-Fehler der Residuen", r$fit$sigma, 4),
      est_stat("Significance level", "Signifikanzniveau", ALPHA, 2),
      est_stat("Smallest relevant effect (%)", "Kleinster relevanter Effekt (%)", sre, 0)
    )
  )
}

# Average deviation of each calendar month from its year's mean (log scale), complete years only,
# with a t-interval over the years; as per cent (figure 2, descriptive).
month_profile <- function(d) {
  d <- d[d$year <= 2025, ]
  d$dev <- d$log_value - ave(d$log_value, d$year)
  lapply(1:12, function(m) {
    x <- d$dev[d$m == m]
    ci <- t.test(x, conf.level = 1 - ALPHA)$conf.int
    list(month = m, n = length(x), pct = round(100 * (exp(mean(x)) - 1), 2),
         lo = round(100 * (exp(ci[1]) - 1), 2), hi = round(100 * (exp(ci[2]) - 1), 2))
  })
}

main <- function() {
  if (!file.exists(RAW)) prep()
  raw <- read.csv(RAW, encoding = "UTF-8", stringsAsFactors = FALSE)
  s <- lapply(names(TERMS), function(id) series(raw, id))
  names(s) <- names(TERMS)
  for (id in names(TERMS)) {
    cat(sprintf("%s: from %d, %d months, %d months with index 0 left out\n", TERMS[[id]],
                attr(s[[id]], "start"), nrow(s[[id]]), attr(s[[id]], "zeros")))
  }

  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  cat("\nCalculation paths (effect = per cent more search interest in spring):\n")
  specs <- compute_specs(s, claim_file$forks)
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(window = "feb_apr", term = "fitnessstudio", years = "all")))
  main_d <- path_data(s, "feb_apr", "fitnessstudio", "all")
  main_r <- test_path(main_d)
  main_spec <- specs[[which(vapply(specs, function(x) identical(x$choices, primary), TRUE))]]
  stopifnot(abs(main_r$p - main_spec$p) < 1e-12)
  # corAR1 over t treats left-out months as gaps; with no gap it equals corCAR1 (check)
  car <- gls(log_value ~ spring + factor(year), data = main_d, correlation = corCAR1(form = ~ t),
             method = "REML")
  stopifnot(abs(coef(car)[["spring"]] - main_r$b) < 1e-6)
  est <- estimation(main_d, main_r, claim_file$claim$smallest_relevant_effect)
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)

  fs <- s$fitnessstudio
  complete <- fs[fs$year <= 2025, ]
  spring <- complete$m %in% WINDOWS$feb_apr
  peak <- tapply(complete$m[ave(complete$value, complete$year, FUN = max) == complete$value],
                 complete$year[ave(complete$value, complete$year, FUN = max) == complete$value],
                 function(x) x[1])
  data <- list(
    meta = list(
      source = "Google Trends (web search, Germany), exported by John Brüne on 18 November 2026",
      updated = format(Sys.Date()),
      accessed = "2026-11-18",
      lastMonth = LAST_MONTH
    ),
    summary = list(
      start = attr(fs, "start"),
      months = nrow(fs),
      vertragStart = attr(s$vertrag, "start"),
      vertragMonths = nrow(s$vertrag),
      vertragZeros = attr(s$vertrag, "zeros"),
      rawSpring = round(mean(complete$value[spring]), 2),
      rawOther = round(mean(complete$value[!spring]), 2),
      januaryPeaks = sum(peak == 1),
      completeYears = length(peak)
    ),
    series = lapply(seq_len(nrow(fs)), function(i) list(month = fs$month[i], value = fs$value[i])),
    profile = month_profile(fs),
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null"), OUT,
             useBytes = TRUE)
  cat(sprintf("\nWrote %s\n", OUT))
  cat(sprintf("  raw means 2011-2025: spring %.2f, other months %.2f; January the top month in %d of %d years\n",
              data$summary$rawSpring, data$summary$rawOther, data$summary$januaryPeaks,
              data$summary$completeYears))
  cat(sprintf("  main: %+.1f per cent, 95%% CI [%+.1f, %+.1f], p = %.4f, n = %d\n",
              main_spec$effect, main_spec$ci_low, main_spec$ci_high, main_spec$p, main_spec$n))
  yes <- sum(vapply(specs, function(x) x$p < ALPHA && x$effect > 0, TRUE))
  cat(sprintf("  yes paths: %d of %d\n", yes, length(specs)))
}

if (sys.nframe() == 0L) {
  sink(LOG, split = TRUE)
  cat(sprintf("%s, run on %s\n\n", R.version.string, format(RUN_TIME, "%Y-%m-%d %H:%M %Z", tz = "UTC")))
  main()
  cat("\n")
  print(sessionInfo())
  sink()
}
