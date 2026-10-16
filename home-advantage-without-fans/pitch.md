# Story Pitch — Does home advantage shrink without fans?

> Renumbered on 16 October 2026: this story was #006 and is now #003; the three pre-relaunch stories were removed. The text below is unchanged.

> Standards: `content/story-standards.md`; rules: `content/no-slop.md`.

---

## Meta

| Field | Value |
| --- | --- |
| Story number | #006 |
| Working title | Does home advantage shrink without fans? / Schrumpft der Heimvorteil ohne Zuschauer? |
| Slug | `/2026/10/home-advantage-without-fans` |
| Target publish week | 2026-W43 (Thursday 22 October 2026) |
| Status | built 2026-10-16 on branch story/006-home-advantage, to publish 2026-10-22 (see Outcome) |

## 1. Fragestellung (the question)

**Do home teams lose part of their advantage when nobody is in the stadium?**

- Popular claim: "Die Fans sind der zwölfte Mann." If the crowd carries the home team, home
  advantage must shrink in matches without spectators. From March 2020 to spring 2022 hundreds of
  league matches were played in empty stadiums: the closest thing football has to an experiment.
- What we measure: per match, the home team's points minus the away team's points (3/1/0). Home
  advantage is the mean of that difference. We compare matches without spectators with matches
  in full stadiums.
- Hypothesis, written before the analysis: for the five big leagues together, a clear reduction.
  For the Bundesliga alone with all ghost games, a smaller reduction that may not be significant,
  because the literature finds the big drop in the restart weeks of 2020 and almost none in
  2020/21. I expect the fork "which ghost games" to decide many paths.

## 1b. Der Streit, die Gabelungen, die Präregistrierung

Fixed on 2026-10-16, after downloading the data and counting matches and attendance figures per
league and month, before computing any result (no points, goals or home win shares looked at).

- **Claim as yes/no question:** EN "Does home advantage shrink without fans?" /
  DE „Schrumpft der Heimvorteil ohne Zuschauer?"
- **Says yes:** McCarrick, Bilalic, Neave & Wolfson (2021), Psychology of Sport and Exercise
  (see Dispute).
- **Says no:** Schank, Voigt & Orthey (2024), arXiv preprint (see Dispute). Fischer & Haucap
  (2021) as context: reduction in the Bundesliga, none in the 2. and 3. Liga.
- **Unit:** one league match. **Outcome:** y = home points − away points (win 3, draw 1).
- **Groups:**
  - *Ghost game:* no attendance figure in transfermarkt between 8 March 2020 and 30 June 2022.
    Only Germany played without spectators again in 2021/22 (December 2021 to February 2022); in
    the other four leagues a missing figure in 2021/22 is a gap in the data and the match is
    dropped.
  - *Full stadium:* played before 8 March 2020 or from 1 July 2022 on, with an attendance figure.
  - *Restricted crowd:* attendance figure between 8 March 2020 and 30 June 2022 (capacity limits).
- **Effect:** mean y in the comparison group minus mean y in the ghost games, in points per match.
  Positive = home advantage is smaller without fans (the claimed direction).
- **Primary test and how p and the 95% confidence interval are computed:** cluster bootstrap.
  Cluster = league × season × matchday × group. Clusters are resampled with replacement within
  each group, B = 10,000. 95% CI = 250th and 9,751st sorted replicate; p = 2 · min(share of
  replicates ≤ 0, share ≥ 0). Same procedure as #004 and #005, so p < 0.05 exactly when the
  interval excludes zero. One fixed seed per calculation path (`set.seed(6000 + i)`).
- **α:** 0.05, **two-sided**. Verdict "yes" needs p < 0.05 and a positive effect.
- **Main calculation:** leagues = `bundesliga`, ghost = `all`, comparison = `full`.
- **Smallest relevant effect:** 0.10 points per match. That is the same as one match in thirty
  ending in a draw instead of a home win. A smaller change would not show in any table.
- **Fixed before the analysis:** everything in this section. **Fixed after:** nothing so far.

| Fork as an everyday question (EN / DE) | Options with one-line reason | Main | Why it could flip the result |
| --- | --- | --- | --- |
| Which leagues? / Welche Ligen? | `bundesliga`: the league this site has data on since #004 and the one German readers know · `top5`: Bundesliga, Premier League, LaLiga, Serie A, Ligue 1 together, five times the matches | `bundesliga` | More matches make a small effect significant; leagues differ in crowd size and culture |
| Which ghost games count? / Welche Geisterspiele zählen? | `all`: every match without spectators · `restart`: only the restart in spring and summer 2020 (season 2019/20), when empty stadiums were new · `season2021`: only season 2020/21, a full season without fans | `all` | The literature finds the drop mainly in the restart weeks and almost none in 2020/21 |
| What do we compare with? / Womit vergleichen wir? | `full`: all matches in full stadiums 2012/13–2025/26 · `before`: only full stadiums before the pandemic (2012/13 to March 2020) · `any_crowd`: full stadiums plus matches with restricted crowds | `full` | Home advantage drifts over the years; restricted crowds are neither full nor empty |

