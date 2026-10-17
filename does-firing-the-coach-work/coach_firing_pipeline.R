# coach_firing_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline (part 2 of 2) for story #001 "Does changing the coach win more points?".
#
# Inputs:
#   content/incoming/coach-changes/games.csv.gz   (only needed once, see prep())
#       transfermarkt-datasets `games` table, CC0 1.0, data from Transfermarkt.de
#       https://github.com/dcaribou/transfermarkt-datasets (release of 2026-09-05)
#   notebooks/raw/bundesliga/coach_games_L1.csv   (written by prep(), committed)
#   notebooks/raw/bundesliga/matches.csv          (openfootball, for cross-checking)
#   notebooks/claims/does-firing-the-coach-work.json   (claim and fork texts, hand-written)
# Outputs:
#   data/does-firing-the-coach-work.json
#   data/does-firing-the-coach-work.output.txt   (this script's console output via sink(),
#                                                 with sessionInfo(); not edited afterwards)
#   The result table of the main calculation (key `estimation`) is built with
#   notebooks/estimation_table.R.
#
# Run from project root, in a UTF-8 locale:
#     LANG=C.UTF-8 Rscript notebooks/coach_firing_pipeline.R
#
# Requires: base R and jsonlite.
#
# Method
#   A coach change is the first game a club plays under a new manager during a
#   season. Stand-ins (the previous manager returns later the same season, e.g.
#   touchline bans or illness) are not changes. A caretaker followed by a new
#   permanent coach counts as one change.
#
#   For each change we compare points in the K games before and the K games after.
#   Controls are all other team-game positions with a full ±K window and no coach
#   change inside it. Main calculation: a linear model of points per game in the K games
#   after on a coach-change dummy and one dummy per points in the K games before, with the
#   t-test of the change dummy. The 18 calculation paths (comparison × window × opponents)
#   use test_path() in coach_firing_stats.R.
# ──────────────────────────────────────────────────────────────────────

if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")
library(jsonlite)
source(file.path("notebooks", "coach_firing_stats.R"))
source(file.path("notebooks", "estimation_table.R"))

INCOMING <- file.path("content", "incoming", "coach-changes", "games.csv.gz")
RAW <- file.path("notebooks", "raw", "bundesliga", "coach_games_L1.csv")
MATCHES <- file.path("notebooks", "raw", "bundesliga", "matches.csv")
OUT <- file.path("data", "does-firing-the-coach-work.json")
LOG <- file.path("data", "does-firing-the-coach-work.output.txt")
CLAIM <- file.path("notebooks", "claims", "does-firing-the-coach-work.json")

K <- 6L          # window length in games (main specification)
RUN_TIME <- Sys.time()
FORK_OPTIONS <- list(
  comparison = c("before", "matched", "all_slumps"),
  window = c("5", "6", "10"),
  opponents = c("no", "yes")
)

DISPLAY <- c(
  "1. Fußballclub Heidenheim 1846" = "1. FC Heidenheim",
  "1.FC Köln" = "1. FC Köln",
  "1.FC Nuremberg" = "1. FC Nürnberg",
  "1.FC Union Berlin" = "Union Berlin",
  "1.FSV Mainz 05" = "Mainz 05",
  "Bayer 04 Leverkusen" = "Bayer Leverkusen",
  "Bayern Munich" = "Bayern München",
  "Borussia Mönchengladbach" = "Mönchengladbach",
  "SV Werder Bremen" = "Werder Bremen",
  "TSG 1899 Hoffenheim" = "Hoffenheim"
)

read_csv_utf8 <- function(path) {
  read.csv(path, encoding = "UTF-8", stringsAsFactors = FALSE, check.names = FALSE)
}

