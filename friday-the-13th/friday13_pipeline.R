# friday13_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline for story #002 "Are there more road accidents on Friday the 13th?".
#
# Inputs:
#   notebooks/raw/stats19/daily_collisions.csv        collisions per day and severity, Great
#                                                     Britain (STATS19, Open Government Licence
#                                                     v3.0; counted by friday13_prep.py)
#   notebooks/raw/stats19/daily_collisions.meta.json  provenance of the daily counts
#   notebooks/raw/stats19/bank_holidays_eng.csv       bank holidays, England and Wales
#                                                     (written by friday13_holidays.py)
#   notebooks/claims/friday-the-13th.json             claim and fork texts, hand-written
# Outputs:
#   data/friday-the-13th.json
#   data/friday-the-13th.output.txt  (this script's console output via sink(), with sessionInfo())
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/friday13_pipeline.R
#
# Requires: base R and jsonlite.
#
# Method
#   For every month with a Friday the 13th: the collisions on the 13th and on the comparison days
#   of the same month (fork comparison), all collisions, killed-or-seriously-injured or fatal
#   (fork outcome), bank holidays left out or kept (fork holidays). Poisson regression of the daily
#   count on a dummy for the 13th and one constant per month, with overdispersion (quasi-Poisson):
#   the dispersion is estimated and the test is a t-test. Effect = 100 (exp(beta) - 1) per cent.
# ──────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages(library(jsonlite))
source(file.path("notebooks", "estimation_table.R"))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

DAILY <- file.path("notebooks", "raw", "stats19", "daily_collisions.csv")
DAILY_META <- file.path("notebooks", "raw", "stats19", "daily_collisions.meta.json")
HOLIDAYS <- file.path("notebooks", "raw", "stats19", "bank_holidays_eng.csv")
CLAIM <- file.path("notebooks", "claims", "friday-the-13th.json")
OUT <- file.path("data", "friday-the-13th.json")
LOG <- file.path("data", "friday-the-13th.output.txt")

ALPHA <- 0.05
RUN_TIME <- Sys.time()
FORK_OPTIONS <- list(
  comparison = c("all_days", "fridays", "friday_6th"),
  outcome = c("all", "ksi", "fatal"),
  holidays = c("exclude", "keep")
)
WEEKDAYS <- c("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")

read_daily <- function() {
  d <- read.csv(DAILY, stringsAsFactors = FALSE)
  d$date <- as.Date(d$date)
  stopifnot(all(diff(d$date) == 1))
  d
}

# Monday = 1 … Sunday = 7, independent of the locale
wday <- function(x) as.integer(format(x, "%u"))

fridays_13th <- function(first, last) {
  days <- as.Date(sprintf("%d-%02d-13", rep(first:last, each = 12), rep(1:12, last - first + 1)))
  days[wday(days) == 5]
}

comparison_days <- function(d13, comparison) {
  if (comparison == "all_days") {
    month_days <- seq(as.Date(format(d13, "%Y-%m-01")), by = "day", length.out = 31)
    month_days <- month_days[format(month_days, "%m") == format(d13, "%m")]
    return(month_days[month_days != d13])
  }
  if (comparison == "fridays") return(d13 + c(-7, 7))
  if (comparison == "friday_6th") return(d13 - 7)
  stop(comparison)
}

# One row per day used: month (the Friday the 13th it belongs to), dummy for the 13th, count.
path_data <- function(daily, outcome, comparison, hol) {
  count <- setNames(daily[[outcome]], as.character(daily$date))
  d13s <- fridays_13th(as.integer(format(min(daily$date), "%Y")),
                       as.integer(format(max(daily$date), "%Y")))
  rows <- list()
  for (k in seq_along(d13s)) {
    d13 <- d13s[k]
    if (!is.null(hol) && d13 %in% hol) next
    days <- comparison_days(d13, comparison)
    if (!is.null(hol)) days <- days[!days %in% hol]
    if (!length(days)) next
    all_days <- c(d13, days)
    rows[[length(rows) + 1]] <- data.frame(month = format(d13), is13 = c(1, rep(0, length(days))),
                                           count = unname(count[as.character(all_days)]))
  }
  do.call(rbind, rows)
}

