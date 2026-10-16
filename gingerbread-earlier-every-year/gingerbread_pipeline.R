# gingerbread_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline for story #004 "Does the gingerbread season start earlier every year?".
# Pitch with every choice fixed before the analysis: content/pitches/004-gingerbread-earlier-every-year.md
#
# Inputs:
#   notebooks/raw/gingerbread/trends_daily.csv   (Google Trends, written by gingerbread_download.py)
#   notebooks/claims/gingerbread-earlier-every-year.json  (claim and fork texts, hand-written)
# Outputs:
#   data/gingerbread-earlier-every-year.json
#   data/gingerbread-earlier-every-year.output.txt  (this script's console output via sink(),
#                                                    with sessionInfo(); not edited afterwards)
#   The result table of the main calculation (key `estimation`) is built with
#   notebooks/estimation_table.R.
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/gingerbread_pipeline.R
#
# Requires: base R and jsonlite.
#
# Method (pitch §1b)
#   Daily search interest, Germany, 1 June to 31 December of each season, three terms in one
#   request. For each season and treat: the 7-day mean ending on each day; the peak is its largest
#   value; the onset is the first day from which the 7-day mean stays at or above a share of the
#   peak until the peak, counted in days after 1 June. Effect = minus the OLS slope of onset on
#   year (days earlier per year); t-test with n − 2 degrees of freedom and the 95% interval from
#   the same t distribution. No random numbers anywhere, so no seed.
# ──────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages(library(jsonlite))
source(file.path("notebooks", "estimation_table.R"))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

RAW <- file.path("notebooks", "raw", "gingerbread", "trends_daily.csv")
DOWNLOAD_LOG <- file.path("notebooks", "raw", "gingerbread", "download_log.json")
CLAIM <- file.path("notebooks", "claims", "gingerbread-earlier-every-year.json")
OUT <- file.path("data", "gingerbread-earlier-every-year.json")
LOG <- file.path("data", "gingerbread-earlier-every-year.output.txt")

TERMS <- c(lebkuchen = "Lebkuchen", spekulatius = "Spekulatius", dominosteine = "Dominosteine")
SEASONS <- 2004:2025
DAYS <- 214L     # 1 June to 31 December
WINDOW <- 7L     # days in the moving mean
ALPHA <- 0.05
RUN_TIME <- Sys.time()

FORK_OPTIONS <- list(
  treat = c("lebkuchen", "spekulatius", "all"),
  threshold = c("10", "20", "30"),
  years = c("all", "from2011", "from2016")
)
FIRST_YEAR <- c(all = 2004L, from2011 = 2011L, from2016 = 2016L)

# Daily values per season (rows) and day after 1 June (columns, 0 = 1 June) for one treat.
series <- function(raw, treat) {
  terms <- if (treat == "all") unname(TERMS) else TERMS[[treat]]
  d <- raw[raw$term %in% terms, ]
  day <- as.integer(as.Date(d$date) - as.Date(sprintf("%d-06-01", d$season)))
  v <- tapply(d$value, list(d$season, day), sum)
  stopifnot(identical(dim(v), c(length(SEASONS), DAYS)), !anyNA(v),
            identical(colnames(v), as.character(0:(DAYS - 1L))))
  v
}

# 7-day mean ending on each day; NA for the first six days.
moving_mean <- function(x, k = WINDOW) {
  m <- stats::filter(x, rep(1 / k, k), sides = 1)
  as.numeric(m)
}

# Onset: first day from which the moving mean stays at or above share × peak until the peak.
onset <- function(x, share) {
  m <- moving_mean(x)
  peak <- which.max(m)
  stopifnot(m[peak] > 0)
  level <- share * m[peak]
  d <- peak
  while (d > WINDOW && m[d - 1] >= level) d <- d - 1
  as.integer(d - 1L)    # column index 1 is 1 June = day 0
}

