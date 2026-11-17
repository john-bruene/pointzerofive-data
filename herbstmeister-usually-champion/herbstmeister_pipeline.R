# herbstmeister_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline for story #008 "Does the halfway leader usually win the Bundesliga?".
# Pitch with every choice fixed before the analysis: content/pitches/008-herbstmeister-usually-champion.md
#
# Inputs:
#   football.csv / deutschland (CC0 1.0, an export of openfootball), Bundesliga 1963/64–2009/10,
#       https://github.com/footballcsv/deutschland  <decade>/<season>/de.1.csv
#       (only needed once, see prep(); downloaded 2026-11-17)
#   notebooks/raw/bundesliga/matches_1963_2010.csv  (written by prep(), committed)
#   notebooks/raw/bundesliga/matches.csv            (openfootball, 2010/11–2025/26, from #001)
#   notebooks/raw/bundesliga/reference_lists.csv    (cross-check only: Herbstmeister from
#       de.wikipedia.org/wiki/Herbstmeister, champions from
#       en.wikipedia.org/wiki/List_of_German_football_champions, both read 2026-11-17)
#   notebooks/claims/herbstmeister-usually-champion.json  (claim and fork texts, hand-written)
# Outputs:
#   data/herbstmeister-usually-champion.json
#   data/herbstmeister-usually-champion.output.txt  (this script's console output via sink(),
#                                                    with sessionInfo(); not edited afterwards)
#   The result table of the main calculation (key `estimation`) is built with
#   notebooks/estimation_table.R.
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/herbstmeister_pipeline.R
#
# Requires: base R and jsonlite.
#
# Method (pitch §1b)
#   One row per season. Tables: points as awarded at the time (2 per win until 1994/95, then 3),
#   ties broken by goal quotient until 1968/69, then goal difference, then goals scored.
#   Herbstmeister: top of the table of all first-half matches (matchdays 1 to number of clubs − 1),
#   or of all matches played by 31 December (fork table). Champion: top of the final table.
#   y = 1 if the Herbstmeister became champion. Effect = share of y = 1 minus one half, in
#   percentage points. Test: logistic regression on an intercept only, Wald z-test of
#   intercept = 0 (share = 0.5); 95% interval from the same standard error on the log-odds scale.
# ──────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages(library(jsonlite))
source(file.path("notebooks", "estimation_table.R"))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

FCSV <- "https://raw.githubusercontent.com/footballcsv/deutschland/master"
OLD <- file.path("notebooks", "raw", "bundesliga", "matches_1963_2010.csv")
NEW <- file.path("notebooks", "raw", "bundesliga", "matches.csv")
REFERENCE <- file.path("notebooks", "raw", "bundesliga", "reference_lists.csv")
CLAIM <- file.path("notebooks", "claims", "herbstmeister-usually-champion.json")
OUT <- file.path("data", "herbstmeister-usually-champion.json")
LOG <- file.path("data", "herbstmeister-usually-champion.output.txt")

SEASONS <- 1963:2025
ALPHA <- 0.05
RUN_TIME <- Sys.time()

FORK_OPTIONS <- list(
  seasons = c("all", "without_bayern", "three_points"),
  table = c("first_half", "winter_break"),
  ties = c("official", "clear_lead")
)

read_csv_utf8 <- function(path) {
  read.csv(path, encoding = "UTF-8", stringsAsFactors = FALSE, check.names = FALSE)
}

season_code <- function(s) sprintf("%d-%s", s, substr(s + 1, 3, 4))
season_label <- function(s) sprintf("%d/%s", s, substr(s + 1, 3, 4))

