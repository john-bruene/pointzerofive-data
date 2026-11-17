# Story Pitch — Does the halfway leader usually win the Bundesliga?

> Standards: `content/story-standards.md`; rules: `content/no-slop.md`.

---

## Meta

| Field | Value |
| --- | --- |
| Story number | #008 |
| Working title | Does the halfway leader usually win the Bundesliga? / Wird der Herbstmeister am Ende meistens Meister? |
| Slug | `/2026/10/herbstmeister-usually-champion` (URL month follows the display date John sets) |
| Target publish week | display date set by John; the next free Thursday in the series is 29 October 2026 |
| Status | pitch fixed 2026-11-17, before the analysis |

## 1. Fragestellung (the question)

**When a club is top of the Bundesliga at the halfway point, does it usually end the season as
champion?**

- Popular claim: the Herbstmeister becomes Meister. Every December the sports pages count how
  often that happened. The title "Herbstmeister" is unofficial, and a few famous collapses
  (Hoffenheim 2008/09, seventh at the end) keep the opposite story alive.
- What we measure: per season, whether the team on top of the first-half table won the title.
  The question is "meistens": in more than half of the seasons.
- Known before the analysis (published counts, not computed by me): bundesliga.com counted
  43 Herbstmeister out of 62 who became champion (15 January 2026), Bayern 24 of 27, all other
  clubs 19 of 35. The DSFS counted 38 of 57 up to 2020. I have not counted anything myself yet.
- Hypothesis, written before the analysis: over all seasons, clearly more than half (yes). Without
  the seasons in which Bayern was Herbstmeister, a share near one half that is not significant.
  The fork "which seasons" will decide the verdict on several paths.

## 1b. Der Streit, die Gabelungen, die Präregistrierung

Fixed on 2026-11-17, after checking which seasons the open data covers and counting matches per
season, before computing any table, Herbstmeister, champion or share.

- **Claim as yes/no question:** EN "Does the halfway leader usually win the Bundesliga?" /
  DE „Wird der Herbstmeister am Ende meistens Meister?"
- **Says yes:** bundesliga.com (2021): 39 of 58 Herbstmeister became champion, 67 per cent
  (see Dispute).
- **Says no:** bundesliga.com (2026), the same publisher four years later, split by club: Bayern
  converted 24 of 27 halfway leads, every other club only 19 of 35, little more than a coin toss.
  So "meistens" may hold for Bayern only. There is no study that says no for all clubs; the
  dispute is whether the rule is more than a Bayern habit.
- **Unit:** one Bundesliga season, 1963/64 to 2025/26 (63 completed seasons).
- **Herbstmeister:** the team on top of the table built from all first-half matches (matchdays 1
  to 17; 1 to 15 in 1963/64 and 1964/65 with 16 clubs; 1 to 19 in 1991/92 with 20 clubs),
  postponed first-half matches included. Points as awarded at the time (two per win until
  1994/95, three from 1995/96). Ties on points are broken by the rule of the time: goal quotient
  until 1968/69, then goal difference, then goals scored.
- **Champion:** the team on top of the final table under the same rules, checked against the
  official list of German champions.
- **Outcome:** y = 1 if the Herbstmeister became champion, else 0.
- **Effect:** share of seasons with y = 1 minus 0.5, in percentage points. Positive = the
  Herbstmeister becomes champion in more than half of the seasons (the claimed direction).
- **Primary test and how p and the 95% confidence interval are computed:** logistic regression
  (binomial GLM, logit link) of y on an intercept only, `glm(y ~ 1, family = binomial)`. The
  intercept is the log-odds of the share. H0: share = 0.5, i.e. intercept = 0; Wald z-test. 95%
  confidence interval: intercept ± 1.96 standard errors on the log-odds scale, transformed to the
  share with the logistic function, minus 0.5. Because the interval and the test use the same
  standard error, p < 0.05 exactly when the interval excludes zero. No random numbers.
- **α:** 0.05, **two-sided**. Verdict "yes" needs p < 0.05 and a positive effect.
- **Main calculation:** seasons = `all`, table = `first_half`, ties = `official`.
- **Smallest relevant effect:** 10 percentage points, a share of 60 per cent. Three of five
  Herbstmeister becoming champion is the least I would call "meistens"; 52 per cent would be a
  coin toss with a slight lean.
- **Fixed before the analysis:** everything in this section. **Fixed after:** nothing so far.

| Fork as an everyday question (EN / DE) | Options with one-line reason | Main | Why it could flip the result |
| --- | --- | --- | --- |
| Which seasons count? / Welche Spielzeiten zählen? | `all`: every season since the Bundesliga began in 1963/64 · `without_bayern`: only seasons in which a club other than Bayern was Herbstmeister, because Bayern's dominance may carry the whole rule · `three_points`: only seasons since 1995/96, three points per win, a different league | `all` | Bayern converts almost every halfway lead; without them the share may sink towards one half |
| Which table counts? / Welche Tabelle zählt? | `first_half`: the table after all first-half matches, the Herbstmeister in the strict sense · `winter_break`: the table on 31 December, the leader at Christmas, which is what most people remember | `first_half` | In many seasons the winter break and the end of the first half fall on different matchdays (e.g. 2022/23, World Cup break after matchday 15) |
| Does a lead on goals alone count? / Zählt ein Herbstmeister, der nur nach Toren vorne liegt? | `official`: yes, the tie-break rules decide who is top, as the table shows it · `clear_lead`: only seasons in which the leader was ahead on points; seasons with a tie on points at the top are left out | `official` | A leader level on points with the second (Hoffenheim 2008/09) is a weak leader; leaving them out may raise the share |

