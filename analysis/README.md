# V6 analysis notebooks

This directory contains source code only. It does not include the manuscript,
prepared data, rendered HTML, model objects, results tables, or figures.

Run the notebooks in this order:

1. `01_importacao_preparacao_dados.Rmd`
2. `02_analise_estatistica.Rmd`

The first notebook checks that the selected analytical run reports `PASSED_QA`,
imports the retained municipal CSV files and audited tables, joins Brazilian
municipal area, validates identifiers and coverage, and writes a local prepared
RDS file. The second notebook refits the main Brazil and Portugal models,
applies the documented CR2 and Satterthwaite inference, checks the main effects
against `RESULTS_MASTER.csv`, and displays the audited sensitivity tables.

## Required inputs

The notebooks start from retained derived inputs. Set these paths before
rendering:

```powershell
$env:LDI_AUDITED_RUN_DIR = "C:\path\to\revision_v4_analysis_06"
$env:LDI_BR_SHAPE_PATH = "C:\path\to\BR_Municipios_2022.shp"
```

An optional pipeline path allows the notebooks to reuse a project `renv`
library:

```powershell
$env:LDI_PIPELINE_DIR = "C:\path\to\revision_pipeline_v4"
```

Then render from the repository root:

```powershell
Rscript -e "rmarkdown::render('analysis/01_importacao_preparacao_dados.Rmd')"
Rscript -e "rmarkdown::render('analysis/02_analise_estatistica.Rmd')"
```

R 4.3 or later is recommended. Required packages are `data.table`, `sf`,
`knitr`, `MASS`, `sandwich`, `clubSandwich`, and `ggplot2`.

The generated HTML and RDS files are ignored by Git. They are local inspection
artifacts and must not be committed.

## Reproducibility boundary

These notebooks reproduce the reported models from the retained audited CSV
inputs. They do not recreate the full upstream extraction, classification, and
processing of all 972 SIH/SUS files. The public access scripts in the repository
document and retrieve the provider files separately.