# Download 1963/64–2009/10 from football.csv once and check 2010/11–2019/20, which both sources
# have, against openfootball (matches.csv): same scores on every match date.
prep <- function() {
  old <- do.call(rbind, lapply(1963:2009, function(s) {
    url <- sprintf("%s/%ds/%s/de.1.csv", FCSV, s %/% 10 * 10, season_code(s))
    d <- read.csv(url(url, encoding = "UTF-8"), stringsAsFactors = FALSE, check.names = FALSE)
    stopifnot(identical(names(d), c("Matchday", "Date", "Team 1", "FT", "Team 2")),
              all(grepl("^[0-9]+-[0-9]+$", d$FT)))
    goals <- do.call(rbind, strsplit(d$FT, "-", fixed = TRUE))
    data.frame(season = season_code(s), matchday = d$Matchday,
               date = format(as.Date(d$Date, "%a %b %d %Y")),
               home = d[["Team 1"]], away = d[["Team 2"]],
               home_goals = as.integer(goals[, 1]), away_goals = as.integer(goals[, 2]))
  }))
  stopifnot(!anyNA(old$date))
  new <- read_csv_utf8(NEW)
  agree <- 0L
  for (s in 2010:2019) {
    url <- sprintf("%s/%ds/%s/de.1.csv", FCSV, s %/% 10 * 10, season_code(s))
    d <- read.csv(url(url, encoding = "UTF-8"), stringsAsFactors = FALSE, check.names = FALSE)
    d$date <- format(as.Date(d$Date, "%a %b %d %Y"))
    of <- new[new$season == season_code(s), ]
    a <- tapply(d$FT, d$date, function(x) paste(sort(x, method = "radix"), collapse = " "))
    b <- tapply(paste(of$home_goals, of$away_goals, sep = "-"), of$date,
                function(x) paste(sort(x, method = "radix"), collapse = " "))
    stopifnot(setequal(names(a), names(b)), all(a == b[names(a)]))
    agree <- agree + length(a)
  }
  cat(sprintf("prep: %d matches 1963/64–2009/10 from football.csv; %d match dates 2010/11–2019/20 agree with openfootball\n\n",
              nrow(old), agree))
  write.csv(old, OLD, row.names = FALSE, fileEncoding = "UTF-8")
}

# All matches 1963/64–2025/26, one row each.
all_matches <- function() {
  m <- rbind(read_csv_utf8(OLD), read_csv_utf8(NEW))
  m$start <- as.integer(substr(m$season, 1, 4))
  m$date <- as.Date(m$date)
  stopifnot(setequal(unique(m$start), SEASONS), !anyNA(m$home_goals), !anyNA(m$away_goals))
  m
}

# The table of a set of matches: points with win_pts per win, sorted by the rule of the season.
standings <- function(m, win_pts, quotient) {
  team <- c(m$home, m$away)
  gf <- c(m$home_goals, m$away_goals)
  ga <- c(m$away_goals, m$home_goals)
  pts <- ifelse(gf > ga, win_pts, ifelse(gf == ga, 1L, 0L))
  t <- data.frame(team = sort(unique(team), method = "radix"))
  t$played <- as.vector(table(factor(team, levels = t$team)))
  t$pts <- as.vector(tapply(pts, factor(team, levels = t$team), sum))
  t$gf <- as.vector(tapply(gf, factor(team, levels = t$team), sum))
  t$ga <- as.vector(tapply(ga, factor(team, levels = t$team), sum))
  t$gd <- t$gf - t$ga
  t$gq <- ifelse(t$ga == 0, Inf, t$gf / t$ga)
  o <- if (quotient) order(-t$pts, -t$gq, t$team, method = "radix") else
    order(-t$pts, -t$gd, -t$gf, t$team, method = "radix")
  t <- t[o, ]
  rownames(t) <- NULL
  # the top two must differ in a deciding criterion, else the leader is not defined
  same <- if (quotient) t$pts[1] == t$pts[2] && t$gq[1] == t$gq[2] else
    t$pts[1] == t$pts[2] && t$gd[1] == t$gd[2] && t$gf[1] == t$gf[2]
  attr(t, "level_at_top") <- same
  t
}

# Rules of one season: points per win and tie-break.
win_points <- function(start) if (start >= 1995) 3L else 2L
uses_quotient <- function(start) start <= 1968

# One row per season and table option: Herbstmeister, lead, champion and their places.
season_rows <- function(m) {
  rows <- list()
  for (s in SEASONS) {
    d <- m[m$start == s, ]
    clubs <- length(unique(c(d$home, d$away)))
    half <- clubs - 1L
    stopifnot(nrow(d) == clubs * (clubs - 1L), max(d$matchday) == 2L * half)
    wp <- win_points(s)
    q <- uses_quotient(s)
    final <- standings(d, wp, q)
    stopifnot(!attr(final, "level_at_top"))
    tables <- list(first_half = d[d$matchday <= half, ],
                   winter_break = d[d$date <= as.Date(sprintf("%d-12-31", s)), ])
    for (tab in names(tables)) {
      ht <- standings(tables[[tab]], wp, q)
      if (attr(ht, "level_at_top")) stop(sprintf("%s %s: leader not defined", season_label(s), tab))
      leader <- ht$team[1]
      ht3 <- standings(tables[[tab]], 3L, q)
      rows[[length(rows) + 1L]] <- list(
        start = s, season = season_label(s), table = tab, clubs = clubs,
        matches = nrow(tables[[tab]]), matchday = max(tables[[tab]]$matchday),
        leader = leader, leader_pts = ht$pts[1], second = ht$team[2], second_pts = ht$pts[2],
        level_on_points = ht$pts[1] == ht$pts[2],
        lead3 = ht3$pts[ht3$team == leader] - max(ht3$pts[ht3$team != leader]),
        champion = final$team[1], leader_final_place = match(leader, final$team),
        champion_half_place = match(final$team[1], ht$team),
        champion_half_pts = ht$pts[ht$team == final$team[1]],
        y = as.integer(leader == final$team[1])
      )
    }
  }
  r <- do.call(rbind, lapply(rows, as.data.frame))
  r$bayern <- r$leader == "Bayern München"
  r
}