3 × 2 × 2 = 12 paths. All forks, options, the definitions, the effect formula, the test and the
smallest relevant effect are fixed now, before the analysis.

## 2. Datenbeschaffung (data acquisition)

| Source | URL | Format | License / Terms | Accessed |
| --- | --- | --- | --- | --- |
| football.csv / deutschland, Bundesliga 1963/64–2009/10 (export of openfootball) | https://github.com/footballcsv/deutschland, files `<decade>/<season>/de.1.csv` | CSV | CC0 1.0 | 2026-11-17 |
| openfootball/deutschland, Bundesliga 2010/11–2025/26 | https://github.com/openfootball/deutschland | text | CC0 1.0 | already in `notebooks/raw/bundesliga/matches.csv` (#001) |
| Official list of German champions (cross-check only) | to be fixed in the pipeline with its URL | web page | citation | 2026-11-17 |

- **Acquisition plan:** `notebooks/herbstmeister_pipeline.R` downloads the 47 seasons 1963/64 to
  2009/10 from football.csv once (`prep()`), writes `notebooks/raw/bundesliga/matches_1963_2010.csv`
  (committed) and checks the 11 seasons 2010/11 to 2020/21, which both sources have, match date by
  match date against `matches.csv`.
- **Unit of analysis:** season. **Coverage:** 63 completed seasons; the running season 2026/27 is
  not part of the analysis.
- **Known biases / caveats:** results only, no point deductions (none decided a title); one
  league, so the share says nothing about other leagues. Other big leagues are not available as
  open data for the whole period (football.csv has gaps), so there is no fork for them.

## 3. Geplante Visualisierung (planned figures)

- **Fig. 1 (first results):** every season 1963/64–2025/26, the Herbstmeister's final place
  (1 = champion), open circles; the seasons in which the Herbstmeister did not win in red,
  labelled with the club.
- **Fig. 2 (analysis):** the Herbstmeister's lead in points after the first half (recounted with
  three points per win for all seasons, so leads are comparable) against the outcome, with a
  descriptive logistic curve. Descriptive only, not part of the test.
- Robustness: specification curve of all 12 paths and the table.

## 4. Quellenangaben (sources & attribution)

- football.csv / openfootball (CC0 1.0).
- Counts in the press: see Dispute.

## Dispute (checked 2026-11-17)

| Side | Source (exact citation) | URL | Finding in one sentence |
| --- | --- | --- | --- |
| Yes | Bundesliga.com: „Herbstmeisterschaft: Rekorde, Zahlen und Fakten", 14 December 2021 | https://www.bundesliga.com/de/bundesliga/news/herbstmeisterschaft-rekord-zahlen-fakten-borussia-dortmund-bvb-bayern-munchen-699 | „In 39 der bislang 58 abgeschlossenen Spielzeiten (67 Prozent)" the first-half leader was also champion. |
| No | Bundesliga.com: "What does being top of the table halfway mean for the title race?", 15 January 2026 | https://www.bundesliga.com/en/bundesliga/news/what-does-being-top-of-table-halfway-mean-for-title-race-bayern-munich-30419 | Bayern won 24 of their 27 halfway leads; the other clubs only 19 of 35, about 54 per cent. |
| Context | Niggemann, C. (2020). Meisterkriterien in der Bundesliga. Statistische Auswertungen. Deutscher Sportclub für Fußballstatistiken (DSFS), as of 7 July 2020 | https://www.dsfs.de/wp-content/uploads/2024/01/Bundesliga_Statistische_Auswertungen_Meisterkriterien.pdf | Herbstmeister champion in 38 of 57 seasons (66.67 %); fewest defeats (87.72 %) and most wins (85.96 %) were better predictors. |

## 5. Outcome (2026-11-17, written after the analysis)

- Nothing in §1b was changed after the pitch commit (6691956, 19:51 UTC). The pipeline implements
  the definitions, forks, effect and test exactly as written there.
- One display text changed, no method: `cases` in `claim.json` read "{n} seasons since 1963/64",
  which would be wrong on the paths that start in 1995/96; it now reads "{n} Bundesliga seasons".
- Data: 19,220 matches; football.csv 14,324 matches 1963/64–2009/10; for 2010/11–2019/20 both
  sources agree on all 961 match dates. Halfway leader, champion and "champion yes/no" agree with
  the two Wikipedia lists in all 63 seasons.
- Main: 44 of 63 halfway leaders became champion, +19.8 percentage points [+7.5, +29.9],
  p = 0.0022, n = 63: **Yes.** The lower bound lies below the smallest relevant effect of 10.
  A χ² test against 50:50 gives p = 0.0016. Up to 2019/20: 38 of 57, the DSFS count.
- Bayern 25 of 28, other clubs 19 of 35 (Bundesliga.com's January count plus 2025/26).
- Yes on 8 of 12 paths. All four paths without the Bayern seasons say No (main path without
  Bayern: +4.3 [−12.1, +19.8], p = 0.61); since 1995/96 +24.2 [+6.3, +36.5], p = 0.010.
- Hypothesis confirmed. Lead at halfway (three points per win): 6 or more, 15 of 17 champions;
  2 or less, 15 of 29.
