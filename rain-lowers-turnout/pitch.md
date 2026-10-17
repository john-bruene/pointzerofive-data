# Story Pitch — Does rain lower turnout?

> Standards: `content/story-standards.md`; rules: `content/no-slop.md`.

---

## Meta

| Field         | Value                                                                                                   |
| ------------- | ------------------------------------------------------------------------------------------------------- |
| Story number  | #007                                                                                                    |
| Working title | Does rain lower turnout? / Senkt Regen die Wahlbeteiligung?                                             |
| Slug          | `/2026/10/rain-lowers-turnout`                                                                          |
| Display date  | Thursday 22 October 2026 (weekly series set by John)                                                    |
| Status        | pitch fixed 2026-10-16, before any turnout or rain value was read for the analysis (see "Known before") |

## 1. Fragestellung (the question)

**Do fewer people vote in a German Bundestag election where it rains on election day?**

- Popular claim: bad weather keeps voters at home, and which parties profit from it is a fixture of
  election-weekend weather columns.
- What we measure: for every Wahlkreis, the change in turnout from one Bundestag election to the
  next and the change in rain on the two election days. Rain varies between Wahlkreise on the same
  day; the comparison is made within each Land and election.
- Hypothesis, written before the analysis: no. Most German federal elections fall in September,
  rain on those days is usually light, turnout is high and since 2021 close to half of the voters
  vote by post. I expect an effect close to zero that is not significant.

## 1b. Der Streit, die Gabelungen, die Präregistrierung

Fixed on 2026-10-16. **Known before:** the list of files the Bundeswahlleiterin publishes for each
election (Wahlkreis results 1949–2025 in `btw_kerg.zip`, Kreis results and postal/polling-station
splits 2013–2025, Wahlkreis geometries 2005–2025) and the description of the DWD grid HYRAS-DE-PR
(1 km, daily sums from 06 UTC to 06 UTC of the following day, CC BY 4.0). While I listed the
column names of `btw2025kreis.csv`, my command also printed its first nine data rows (Kreise in
Schleswig-Holstein, 2025 only). No rain value and no Wahlkreis result was read.

- **Claim as yes/no question:** EN "Does rain lower turnout?" / DE „Senkt Regen die
  Wahlbeteiligung?"
- **Dispute (verified 2026-10-16):**
  - Yes: Gomez, Hansford and Krause (2007), "The Republicans Should Pray for Rain: Weather,
    Turnout, and Voting in U.S. Presidential Elections", _Journal of Politics_ 69(3): 649–663.
    Fourteen US presidential elections, county level: rain lowers turnout by just under 1
    percentage point per inch (25.4 mm).
  - No: Persson, Sundell and Öhrvall (2014), "Does Election Day weather affect voter turnout?
    Evidence from Swedish elections", _Electoral Studies_, doi 10.1016/j.electstud.2013.07.021:
    "In none of the three datasets do we find robust negative effects of rain."
  - Method: Cooperman (2017), "Randomization Inference with Rainfall Data", _Political Analysis_
    25(3): 277–288: with historical rainfall as placebo assignments the US effect is far less
    certain than conventional standard errors suggest. Rain falls in large fields, so neighbouring
    areas are not independent observations. The test below follows this approach.
- **Data:**
  - Turnout: Bundeswahlleiterin, Wahlkreis results (`btw2005_kerg.csv` … `btw2025_kerg.csv` from
    `btw_kerg.zip`). Each file gives the current and the previous election ("Vorperiode")
    computed on the current Wahlkreis boundaries. Turnout = voters (Wählende) / eligible voters
    (Wahlberechtigte) × 100, both from these files.
  - Rain: DWD HYRAS-DE-PR v6-1, daily grids, years 1995–2025.
  - Geometry: Bundeswahlleiterin Wahlkreis shapefiles for 2005, 2009, 2013, 2017, 2021, 2025.
- **Elections and dates:** 22 Sep 2002, 18 Sep 2005, 27 Sep 2009, 22 Sep 2013, 24 Sep 2017,
  26 Sep 2021, 23 Feb 2025. Six differences (2005−2002 … 2025−2021), 299 Wahlkreise each.
  Left out: Dresden I in 2005 (election postponed to 2 October 2005); the Berlin Wahlkreise in
  the 2025 difference (their 2021 result includes the partial repeat of 11 February 2024).
- **Rain in a Wahlkreis:** mean of all HYRAS cells whose centre lies inside the Wahlkreis
  (geometry of the later election of each pair, used for both days), in mm. The HYRAS value
  dated D is taken as the sum from 06 UTC on D to 06 UTC on D+1, which contains the polling hours
  (8 to 18 local time). Before any value is read, this is checked against the time metadata of
  the file; if the date marks the end of the 24 hours, D+1 is used.
- **Model:** Δturnout (percentage points) = constant per Land and election + β · Δrain / 10 mm.
  Effect β = percentage points of turnout per 10 mm more rain. Negative means rain lowers turnout
  (the claim).
- **Primary test and how p and the 95% interval are computed:** randomization inference with
  historical rain (Cooperman 2017). Under the null hypothesis, the rain field of an election day
  could as well have been the field of the same calendar date in any other year. One replicate
  draws, for every election date separately, a year from 1995–2025 other than the election year,
  and recomputes the coefficient with these placebo rain fields (R = 10,000 replicates, seed 7100
  - path number). Test of β = b: T(b) = β̂ − b against the placebo coefficients of
    Δturnout − b · Δrain; p(b) = share of replicates with |placebo| ≥ |T(b)|. p = p(0); the 95%
    interval is the set of b with p(b) ≥ 0.05 (test inversion).