# Filter the transfermarkt games table to the Bundesliga and check it against openfootball.
prep <- function() {
  g <- read.csv(gzfile(INCOMING, encoding = "UTF-8"), stringsAsFactors = FALSE)
  l1 <- g[g$competition_id == "L1",
          c("season", "round", "date", "home_club_name", "away_club_name",
            "home_club_goals", "away_club_goals", "home_club_manager_name",
            "away_club_manager_name")]
  l1 <- l1[order(l1$date, l1$home_club_name, method = "radix"), ]
  stopifnot(all(table(l1$season) == 306))
  stopifnot(!anyNA(l1$home_club_manager_name), !anyNA(l1$away_club_manager_name))

  # Cross-check: every date has the same multiset of scorelines in both sources
  of <- read_csv_utf8(MATCHES)
  by_date <- function(df, h, a) {
    lines <- paste(df[[h]], df[[a]], sep = "-")
    tapply(lines, df$date, function(x) paste(sort(x, method = "radix"), collapse = " "))
  }
  tm <- by_date(l1, "home_club_goals", "away_club_goals")
  ofd <- by_date(of[of$date %in% names(tm), ], "home_goals", "away_goals")
  stopifnot(setequal(names(tm), names(ofd)), all(tm == ofd[names(tm)]))
  cat(sprintf("prep: %d Bundesliga matches, %d match dates agree with openfootball\n",
              nrow(l1), length(tm)))
  dir.create(dirname(RAW), recursive = TRUE, showWarnings = FALSE)
  write.csv(l1, RAW, row.names = FALSE, fileEncoding = "UTF-8")
}

# Points above expectation given the opponent (spec §7.1, opponents=yes).
#
# Expected points come from a league-wide linear fit of points on the opponent's season points
# per game (this match excluded) and home advantage. The opponent's season figure includes games
# played after a coach change: leakage of later information, accepted and disclosed.
add_expected_points <- function(tg) {
  key <- paste(tg$season, tg$club)
  sums <- tapply(tg$pts, key, sum)
  sizes <- tapply(tg$pts, key, length)
  okey <- paste(tg$season, tg$opp)
  opp_pts_here <- c(3, 1, 0)[match(tg$pts, c(0, 1, 3))]
  tg$opp_ppg_loo <- (sums[okey] - opp_pts_here) / (sizes[okey] - 1)
  x <- cbind(1, tg$opp_ppg_loo, tg$home)
  beta <- qr.coef(qr(x), tg$pts)
  tg$adj <- tg$pts - drop(x %*% beta)
  tg
}

# One row per team per game, in date order within each season.
team_games <- function() {
  l1 <- read_csv_utf8(RAW)
  home <- data.frame(season = l1$season, date = l1$date, home = 1L, club = l1$home_club_name,
                     opp = l1$away_club_name, gf = l1$home_club_goals,
                     ga = l1$away_club_goals, mgr = l1$home_club_manager_name)
  away <- data.frame(season = l1$season, date = l1$date, home = 0L, club = l1$away_club_name,
                     opp = l1$home_club_name, gf = l1$away_club_goals,
                     ga = l1$home_club_goals, mgr = l1$away_club_manager_name)
  tg <- rbind(home, away)
  tg <- tg[order(tg$season, tg$club, tg$date, method = "radix"), ]
  rownames(tg) <- NULL
  tg$pts <- ifelse(tg$gf > tg$ga, 3L, ifelse(tg$gf == tg$ga, 1L, 0L))
  key <- paste(tg$season, tg$club)
  tg$n <- ave(seq_along(key), key, FUN = seq_along)
  season_ppg <- tapply(tg$pts, key, mean)
  tg$opp_ppg <- unname(season_ppg[paste(tg$season, tg$opp)])
  add_expected_points(tg)
}

find_changes <- function(tg, k) {
  changes <- list()
  standins <- 0L
  key <- paste(tg$season, tg$club, sep = "\r")
  for (grp in unique(key)) {
    d <- tg[key == grp, ]
    m <- d$mgr
    n <- length(m)
    i <- 1L  # 0-based position of the game being looked at, as in the original Python
    while (i < n) {
      if (m[i + 1] == m[i]) {
        i <- i + 1L
        next
      }
      outgoing <- m[i]
      rest <- m[(i + 1):n]
      if (outgoing %in% rest) {
        # Stand-in: skip to the outgoing manager's return
        standins <- standins + 1L
        i <- i + match(outgoing, rest)
        next
      }
      permanent <- m[min(i + k - 1L, n - 1L) + 1L]
      changes[[length(changes) + 1]] <- data.frame(
        season = d$season[1], club = d$club[1], game = i + 1L,
        out = outgoing, `in` = m[i + 1], permanent = permanent, check.names = FALSE
      )
      i <- i + k  # a caretaker-then-permanent sequence is one change
    }
  }
  list(changes = do.call(rbind, changes), standins = standins)
}

