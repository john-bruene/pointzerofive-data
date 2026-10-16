# Story Pitch — Are there more road accidents on Friday the 13th?

> Renumbered on 16 October 2026: this story was #005 and is now #002; the three pre-relaunch stories were removed. The text below is unchanged.

> Standards: `content/story-standards.md`; rules: `content/no-slop.md`.
> Targets: 1,500–2,500 words per language, one core dataset, 2–4 figures.

---

## Meta

| Field | Value |
| --- | --- |
| Story number | #005 |
| Working title | Are there more road accidents on Friday the 13th? |
| Slug | `/2026/10/friday-the-13th` |
| Category | Traffic / Verkehr |
| Target publish week | 2026-W42 (next Friday the 13th: 13 November 2026) |
| Status | published 2026-10-15 (see Outcome) |

## 1. Fragestellung (the question)

**Do more road accidents happen on Friday the 13th than on other days?**

- What we measure: police-reported road collisions with at least one injured person in Great
  Britain, per calendar day, 1979–2025 (STATS19). Every Friday the 13th in that period against
  comparison days in the same month.
- Why it is interesting: the claim goes back to a 1993 paper in the BMJ that is still quoted as
  evidence. It used 65 against 45 hospital admissions from one English health region. The same
  country publishes every reported injury collision since 1979 with its date, so the original
  question can be asked again with roughly 9 million collisions instead of 110 admissions.
- Hypothesis, written before the analysis: no detectable increase. The naive comparison with all
  other days of the month will show a large "increase", because Friday is the busiest day of the
  week on British roads; against other Fridays the difference will be close to zero, possibly
  slightly negative (Scanlon et al. counted fewer cars on the 13th).

## 1b. Der Streit, die Gabelungen, die Präregistrierung

Fixed on 2026-10-15, after downloading the data and counting rows per year, before computing any
comparison between Fridays the 13th and other days.

- **Claim as yes/no question:** EN "Are there more road accidents on Friday the 13th?" /
  DE „Passieren an Freitag, dem 13., mehr Verkehrsunfälle?"
- **Says yes:** Scanlon, Luben, Scanlon & Singleton (1993), BMJ, and Näyhä (2002), Am J Psychiatry
  (see Dispute below).
- **Says no:** Radun & Summala (2004), BMC Public Health (see Dispute below).
- **Unit:** one calendar day in Great Britain. **Outcome:** number of collisions on that day.
- **Effect:** for months i with a Friday the 13th, y_i = collisions on the 13th and c_i = mean
  collisions per comparison day in the same month. Effect = 100 · (Σ y_i / Σ c_i − 1), in per cent
  ("per cent more collisions than on the comparison days").
- **Primary test and how p and the 95% range are computed:** bootstrap over months: resample the
  months with a Friday the 13th with replacement (each month brings its 13th and its comparison
  days), B = 10,000. 95% range = 250th and 9,751st sorted replicate; p = 2 · min(share of
  replicates ≤ 0, share ≥ 0). Same procedure as #004, so p < 0.05 exactly when the range excludes
  zero. One fixed random stream per calculation path.
- **α:** 0.05 · **two-sided**. Verdict "yes" needs p < 0.05 and a positive effect.
- **Main calculation:** comparison = `fridays`, outcome = `all`, holidays = `exclude`.
- **Smallest relevant effect:** 5 per cent. A tenth of the 52 per cent named in the 1993 paper;
  an effect below 5 per cent would not justify a warning to stay off the road.

| Fork as an everyday question (EN / DE) | Options with one-line reason | Main | Why it could flip the result |
| --- | --- | --- | --- |
| What do we compare with? / Womit vergleichen wir? | `all_days`: all other days of the same month (how headlines compare) · `fridays`: the Fridays one week before and one week after, the 6th and the 20th (same weekday, same season; design of Radun & Summala 2004) · `friday_6th`: only the Friday a week before (design of Scanlon et al. 1993) | `fridays` | Fridays have more collisions than the average day, so `all_days` favours yes |
| What do we count? / Was zählen wir? | `all`: every collision with an injured person · `ksi`: collisions with someone killed or seriously injured · `fatal`: collisions with someone killed (Näyhä 2002 counted deaths) | `all` | Fewer, more serious cases are noisier; superstition might matter more for serious crashes |
| What about public holidays? / Was machen wir mit Feiertagen? | `exclude`: bank holidays in England and Wales (Python package `holidays`, `UK(subdiv="ENG")`) are removed from the 13ths and from the comparison days; a month without any comparison day left drops out · `keep`: holidays count as ordinary days | `exclude` | Good Friday fell on the 13th in 1979, 1990 and 2001 and on a comparison Friday in 1984, 2007 and 2012; holiday traffic differs |

3 × 3 × 2 = 18 paths. All forks, options, the effect formula, the bootstrap and the smallest
relevant effect are fixed now, before the analysis.

## 2. Datenbeschaffung (data acquisition)

