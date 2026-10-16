# Story Pitch — Does the gingerbread season start earlier every year?

> Standards: `content/story-standards.md`; rules: `content/no-slop.md`.

---

## Meta

| Field | Value |
| --- | --- |
| Story number | #004 |
| Working title | Does the gingerbread season start earlier every year? / Beginnt die Lebkuchensaison jedes Jahr früher? |
| Slug | `/2026/10/gingerbread-earlier-every-year` |
| Display date | Thursday 1 October 2026 (series of weekly Thursdays from 10 September, set by John) |
| Status | pitch fixed 2026-10-16 (commit 84a530b, 14:45 UTC), before any search data was downloaded; built the same day (see Outcome) |

## 1. Fragestellung (the question)

**Does the gingerbread season in Germany start a little earlier every year?**

- Popular claim: "Jedes Jahr stehen die Lebkuchen früher im Regal." Every late August the same
  newspaper piece appears, and every year the trade association answers that nothing has moved.
- What we measure: when the season starts in what people search for. Google Trends gives daily
  search interest in Germany for "Lebkuchen". Shelves are not in any open data set; searches are
  the trace the season leaves when people see the first packs, talk about them and buy them. The
  story says plainly that this measures the season in people's heads and browsers, not the date a
  pallet arrives at a store.
- Hypothesis, written before the analysis: no clear trend. The trade says the start date has not
  moved for 25 years, and I expect the searches to agree within a few days per decade. If anything
  moves, I expect the end of the period (smartphones, more people searching for everything) to look
  slightly earlier at the 10% threshold.

## 1b. Der Streit, die Gabelungen, die Präregistrierung

Fixed on 2026-10-16, before downloading any search data for the three terms. The download was
tested only with an unrelated term ("Regenschirm"), which Google rate-limited.

- **Claim as yes/no question:** EN "Does the gingerbread season start earlier every year?" /
  DE „Beginnt die Lebkuchensaison jedes Jahr früher?" (title to be confirmed by John; the
  calculation does not depend on it)
- **Says yes:** the popular feeling, written down for example by Dominic Schmidt in the Nordkurier,
  14 September 2024: „Gefühlt beginnt der Einzug der Weihnachtsleckereien in die Regale jedes Jahr
  früher." The trade association itself calls it the common belief: „Im Gegensatz zur landläufigen
  Behauptung …" (Christian Böttcher, BVLH, in web.de, updated 12 October 2021). No data source
  for the yes side was found.
  https://www.nordkurier.de/regional/mecklenburg-vorpommern/wieso-ist-jetzt-schon-wieder-weihnachten-2879827
- **Says no:** Philipp Hennerkes, managing director of the Bundesverband des Deutschen
  Lebensmittelhandels, told BR24 that the start of sales has not changed in 25 years (Sonntagsblatt,
  24 November 2024). Christian Böttcher, BVLH: „Im Gegensatz zur landläufigen Behauptung findet
  diese Saisoneröffnung nicht jedes Jahr früher statt" (web.de, updated 12 October 2021). Markus
  Geiger, Kaufland: „Nein, das stimmt nicht" (inFranken.de, 7 October 2024).
  https://www.sonntagsblatt.de/artikel/kultur/lebkuchen-gibt-es-seit-august-im-supermarkt-wann-weihnachtsgebaeck-wirklich-gekauft
  https://web.de/magazine/ratgeber/finanzen-verbraucher/lebkuchen-stollen-jahr-frueher-kaufen-36241950
  https://www.infranken.de/ratgeber/verbraucher/weihnachtsleckereien-supermarktregale-lebkuchen-spekulatius-vorweihnachtszeit-spaetsommer-nachfrage-kunden-haendler-tmr-1-art-5928165
- **Data:** Google Trends, Germany, web search, one request per season covering 1 June to
  31 December (daily values), the three terms "Lebkuchen", "Spekulatius", "Dominosteine" in the
  same request so their values share one scale. Seasons 2004 to 2025 (2026 is not over).
- **Season start (onset):** the 7-day mean of search interest, ending on each day. The season's
  peak is the largest 7-day mean between 1 June and 31 December. The onset is the first day from
  which the 7-day mean stays at or above a threshold share of the peak until the peak. Measured in
  days after 1 June (the same calendar date every year, leap years included).
- **Effect:** days earlier per year = minus the slope of an ordinary least-squares line of onset
  on year. Positive means earlier every year (the claim).
