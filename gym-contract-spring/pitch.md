# Story Pitch — Do more people want out of their gym contract in spring?

> Renumbered on 18 November 2026: planned as #010, published as #009 with the display date 5 November 2026 (John); #009 "Bier auf Wein" waits for its data. The text below is unchanged.

> Standards: `content/story-standards.md`; rules: `content/no-slop.md`.

---

## Meta

| Field | Value |
| --- | --- |
| Story number | #010 (number as planned in the backlog; John may renumber if #009 waits for its data) |
| Working title | Do more people want out of their gym contract in spring? / Suchen im Frühjahr mehr Menschen, wie sie ihr Fitnessstudio kündigen? |
| Slug | `/2026/MM/gym-contract-spring` (URL month follows the display date John sets) |
| Target publish week | January or February 2027 (backlog), display date set by John |
| Status | pitch fixed 2026-11-18, before the analysis; data: two Google Trends exports by John (§2) |

## 1. Fragestellung (the question)

**After the New Year rush, do more people look for a way out of their gym contract in spring than
in the rest of the year?**

- Popular claim: in January the gyms are full of New Year's resolutions, by spring the resolutions
  are gone and people want out of their contracts. The backlog phrased it as „Wollen die meisten im
  Frühjahr ihren Fitnessvertrag wieder loswerden?“. Google Trends cannot count people, only when
  they search, so the testable form is: are searches for cancelling a gym contract higher in
  spring than in the other months of the same year?
- What we measure: Google Trends, web search, Germany, monthly search interest for cancelling a
  gym contract. Effect: how many per cent higher the spring months are than the other months of
  the same year.
- Hypothesis, written before the analysis: a spring rise exists but is small, and January itself
  may already be high (the Trends index of "Fitnessstudio" peaks every January, see §1b). I expect
  the window fork to matter and the Corona years to distort the series.

## 1b. Der Streit, die Gabelungen, die Präregistrierung

Fixed on 2026-11-18, before the two exports in §2 exist. Seen before: John's joint export of
"Fitnessstudio kündigen" with "Fitnessstudio" (Germany, 2004 to November 2026,
`content/incoming/fitness/multiTimeline_fitnessstudio_vs_kuendigen_2026-11-18.csv`). In that
export "Fitnessstudio" peaks every January; "Fitnessstudio kündigen" is scaled to the larger term
and only takes the values 0, <1, 1 and 2, which says nothing about its seasons. That file is not
used in the analysis.

- **Claim as yes/no question:** EN "Do more people want out of their gym contract in spring?" /
  DE „Suchen im Frühjahr mehr Menschen, wie sie ihr Fitnessstudio kündigen?"
- **Says yes:** Strava's "Quitter's Day": for 2020 Strava named 19 January as the day most people
  give up their New Year's fitness resolutions (see Dispute). If the resolutions die in January,
  the wish to cancel should follow in the next weeks.
- **Says no:** DellaVigna & Malmendier (2006), American Economic Review: members do not cancel
  when they stop going; on average 2.31 full months pass between the last visit and the
  termination. Inertia, contract terms and notice periods spread cancellations over the year.
- **Unit:** one month. **Outcome:** log of the monthly Google Trends index (0 to 100 within each
  export) of the search term.
- **Years:** from the first calendar year in which every month of the term has an index of at
  least 1 ("<1" counts as below 1), to 2025, plus January to October 2026; November 2026 is
  incomplete and left out.