# The seasons of one calculation path.
path_rows <- function(r, seasons, table, ties) {
  d <- r[r$table == table, ]
  if (seasons == "without_bayern") d <- d[!d$bayern, ]
  if (seasons == "three_points") d <- d[d$start >= 1995, ]
  if (ties == "clear_lead") d <- d[!d$level_on_points, ]
  d
}

# Effect = share − 0.5 in percentage points; logit on an intercept only, Wald z-test.
test_path <- function(d) {
  fit <- glm(y ~ 1, family = binomial, data = d)
  co <- summary(fit)$coefficients
  b <- co[1, "Estimate"]
  se <- co[1, "Std. Error"]
  p <- co[1, "Pr(>|z|)"]
  stopifnot(abs(p - 2 * pnorm(-abs(b / se))) < 1e-12)
  z <- qnorm(1 - ALPHA / 2)
  share <- plogis(b)
  stopifnot(abs(share - mean(d$y)) < 1e-9)
  list(effect = 100 * (share - 0.5), ci_low = 100 * (plogis(b - z * se) - 0.5),
       ci_high = 100 * (plogis(b + z * se) - 0.5), p = p, n = nrow(d), k = sum(d$y),
       b = b, se = se, fit = fit)
}

# Every combination of the forks in the claim file, in fork order.
compute_specs <- function(r, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  specs <- list()
  for (seasons in FORK_OPTIONS$seasons) {
    for (table in FORK_OPTIONS$table) {
      for (ties in FORK_OPTIONS$ties) {
        choices <- list(seasons = seasons, table = table, ties = ties)
        key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
        s <- test_path(path_rows(r, seasons, table, ties))
        specs[[length(specs) + 1L]] <- c(list(choices = choices),
                                         s[c("effect", "ci_low", "ci_high", "p", "n")])
        cat(sprintf("  %s: %d of %d, %+.1f [%+.1f, %+.1f] pp, p=%.4f\n", key, s$k, s$n,
                    s$effect, s$ci_low, s$ci_high, s$p))
      }
    }
  }
  specs
}

# The result table of the main calculation (estimation_table.R).
estimation <- function(d, s, sre) {
  z <- qnorm(1 - ALPHA / 2)
  share <- plogis(s$b)
  se_share <- share * (1 - share) * s$se
  lo <- plogis(s$b - z * s$se)
  hi <- plogis(s$b + z * s$se)
  est_table(RUN_TIME,
    dependent = txt("Herbstmeister became champion (1 = yes, 0 = no)",
                    "Herbstmeister wurde Meister (1 = ja, 0 = nein)"),
    method = txt("Logistic regression (binomial GLM), intercept only; Wald z-test",
                 "Logistische Regression (binomiales GLM), nur Konstante; Wald-z-Test"),
    sample = txt(sprintf("Bundesliga %s–%s", season_label(min(d$start)), season_label(max(d$start)))),
    observations = nrow(d),
    rows = list(
      est_row("Constant (log-odds)", "Konstante (Log-Odds)",
              c(s$b, s$se, s$b - z * s$se, s$b + z * s$se, s$p)),
      est_row("Share champion", "Anteil Meister", c(share, se_share, lo, hi, s$p)),
      est_row("Share − 0.5 (pp)", "Anteil − 0,5 (Pp.)",
              c(s$effect, 100 * se_share, s$ci_low, s$ci_high, s$p))
    ),
    left = list(
      est_stat("Seasons", "Spielzeiten", nrow(d), 0),
      est_stat("Herbstmeister champion", "Herbstmeister Meister", s$k, 0),
      est_stat("Log likelihood", "Log-Likelihood", as.numeric(logLik(s$fit)), 4),
      est_stat("Akaike info criterion", "Akaike-Kriterium", AIC(s$fit), 4)
    ),
    right = list(
      est_stat("z-statistic", "z-Statistik", s$b / s$se, 4),
      est_stat("Significance level", "Signifikanzniveau", ALPHA, 2),
      est_stat("Smallest relevant effect (pp)", "Kleinster relevanter Effekt (Pp.)", sre, 0)
    )
  )
}

