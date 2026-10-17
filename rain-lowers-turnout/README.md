# Does rain lower turnout?

Data and code behind the story
[Does rain lower turnout?](https://pointzerofive.net/2026/10/rain-lowers-turnout)
(#007, 22 October 2026; German:
[Senkt Regen die Wahlbeteiligung?](https://pointzerofive.net/de/2026/10/rain-lowers-turnout)).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/rain-lowers-turnout/story_007_rain.ipynb)
(choose the R runtime; the 16 placebo tests take about half a minute).

File | Contents
---|---
`story_007_rain.ipynb` | R notebook that reproduces every number in the story, including all 16 calculation paths
`rain-lowers-turnout.json` | Published results: main calculation, the 16 calculation paths (`specs`), chart data
`rain-lowers-turnout.output.txt` | Console output of the pipeline run, unedited, ending with R and package versions
`turnout.csv` | Eligible voters and voters per Wahlkreis, Bundestag elections 2005–2025, with the previous election on the same boundaries
`rain.csv` | Mean precipitation per Wahlkreis on the calendar dates of the elections, every year 1995–2025
`claim.json` | Texts of the claim and of the forks, English and German
`pitch.md` | The pitch: question, main calculation and forks, fixed before the analysis
`rain_download.py` | Downloads the raw files (Python)
`rain_extract.py` | Reduces them to `turnout.csv` and `rain.csv` (Python with netCDF4, pyshp, shapely, pyproj)
`rain_pipeline.R` | Computes all calculation paths and the published results
`estimation_table.R` | Builds and prints the result table of the main calculation (key `estimation` in the JSON)

The notebook runs in this folder as it is. The raw files (about 1.8 GB) are not in this
repository; `rain_download.py` fetches them into `content/incoming/rain/` (see Sources).

## turnout.csv

Header | Definition
---|---
`election` | Year of the Bundestag election
`wkr` | Wahlkreis number in that election
`name` | Wahlkreis name
`land` | Land number (1 Schleswig-Holstein … 16 Thüringen)
`eligible` | Eligible voters (Wahlberechtigte), first-vote column
`voters` | Voters (Wähler, Wählende), first-vote column
`eligible_prev` | Eligible voters at the previous election, recomputed on this election's boundaries
`voters_prev` | Voters at the previous election, recomputed on this election's boundaries

## rain.csv

Header | Definition
---|---
`geometry` | Election whose Wahlkreis boundaries are used
`which` | `this`: the calendar date of that election; `prev`: the date of the election before
`date` | Calendar date, month and day
`year` | Year of the rain field (1995–2025)
`wkr` | Wahlkreis number in the election `geometry`
`mm` | Mean HYRAS precipitation over the 1 km cells whose centre lies in the Wahlkreis, mm; the value of a date covers 06 UTC that day to 06 UTC the next

## Sources and licences

- Turnout and boundaries: Die Bundeswahlleiterin, Wiesbaden,
  `https://www.bundeswahlleiterin.de/dam/jcr/ce2d2b6a-f211-4355-8eea-355c98cd4e47/btw_kerg.zip`
  and the Wahlkreis shapefiles on the `wahlkreiseinteilung` pages of each election, downloaded on
  16 October 2026. The 2025 results are licensed under the Datenlizenz Deutschland Namensnennung
 2.0 (dl-de/by-2-0).
- Rain: Deutscher Wetterdienst, Raster data set precipitation sums in mm for Germany – HYRAS-DE-PR
  v6-1, daily files `pr_hyras_1_<year>_v6-1_de.nc`,
  `https://opendata.dwd.de/climate_environment/CDC/grids_germany/daily/hyras_de/precipitation/`,
  CC BY 4.0, downloaded on 16 October 2026.

Everything else in this folder: © John Brüne, all rights reserved (see the main README).
