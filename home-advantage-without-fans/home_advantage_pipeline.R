# home_advantage_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline for story #003 "Does home advantage shrink without fans?".
# Pitch with every choice fixed before the analysis: content/pitches/003-home-advantage-without-fans.md
#
# Inputs:
#   content/incoming/home-advantage/games.csv.gz   (only needed once, see prep())
#       transfermarkt-datasets `games` table, CC0 1.0, data from Transfermarkt.de
#       https://github.com/dcaribou/transfermarkt-datasets
#       file https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data/games.csv.gz
#       (Last-Modified 2026-09-05, downloaded 2026-10-16)
#   notebooks/raw/home_advantage/games_top5.csv     (written by prep(), committed)
#   notebooks/raw/bundesliga/matches.csv            (openfootball, for cross-checking)
#   notebooks/claims/home-advantage-without-fans.json  (claim and fork texts, hand-written)
# Outputs:
#   data/home-advantage-without-fans.json
#   data/home-advantage-without-fans.output.txt  (this script's console output via sink(),
#                                                 with sessionInfo(); not edited afterwards)
#   The result table of the main calculation (key `estimation`) is built with
#   notebooks/estimation_table.R.
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/home_advantage_pipeline.R
#
# Requires: base R and jsonlite.
#
# Method (pitch §1b)
#   One row per league match. y = home points − away points (win 3, draw 1, loss 0).
#   Ghost game: no attendance figure between 8 March 2020 and 30 June 2022; in 2021/22 only the
#   Bundesliga played without spectators, so a missing figure there in another league is a gap
#   in the data and the match is dropped. Full stadium: attendance figure and played before
#   8 March 2020 or from 1 July 2022 on. Restricted crowd: attendance figure inside the window.
#   Effect = mean y in the comparison group − mean y in the ghost games (positive = home
#   advantage smaller without fans). Test: Welch two-sample t-test (unequal variances).
# ──────────────────────────────────────────────────────────────────────

suppressPackageStartupMessages(library(jsonlite))
source(file.path("notebooks", "estimation_table.R"))
if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

INCOMING <- file.path("content", "incoming", "home-advantage", "games.csv.gz")
RAW <- file.path("notebooks", "raw", "home_advantage", "games_top5.csv")
MATCHES <- file.path("notebooks", "raw", "bundesliga", "matches.csv")
CLAIM <- file.path("notebooks", "claims", "home-advantage-without-fans.json")
OUT <- file.path("data", "home-advantage-without-fans.json")
LOG <- file.path("data", "home-advantage-without-fans.output.txt")

LEAGUES <- c(L1 = "Bundesliga", GB1 = "Premier League", ES1 = "LaLiga", IT1 = "Serie A",
             FR1 = "Ligue 1")
SEASONS <- 2012:2025
WINDOW_START <- as.Date("2020-03-08")
WINDOW_END <- as.Date("2022-06-30")
ALPHA <- 0.05
RUN_TIME <- Sys.time()

FORK_OPTIONS <- list(
  leagues = c("bundesliga", "top5"),
  ghost = c("all", "restart", "season2021"),
  comparison = c("full", "before", "any_crowd")
)

read_csv_utf8 <- function(path) {
  read.csv(path, encoding = "UTF-8", stringsAsFactors = FALSE, check.names = FALSE)
}

# Keep the five leagues, 2012/13–2025/26, and check the Bundesliga against openfootball.
prep <- function() {
  g <- read.csv(gzfile(INCOMING, encoding = "UTF-8"), stringsAsFactors = FALSE)
  g <- g[g$competition_id %in% names(LEAGUES) & g$competition_type == "domestic_league" &
           g$season %in% SEASONS,
         c("competition_id", "season", "round", "date", "home_club_name", "away_club_name",
           "home_club_goals", "away_club_goals", "attendance")]
  g <- g[order(g$competition_id, g$date, g$home_club_name, method = "radix"), ]
  stopifnot(!anyNA(g$home_club_goals), !anyNA(g$away_club_goals))
  stopifnot(all(table(g$season[g$competition_id == "L1"]) == 306))

  of <- read_csv_utf8(MATCHES)
  l1 <- g[g$competition_id == "L1", ]
  by_date <- function(df, h, a) {
    lines <- paste(df[[h]], df[[a]], sep = "-")
    tapply(lines, df$date, function(x) paste(sort(x, method = "radix"), collapse = " "))
  }
  tm <- by_date(l1, "home_club_goals", "away_club_goals")
  ofd <- by_date(of[of$date %in% names(tm), ], "home_goals", "away_goals")
  stopifnot(setequal(names(tm), names(ofd)), all(tm == ofd[names(tm)]))
  cat(sprintf("prep: %d league matches; %d Bundesliga match dates agree with openfootball\n\n",
              nrow(g), length(tm)))
  dir.create(dirname(RAW), recursive = TRUE, showWarnings = FALSE)
  write.csv(g, RAW, row.names = FALSE, fileEncoding = "UTF-8", na = "")
}