- **α:** 0.05, **two-sided**. "Yes" needs p < 0.05 and a negative effect.
- **Main calculation:** rain on the day, constants per Land and election, all six differences,
  every Wahlkreis counted once.
- **Smallest relevant effect:** 0.4 percentage points per 10 mm, about the US estimate of Gomez
  et al. (just under 1 point per inch).
- **Fixed before the analysis:** everything above and the forks below.

| Fork as an everyday question (EN / DE)                          | Options with one-line reason (EN / DE)                                                                                                                           | Main   | Why it could flip the result                                                      |
| --------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------ | --------------------------------------------------------------------------------- |
| How is rain measured? / Wie wird Regen gemessen?                | `day` mm on election day / mm am Wahltag; `anomaly` mm minus the Wahlkreis mean of the same date over 1995–2025 / mm minus das Mittel desselben Datums 1995–2025 | `day`  | Some areas are wetter every year; the anomaly measures unusual rain               |
| Compared within what? / Verglichen innerhalb wovon?             | `land` each Land and election / jedes Land und jede Wahl; `election` each election only / jede Wahl                                                              | `land` | State elections on the same day (2009, 2013, 2021) change turnout in whole Länder |
| Which elections? / Welche Wahlen?                               | `all` 2005–2025; `pre2021` 2005–2017, before postal voting rose sharply / vor dem starken Anstieg der Briefwahl                                                  | `all`  | Postal voters cast their vote before election day                                 |
| How are Wahlkreise weighted? / Wie werden Wahlkreise gewichtet? | `none` each Wahlkreis once / jeder Wahlkreis einmal; `voters` by eligible voters / nach Wahlberechtigten                                                         | `none` | Rain in large cities may matter more or less than in rural Wahlkreise             |

2 × 2 × 2 × 2 = 16 calculation paths.

## 2. Datenbeschaffung (data acquisition)

| Source                                                 | URL                                                                                         | Format     | License / Terms                                        | Accessed   |
| ------------------------------------------------------ | ------------------------------------------------------------------------------------------- | ---------- | ------------------------------------------------------ | ---------- |
| Die Bundeswahlleiterin, Wahlkreis results 1949–2025    | https://www.bundeswahlleiterin.de/dam/jcr/ce2d2b6a-f211-4355-8eea-355c98cd4e47/btw_kerg.zip | CSV in ZIP | © Die Bundeswahlleiterin, Wiesbaden; reuse with source | 2026-10-16 |
| Die Bundeswahlleiterin, Wahlkreis geometries 2005–2025 | `wahlkreiseinteilung` download pages of each election                                       | Shapefile  | as above                                               | 2026-10-16 |
| DWD HYRAS-DE-PR v6-1, daily                            | https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/hyras_de/precipitation/ | NetCDF     | CC BY 4.0 Deutscher Wetterdienst                       | 2026-10-16 |

- **Acquisition plan:** `notebooks/rain_download.py` downloads the files;
  `notebooks/rain_extract.py` (Python: netCDF, shapefile, shapely, pyproj) computes the mean rain
  per Wahlkreis for every election date and every placebo year and writes
  `notebooks/raw/rain/turnout.csv` and `notebooks/raw/rain/rain.csv`.
  `notebooks/rain_pipeline.R` does the analysis.
- **Unit of analysis:** Wahlkreis and election (first differences).
- **Known biases / caveats:** daily sums include rain at night; the station network behind HYRAS
  changed over time; boundaries of the previous election are recomputed by the Bundeswahlleiterin.

## 3. Geplante Visualisierung (planned figures)

1. Map or dot plot of rain on one election day by Wahlkreis (first results).
2. Δturnout against Δrain with the fitted line (analysis); the placebo distribution with the
   observed coefficient.
3. Specification curve of all 16 paths (robustness, `SpecPaths`).

## 4. Quellenangaben (sources & attribution)

- Die Bundeswahlleiterin, Wiesbaden.
- Deutscher Wetterdienst, HYRAS-DE-PR v6-1, CC BY 4.0.

## 5. Outcome

Analysis run 2026-10-16 with `rain_pipeline.R`, exactly as fixed above.

- **Before the analysis:** the time metadata of the HYRAS files say "Beginning Of Twentyfour Hour
  Time Interval [UTC]", with 06 UTC as the start; the date D is used as planned. Licence of the
  2025 results file: Datenlizenz Deutschland Namensnennung 2.0 (dl-de/by-2-0).
- **Main calculation:** −0.05 percentage points per 10 mm [−0.33, +0.20], p = 0.62,
  n = 1,781 Wahlkreis results. Verdict **no**; the interval lies within ±0.4, so a relevant effect
  is ruled out.
- **Forks:** "yes" on 0 of 16 paths; none significant. Smallest p: 0.064 (rain as anomaly,
  2005–2017, −0.41). Comparing within elections only gives intervals of about ±1.1.
- **Note:** four of the seven election days were dry almost everywhere (2005, 2009, 2013, 2025);
  the rain variation comes from 2002 (rain nearly everywhere), 2021 and a little from 2017.
- **Text changes after the result:** wording only (claim texts, licence name, the generic fork
  sentence for a bound on the negative side).
