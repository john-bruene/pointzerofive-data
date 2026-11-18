# Do more people want out of their gym contract in spring?

Data and code behind the story
[Do more people want out of their gym contract in spring?](https://pointzerofive.net/2026/11/gym-contract-spring)
(#009, 5 November 2026; German:
[Suchen im Frühjahr mehr Menschen, wie sie ihr Fitnessstudio kündigen?](https://pointzerofive.net/de/2026/11/gym-contract-spring)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/gym-contract-spring/story_009_gym_contract.ipynb)
(choose the R runtime).

File | Contents
---|---
`story_009_gym_contract.ipynb` | R notebook that reproduces every number in the story, including all 18 calculation paths
`gym-contract-spring.json` | Published results: main calculation, the 18 calculation paths (`specs`), the monthly series and the month profile
`gym-contract-spring.output.txt` | Console output of the pipeline run, unedited, ending with R and package versions
`trends_monthly.csv` | Both search terms as one table, written from the two exports
`multiTimeline_fitnessstudio_kuendigen_2026-11-18.csv` | Google Trends export of "Fitnessstudio kündigen", as downloaded
`multiTimeline_fitnessvertrag_kuendigen_2026-11-18.csv` | Google Trends export of "Fitnessvertrag kündigen", as downloaded
`claim.json` | Texts of the claim and of the forks, English and German
`pitch.md` | The pitch: question, dispute, main calculation and forks, fixed before the analysis
`gym_pipeline.R` | Builds `trends_monthly.csv` and the published results
`estimation_table.R` | Builds and prints the result table of the main calculation (key `estimation` in the JSON)

The notebook runs in this folder as it is. The pipeline script expects the folder layout of the
website's repository (`content/incoming/fitness/`, `notebooks/raw/fitness/`, `data/`). Requires
base R, `jsonlite` and `nlme`.

## trends_monthly.csv

Header | Definition
---|---
`term` | `fitnessstudio` = "Fitnessstudio kündigen", `vertrag` = "Fitnessvertrag kündigen"
`month` | Month, `YYYY-MM`, January 2004 to November 2026
`value` | Google Trends index, 0 to 100 within each term's export; 100 is the month with the term's highest share of all searches

## Sources and licences

- Search interest: [Google Trends](https://trends.google.com), web search, Germany, exported on
  18 November 2026, each term on its own. "Source: Google Trends". Google draws the values from a
  sample of searches; a repeated export can differ by a few points.

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