# One row per match with points, y, group and cluster.
matches <- function() {
  m <- read_csv_utf8(RAW)
  m$date <- as.Date(m$date)
  hg <- m$home_club_goals
  ag <- m$away_club_goals
  m$home_pts <- ifelse(hg > ag, 3L, ifelse(hg == ag, 1L, 0L))
  m$away_pts <- ifelse(hg < ag, 3L, ifelse(hg == ag, 1L, 0L))
  m$y <- m$home_pts - m$away_pts
  in_window <- m$date >= WINDOW_START & m$date <= WINDOW_END
  has_att <- !is.na(m$attendance)
  m$group <- NA_character_
  m$group[!in_window & has_att] <- "full"
  m$group[in_window & has_att] <- "restricted"
  m$group[in_window & !has_att & (m$season <= 2020 | m$competition_id == "L1")] <- "ghost"
  m$dropped <- is.na(m$group)
  m$cluster <- paste(m$competition_id, m$season, m$round, m$group, sep = "|")
  m
}

# The two groups of one calculation path.
path_groups <- function(m, leagues, ghost, comparison) {
  d <- m[!m$dropped, ]
  if (leagues == "bundesliga") d <- d[d$competition_id == "L1", ]
  g <- d[d$group == "ghost", ]
  if (ghost == "restart") g <- g[g$season == 2019, ]
  if (ghost == "season2021") g <- g[g$season == 2020, ]
  c <- switch(comparison,
    full = d[d$group == "full", ],
    before = d[d$group == "full" & d$date < WINDOW_START, ],
    any_crowd = d[d$group %in% c("full", "restricted"), ]
  )
  list(ghost = g, comparison = c)
}

# Effect = mean y (comparison) − mean y (ghost), Welch two-sample t-test.
test_path <- function(pg) {
  t <- t.test(pg$comparison$y, pg$ghost$y, var.equal = FALSE, conf.level = 1 - ALPHA)
  list(effect = mean(pg$comparison$y) - mean(pg$ghost$y), ci_low = t$conf.int[1],
       ci_high = t$conf.int[2], p = t$p.value, n = nrow(pg$ghost),
       se = unname(t$stderr), df = unname(t$parameter))
}

# Every combination of the forks in the claim file, in fork order.
compute_specs <- function(m, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  specs <- list()
  for (leagues in FORK_OPTIONS$leagues) {
    for (ghost in FORK_OPTIONS$ghost) {
      for (comparison in FORK_OPTIONS$comparison) {
        i <- length(specs) + 1L
        choices <- list(leagues = leagues, ghost = ghost, comparison = comparison)
        key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
        s <- test_path(path_groups(m, leagues, ghost, comparison))
        specs[[i]] <- c(list(choices = choices), s[c("effect", "ci_low", "ci_high", "p", "n")])
        cat(sprintf("  %s: n=%d, %+.3f [%+.3f, %+.3f] p=%.4f\n", key, s$n, s$effect,
                    s$ci_low, s$ci_high, s$p))
      }
    }
  }
  specs
}

# Mean y of one group with its 95% t-interval.
group_mean <- function(d) {
  if (nrow(d) == 0L) return(NULL)
  ci <- t.test(d$y, conf.level = 1 - ALPHA)$conf.int
  list(n = nrow(d), ha = round(mean(d$y), 3), lo = round(ci[1], 3), hi = round(ci[2], 3),
       homeWin = round(mean(d$y > 0), 3), draw = round(mean(d$y == 0), 3),
       awayWin = round(mean(d$y < 0), 3))
}

# Mean, standard error and t-interval of one group, as a row of the result table.
mean_values <- function(y) {
  est_values_t(mean(y), sd(y) / sqrt(length(y)), length(y) - 1)
}

# The result table of the main calculation (estimation_table.R).
estimation <- function(m, primary, spec, sre) {
  pg <- path_groups(m, primary$leagues, primary$ghost, primary$comparison)
  s <- test_path(pg)
  stopifnot(abs(s$p - spec$p) < 1e-12)
  y <- c(pg$comparison$y, pg$ghost$y)
  est_table(RUN_TIME,
    dependent = txt("Home points − away points per match",
                    "Heimpunkte − Auswärtspunkte je Spiel"),
    method = txt("Welch two-sample t-test (unequal variances)",
                 "Welch-t-Test für zwei Stichproben (ungleiche Varianzen)"),
    sample = txt(sprintf("Bundesliga %s–%s", season_label(min(SEASONS)),
                         season_label(max(SEASONS)))),
    observations = length(y),
    rows = list(
      est_row("Full stadiums", "Volle Stadien", mean_values(pg$comparison$y)),
      est_row("Ghost games", "Geisterspiele", mean_values(pg$ghost$y)),
      est_row("Difference (full − ghost)", "Differenz (voll − Geister)",
              c(s$effect, s$se, s$ci_low, s$ci_high, s$p))
    ),
    left = list(
      est_stat("Mean dependent var", "Mittelwert abh. Variable", mean(y), 6),
      est_stat("S.D. dependent var", "Std.-Abw. abh. Variable", sd(y), 6),
      est_stat("Observations, full", "Beobachtungen, voll", nrow(pg$comparison), 0),
      est_stat("Observations, ghost", "Beobachtungen, Geister", nrow(pg$ghost), 0)
    ),
    right = list(
      est_stat("Degrees of freedom (Welch)", "Freiheitsgrade (Welch)", s$df, 2),
      est_stat("Significance level", "Signifikanzniveau", ALPHA, 2),
      est_stat("Smallest relevant effect", "Kleinster relevanter Effekt", sre, 2)
    )
  )
}