# Sum of the k values before position i (NA without k of them).
roll_prev <- function(x, k) {
  n <- length(x)
  out <- rep(NA_real_, n)
  if (n > k) for (i in (k + 1):n) out[i] <- sum(x[(i - k):(i - 1)])
  out
}

# Sum of the value at i and the k - 1 after it (NA without k of them).
roll_next <- function(x, k) {
  n <- length(x)
  out <- rep(NA_real_, n)
  if (n >= k) for (i in 1:(n - k + 1)) out[i] <- sum(x[i:(i + k - 1)])
  out
}

windows <- function(tg, k) {
  key <- paste(tg$season, tg$club)
  by_team <- function(x, f) ave(as.numeric(x), key, FUN = function(v) f(v, k))
  tg$pre <- by_team(tg$pts, roll_prev)
  tg$post <- by_team(tg$pts, roll_next)
  tg$pre_adj <- by_team(tg$adj, roll_prev)
  tg$post_adj <- by_team(tg$adj, roll_next)
  tg$opp_post <- by_team(tg$opp_ppg, roll_next) / k
  tg
}

split_windows <- function(tg, changes, k) {
  w <- windows(tg, k)
  wkey <- paste(w$season, w$club, w$n)
  idx <- match(paste(changes$season, changes$club, changes$game), wkey)
  treated <- cbind(changes, w[idx, setdiff(names(w), c("season", "club"))])
  treated <- treated[!is.na(treated$pre) & !is.na(treated$post), ]
  rownames(treated) <- NULL
  pool <- w[!is.na(w$pre) & !is.na(w$post), ]
  # a stretch is clean if no change falls on games n - k + 1 .. n + k of the same club-season
  near <- unlist(lapply(seq_len(nrow(changes)), function(r) {
    paste(changes$season[r], changes$club[r], (changes$game[r] - k):(changes$game[r] + k - 1))
  }))
  control <- pool[!(paste(pool$season, pool$club, pool$n) %in% near), ]
  rownames(control) <- NULL
  list(treated = treated, control = control)
}

# Mean of post minus the matched controls' mean post, per game.
effect <- function(treated, control, k) {
  cm <- tapply(control$post, control$pre, mean)
  cp <- cm[as.character(treated$pre)]
  ok <- !is.na(cp)
  mean(treated$post[ok] - cp[ok]) / k
}

# Every combination of the forks in the claim file, in fork order (spec §7.1).
compute_specs <- function(tg, forks) {
  ids <- vapply(forks, function(f) f$id, "")
  options <- lapply(forks, function(f) vapply(f$options, function(o) o$id, ""))
  names(options) <- ids
  stopifnot(identical(ids, names(FORK_OPTIONS)), identical(options, FORK_OPTIONS))
  splits <- list()
  for (window in FORK_OPTIONS$window) {
    k <- as.integer(window)
    splits[[window]] <- split_windows(tg, find_changes(tg, k)$changes, k)
  }
  specs <- list()
  for (comparison in FORK_OPTIONS$comparison) {
    for (window in FORK_OPTIONS$window) {
      for (opponents in FORK_OPTIONS$opponents) {
        i <- length(specs) + 1L
        choices <- list(comparison = comparison, window = window, opponents = opponents)
        key <- paste0(names(choices), "=", unlist(choices), collapse = "|")
        sp <- splits[[window]]
        s <- test_path(sp$treated, sp$control, comparison, opponents, as.integer(window))
        specs[[i]] <- c(list(choices = choices), s[c("effect", "ci_low", "ci_high", "p", "n")])
        cat(sprintf("  %s: n=%d, %+.3f [%+.3f, %+.3f] p=%.4f\n", key, s$n, s$effect,
                    s$ci_low, s$ci_high, s$p))
      }
    }
  }
  specs
}