# OLS of onset on year; effect = days earlier per year = minus the slope.
test_path <- function(years, onsets) {
  fit <- lm(onsets ~ years)
  co <- summary(fit)$coefficients
  slope <- co["years", "Estimate"]
  se <- co["years", "Std. Error"]
  df <- fit$df.residual
  q <- qt(1 - ALPHA / 2, df)
  p <- 2 * pt(-abs(slope / se), df)
  stopifnot((p < ALPHA) == (abs(slope) > q * se))
  list(effect = -slope, ci_low = -slope - q * se, ci_high = -slope + q * se, p = p,
       n = length(years))
}

# Onset per season, treat and threshold.
all_onsets <- function(raw) {
  out <- list()
  for (treat in FORK_OPTIONS$treat) {
    s <- series(raw, treat)
    for (th in FORK_OPTIONS$threshold) {
      out[[paste(treat, th, sep = "|")]] <-
        vapply(rownames(s), function(y) onset(s[y, ], as.numeric(th) / 100), 0L)
    }
  }
  out
}

# Every combination of the forks in the claim file, in fork order.
compute_specs <- function(onsets, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  specs <- list()
  for (treat in FORK_OPTIONS$treat) {
    for (threshold in FORK_OPTIONS$threshold) {
      for (years in FORK_OPTIONS$years) {
        choices <- list(treat = treat, threshold = threshold, years = years)
        key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
        o <- onsets[[paste(treat, threshold, sep = "|")]]
        y <- as.integer(names(o))
        keep <- y >= FIRST_YEAR[[years]]
        s <- test_path(y[keep], o[keep])
        specs[[length(specs) + 1L]] <- c(list(choices = choices), s)
        cat(sprintf("  %s: n=%d, %+.3f [%+.3f, %+.3f] p=%.4f\n", key, s$n, s$effect,
                    s$ci_low, s$ci_high, s$p))
      }
    }
  }
  specs
}

# The result table of the main calculation (estimation_table.R): the OLS line of onset on years
# since 2004, with the slope turned into days earlier per year as the last row.
estimation <- function(years, onsets, spec, threshold, sre) {
  x <- years - min(years)
  fit <- lm(onsets ~ x)
  sm <- summary(fit)
  co <- sm$coefficients
  df <- fit$df.residual
  earlier <- est_values_t(-co["x", "Estimate"], co["x", "Std. Error"], df)
  stopifnot(isTRUE(all.equal(earlier[c(1, 3:5)],
                             c(spec$effect, spec$ci_low, spec$ci_high, spec$p))))
  r <- residuals(fit)
  est_table(RUN_TIME,
    dependent = txt("Onset of the season, days after 1 June",
                    "Saisonbeginn, Tage nach dem 1. Juni"),
    method = txt("Least squares, t-test of the slope",
                 "Kleinste Quadrate, t-Test der Steigung"),
    sample = txt(sprintf("Seasons %d–%d, Google Trends, Germany", min(years), max(years)),
                 sprintf("Saisons %d–%d, Google Trends, Deutschland", min(years), max(years))),
    observations = length(years),
    rows = list(
      est_row(sprintf("Onset in %d (C)", min(years)), sprintf("Beginn %d (C)", min(years)),
              est_values_t(co["(Intercept)", "Estimate"], co["(Intercept)", "Std. Error"], df)),
      est_row("Days earlier per year", "Tage früher pro Jahr", earlier)
    ),
    left = list(
      est_stat("R-squared", "R²", sm$r.squared, 6),
      est_stat("Adjusted R-squared", "Korrigiertes R²", sm$adj.r.squared, 6),
      est_stat("S.E. of regression", "Std.-Fehler der Regression", sm$sigma, 6),
      est_stat("Durbin-Watson stat", "Durbin-Watson-Statistik",
               sum(diff(r)^2) / sum(r^2), 6)
    ),
    right = list(
      est_stat("Mean dependent var", "Mittelwert abh. Variable", mean(onsets), 6),
      est_stat("S.D. dependent var", "Std.-Abw. abh. Variable", sd(onsets), 6),
      est_stat("Threshold (share of peak)", "Schwelle (Anteil am Höhepunkt)", threshold, 2),
      est_stat("Smallest relevant effect", "Kleinster relevanter Effekt", sre, 2)
    )
  )
}

