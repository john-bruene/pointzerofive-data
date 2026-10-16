# The Cooling Gap

Data and code behind the story [The Cooling Gap](https://pointzerofive.net/2026/10/the-cooling-gap)
(#003, 14 October 2026, from before the relaunch; English only).

[Open the notebook in Colab](https://colab.research.google.com/github/john-bruene/pointzerofive-data/blob/main/the-cooling-gap/story_003_cooling_gap.ipynb)

File | Contents
---|---
`story_003_cooling_gap.ipynb` | Python notebook that reproduces the numbers of the story
`the-cooling-gap.json` | Published results
`*.dta` | Output data of Pavanello et al. (2021), unmodified (table below)
`cooling_gap_pipeline.py` | Builds `the-cooling-gap.json` from the `.dta` files

File | Contents
---|---
`Figure_4.dta` | Air-conditioner ownership, cooling degree days and households per state; projections for 2040 in 10 scenarios
`HH_4countries_proj_dec.dta` | Air-conditioner ownership and electricity use by state and expenditure decile, today and 2040
`HH_4countries_agg_state.dta` | Survey-weighted air-conditioner share and expenditure per head by state and survey wave
`*_ac_CDD_wb_pred_prob.dta` | Predicted probability of owning an air conditioner by cooling degree days
`*_ac_CDD_wb_exp.dta` | Average marginal effect of cooling degree days by household expenditure

Survey codes: POF = Brazil, NSS = India, ENIGH = Mexico.

## Sources and licences

- Pavanello, F. et al. (2021), Air-conditioning and the adaptation cooling deficit in emerging
  economies, Nature Communications 12, 6460, <https://doi.org/10.1038/s41467-021-26592-2>.
  Output data from the replication repository
  [Energy-a/comparative_paper_natcomms](https://github.com/Energy-a/comparative_paper_natcomms)
  (commit 69a0125, accessed 14 October 2026), distributed under the
  [GNU General Public License v3.0](https://www.gnu.org/licenses/gpl-3.0.html); the `.dta` files
  are unmodified copies under the same licence.

Code and notebook: © John Brüne, all rights reserved (see the main README).
