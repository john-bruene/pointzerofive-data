# abitur_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline for story #005 "Are Abitur grades getting better every year?".
# Pitch with every choice fixed before the analysis: content/pitches/005-abitur-grades-better-every-year.md
#
# Inputs:
#   notebooks/raw/abitur/kmk_abitur.csv   (KMK, Abiturnoten im Ländervergleich 2014–2025, written
#                                          by abitur_extract.py)
#   notebooks/claims/abitur-grades-better-every-year.json  (claim and fork texts, hand-written)
# Outputs:
#   data/abitur-grades-better-every-year.json
#   data/abitur-grades-better-every-year.output.txt  (this script's console output via sink(),
#                                                     with sessionInfo(); not edited afterwards)
#   The result table of the main calculation (key `estimation`) is built with
#   notebooks/estimation_table.R.
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/abitur_pipeline.R
#
# Requires: base R, jsonlite and nlme (ships with R).
#
# Method
#   One row per Land and year, y = mean Abitur grade (1.0 best). Generalized least squares (GLS)
#   of y on year with one constant per Land and AR(1) errors within each Land (consecutive
#   cohorts of a Land are not independent), optionally weighted by the number of exams (error
#   variance proportional to 1 / exams). Effect = minus the slope: grade points better per year.
#   Test: t-test of the slope from the GLS fit; the 95% interval from the same t distribution.
# ──────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages({
  library(jsonlite)
  library(nlme)
})
source(file.path("notebooks", "estimation_table.R"))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

RAW <- file.path("notebooks", "raw", "abitur", "kmk_abitur.csv")
CLAIM <- file.path("notebooks", "claims", "abitur-grades-better-every-year.json")
OUT <- file.path("data", "abitur-grades-better-every-year.json")
LOG <- file.path("data", "abitur-grades-better-every-year.output.txt")

ALPHA <- 0.05
RUN_TIME <- Sys.time()

FORK_OPTIONS <- list(
  years = c("all", "nocorona", "precorona"),
  weight = c("equal", "exams"),
  cohorts = c("all", "regular")
)
LAND_NAMES <- c(BW = "Baden-Württemberg", BY = "Bayern", BE = "Berlin", BB = "Brandenburg",
                HB = "Bremen", HH = "Hamburg", HE = "Hessen", MV = "Mecklenburg-Vorpommern",
                NI = "Niedersachsen", NW = "Nordrhein-Westfalen", RP = "Rheinland-Pfalz",
                SL = "Saarland", SN = "Sachsen", ST = "Sachsen-Anhalt", SH = "Schleswig-Holstein",
                TH = "Thüringen")
GRADE_COLS <- sprintf("n_%s", gsub(".", "_", sprintf("%.1f", seq(1, 4, by = 0.1)), fixed = TRUE))

# Land-years used in the analysis, with the flag for unusual cohorts.
land_years <- function(raw) {
  d <- raw[raw$previous_year == 0, ]
  med <- tapply(d$exams, d$land, median)
  ratio <- d$exams / med[d$land]
  d$regular <- ratio >= 0.7 & ratio <= 1.3
  d
}

path_data <- function(d, years, cohorts) {
  if (years == "nocorona") d <- d[!d$year %in% c(2020, 2021), ]
  if (years == "precorona") d <- d[d$year <= 2019, ]
  if (cohorts == "regular") d <- d[d$regular, ]
  d
}

# GLS fit: y on year with a constant per Land, AR(1) errors within each Land (positions = years,
# so a missing year counts as a gap), optional weights by the number of exams.
gls_fit <- function(d, weight) {
  d$land <- factor(d$land)
  d$inv_exams <- 1 / d$exams
  gls(mean ~ year + land, data = d, correlation = corAR1(form = ~ year | land),
      weights = if (weight == "exams") varFixed(~ inv_exams) else NULL, method = "REML")
}

# Effect = grade points better per year = minus the slope; t-test with n - (number of
# coefficients) degrees of freedom.
test_path <- function(d, weight) {
  fit <- gls_fit(d, weight)
  tt <- summary(fit)$tTable
  slope <- tt["year", "Value"]
  se <- tt["year", "Std.Error"]
  df <- nrow(d) - length(coef(fit))
  q <- qt(1 - ALPHA / 2, df)
  list(effect = -slope, ci_low = -slope - q * se, ci_high = -slope + q * se,
       p = tt["year", "p-value"], n = nrow(d), se = se, df = df,
       phi = unname(coef(fit$modelStruct$corStruct, unconstrained = FALSE)))
}

compute_specs <- function(d, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  specs <- list()
  for (years in FORK_OPTIONS$years) {
    for (weight in FORK_OPTIONS$weight) {
      for (cohorts in FORK_OPTIONS$cohorts) {
        i <- length(specs) + 1L
        choices <- list(years = years, weight = weight, cohorts = cohorts)
        key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
        s <- test_path(path_data(d, years, cohorts), weight)
        specs[[i]] <- c(list(choices = choices), s[c("effect", "ci_low", "ci_high", "p", "n")])
        cat(sprintf("  %s: n=%d, %+.4f [%+.4f, %+.4f] p=%.4f\n", key, s$n, s$effect,
                    s$ci_low, s$ci_high, s$p))
      }
    }
  }
  specs
}

