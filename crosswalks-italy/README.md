# Crosswalks of Italy

Data and code behind the story
[Crosswalks of Italy](https://pointzerofive.net/2026/02/crosswalks-italy) (#001, 27 February 2026,
from before the relaunch; English only).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/crosswalks-italy/story_001_crosswalks.ipynb)

File | Contents
---|---
`story_001_crosswalks.ipynb` | Python notebook with the numbers and charts of the story
`crosswalks-italy.json` | Published results per city
`crosswalks_raw.csv` | Crossings and population of 14 provincial capitals
`crosswalks_pipeline.py` | Builds `crosswalks-italy.json` from `crosswalks_raw.csv`

## crosswalks_raw.csv

Header | Definition
---|---
`city` | Provincial capital
`region` | Region
`province_code` | Province code, e.g. `BZ`
`population_2023` | Resident population 2023 (ISTAT)
`osm_crosswalk_count` | Pedestrian crossings mapped in OpenStreetMap (`highway=crossing` nodes within the municipal boundary)
`source` | Source of the row

## Sources and licences

- Crossings: © OpenStreetMap contributors, available under the
  [Open Database License (ODbL) 1.0](https://opendatacommons.org/licenses/odbl/1-0/).
  `crosswalks_raw.csv` and `crosswalks-italy.json` contain data derived from OpenStreetMap and are
  available under the same licence.
- Population: ISTAT, resident population 2023.

Code and notebook: © John Brüne, all rights reserved (see the main README).
