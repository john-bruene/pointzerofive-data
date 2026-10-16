# estimation_table.R
# ──────────────────────────────────────────────────────────────────────
# The result table of a story's main calculation, laid out like an EViews estimation output
# (decision log 16 Oct 2026). The pipeline builds it with est_table(), writes it into the story's
# JSON (key `estimation`, English and German texts) and prints the English version to its console
# output with print_est_table(). The website draws the table from the JSON; it does not compute
# anything.
#
# Requires: base R only.
# ──────────────────────────────────────────────────────────────────────

# A text in both languages.
txt <- function(en, de = en) list(en = en, de = de)

# One line of the statistics block under the table.
est_stat <- function(en, de, value, digits) {
  list(label = txt(en, de), value = value, digits = as.integer(digits))
}

# One row of the coefficient table: name and one value per column (NA = empty cell).
est_row <- function(en, de, values) list(name = txt(en, de), values = as.list(unname(values)))

# The columns every bootstrap table uses.
EST_COLUMNS <- list(
  txt("Coefficient", "Koeffizient"),
  txt("Std. Error", "Std.-Fehler"),
  txt("Lower 95%", "Untere 95 %"),
  txt("Upper 95%", "Obere 95 %"),
  txt("Prob.", "p-Wert")
)
EST_DIGITS <- c(6L, 6L, 6L, 6L, 4L)

# Coefficient, standard error, 95% interval and two-sided p-value of one set of bootstrap
# replicates; same order statistics and p-value as summarize() in the pipelines.
est_values <- function(estimate, reps, alpha = 0.05) {
  b <- length(reps)
  m <- round(alpha / 2 * b)
  s <- sort(reps)
  p <- min(1, 2 * min(sum(reps <= 0), sum(reps >= 0)) / b)
  unname(c(estimate, sd(reps), s[m], s[b + 1 - m], p))
}

# The same columns for an estimate with a t distribution (e.g. an OLS coefficient): interval
# estimate ± t(1 - alpha/2, df) × se and the two-sided p-value of the t-test.
est_values_t <- function(estimate, se, df, alpha = 0.05) {
  q <- qt(1 - alpha / 2, df)
  unname(c(estimate, se, estimate - q * se, estimate + q * se,
           2 * pt(-abs(estimate / se), df)))
}

est_table <- function(run, dependent, method, sample, observations, rows, left, right) {
  list(run = format(run, "%Y-%m-%dT%H:%M:00Z", tz = "UTC"), dependent = dependent,
       method = method, sample = sample, observations = as.integer(observations),
       columns = EST_COLUMNS, digits = EST_DIGITS, rows = rows,
       stats = list(left = left, right = right))
}

# The English table as plain text, in the console output.
print_est_table <- function(t) {
  num <- function(v, d) if (is.null(v) || is.na(v)) "" else formatC(v, format = "f", digits = d)
  w <- 86
  rule <- function(ch) cat(strrep(ch, w), "\n", sep = "")
  rule("=")
  cat("Dependent Variable: ", t$dependent$en, "\n", sep = "")
  cat("Method: ", t$method$en, "\n", sep = "")
  cat("Date: ", substr(t$run, 1, 10), "   Time: ", substr(t$run, 12, 16), " UTC\n", sep = "")
  cat("Sample: ", t$sample$en, "\n", sep = "")
  cat("Included observations: ", t$observations, "\n", sep = "")
  rule("=")
  heads <- vapply(t$columns, function(x) x$en, "")
  cat(formatC("Variable", width = -26), paste(formatC(heads, width = 12), collapse = ""), "\n",
      sep = "")
  rule("-")
  for (r in t$rows) {
    cells <- mapply(function(v, d) num(v, d), r$values, t$digits)
    cat(formatC(r$name$en, width = -26), paste(formatC(cells, width = 12), collapse = ""), "\n",
        sep = "")
  }
  rule("-")
  side <- function(s) if (is.null(s)) strrep(" ", 43) else
    paste0(formatC(s$label$en, width = -29), formatC(num(s$value, s$digits), width = 12), "  ")
  for (i in seq_len(max(length(t$stats$left), length(t$stats$right)))) {
    l <- if (i <= length(t$stats$left)) t$stats$left[[i]] else NULL
    r <- if (i <= length(t$stats$right)) t$stats$right[[i]] else NULL
    cat(sub(" +$", "", paste0(side(l), side(r))), "\n", sep = "")
  }
  rule("=")
}