season_label <- function(s) sprintf("%d/%s", s, substr(s + 1, 3, 4))

main <- function() {
  if (file.exists(INCOMING)) prep()
  m <- matches()
  kept <- m[!m$dropped, ]

  cat("Matches per league and group (dropped: missing attendance outside the ghost rule):\n")
  print(table(factor(m$competition_id, levels = names(LEAGUES)),
              ifelse(m$dropped, "dropped", m$group)))
  cat("\n")

  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  cat("Calculation paths (effect = comparison − ghost games, points per match):\n")
  specs <- compute_specs(m, claim_file$forks)
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(leagues = "bundesliga", ghost = "all", comparison = "full")))
  main_i <- which(vapply(specs, function(s) identical(s$choices, primary), TRUE))
  main_spec <- specs[[main_i]]
  est <- estimation(m, primary, main_spec, claim_file$claim$smallest_relevant_effect)
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)

  # Group means per league and for the five leagues together (figure 2)
  groups <- lapply(c(names(LEAGUES), "top5"), function(l) {
    d <- if (l == "top5") kept else kept[kept$competition_id == l, ]
    out <- list(id = l, name = if (l == "top5") "top5" else unname(LEAGUES[l]))
    for (g in c("full", "restricted", "ghost")) out[[g]] <- group_mean(d[d$group == g, ])
    out
  })

  # Bundesliga per season (figure 1): matches with spectators and ghost games
  bl <- kept[kept$competition_id == "L1", ]
  seasons <- lapply(SEASONS, function(s) {
    d <- bl[bl$season == s, ]
    crowd <- d[d$group != "ghost", ]
    ghost <- d[d$group == "ghost", ]
    list(season = season_label(s), n = nrow(crowd), ha = round(mean(crowd$y), 3),
         nGhost = nrow(ghost), haGhost = if (nrow(ghost)) round(mean(ghost$y), 3) else NULL)
  })

  # The Bundesliga restart in 2020, the way headlines counted it (first results)
  r19 <- bl[bl$season == 2019, ]
  restart_counts <- function(d) {
    list(n = nrow(d), homeWins = sum(d$y > 0), draws = sum(d$y == 0), awayWins = sum(d$y < 0),
         ha = round(mean(d$y), 3), homeGoals = round(mean(d$home_club_goals), 2),
         awayGoals = round(mean(d$away_club_goals), 2))
  }
  restart <- list(before = restart_counts(r19[r19$group == "full", ]),
                  after = restart_counts(r19[r19$group == "ghost", ]))

  data <- list(
    meta = list(
      source = paste0("transfermarkt-datasets (games, CC0 1.0; data from Transfermarkt.de); ",
                      "openfootball/deutschland (CC0 1.0)"),
      updated = format(Sys.Date()),
      seasons = sprintf("%s–%s", season_label(min(SEASONS)), season_label(max(SEASONS))),
      windowStart = format(WINDOW_START),
      windowEnd = format(WINDOW_END)
    ),
    summary = list(
      matches = nrow(m),
      dropped = sum(m$dropped),
      bundesliga = as.list(table(factor(bl$group, levels = c("full", "restricted", "ghost")))),
      top5 = as.list(table(factor(kept$group, levels = c("full", "restricted", "ghost"))))
    ),
    restart = restart,
    seasons = seasons,
    groups = groups,
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null"), OUT,
             useBytes = TRUE)
  cat(sprintf("\nWrote %s\n", OUT))
  cat(sprintf("  Bundesliga: %d full, %d restricted, %d ghost games\n",
              data$summary$bundesliga$full, data$summary$bundesliga$restricted,
              data$summary$bundesliga$ghost))
  cat(sprintf("  restart 2019/20: before %d-%d-%d (H-D-A), after %d-%d-%d\n",
              restart$before$homeWins, restart$before$draws, restart$before$awayWins,
              restart$after$homeWins, restart$after$draws, restart$after$awayWins))
  cat(sprintf("  main: %+.3f points per match, 95%% CI [%+.3f, %+.3f], p = %.4f, n = %d\n",
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