# Points per game at relative games -k..-1 and +1..+k, controls matched on pre.
trajectories <- function(tg, treated, control, k) {
  pkey <- paste(tg$season, tg$club, tg$n)
  vec <- function(df) {
    sapply(-k:(k - 1), function(j) tg$pts[match(paste(df$season, df$club, df$n + j), pkey)])
  }
  t <- vec(treated)
  cv <- vec(control)
  by_pre <- rowsum(cv, control$pre) / as.vector(table(control$pre))
  c <- by_pre[as.character(treated$pre), , drop = FALSE]
  list(t = t, c = c)
}

season_label <- function(s) sprintf("%d/%s", s, substr(s + 1, 3, 4))

# The result table of the main calculation (estimation_table.R): the coefficient of the
# coach-change dummy with its t-test; the dummies for the points before are not shown.
estimation <- function(tg, spec, sre) {
  sp <- split_windows(tg, find_changes(tg, K)$changes, K)
  s <- test_path(sp$treated, sp$control, "matched", "no", K)
  stopifnot(abs(s$effect - spec$effect) < 1e-12, abs(s$p - spec$p) < 1e-12)
  sm <- summary(s$fit)
  seasons <- sprintf("%s–%s", season_label(min(tg$season)), season_label(max(tg$season)))
  est_table(RUN_TIME,
    dependent = txt(sprintf("Points per game in the %d games after", K),
                    sprintf("Punkte je Spiel in den %d Spielen danach", K)),
    method = txt("Least squares, dummies for the points before, t-test",
                 "Kleinste Quadrate, Dummies für die Punkte davor, t-Test"),
    sample = txt(sprintf("Bundesliga %s", seasons)),
    observations = nobs(s$fit),
    rows = list(
      est_row("Coach change (dummy)", "Trainerwechsel (Dummy)",
              est_values_t(s$effect, s$se, s$df))
    ),
    left = list(
      est_stat("Coach changes", "Trainerwechsel", s$n, 0),
      est_stat("Control stretches", "Vergleichsserien", nobs(s$fit) - s$n, 0),
      est_stat("Dummies for points before", "Dummies für Punkte davor",
               length(coef(s$fit)) - 2, 0),
      est_stat("Window (games)", "Fenster (Spiele)", K, 0)
    ),
    right = list(
      est_stat("R-squared", "R²", sm$r.squared, 6),
      est_stat("Degrees of freedom", "Freiheitsgrade", s$df, 0),
      est_stat("Significance level", "Signifikanzniveau", ALPHA, 2),
      est_stat("Smallest relevant effect", "Kleinster relevanter Effekt", sre, 2)
    )
  )
}