# Names in the data → names in the reference lists, for the cross-check only.
club_key <- function(x) {
  x <- sub("^FC Bayern München$|^Bayern Munich$", "Bayern München", x)
  x <- sub("^TSV 1860 Munich$|^1860 München$", "TSV 1860 München", x)
  x <- sub("^Bor\\. Mönchengladbach$", "Borussia Mönchengladbach", x)
  x <- sub("^FC Schalke 04$", "Schalke 04", x)
  x <- sub("^Bayer 04 Leverkusen$|^Bayer Leverkusen$", "Leverkusen", x)
  x <- sub("^TSG 1899 Hoffenheim$|^TSG Hoffenheim$|^1899 Hoffenheim$", "Hoffenheim", x)
  x <- sub("^RasenBallsport Leipzig$|^RB Leipzig$", "RB Leipzig", x)
  x <- sub("^SV Werder Bremen$", "Werder Bremen", x)
  x <- sub("^Borussia Dortmund$|^BV Borussia Dortmund$", "Borussia Dortmund", x)
  x
}

cross_check <- function(r) {
  ref <- read_csv_utf8(REFERENCE)
  main <- r[r$table == "first_half", ]
  stopifnot(identical(main$start, ref$season))
  champ_ok <- club_key(main$champion) == club_key(ref$champion_en_wikipedia)
  hm_ok <- club_key(main$leader) == club_key(ref$herbstmeister_de_wikipedia)
  y_ok <- main$y == ref$herbstmeister_champion_de_wikipedia
  cat(sprintf("Cross-check against the reference lists: champion %d of %d, Herbstmeister %d of %d, champion yes/no %d of %d agree\n",
              sum(champ_ok), nrow(main), sum(hm_ok), nrow(main), sum(y_ok), nrow(main)))
  for (i in which(!(champ_ok & hm_ok & y_ok))) {
    cat(sprintf("  %s: data %s / %s, reference %s / %s\n", main$season[i], main$leader[i],
                main$champion[i], ref$herbstmeister_de_wikipedia[i], ref$champion_en_wikipedia[i]))
  }
  stopifnot(all(champ_ok))
  cat("\n")
}

# Club names as the text uses them: full and short. The two sources spell a few clubs differently.
CLUBS <- rbind(
  c("1. FC Kaiserslautern", "1. FC Kaiserslautern", "Kaiserslautern"),
  c("1. FC Köln", "1. FC Köln", "Köln"),
  c("1. FC Nürnberg", "1. FC Nürnberg", "Nürnberg"),
  c("1. FC Union Berlin", "1. FC Union Berlin", "Union Berlin"),
  c("1. FSV Mainz 05", "1. FSV Mainz 05", "Mainz"),
  c("Bayer 04 Leverkusen", "Bayer Leverkusen", "Leverkusen"),
  c("Bayer Leverkusen", "Bayer Leverkusen", "Leverkusen"),
  c("Bayern München", "Bayern München", "Bayern"),
  c("Bor. Mönchengladbach", "Borussia Mönchengladbach", "Mönchengladbach"),
  c("Borussia Mönchengladbach", "Borussia Mönchengladbach", "Mönchengladbach"),
  c("Borussia Dortmund", "Borussia Dortmund", "Dortmund"),
  c("Eintracht Braunschweig", "Eintracht Braunschweig", "Braunschweig"),
  c("Eintracht Frankfurt", "Eintracht Frankfurt", "Frankfurt"),
  c("FC Schalke 04", "FC Schalke 04", "Schalke"),
  c("Fortuna Düsseldorf", "Fortuna Düsseldorf", "Düsseldorf"),
  c("Hamburger SV", "Hamburger SV", "HSV"),
  c("Hertha BSC", "Hertha BSC", "Hertha"),
  c("RB Leipzig", "RB Leipzig", "Leipzig"),
  c("TSG 1899 Hoffenheim", "TSG Hoffenheim", "Hoffenheim"),
  c("TSV 1860 München", "TSV 1860 München", "1860 München"),
  c("VfB Stuttgart", "VfB Stuttgart", "Stuttgart"),
  c("VfL Wolfsburg", "VfL Wolfsburg", "Wolfsburg"),
  c("Werder Bremen", "Werder Bremen", "Bremen")
)
club_name <- function(x, col) {
  v <- CLUBS[match(x, CLUBS[, 1]), col]
  if (anyNA(v)) stop("No display name for ", paste(x[is.na(v)], collapse = ", "))
  v
}