main <- function() {
  raw <- read.csv(RAW, encoding = "UTF-8", stringsAsFactors = FALSE)
  stopifnot(setequal(unique(raw$season), SEASONS), setequal(unique(raw$term), TERMS),
            nrow(raw) == length(SEASONS) * DAYS * length(TERMS))
  dl <- fromJSON(DOWNLOAD_LOG)
  cat(sprintf("Google Trends: %d seasons, %d terms, %d daily values; downloaded %s to %s UTC\n\n",
              length(SEASONS), length(TERMS), nrow(raw), min(unlist(dl)), max(unlist(dl))))

  onsets <- all_onsets(raw)
  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  cat("Calculation paths (effect = days earlier per year):\n")
  specs <- compute_specs(onsets, claim_file$forks)
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(treat = "lebkuchen", threshold = "20", years = "all")))
  main_spec <- Filter(function(s) identical(s$choices, primary), specs)[[1]]

  o <- onsets[["lebkuchen|20"]]
  years <- as.integer(names(o))
  est <- estimation(years, o, main_spec, 0.2, claim_file$claim$smallest_relevant_effect)
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)

  # Figure 1: 7-day means of "Lebkuchen" per season, on the scale of each request
  lk <- series(raw, "lebkuchen")
  daily <- lapply(rownames(lk), function(y) {
    m <- moving_mean(lk[y, ])
    list(season = as.integer(y), mean7 = round(m[WINDOW:DAYS], 2))
  })
  # Onsets per season for every treat and threshold (figure 2 and the data repository)
  date_of <- function(d) format(as.Date("2000-06-01") + d, "%m-%d")
  seasons <- lapply(seq_along(years), function(i) {
    out <- list(season = years[i])
    for (k in names(onsets)) out[[sub("|", "_", k, fixed = TRUE)]] <- unname(onsets[[k]][i])
    out$date <- date_of(o[[i]])
    out$zeros <- sum(lk[i, ] == 0)                       # days with value 0 ("Lebkuchen")
    out$peakDay <- which.max(moving_mean(lk[i, ])) - 1L   # day of the peak, after 1 June
    out
  })
  fit <- lm(o ~ years)

  # Checked after the result, not part of the pitch: the main calculation without 2004, the
  # season with the most days at 0.
  without2004 <- test_path(years[years > 2004], o[years > 2004])
  cat(sprintf("\nNot preregistered: without 2004 %+.3f [%+.3f, %+.3f] p=%.4f, n=%d\n",
              without2004$effect, without2004$ci_low, without2004$ci_high, without2004$p,
              without2004$n))

  data <- list(
    meta = list(
      source = "Google Trends (web search, Germany), \"Source: Google Trends\"",
      updated = format(Sys.Date()),
      downloaded = max(unlist(dl)),
      seasons = sprintf("%d–%d", min(SEASONS), max(SEASONS)),
      window = WINDOW,
      terms = unname(TERMS)
    ),
    seasons = seasons,
    daily = daily,
    line = list(intercept = unname(coef(fit)[1]), slope = unname(coef(fit)[2])),
    checks = list(without2004 = without2004),
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null"), OUT,
             useBytes = TRUE)
  cat(sprintf("\nWrote %s\n", OUT))
  cat("Onset per season (Lebkuchen, 20% of peak):\n")
  print(data.frame(season = years, days_after_1_june = unname(o), date = date_of(o)),
        row.names = FALSE)
  cat(sprintf("  main: %+.3f days earlier per year, 95%% CI [%+.3f, %+.3f], p = %.4f, n = %d\n",
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