# Quasi-Poisson regression with a constant per month; t-test of the dummy for the 13th.
test_path <- function(dat) {
  fit <- glm(count ~ is13 + factor(month), family = quasipoisson, data = dat)
  co <- summary(fit)$coefficients
  b <- co["is13", "Estimate"]
  se <- co["is13", "Std. Error"]
  df <- fit$df.residual
  q <- qt(1 - ALPHA / 2, df)
  pct <- function(v) 100 * (exp(v) - 1)
  list(effect = pct(b), ci_low = pct(b - q * se), ci_high = pct(b + q * se),
       p = co["is13", "Pr(>|t|)"], n = sum(dat$is13), b = b, se = se, df = df, fit = fit)
}

compute_specs <- function(daily, hol, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  specs <- list()
  for (comparison in FORK_OPTIONS$comparison) for (outcome in FORK_OPTIONS$outcome)
    for (holidays in FORK_OPTIONS$holidays) {
      choices <- list(comparison = comparison, outcome = outcome, holidays = holidays)
      key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
      s <- test_path(path_data(daily, outcome, comparison,
                               if (holidays == "exclude") hol else NULL))
      specs[[length(specs) + 1]] <- c(list(choices = choices),
                                      s[c("effect", "ci_low", "ci_high", "p", "n")])
      cat(sprintf("  %s: n=%d, %+.2f%% [%+.2f, %+.2f] p=%.4f\n", key, s$n, s$effect,
                  s$ci_low, s$ci_high, s$p))
    }
  specs
}

estimation <- function(s, dat, years, sre) {
  disp <- summary(s$fit)$dispersion
  est_table(RUN_TIME,
    dependent = txt("Collisions with injuries per day",
                    "Unfälle mit Verletzten pro Tag"),
    method = txt("Poisson regression with overdispersion (quasi-Poisson), constant per month, t-test",
                 "Poisson-Regression mit Überdispersion (Quasi-Poisson), Konstante je Monat, t-Test"),
    sample = txt(sprintf("Great Britain %s, Fridays the 13th and the Fridays a week before and after", years),
                 sprintf("Großbritannien %s, Freitage, der 13., und die Freitage eine Woche davor und danach", years)),
    observations = nrow(dat),
    rows = list(
      est_row("Friday 13th (log)", "Freitag, 13. (log)",
              est_values_t(s$b, s$se, s$df)),
      est_row("Effect, % = 100(exp-1)", "Effekt, % = 100(exp-1)",
              c(s$effect, NA, s$ci_low, s$ci_high, s$p))
    ),
    left = list(
      est_stat("Fridays the 13th (months)", "Freitage, der 13. (Monate)", s$n, 0),
      est_stat("Comparison Fridays", "Vergleichsfreitage", nrow(dat) - s$n, 0),
      est_stat("Month constants", "Monatskonstanten", length(unique(dat$month)), 0),
      est_stat("Dispersion", "Dispersion", disp, 6)
    ),
    right = list(
      est_stat("Degrees of freedom", "Freiheitsgrade", s$df, 0),
      est_stat("Significance level", "Signifikanzniveau", ALPHA, 2),
      est_stat("Smallest relevant effect, %", "Kleinster relevanter Effekt, %", sre, 2)
    )
  )
}