- **Primary test and how p and the 95% interval are computed:** the t-test of the OLS slope with
  n − 2 degrees of freedom; the 95% confidence interval is the slope ± t(0.975, n − 2) × its
  standard error. Both come from the same t distribution, so p < 0.05 exactly when the interval
  excludes zero.
- **α:** 0.05, **two-sided**. "Yes" needs p < 0.05 and a positive effect (earlier).
- **Main calculation:** Lebkuchen, threshold 20%, all seasons 2004–2025.
- **Smallest relevant effect:** 0.5 days per year, about a week over 15 years. Less than that
  nobody would notice in a store.
- **Fixed before the analysis:** everything above and the forks below. **Fixed after:** nothing
  so far; anything changed later is listed in §5 with the reason.

| Fork as an everyday question (EN / DE) | Options with one-line reason (EN / DE) | Main | Why it could flip the result |
| --- | --- | --- | --- |
| Which treat? / Welches Gebäck? | `lebkuchen` Lebkuchen: the word in the saying / das Wort aus dem Spruch; `spekulatius` Spekulatius: the other early arrival / der andere frühe Gast; `all` all three summed, with Dominosteine / alle drei zusammen, mit Dominosteinen | `lebkuchen` | Spekulatius is also an autumn biscuit in the Rhineland and the Netherlands, so its season may move differently |
| When has the season started? / Ab wann hat die Saison begonnen? | `10` 10% of the peak: the first stirrings / die ersten Regungen; `20` 20%: clearly under way / deutlich angelaufen; `30` 30%: in full swing / in vollem Gang | `20` | A low threshold reacts to early news pieces and stray searches, a high one to the run-up to Advent |
| Which years? / Welche Jahre? | `all` 2004–2025: everything Google has / alles, was Google hat; `from2011` from 2011, after Google changed its data collection on 1 January 2011 / ab 2011, nach Googles Umstellung; `from2016` from 2016, after the next change on 1 January 2016 / ab 2016, nach der nächsten Umstellung | `all` | Early years have few searches and noisy daily values; Google's changes can shift the level of a series |

3 × 3 × 3 = 27 calculation paths.

## 2. Datenbeschaffung (data acquisition)

| Source | URL | Format | License / Terms | Accessed |
| --- | --- | --- | --- | --- |
| Google Trends, web search, Germany | https://trends.google.com/trends/explore?geo=DE&q=Lebkuchen,Spekulatius,Dominosteine | JSON (explore and multiline widget data), saved as CSV | Google Trends data may be used with citation "Source: Google Trends" | to be filled in on download |

- **Acquisition plan:** `notebooks/gingerbread_download.py` fetches one request per season
  (1 June to 31 December, Germany, three terms) and writes `notebooks/raw/gingerbread/trends_daily.csv`
  (season, date, term, value) unedited. Google samples its data; a repeated download can differ by a
  few points. The file saved on the download date is the data of record.
- **Unit of analysis:** season (year), 22 seasons.
- **Known biases / caveats:** searches are not shelves; Google's data collection changed on
  1 January 2011, 2016 and 2022; low volumes in early years round to 0 on many days.

## 3. Geplante Visualisierung (planned figures)

1. Daily search interest for "Lebkuchen" for a few seasons on one calendar axis (first results).
2. Onset date per season with the fitted line (analysis), the main figure.
3. Specification curve of all 27 paths (robustness, `SpecPaths`).

## 4. Quellenangaben (sources & attribution)

- Google Trends (https://trends.google.com), "Source: Google Trends".
- The press quotes listed in §1b.

## 5. Outcome

Added on 2026-10-16 after the analysis. Everything above §5 is unchanged except the status line.

- **Download:** 16 October 2026, 14:47 to 15:01 UTC, all 22 seasons, 214 daily values per term,
  no value marked partial. Google answered 429 several times; the script waited and retried.
- **Main calculation:** +0.835 days earlier per year, 95% CI [+0.295, +1.374], p = 0.0042,
  n = 22. **Verdict: yes.** My hypothesis (no clear trend) was wrong. The lower end of the interval
  is below the smallest relevant effect (0.5), so relevance is not established.
- **Paths:** 6 of 27 say yes: all three Lebkuchen paths at 20%, Lebkuchen at 10% with all years,
  Spekulatius and all three treats at 10% with all years. Two Spekulatius paths (from 2011, 20%
  and 30%) are significant in the opposite direction.
- **Added after the result, not preregistered:** the main calculation without 2004 (176 of 214
  days at 0): +0.525 [+0.095, +0.955], p = 0.019; the number of zero days and the day of the peak
  per season, for the text. The main calculation was not changed.
- **Title:** the working title stays unless John changes it.
