# Story Pitch — Are Abitur grades getting better every year?

> Standards: `content/story-standards.md`; rules: `content/no-slop.md`.

---

## Meta

| Field | Value |
| --- | --- |
| Story number | #005 |
| Working title | Are Abitur grades getting better every year? / Werden die Abiturnoten immer besser? |
| Slug | `/2026/10/abitur-grades-better-every-year` |
| Display date | Thursday 8 October 2026 (weekly series set by John) |
| Status | pitch fixed 2026-10-16 (commit 24dcd1a, 15:44 UTC), after downloading the KMK files and reading their sheet names, row labels and footnotes, before reading any grade; built the same day (see Outcome) |

## 1. Fragestellung (the question)

**Is the average Abitur grade in Germany getting better year after year?**

- Popular claim: grade inflation. Every summer a teachers' association complains about a "flood"
  of 1.0 averages, and every summer a ministry calls the results proof of good schools.
- What we measure: the mean Abitur grade per Land and year as reported to the Kultusministerkonferenz
  (KMK), 1.0 best, 4.0 worst pass. Grades getting better means the mean falls.
- Hypothesis, written before the analysis: yes, a small improvement of about 0.01 to 0.02 grade
  points per year, with a visible bump in the Corona years 2020 and 2021. I expect the fork without
  the Corona years to be closest to the edge.

## 1b. Der Streit, die Gabelungen, die Präregistrierung

Fixed on 2026-10-16 after downloading the KMK files for 2014 to 2025 and reading only sheet names,
row labels and footnotes; no grade, mean or share was read.

- **Claim as yes/no question:** EN "Are Abitur grades getting better every year?" /
  DE „Werden die Abiturnoten immer besser?"
- **Says yes:** Stefan Düll, president of the Deutscher Lehrerverband, to the Rheinische Post in
  July 2025: „Im Vergleich zu früheren Jahren gibt es eine Flut an Einser-Abis", quoted in the taz,
  28 July 2025. Earlier the same in Niedersachsen: Christoph Rabbow (Philologenverband
  Niedersachsen), „Der Wert der Allgemeinen Hochschulreife befindet sich im Sinkflug", news4teachers,
  8 May 2024.
  https://taz.de/!6099298/
  https://www.news4teachers.de/2024/05/philologen-beklagen-einser-inflation-wert-des-abiturs-befindet-sich-im-sinkflug/
- **Says no:** the taz, looking at the latest KMK statistics in the same article: they show „keine
  eindeutige Tendenz hin zu mehr Abiturabschlüssen zwischen 1,0 und 1,9"; the rise of good grades is
  not as clear as claimed (taz, 28 July 2025).