| Source | URL | Format | License / Terms | Accessed |
| --- | --- | --- | --- | --- |
| Department for Transport, Road Safety Data (STATS19), collisions 1979 – latest published year | https://data.dft.gov.uk/road-accidents-safety-data/dft-road-casualty-statistics-collision-1979-latest-published-year.csv | CSV, 1.5 GB | Open Government Licence v3.0 (attribution required) | 2026-10-15 |

- **Acquisition plan:** `notebooks/friday13_pipeline.py` streams the CSV and keeps date and
  severity; it writes daily counts (`notebooks/raw/stats19/daily_collisions.csv`, about 17,000
  rows) and the story JSON. The notebook starts from the daily counts.
- **Unit of analysis:** calendar day; 81 Fridays the 13th from April 1979 to June 2025.
- **Coverage:** 9,116,625 collisions, 1979–2025, Great Britain (England, Scotland, Wales);
  8 rows without a date.
- **Known biases / caveats:** police-reported collisions only (injury collisions not reported to
  the police are missing; the share changes over time but not between Fridays of one month). No
  daily traffic volumes, so the study measures collisions per day, not risk per kilometre driven.
  Severity coding changed when police forces moved to the CRASH system (from 2012 onwards);
  within-month comparisons are not affected. Scotland has partly different bank holidays.

## 3. Geplante Visualisierung (planned figures)

- **Fig. 1 (step 3, first attempt):** collisions per day by weekday in the 81 months with a Friday
  the 13th, open circles; the Fridays the 13th as a red point. Shows why the comparison with all
  days favours yes.
- **Fig. 2 (step 4, fair test):** each Friday the 13th as one open circle, x = date, y = per cent
  difference from the comparison Fridays; dashed zero line; the pooled effect in red.
- Technical version: specification curve of all 18 paths.

## 4. Quellenangaben (sources & attribution)

- Contains public sector information licensed under the Open Government Licence v3.0.
  Department for Transport, Road Safety Data (STATS19).
- Studies: see Dispute.

## Dispute (verified 2026-10-15 via Europe PMC)

| Side | Source (exact citation) | DOI / URL | Finding in one sentence |
| --- | --- | --- | --- |
| Yes | Scanlon, T. J., Luben, R. N., Scanlon, F. L., Singleton, N. (1993). Is Friday the 13th bad for your health? *BMJ* 307(6919): 1584–1586 | https://doi.org/10.1136/bmj.307.6919.1584 (PMID 8292946) | South West Thames region: hospital admissions after transport accidents were higher on Friday the 13th than on Friday the 6th (total 65 v 45; p < 0.05); "the risk ... may be increased by as much as 52%". Fewer vehicles on the M25 on the 13th. Published in the Christmas issue (18–25 December 1993). |
| Yes | Näyhä, S. (2002). Traffic deaths and superstition on Friday the 13th. *American Journal of Psychiatry* 159(12): 2110–2111 | https://doi.org/10.1176/appi.ajp.159.12.2110 (PMID 12450968) | Finland 1971–1997, traffic deaths on Friday the 13th v other Fridays, negative binomial regression: adjusted risk ratio 1.02 for men, 1.63 for women. |
| No | Radun, I., Summala, H. (2004). Females do not have more injury road accidents on Friday the 13th. *BMC Public Health* 4: 54 | https://doi.org/10.1186/1471-2458-4-54 (PMID 15546493) | Finland 1989–2002, 21 Fridays the 13th against the Fridays before and after, holidays excluded: no significant differences for women or men. |

## 5. Pre-build checklist

- [x] Data file lives in `/data/friday-the-13th.json`
- [x] `npm run check-data -- data/friday-the-13th.json` passes
- [x] Pipeline script committed to `notebooks/` (`friday13_pipeline.py`, `friday13_stats.py`)
- [x] Headline finding verified twice (pipeline + notebook asserts)
- [x] Scaffold generated (`--date 2026-10-15`)
- [x] Both languages complete; `npm run check-copy` passes

## 6. Outcome (2026-10-15, written after the analysis)

- Nothing in §1b was changed after the pitch commit (d260eb5).
- 81 Fridays the 13th, 3 of them Good Friday (1979, 1990, 2001); main calculation n = 78.
- Main: 48,949 collisions on the 13ths against 49,385 on the comparison Fridays (mean of the
  6th and 20th per month, summed). Effect −0.88 % [−3.61, +1.80], p = 0.53. The upper bound
  lies below the smallest relevant effect of 5 %: **No.** (ruled out).
- First attempt (all other days of the month): +19.4 % [+16.7, +22.0], p < 0.001. Fridays in
  general have 18 % more collisions than the average day.
- Yes on 6 of 18 paths, all of them comparing with all other days of the month. No path is
  significant in the other direction. Fatal collisions only: +2.5 % [−6.4, +12.0].
- Hypothesis confirmed. Limitation stated in the story: collisions per day, not risk per
  kilometre; no daily traffic counts.
- Social preview: John makes a photo with `content/design/og-template/`; until then the story
  uses `default.png`. Next Friday the 13th: 13 November 2026.