main <- function() {
  daily <- read_daily()
  first <- as.integer(format(min(daily$date), "%Y"))
  last <- as.integer(format(max(daily$date), "%Y"))
  hol <- as.Date(read.csv(HOLIDAYS, stringsAsFactors = FALSE)$date)
  hol_meta <- fromJSON(sub("\\.csv$", ".meta.json", HOLIDAYS))
  raw_meta <- fromJSON(DAILY_META)
  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(comparison = "fridays", outcome = "all",
                                    holidays = "exclude")))

  cat("Calculation paths (effect in per cent, Friday the 13th against its comparison days):\n")
  specs <- compute_specs(daily, hol, claim_file$forks)
  main_i <- which(vapply(specs, function(s) identical(s$choices, primary), TRUE))
  main_spec <- specs[[main_i]]
  dat <- path_data(daily, "all", "fridays", hol)
  s <- test_path(dat)
  stopifnot(abs(s$effect - main_spec$effect) < 1e-12)
  est <- estimation(s, dat, sprintf("%d–%d", first, last), claim_file$claim$smallest_relevant_effect)
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)

  # Descriptive figures (main comparison, holidays left out)
  y13 <- dat$count[dat$is13 == 1]
  cmp <- tapply(dat$count[dat$is13 == 0], dat$month[dat$is13 == 0], mean)
  months <- dat$month[dat$is13 == 1]
  c13 <- unname(cmp[months])
  pct <- 100 * (y13 / c13 - 1)
  naive <- path_data(daily, "all", "all_days", hol)
  naive_cmp <- tapply(naive$count[naive$is13 == 0], naive$month[naive$is13 == 0], mean)
  all13 <- fridays_13th(first, last)
  holiday13 <- all13[all13 %in% hol]
  holiday_controls <- sort(c(all13 - 7, all13 + 7)[c(all13 - 7, all13 + 7) %in% hol])
  yr <- as.integer(format(daily$date, "%Y"))
  not_hol <- !daily$date %in% hol
  fridays <- wday(daily$date) == 5 & not_hol & format(daily$date, "%d") != "13"
  ym <- format(daily$date, "%Y-%m")
  in_months <- ym %in% format(as.Date(months), "%Y-%m") & not_hol &
    format(daily$date, "%d") != "13"
  wk <- tapply(daily$all[in_months], wday(daily$date[in_months]), function(v) c(mean(v), length(v)))
  ex <- as.Date(months[length(months)])
  at <- function(day) daily$all[daily$date == day]

  data <- list(
    meta = list(
      source = "Department for Transport, Road Safety Data (STATS19), Open Government Licence v3.0",
      updated = format(Sys.Date()),
      accessed = raw_meta$accessed,
      years = sprintf("%d–%d", first, last),
      firstYear = first,
      lastYear = last,
      holidaysPackage = hol_meta$version
    ),
    summary = list(
      collisions = sum(daily$all), ksi = sum(daily$ksi), fatal = sum(daily$fatal),
      undated = raw_meta$undated, days = nrow(daily), fridays13 = length(all13),
      holiday13 = format(holiday13), holidayControls = format(holiday_controls),
      perDayFirstYear = round(mean(daily$all[yr == first]), 1),
      perDayLastYear = round(mean(daily$all[yr == last]), 1),
      fridayVsAverage = round(100 * (mean(daily$all[fridays]) / mean(daily$all[not_hol]) - 1), 2)
    ),
    main = list(
      sum13 = sum(y13), sumComparison = round(sum(c13), 1),
      mean13 = round(mean(y13), 1), meanComparison = round(mean(c13), 1),
      moreCount = sum(pct > 0), fewerCount = sum(pct < 0),
      naiveMean13 = round(mean(naive$count[naive$is13 == 1]), 1),
      naiveMeanComparison = round(mean(naive_cmp), 1)
    ),
    example = list(date = format(ex), on13 = at(ex), on6 = at(ex - 7), on20 = at(ex + 7)),
    weekdays = lapply(names(wk), function(i) list(weekday = WEEKDAYS[as.integer(i)],
                                                   mean = round(wk[[i]][1], 1),
                                                   days = as.integer(wk[[i]][2]))),
    points = lapply(seq_along(months), function(i) list(date = months[i], on13 = y13[i],
                                                         comparison = round(c13[i], 1),
                                                         pct = round(pct[i], 2))),
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null"), OUT,
             useBytes = TRUE)
  cat(sprintf("\nWrote %s\n", OUT))
  cat(sprintf("  %s collisions on %d days, %d Fridays the 13th (%d bank holidays)\n",
              format(sum(daily$all), big.mark = ","), nrow(daily), length(all13),
              length(holiday13)))
  cat(sprintf("  main: %+.2f%%, 95%% CI [%+.2f, %+.2f], p = %.4f, n = %d\n",
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