2 × 3 × 3 = 18 paths. All forks, options, the group definitions, the effect formula, the
bootstrap and the smallest relevant effect are fixed now, before the analysis.

## 2. Datenbeschaffung (data acquisition)

| Source | URL | Format | License / Terms | Accessed |
| --- | --- | --- | --- | --- |
| transfermarkt-datasets, table `games`, data from Transfermarkt.de | https://github.com/dcaribou/transfermarkt-datasets, file https://pub-e682421888d945d684bcae8890b0ec20.r2.dev/data/games.csv.gz (Last-Modified 2026-09-05, SHA-256 1425619890…5f464c741) | CSV (gzip) | CC0 1.0 | 2026-10-16 |
| openfootball/deutschland (cross-check of Bundesliga results) | https://github.com/openfootball/deutschland | text | CC0 1.0 | already in `notebooks/raw/bundesliga/matches.csv` |

- **Acquisition plan:** `notebooks/home_advantage_pipeline.R` keeps the league matches of L1,
  GB1, ES1, IT1 and FR1, seasons 2012/13–2025/26, writes
  `notebooks/raw/home_advantage/games_top5.csv` (committed) and the story JSON. Bundesliga
  results are checked against openfootball for every match date.
- **Coverage:** 25,241 league matches; Bundesliga 306 per season (4,284). Ligue 1 2019/20 was
  stopped after 279 matches; Ligue 1 has 18 clubs from 2023/24.
- **Attendance:** outside the pandemic window the Bundesliga has no missing figure; the other
  leagues have 23 in total (dropped). Inside the window ghost games carry no figure.
- **Known biases / caveats:** the empty stadiums came with other changes (five substitutes,
  dense fixture lists, no travelling away fans either, testing and quarantine). The ghost games
  are not a clean experiment for the crowd alone; the story says so.

## 3. Geplante Visualisierung (planned figures)

- **Fig. 1 (first results):** home advantage per season, Bundesliga 2012/13–2025/26, open circles;
  the seasons with ghost games marked, the ghost games themselves as red points.
- **Fig. 2 (analysis):** home advantage with full stadiums, restricted crowds and without fans,
  with 95% intervals, Bundesliga and the five leagues side by side.
- Robustness: specification curve of all 18 paths and the table.

## 4. Quellenangaben (sources & attribution)

- transfermarkt-datasets (CC0 1.0), data from Transfermarkt.de; openfootball (CC0 1.0).
- Studies: see Dispute.

## Dispute (checked 2026-10-16)

| Side | Source (exact citation) | DOI / URL | Finding in one sentence |
| --- | --- | --- | --- |
| Yes | McCarrick, D., Bilalic, M., Neave, N., Wolfson, S. (2021). Home advantage during the COVID-19 pandemic: Analyses of European football leagues. *Psychology of Sport and Exercise* 56: 102013 | https://doi.org/10.1016/j.psychsport.2021.102013 | 4,844 matches in 15 leagues from 11 countries, before and during the pandemic (2019/20): home advantage in goals and points fell without crowds, mainly because home teams did worse. |
| No | Schank, T., Voigt, V., Orthey, C. (2024). During and after COVID-19: What happened to the home advantage in Germany's first football division? arXiv:2411.12509 (preprint) | https://arxiv.org/abs/2411.12509 | Bundesliga: large drop in the nine ghost matchdays of 2019/20, but in 2020/21, a season mostly without spectators, home advantage was very close to 2018/19. |
| Context | Fischer, K., Haucap, J. (2021). Does Crowd Support Drive the Home Advantage in Professional Football? Evidence from German Ghost Games during the COVID-19 Pandemic. *Journal of Sports Economics* 22(8): 982–1008 | https://doi.org/10.1177/15270025211026552 | Ghost games 2019/20: reduced home advantage in the Bundesliga, no change in the 2. and 3. Liga. |

## 5. Outcome (2026-10-16, written after the analysis)

- Nothing in §1b was changed after the pitch commit (ad72ca1, 05:10 UTC). The pipeline implements
  the groups, forks, effect, bootstrap and seeds exactly as written there.
- Description corrected, rule unchanged: the Bundesliga ghost games of 2021/22 fell between
  28 November 2021 and 22 January 2022 (18 matches), not December to February.
- Bundesliga: 3,587 full, 325 restricted, 372 ghost games. Home advantage 0.427 points per match
  in full stadiums, 0.161 without spectators.
- Main: +0.265 points per match [−0.047, +0.573], p = 0.097, n = 372. Not significant, upper
  bound above the smallest relevant effect of 0.10: **No.** (not detectable).
- First results (2019/20 within the season): 95 of 221 home wins before the break, 27 of 83 after
  the restart; home advantage +0.23 → −0.36.
- Yes on 12 of 18 paths: all 9 with the five leagues together (main five-league path +0.314
  [+0.206, +0.421]) and the 3 Bundesliga paths with only the 2020 restart (+0.788 [+0.194,
  +1.350]). Bundesliga 2020/21 only: +0.128 [−0.221, +0.479], as in Schank et al. (2024).
- Hypothesis confirmed. Side observation: Bundesliga 2024/25 with full stadiums had a home
  advantage of +0.07, lower than the ghost season 2020/21 (+0.30).
