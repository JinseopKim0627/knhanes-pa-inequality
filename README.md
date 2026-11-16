# Age, Sex, and Socioeconomic Inequalities in Combined Aerobic and Muscle-Strengthening Physical Activity Among Korean Adults: KNHANES 2014–2023

Analysis code and aggregate results for the manuscript of the same title (Kim J, Cho Y; submitted to *BMC Public Health*).

## Data

The analysis uses the Korea National Health and Nutrition Examination Survey (KNHANES), conducted by the Korea Disease Control and Prevention Agency (KDCA).

**Individual-level KNHANES data are not included in this repository.** Under the KDCA terms of use, the raw data and any individual-level files derived from them cannot be redistributed. Researchers can obtain the data free of charge after registration at <https://knhanes.kdca.go.kr>.

Required raw files (SAS format, `HNyy_ALL`): `HN14_ALL` to `HN23_ALL`. The first script also processes `HN07_ALL` to `HN13_ALL`; these years are not used in the analysis. If you do not have them, comment out the `%SIMPLE_OLD(...)` calls in `01_build_analytic_sample.sas`.

## Software

- SAS 9.4 (Unicode/UTF-8 session), PROC SURVEYREG
- Python 3 with matplotlib (figures only)

## How to reproduce

1. Edit `config.sas` to point `RAWDIR` to the raw KNHANES files and `OUTDIR` to an output folder.
2. In SAS, run `config.sas`, then the scripts in `code/` in order:

| Script | Purpose | Main output |
|---|---|---|
| `01_build_analytic_sample.sas` | Builds the 2014–2023 analytic sample (adults ≥20 y, positive weight, valid aerobic and muscle-strengthening indicators) and the sample flow | `pa4_main2014_v5.sas7bdat`, `sample_flow.csv` |
| `02_fit_models_and_export.sas` | Fits the sex-stratified, category-specific survey-weighted linear probability models for the main and sensitivity analyses (40 models) and exports adjusted margins, differences, and prespecified contrasts at full precision | `final_margins.csv`, `final_differences.csv`, `final_contrasts.csv`, `final_model_n.csv` |
| `03_table1.sas` | Table 1 frequencies and survey-weighted percentages | `table1_check.csv` |
| `04_vif.sas` | Variance inflation factors for the primary covariate set | VIF tables |
| `05_model_sample_audit.sas` | Checks the number of observations used by each model | `model_n_audit.csv` |

3. Draw Figures 1–3 and Supplementary Figures S1–S2 from the exported margins:

```
python figures/make_figures.py results/final_margins.csv figures/
```

## Results included

`results/` contains the aggregate outputs used for all tables and figures in the manuscript. No individual-level data are included.

| File | Contents |
|---|---|
| `final_margins.csv` | Adjusted predicted probabilities and 95% CIs by sex, outcome, and age/education/income group for each analysis specification |
| `final_differences.csv` | All pairwise adjusted differences (age-group comparisons in Supplementary Table S2) |
| `final_contrasts.csv` | Prespecified contrasts (Table 5, Supplementary Table S1): difference, 95% CI, p value |
| `final_model_n.csv` | Observations and sum of weights per model |
| `sample_flow.csv`, `missing_audit.csv` | Sample selection counts and education/income missingness |
| `final_precision_check.csv` | Completeness check of the exported results |
| `table1_check.csv` | Table 1 values |

Analysis specifications: `MAIN` (primary), `NO2014`, `NOCOVID`, and `BMICHRONIC` (sensitivity analyses excluding 2014, excluding 2020–2021, and adding body mass index and chronic disease), and `LEIS` (secondary analysis with aerobic activity restricted to leisure time).

## License

Code is released under the MIT License (see `LICENSE`).

## Citation

Please cite the article once published. Contact: Youngtae Cho (youngtae@snu.ac.kr).
