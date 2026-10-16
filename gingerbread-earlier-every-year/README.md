# Does the gingerbread season start earlier every year?

Data and code behind the story
[Does the gingerbread season start earlier every year?](https://pointzerofive.net/2026/10/gingerbread-earlier-every-year)
(#004, 1 October 2026; German:
[Beginnt die Lebkuchensaison jedes Jahr früher?](https://pointzerofive.net/de/2026/10/gingerbread-earlier-every-year)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/gingerbread-earlier-every-year/story_004_gingerbread.ipynb)
(choose the R runtime).

File | Contents
---|---
`story_004_gingerbread.ipynb` | R notebook that reproduces every number in the story, including all 27 calculation paths
`gingerbread-earlier-every-year.json` | Published results: main calculation, the 27 calculation paths (`specs`), onsets per season, chart data
`gingerbread-earlier-every-year.output.txt` | Console output of the pipeline run, unedited, ending with R and package versions
`trends_daily.csv` | Google Trends daily search interest in Germany, 1 June to 31 December, seasons 2004 to 2025
`download_log.json` | Time of the download of each season (UTC)
`claim.json` | Texts of the claim and of the forks, English and German
`pitch.md` | The pitch: question, dispute, main calculation and forks, fixed before the download
`gingerbread_download.py` | Downloads `trends_daily.csv` from Google Trends (Python, standard library)
`gingerbread_pipeline.R` | Computes onsets, all calculation paths and the published results
`estimation_table.R` | Builds and prints the result table of the main calculation (key `estimation` in the JSON)

The notebook runs in this folder as it is. The pipeline script expects the folder layout of the
website's repository (`notebooks/raw/gingerbread/`, `data/`). Requires base R and `jsonlite`.

## trends_daily.csv

One request per season, web search, Germany, the three terms together, so the three series of a
season share one scale. Values of different seasons are not on the same scale.

Header | Definition
---|---
`season` | Year of the season
`date` | Day, 1 June to 31 December
`term` | `Lebkuchen`, `Spekulatius` or `Dominosteine`
`value` | Search interest, 0 to 100; 100 is the highest daily value of any of the three terms in that season's request. Google rounds small volumes to 0
`partial` | 1 if Google marked the value as incomplete (0 for every row in this file)

## Sources and licences

- Search interest: [Google Trends](https://trends.google.com), downloaded on 16 October 2026.
  "Source: Google Trends". Google draws the values from a sample of searches; a repeated download
  can differ by a few points.

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
