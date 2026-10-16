# bundesliga_matches_pipeline.R
# ──────────────────────────────────────────────────────────────────────
# Data pipeline (part 1 of 2) for story #004 "Does changing the coach win more points?":
# every Bundesliga result 2010/11–2025/26.
#
# Input:  openfootball/deutschland (CC0 1.0), fetched from GitHub:
#         https://github.com/openfootball/deutschland  <season>/1-bundesliga.txt
# Output: notebooks/raw/bundesliga/matches.csv
#         one row per match: season, matchday, date, home, away, home_goals, away_goals
#
# Run from project root, in a UTF-8 locale (club names and the "▪" marker):
#     LANG=C.UTF-8 Rscript notebooks/bundesliga_matches_pipeline.R
#
# Requires: base R only.
# ──────────────────────────────────────────────────────────────────────

if (!isTRUE(l10n_info()[["UTF-8"]])) stop("Run in a UTF-8 locale, e.g. LANG=C.UTF-8 Rscript …")

OUT <- file.path("notebooks", "raw", "bundesliga", "matches.csv")
BASE <- "https://raw.githubusercontent.com/openfootball/deutschland/master"
SEASONS <- sprintf("%d-%s", 2010:2025, substr(2011:2026, 3, 4))

# openfootball spells some clubs differently across seasons — one canonical name each
CANONICAL <- c(
  "FC Bayern München" = "Bayern München",
  "TSG 1899 Hoffenheim" = "1899 Hoffenheim",
  "TSG Hoffenheim" = "1899 Hoffenheim",
  "Borussia Mönchengladbach" = "Bor. Mönchengladbach",
  "Mönchengladbach" = "Bor. Mönchengladbach",
  "Borussia M'gladbach" = "Bor. Mönchengladbach",
  "FC St. Pauli 1910" = "FC St. Pauli",
  "SpVgg Greuther Fürth 1903" = "SpVgg Greuther Fürth",
  "Heidenheim" = "1. FC Heidenheim",
  "1. FC Heidenheim 1846" = "1. FC Heidenheim",
  "Wolfsburg" = "VfL Wolfsburg",
  "Union Berlin" = "1. FC Union Berlin",
  "Mainz 05" = "1. FSV Mainz 05",
  "FSV Mainz 05" = "1. FSV Mainz 05",
  "Köln" = "1. FC Köln",
  "Hamburg" = "Hamburger SV",
  "St. Pauli" = "FC St. Pauli",
  "Augsburg" = "FC Augsburg",
  "Freiburg" = "SC Freiburg",
  "Werder" = "Werder Bremen",
  "SV Werder Bremen" = "Werder Bremen",
  "Schalke 04" = "FC Schalke 04",
  "Dortmund" = "Borussia Dortmund",
  "Leverkusen" = "Bayer Leverkusen",
  "Bayer 04 Leverkusen" = "Bayer Leverkusen",
  "Stuttgart" = "VfB Stuttgart",
  "Frankfurt" = "Eintracht Frankfurt",
  "Leipzig" = "RB Leipzig",
  "Bochum" = "VfL Bochum",
  "VfL Bochum 1848" = "VfL Bochum",
  "Holstein Kiel" = "Holstein Kiel",
  "Darmstadt" = "SV Darmstadt 98",
  "Hertha Berlin" = "Hertha BSC",
  "Hertha BSC Berlin" = "Hertha BSC",
  "Arminia Bielefeld" = "Arminia Bielefeld",
  "Greuther Fürth" = "SpVgg Greuther Fürth",
  "Fortuna Düsseldorf" = "Fortuna Düsseldorf",
  "Paderborn" = "SC Paderborn 07",
  "SC Paderborn" = "SC Paderborn 07",
  "Ingolstadt" = "FC Ingolstadt 04",
  "Hannover" = "Hannover 96",
  "Nürnberg" = "1. FC Nürnberg",
  "Kaiserslautern" = "1. FC Kaiserslautern",
  "Braunschweig" = "Eintracht Braunschweig"
)

MONTHS <- c(Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6,
            Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12)