- **Data:** KMK, „Abiturnoten im Ländervergleich", one file per year 2014 to 2025 (2025 is the
  „Schnellmeldung"), sheet „Noten": per Land the number of exams, passed, failed, the mean grade
  („Notenmittel") and the count per grade 1.0 to 4.0. Older years are not on the KMK site.
- **Excluded by rule before the analysis:** Land-years that the KMK marks as the previous year's
  values (Rheinland-Pfalz 2021 „Vorjahresdaten", Baden-Württemberg 2025 „Vorjahreswerte
  (2023/24)"). They are copies, not new observations.
- **Effect:** grade points better per year = minus the slope of the mean grade on year, from a
  least-squares fit with one intercept per Land (Land fixed effects), so differences in level
  between Länder (and in what they count, e.g. Bayern includes vocational schools) drop out.
  Positive means better every year (the claim).
- **Primary test and how p and the 95% interval are computed:** cluster bootstrap over Länder:
  draw 16 Länder with replacement (a Land drawn twice counts as two Länder), refit, B = 10,000.
  The 95% interval is the 250th to the 9,751st sorted replicate; p = 2 · min(share ≤ 0,
  share ≥ 0), so p < 0.05 exactly when the interval excludes zero. Seed 5000 + path number.
- **α:** 0.05, **two-sided**. "Yes" needs p < 0.05 and a positive effect.
- **Main calculation:** all years 2014–2025, each Land weighted equally, all Land-years except the
  two copies.
- **Smallest relevant effect:** 0.01 grade points per year, a tenth of a grade step per decade.
  Less than that would take a generation to notice.
- **Fixed before the analysis:** everything above and the forks below. **Fixed after:** nothing
  so far; changes go into §5 with the reason.

| Fork as an everyday question (EN / DE) | Options with one-line reason (EN / DE) | Main | Why it could flip the result |
| --- | --- | --- | --- |
| Which years? / Welche Jahre? | `all` 2014–2025 / 2014 bis 2025; `nocorona` without the Corona exams of 2020 and 2021 / ohne die Corona-Prüfungen 2020 und 2021; `precorona` 2014–2019 only / nur 2014 bis 2019 | `all` | Exams under Corona rules were graded differently in several Länder; before Corona the trend may be flatter |
| How much does each Land count? / Wie viel zählt jedes Land? | `equal` every Land the same / jedes Land gleich; `exams` by number of exams / nach Zahl der Prüfungen | `equal` | Weighting by exams lets Nordrhein-Westfalen and Bayern dominate |
| Which cohorts? / Welche Jahrgänge? | `all` every Land-year / alle Länder-Jahre; `regular` without unusual cohorts: Land-years with fewer than 70% or more than 130% of the Land's median number of exams (switches between G8 and G9) / ohne ungewöhnliche Jahrgänge (Wechsel zwischen G8 und G9) | `all` | A half-empty year after a switch back to G9 (Niedersachsen 2020, Bayern 2025) consists of unusual pupils |

3 × 2 × 2 = 12 calculation paths.

## 2. Datenbeschaffung (data acquisition)

| Source | URL | Format | License / Terms | Accessed |
| --- | --- | --- | --- | --- |
| KMK, Abiturnoten im Ländervergleich 2014–2025 | https://www.kmk.org/downloads-dokumente/statistik/schulstatistik/abiturnoten.html (2014–2016 under /fileadmin/Dateien/pdf/Statistik/, 2017–2025 under …/Statistik/Dokumentationen/) | XLS/XLSX and PDF | Official statistics, source to be cited („Quelle: KMK“) | 2026-10-16 |

- **Acquisition plan:** `notebooks/abitur_extract.py` reads sheet „Noten" of every file and
  writes `notebooks/raw/abitur/kmk_abitur.csv` (year, land, exams, passed, failed, mean, count per
  grade) unedited; `notebooks/abitur_pipeline.R` does the analysis.
- **Unit of analysis:** Land-year, 16 × 12 = 192, minus 2 copies.
- **Known biases / caveats:** Länder count differently (vocational schools, private schools,
  external candidates), constant within a Land as far as the footnotes say; 2025 is preliminary
  for some Länder; G8/G9 switches change who sits the exam.

## 3. Geplante Visualisierung (planned figures)

1. Mean grade per Land and year (thin lines) with the Germany figure (first results).
2. Share of averages from 1.0 to 1.9 per year (analysis, descriptive).
3. Specification curve of all 12 paths (robustness, `SpecPaths`).

## 4. Quellenangaben (sources & attribution)

- Sekretariat der Kultusministerkonferenz, Abiturnoten im Ländervergleich, 2014 to 2025.
- The press quotes in §1b.

## 5. Outcome

Added on 2026-10-16 after the analysis. Everything above §5 is unchanged except the status line.

- **Data:** 192 state-years read by `abitur_extract.py`; the rule found exactly the two copies named
  in §1b. Unusual cohorts by the 70/130% rule: Sachsen 2014, Schleswig-Holstein 2016,
  Niedersachsen 2020, Bayern 2025.
- **Main calculation:** +0.0122 grade points better per year, 95% CI [+0.0098, +0.0145],
  p < 0.001, n = 190. **Verdict: yes**, as expected. The lower end of the interval is just below
  the smallest relevant effect (0.01).
- **Paths:** 12 of 12 say yes. Before Corona only (2014–2019): +0.007, about half as steep.
- **Not in the hypothesis, seen in the data:** the national average was best in 2021 (2.28) and
  got worse every year after that, to 2.35 in 2025; all 15 states with figures for 2021 had a
  worse average in 2024 than in 2021. The failure rate rose from 3.3% (2014) to 4.7% (2025).
- **Changed after the result:** nothing in the calculation.