main <- function() {
  if (file.exists(INCOMING)) prep()
  tg <- team_games()
  league_ppg <- mean(tg$pts)

  fc <- find_changes(tg, K)
  changes <- fc$changes
  sp <- split_windows(tg, changes, K)
  treated <- sp$treated
  control <- sp$control
  cm <- tapply(control$post, control$pre, mean)
  treated$ctrl_post <- unname(cm[as.character(treated$pre)])
  eff <- effect(treated, control, K)
  traj <- trajectories(tg, treated, control, K)

  # Slump depth: what happens next, by points in the previous K games (no coach change)
  depth_mean <- tapply(control$post, control$pre, mean)
  depth_n <- tapply(control$post, control$pre, length)
  depth <- lapply(names(depth_mean), function(p) {
    list(pre = as.integer(p), postPpg = round(depth_mean[[p]] / K, 3), n = depth_n[[p]])
  })
  slump <- control[control$pre <= 4, ]
  crisis <- treated[treated$pre <= 4, ]
  improved_by_pre <- tapply(control$post > control$pre, control$pre, mean)

  claim_file <- fromJSON(CLAIM, simplifyVector = FALSE)
  cat("Calculation paths:\n")
  specs <- compute_specs(tg, claim_file$forks)
  primary <- lapply(claim_file$forks, function(f) f$primary)
  names(primary) <- vapply(claim_file$forks, function(f) f$id, "")
  stopifnot(identical(primary, list(comparison = "matched", window = as.character(K),
                                    opponents = "no")))
  main_i <- which(vapply(specs, function(s) identical(s$choices, primary), TRUE))
  main_spec <- specs[[main_i]]
  est <- estimation(tg, main_spec, claim_file$claim$smallest_relevant_effect)
  cat("\nResult table of the main calculation:\n")
  print_est_table(est)
  cat("\n")

  points_of <- function(row) lapply(row, function(v) if (is.na(v)) NULL else as.integer(v))
  data <- list(
    meta = list(
      source = paste0("transfermarkt-datasets (games, CC0 1.0; data from Transfermarkt.de); ",
                      "openfootball/deutschland (CC0 1.0)"),
      updated = format(Sys.Date()),
      seasons = sprintf("%s–%s", season_label(min(tg$season)), season_label(max(tg$season))),
      window = K
    ),
    summary = list(
      matches = nrow(tg) %/% 2L,
      changes = nrow(changes),
      standins = fc$standins,
      analysed = nrow(treated),
      controlPositions = nrow(control),
      leaguePpg = round(league_ppg, 3)
    ),
    effect = list(
      prePpg = round(mean(treated$pre) / K, 3),
      postPpg = round(mean(treated$post) / K, 3),
      controlPostPpg = round(mean(treated$ctrl_post) / K, 3),
      perGame = round(main_spec$effect, 3),
      perWindow = round(main_spec$effect * K, 2),
      improvedShare = round(mean(treated$post > treated$pre), 3),
      controlImprovedShare = round(mean(improved_by_pre[as.character(treated$pre)]), 3),
      oppPostPpg = round(mean(treated$opp_post), 3),
      controlOppPostPpg = round(mean(control$opp_post), 3)
    ),
    slump = list(
      threshold = 4L,
      positions = nrow(slump),
      prePpg = round(mean(slump$pre) / K, 3),
      postPpg = round(mean(slump$post) / K, 3),
      crisisChanges = nrow(crisis),
      crisisPrePpg = round(mean(crisis$pre) / K, 3),
      crisisPostPpg = round(mean(crisis$post) / K, 3)
    ),
    trajectory = list(
      relative = c(-K:-1, 1:K),
      changes = round(colMeans(traj$t, na.rm = TRUE), 3),
      controls = round(colMeans(traj$c, na.rm = TRUE), 3)
    ),
    depth = depth,
    changes = lapply(seq_len(nrow(treated)), function(i) {
      r <- treated[i, ]
      club <- if (r$club %in% names(DISPLAY)) unname(DISPLAY[r$club]) else r$club
      list(season = season_label(r$season), club = club, game = r$game, out = r$out,
           `in` = r$`in`, permanent = r$permanent, pre = as.integer(r$pre),
           post = as.integer(r$post), ctrlPost = round(r$ctrl_post, 2),
           points = points_of(traj$t[i, ]))
    }),
    estimation = est,
    claim = claim_file$claim,
    forks = claim_file$forks,
    specs = specs
  )
  writeLines(toJSON(data, auto_unbox = TRUE, digits = NA, pretty = 1, null = "null"), OUT,
             useBytes = TRUE)
  e <- data$effect
  cat(sprintf("Wrote %s\n", OUT))
  cat(sprintf("  %d changes (%d stand-ins excluded), %d with full ±%d windows\n",
              nrow(changes), fc$standins, nrow(treated), K))
  cat(sprintf("  before %s → after %s ppg; matched controls → %s\n",
              e$prePpg, e$postPpg, e$controlPostPpg))
  cat(sprintf("  main: %+.3f ppg, 95%% CI [%+.3f, %+.3f], p = %.4f\n",
              main_spec$effect, main_spec$ci_low, main_spec$ci_high, main_spec$p))
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
