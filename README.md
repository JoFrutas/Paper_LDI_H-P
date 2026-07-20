# Public data access for the Portugal-Brazil deprivation study

This repository contains only the code and source register used to obtain the
public inputs. It does not contain the manuscript, prepared datasets, results,
figures, or raw provider files.

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