# The result table of the main calculation (estimation_table.R).
estimation <- function(d, spec, sre) {
  s <- test_path(d, "equal")
  stopifnot(abs(s$effect - spec$effect) < 1e-12, abs(s$p - spec$p) < 1e-12)
  est_table(RUN_TIME,
    dependent = txt("Mean Abitur grade (1.0 best)", "Abiturdurchschnittsnote (1,0 beste)"),
    method = txt("Generalized least squares, constant per state, AR(1) errors within states, t-test",
                 "Verallgemeinerte kleinste Quadrate, Konstante je Land, AR(1)-Fehler je Land, t-Test"),
    sample = txt(sprintf("16 states, %d–%d, KMK", min(d$year), max(d$year)),
                 sprintf("16 Länder, %d–%d, KMK", min(d$year), max(d$year))),
    observations = nrow(d),
    rows = list(
      est_row("Better per year", "Besser pro Jahr", est_values_t(s$effect, s$se, s$df))
    ),
    left = list(
      est_stat("State-years", "Länder-Jahre", nrow(d), 0),
      est_stat("States (constants)", "Länder (Konstanten)", length(unique(d$land)), 0),
      est_stat("Previous-year copies left out", "Ausgelassene Vorjahreskopien", 2, 0),
      est_stat("AR(1) coefficient", "AR(1)-Koeffizient", s$phi, 6)
    ),
    right = list(
      est_stat("Degrees of freedom", "Freiheitsgrade", s$df, 0),
      est_stat("Significance level", "Signifikanzniveau", ALPHA, 2),
      est_stat("Smallest relevant effect", "Kleinster relevanter Effekt", sre, 2)
    )
  )
}

main <- function() {
  raw <- read.csv(RAW, encoding = "UTF-8", stringsAsFactors = FALSE)
  stopifnot(nrow(raw) == 16 * 12, !anyNA(raw$mean), !anyNA(raw$exams),
            all(rowSums(raw[, GRADE_COLS]) == raw$passed))
  d <- land_years(raw)
  cat(sprintf("KMK: %d Land-years %d–%d; left out as previous-year copies: %s\n",
              nrow(raw), min(raw$year), max(raw$year),
              paste(raw$land[raw$previous_year == 1], raw$year[raw$previous_year == 1],
                    collapse = ", ")))
  cat(sprintf("Unusual cohorts (exams < 70%% or > 130%% of the Land's median): %s\n\n",
              paste(d$land[!d$regular], d$year[!d$regular], collapse = ", ")))

  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  cat("Calculation paths (effect = grade points better per year):\n")
  specs <- compute_specs(d, claim_file$forks)
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(years = "all", weight = "equal", cohorts = "all")))
  main_i <- which(vapply(specs, function(s) identical(s$choices, primary), TRUE))
  main_spec <- specs[[main_i]]
  est <- estimation(d, main_spec, claim_file$claim$smallest_relevant_effect)
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)

  # Germany per year: all Länder that reported new values that year, weighted by passes
  years <- sort(unique(raw$year))
  germany <- lapply(years, function(y) {
    g <- d[d$year == y, ]
    counts <- colSums(g[, GRADE_COLS])
    list(year = y, lands = nrow(g), exams = sum(g$exams), passed = sum(g$passed),
         failed = sum(g$failed),
         mean = round(sum(g$mean * g$passed) / sum(g$passed), 4),
         share1 = round(sum(counts[1:10]) / sum(g$passed), 4),
         share10 = round(counts[[1]] / sum(g$passed), 4),
         failRate = round(sum(g$failed) / sum(g$exams), 4))
  })
  lands <- lapply(names(LAND_NAMES), function(l) {
    g <- d[d$land == l, ]
    list(id = l, name = unname(LAND_NAMES[l]), years = g$year, mean = round(g$mean, 4),
         regular = g$regular)
  })

  data <- list(
    meta = list(
      source = "Sekretariat der Kultusministerkonferenz, Abiturnoten im Ländervergleich",
      updated = format(Sys.Date()),
      years = sprintf("%d–%d", min(years), max(years)),
      copies = lapply(which(raw$previous_year == 1),
                      function(j) list(land = raw$land[j], year = raw$year[j])),
      unusual = lapply(which(!d$regular),
                       function(j) list(land = d$land[j], year = d$year[j]))
    ),
    germany = germany,
    lands = lands,
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null"), OUT,
             useBytes = TRUE)
  cat(sprintf("\nWrote %s\nGermany per year:\n", OUT))
  print(do.call(rbind, lapply(germany, as.data.frame)), row.names = FALSE)
  cat(sprintf("  main: %+.4f grade points better per year, 95%% CI [%+.4f, %+.4f], p = %.4f, n = %d\n",
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
