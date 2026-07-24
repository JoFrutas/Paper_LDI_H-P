# Public data access for the Portugal-Brazil deprivation study

This repository contains the code and source register used to obtain the public
inputs, together with source-only R Markdown notebooks for inspecting the
statistical analysis. It does not contain the manuscript, prepared datasets,
rendered results, figures, or raw provider files.

## General source access

R 4.3 or later is recommended. In PowerShell:

```powershell
.\ACCESS_PUBLIC_DATA.bat catalog
.\ACCESS_PUBLIC_DATA.bat fetch --only=pt_illiteracy,pt_income,pt_mortality
```

Omit `--only=` to request every source with a stable direct endpoint. Some
official sources are large. The Atlas do Desenvolvimento Humano source does not
provide a stable direct file endpoint and therefore remains a documented manual
source in `config/public_data_sources.csv`.

## SIH/SUS files

The hospital source comprises 972 monthly RD files for 2021-2023. Review the
catalog before starting the large transfer:

```powershell
Rscript access_sih_sus.R catalog
Rscript access_sih_sus.R fetch --output=C:\LDI_data\sih_sus
```

`access_sih_sus.R` records the official URL, file size and SHA-256 for each
download. The file naming and scope are described in `SIH_SUS_METHOD.md`.

Official providers may revise live files. The generated access manifest records
what was retrieved; it should not be interpreted as proof that a later download
is byte-identical to the analytical snapshot.

## Analysis notebooks

The `analysis` directory contains two versioned R Markdown notebooks. The first
checks and prepares the retained derived inputs from an audited run. The second
refits the main Brazil and Portugal models and reads the audited sensitivity
tables in separate chunks.

These notebooks require paths to the audited run and the Brazilian municipal
boundary file. Neither input is included in this public repository. See
`analysis/README.md` for the required environment variables and execution order.

This is an inspection layer built from retained derived inputs. It is not a
claim of full reconstruction from every raw provider file.