- **Effect:** coefficient b of a spring dummy (1 in the spring months, 0 otherwise) in a regression
  of the log index on the spring dummy and one dummy per calendar year (the year dummies take out
  the long-run trend and Google's rescaling). Reported as 100 · (exp(b) − 1), per cent more search
  interest in spring than in the other months of the same year. Positive = the claimed direction.
- **Primary test and how p and the 95% confidence interval are computed:** generalized least
  squares with AR(1) errors between consecutive months (`nlme::gls`, `corAR1(form = ~ t)`, REML),
  t-test of b. 95% confidence interval b ± t(0.975, df) · se, transformed with 100 · (exp(·) − 1);
  so p < 0.05 exactly when the interval excludes zero. No random numbers.
- **α:** 0.05, **two-sided**. Verdict "yes" needs p < 0.05 and a positive effect.
- **Main calculation:** window = `feb_apr`, term = `fitnessstudio`, years = `all`.
- **Smallest relevant effect:** 10 per cent. A rise of a tenth over the rest of the year is the
  least I would call a spring wave; anything smaller disappears in Google's sampling noise.
- **Fixed before the analysis:** everything in this section. **Fixed after:** nothing so far.

| Fork as an everyday question (EN / DE) | Options with one-line reason | Main | Why it could flip the result |
| --- | --- | --- | --- |
| What counts as spring? / Was zählt als Frühjahr? | `feb_apr`: February to April, after the January rush and with the lag of a few weeks until people act · `jan_mar`: January to March, right after the resolutions · `mar_may`: March to May, the calendar spring | `feb_apr` | January may be high for its own reasons (new contracts, questions about terms); the calendar spring is later |
| Which search? / Welche Suchanfrage? | `fitnessstudio`: "Fitnessstudio kündigen", the common wording · `vertrag`: "Fitnessvertrag kündigen", the contract itself | `fitnessstudio` | The two searches may come from different people (members vs. people reading about their rights) |
| Which years? / Welche Jahre? | `all`: every year of the series · `without_covid`: without 2020 and 2021, when gyms were closed for months and members asked about their fees · `since_2023`: only 2023 to 2026, after the law of 1 March 2022 that lets members leave with one month's notice once the first term is over | `all` | Closures and the new law change when and why people cancel |

3 × 2 × 3 = 18 paths. All forks, options, the year rule, the effect formula, the test and the
smallest relevant effect are fixed now, before the analysis.

## 2. Datenbeschaffung (data acquisition)

Two exports by John from trends.google.com, each term **on its own** (not compared with another
term, so each series uses the full 0 to 100 scale): Explore → term → Germany, "2004 – present",
all categories, web search → download "Interest over time" (`multiTimeline.csv`).

| Source | Term | Format | License / Terms | Accessed |
| --- | --- | --- | --- | --- |
| Google Trends, Germany, web search, monthly | „Fitnessstudio kündigen" | CSV | Google Trends terms; values are sampled and rescaled by Google | to be filled |
| Google Trends, Germany, web search, monthly | „Fitnessvertrag kündigen" | CSV | as above | to be filled |

- **Storage:** `content/incoming/fitness/` with the date of the download in the file name, then
  `notebooks/raw/fitness/` as written by the pipeline.
- **Known biases / caveats:** Trends measures interest in a search, not cancellations; Google
  samples its data, so a repeated export can differ by a few points; the index is relative within
  each export.

## 3. Geplante Visualisierung (planned figures)

- **Fig. 1 (first results):** the monthly index of "Fitnessstudio kündigen" over the whole period,
  R-base line chart, spring months marked.
- **Fig. 2 (analysis):** average deviation of each calendar month from its year's mean (log
  scale, as per cent), with 95% intervals; spring months in red.
- Robustness: specification curve of all 18 paths and the table.

## 4. Quellenangaben (sources & attribution)

- Google Trends (google.com/trends), exports by John.
- Studies and press: see Dispute.

## Dispute (checked 2026-11-18)

| Side | Source (exact citation) | URL | Finding in one sentence |
| --- | --- | --- | --- |
| Yes | BikeRadar: "Strava has predicted when you'll give up your new year's resolution", 6 January 2020 | https://www.bikeradar.com/news/strava-2020-quitters-day | "Strava has announced its prediction for 2020's Quitter's Day as Sunday 19 January", the day most people give up their resolutions. |
| No | DellaVigna, S., Malmendier, U. (2006). Paying Not to Go to the Gym. *American Economic Review* 96(3): 694–719 | https://doi.org/10.1257/aer.96.3.694 | 7,752 members of three US health clubs: "On average, 2.31 full months elapse between the last attendance and contract termination for monthly members". |

## 5. Outcome (2026-11-18, written after the analysis)

- The two exports arrived after the pitch commit (798e6bd, 07:37 UTC). A third export,
  "Kündigung Fitnessstudio", came in between; it is not a pitched term, is stored and not used.
- **Rule added after the pitch:** months with an index of 0 after a series' start count as
  missing (Google shows 0 when too few people searched). The pitch did not cover zeros after the
  start year. It affects only "Fitnessvertrag kündigen": series from 2020, 57 months, 25 zeros
  left out. `corAR1(form = ~ t)` treats a left-out month as a gap (checked against `corCAR1`:
  identical estimates), so the test itself is as pitched.
- One display text changed, no method: `unit` in `claim.json` read "per cent more searches", which
  reads oddly with a negative effect; it now reads "per cent, spring against the rest of the year".
- "Fitnessstudio kündigen": from January 2011 (first year with a value in every month) to October
  2026, 190 months, no zero.
- Main: −6.9 per cent [−12.9, −0.5], p = 0.037, n = 190: **No** (significantly the opposite).
  A spring rise of 10 per cent is ruled out.
- January lies 16.9 per cent above its year's mean and was the top month in 8 of 15 complete
  years. Raw means 2011–2025: spring 29.9, other months 30.5.
- Yes on 5 of 18 paths: the three "Fitnessstudio kündigen" paths with January to March
  (all years +9.1 [+1.9, +16.7], p = 0.012), February to April since 2023 (+14.5 [+3.6, +26.5],
  p = 0.009) and "Fitnessvertrag kündigen" January to March without 2020/21.
- Hypothesis partly wrong: there is no spring rise in the main calculation, spring is lower;
  January is high, as expected.
