# Are Abitur grades getting better every year?

Data and code behind the story
[Are Abitur grades getting better every year?](https://pointzerofive.net/2026/10/abitur-grades-better-every-year)
(#005, 8 October 2026; German:
[Werden die Abiturnoten immer besser?](https://pointzerofive.net/de/2026/10/abitur-grades-better-every-year)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/abitur-grades-better-every-year/story_005_abitur.ipynb)
(choose the R runtime).

File | Contents
---|---
`story_005_abitur.ipynb` | R notebook that reproduces every number in the story, including all 12 calculation paths
`abitur-grades-better-every-year.json` | Published results: main calculation, the 12 calculation paths (`specs`), chart data
`abitur-grades-better-every-year.output.txt` | Console output of the pipeline run, unedited, ending with R and package versions
`kmk_abitur.csv` | Abitur results per state and year 2014 to 2025 as reported by the KMK
`claim.json` | Texts of the claim and of the forks, English and German
`pitch.md` | The pitch: question, dispute, main calculation and forks, fixed before the analysis
`abitur_extract.py` | Reads the KMK Excel files into `kmk_abitur.csv` (Python with pandas)
`abitur_pipeline.R` | Computes all calculation paths and the published results
`estimation_table.R` | Builds and prints the result table of the main calculation (key `estimation` in the JSON)

The notebook runs in this folder as it is. The pipeline script expects the folder layout of the
website's repository (`notebooks/raw/abitur/`, `data/`). Requires base R, `jsonlite` and `nlme` (ships with R).

## kmk_abitur.csv

One row per state and year, read unedited from the sheet "Noten" of the KMK file of that year.

Header | Definition
---|---
`year` | Year of the exam
`land` | State: `BW` Baden-Württemberg, `BY` Bayern, `BE` Berlin, `BB` Brandenburg, `HB` Bremen, `HH` Hamburg, `HE` Hessen, `MV` Mecklenburg-Vorpommern, `NI` Niedersachsen, `NW` Nordrhein-Westfalen, `RP` Rheinland-Pfalz, `SL` Saarland, `SN` Sachsen, `ST` Sachsen-Anhalt, `SH` Schleswig-Holstein, `TH` Thüringen
`exams` | Number of Abitur exams ("Zahl der Prüfungen")
`passed`, `failed` | Passed and failed exams
`mean` | Mean grade of the passes ("Notenmittel"), 1.0 best, 4.0 worst pass
`previous_year` | 1 if the KMK marks the column as the previous year's values (left out of the analysis)
`n_1_0` … `n_4_0` | Number of passes with each average grade from 1.0 to 4.0

## Sources and licences

- Sekretariat der Kultusministerkonferenz, "Abiturnoten im Ländervergleich", 2014 to 2025,
  https://www.kmk.org/downloads-dokumente/statistik/schulstatistik/abiturnoten.html (files for
  2014 to 2016 under `https://www.kmk.org/fileadmin/Dateien/pdf/Statistik/Aus_Abiturnoten_<year>.xls`,
  2017 to 2024 under `…/Statistik/Dokumentationen/Aus_Abiturnoten_<year>.xls(x)`, 2020 as
  `Aus_Abiturnoten_2020_Werte.xlsx`, 2025 as `Schnellmeldung_Abiturnoten_2025.xlsx`), downloaded on
  16 October 2026. Official statistics; source: KMK.

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