# Descriptive logistic curve of the outcome on the halfway lead (figure 2, not a test).
lead_curve <- function(d) {
  fit <- glm(y ~ lead3, family = binomial, data = d)
  x <- seq(min(d$lead3), max(d$lead3), length.out = 41)
  list(intercept = unname(coef(fit)[1]), slope = unname(coef(fit)[2]),
       points = lapply(x, function(v) list(lead = round(v, 2),
                                           p = round(plogis(coef(fit)[1] + coef(fit)[2] * v), 4))))
}

main <- function() {
  if (!file.exists(OLD)) prep()
  m <- all_matches()
  cat(sprintf("Matches: %d in %d seasons (%s–%s)\n\n", nrow(m), length(SEASONS),
              season_label(min(SEASONS)), season_label(max(SEASONS))))
  r <- season_rows(m)
  cross_check(r)

  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  cat("Calculation paths (effect = share champion − 0.5, percentage points):\n")
  specs <- compute_specs(r, claim_file$forks)
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(seasons = "all", table = "first_half", ties = "official")))
  main_rows <- path_rows(r, "all", "first_half", "official")
  main_test <- test_path(main_rows)
  main_spec <- specs[[which(vapply(specs, function(s) identical(s$choices, primary), TRUE))]]
  stopifnot(abs(main_test$p - main_spec$p) < 1e-12)
  est <- estimation(main_rows, main_test, claim_file$claim$smallest_relevant_effect)
  chi <- chisq.test(c(main_test$k, main_test$n - main_test$k), p = c(0.5, 0.5))
  cat(sprintf("\nChecks for the text: chi-squared test against 50:50, X2 = %.3f, p = %.4f; up to 2019/20 (DSFS count): %d of %d\n",
              unname(chi$statistic), chi$p.value, sum(main_rows$y[main_rows$start <= 2019]),
              sum(main_rows$start <= 2019)))
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)

  fh <- r[r$table == "first_half", ]
  wb <- r[r$table == "winter_break", ]
  seasons <- lapply(seq_len(nrow(fh)), function(i) {
    list(season = fh$season[i], clubs = fh$clubs[i], leader = club_name(fh$leader[i], 2),
         leaderShort = club_name(fh$leader[i], 3), leaderPts = fh$leader_pts[i],
         second = club_name(fh$second[i], 2), secondPts = fh$second_pts[i],
         levelOnPoints = fh$level_on_points[i], lead3 = fh$lead3[i],
         champion = club_name(fh$champion[i], 2), championShort = club_name(fh$champion[i], 3),
         place = fh$leader_final_place[i], championHalfPlace = fh$champion_half_place[i],
         championHalfPts = fh$champion_half_pts[i], y = fh$y[i], bayern = fh$bayern[i],
         winterLeader = club_name(wb$leader[i], 2), winterMatchday = wb$matchday[i],
         winterY = wb$y[i])
  })
  count <- function(d) list(n = nrow(d), champion = sum(d$y))
  data <- list(
    meta = list(
      source = "football.csv / openfootball, deutschland (CC0 1.0)",
      updated = format(Sys.Date()),
      seasons = sprintf("%s–%s", season_label(min(SEASONS)), season_label(max(SEASONS)))
    ),
    summary = list(
      matches = nrow(m),
      seasons = nrow(fh),
      all = count(fh),
      bayern = count(fh[fh$bayern, ]),
      others = count(fh[!fh$bayern, ]),
      levelOnPoints = count(fh[fh$level_on_points, ]),
      winterDiffers = sum(fh$leader != wb$leader),
      championSecondAtHalf = sum(fh$champion_half_place == 2L),
      championBelowSecondAtHalf = sum(fh$champion_half_place > 2L)
    ),
    seasons = seasons,
    leadCurve = lead_curve(fh),
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null"), OUT,
             useBytes = TRUE)
  cat(sprintf("\nWrote %s\n", OUT))
  cat(sprintf("  Herbstmeister champion: %d of %d (Bayern %d of %d, others %d of %d)\n",
              data$summary$all$champion, data$summary$all$n, data$summary$bayern$champion,
              data$summary$bayern$n, data$summary$others$champion, data$summary$others$n))
  cat(sprintf("  main: %+.1f percentage points, 95%% CI [%+.1f, %+.1f], p = %.4f, n = %d\n",
              main_spec$effect, main_spec$ci_low, main_spec$ci_high, main_spec$p, main_spec$n))
  yes <- sum(vapply(specs, function(s) s$p < ALPHA && s$effect > 0, TRUE))
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