# (*UCP): \s, \d and \b follow Unicode, as in Python's re
RE_MATCHDAY <- "(*UCP)^▪\\s*(?:Matchday|Regular Season\\s*-)\\s*(\\d+)"
RE_DATE <- "(*UCP)^\\s*(?:Mon|Tue|Wed|Thu|Fri|Sat|Sun)\\s+([A-Z][a-z]{2})\\s+(\\d{1,2})(?:\\s+(\\d{4}))?"
# "Home v Away  2-1 (1-0)"
RE_MATCH_V <- "(*UCP)^\\s*(?:\\d{2}:\\d{2}\\s+)?(.+?)\\s+v\\s+(.+?)\\s+(\\d+)-(\\d+)\\b"
# "Home  2-1 (1-0)  Away"
RE_MATCH_SCORE <- "(*UCP)^\\s*(?:\\d{2}:\\d{2}\\s+)?(.+?)\\s{2,}(\\d+)-(\\d+)(?:\\s+\\(\\d+-\\d+\\))?\\s{2,}(.+?)\\s*$"

# Capture groups of a perl regex as a character vector, or NULL without a match.
groups <- function(pattern, x) {
  m <- regexec(pattern, x, perl = TRUE)[[1]]
  if (m[1] == -1) return(NULL)
  g <- regmatches(x, list(m))[[1]]
  attr(g, "end") <- m[1] + attr(m, "match.length")[1]
  g
}

canon <- function(name) {
  name <- gsub("(*UCP)\\s+", " ", trimws(name, whitespace = "[\\h\\v]"), perl = TRUE)
  if (name %in% names(CANONICAL)) unname(CANONICAL[name]) else name
}

parse_season <- function(season, lines) {
  start_year <- as.integer(substr(season, 1, 4))
  rows <- list()
  matchday <- NA_integer_
  current <- NA_character_
  for (line in lines) {
    if (!is.null(g <- groups(RE_MATCHDAY, line))) {
      matchday <- as.integer(g[2])
      next
    }
    if (!is.null(g <- groups(RE_DATE, line))) {
      mon <- MONTHS[[g[2]]]
      day <- as.integer(g[3])
      year <- if (nzchar(g[4])) as.integer(g[4]) else if (mon >= 7) start_year else start_year + 1L
      current <- sprintf("%04d-%02d-%02d", year, mon, day)
      rest <- substring(line, attr(g, "end"))
      if (!grepl("\\d+-\\d+", rest, perl = TRUE)) next
      line <- rest
    }
    if (is.na(matchday) || is.na(current) || startsWith(trimws(line, whitespace = "[\\h\\v]"), "(")) next
    if (!is.null(g <- groups(RE_MATCH_V, line))) {
      home <- g[2]; away <- g[3]; hg <- g[4]; ag <- g[5]
    } else if (!is.null(g <- groups(RE_MATCH_SCORE, line))) {
      home <- g[2]; hg <- g[3]; ag <- g[4]; away <- g[5]
    } else {
      next
    }
    home <- sub("(*UCP)^\\d{2}:\\d{2}\\s+", "", home, perl = TRUE)
    rows[[length(rows) + 1]] <- data.frame(
      season = season, matchday = matchday, date = current,
      home = canon(home), away = canon(away),
      home_goals = as.integer(hg), away_goals = as.integer(ag)
    )
  }
  do.call(rbind, rows)
}

main <- function() {
  all_rows <- list()
  for (season in SEASONS) {
    lines <- readLines(url(sprintf("%s/%s/1-bundesliga.txt", BASE, season)),
                       encoding = "UTF-8", warn = FALSE)
    rows <- parse_season(season, lines)
    teams <- unique(c(rows$home, rows$away))
    cat(sprintf("%s: %d matches, %d teams\n", season, nrow(rows), length(teams)))
    if (nrow(rows) != 306) stop(sprintf("%s: expected 306 matches, got %d", season, nrow(rows)))
    if (length(teams) != 18) stop(sprintf("%s: expected 18 teams, got %s", season,
                                          paste(sort(teams), collapse = ", ")))
    all_rows[[season]] <- rows
  }
  df <- do.call(rbind, unname(all_rows))
  # Every team plays 34 games per season, 17 home and 17 away
  per_team <- table(paste(c(df$season, df$season), c(df$home, df$away)))
  stopifnot(all(per_team == 34))
  stopifnot(!anyDuplicated(paste(df$season, df$home, df$away)))

  dir.create(dirname(OUT), recursive = TRUE, showWarnings = FALSE)
  df <- df[order(df$date, df$home, method = "radix"), ]
  stopifnot(!any(grepl("[,\"\n]", c(df$home, df$away))))
  write.csv(df, OUT, row.names = FALSE, quote = FALSE, fileEncoding = "UTF-8")
  cat(sprintf("Wrote %s (%d matches, %d clubs, accessed %s)\n",
              OUT, nrow(df), length(unique(df$home)), format(Sys.Date())))
}

if (sys.nframe() == 0L) main()
