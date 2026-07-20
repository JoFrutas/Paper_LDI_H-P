# SIH/SUS source access

The hospital source is the official DATASUS SIH/SUS RD dissemination series.
The study period is processing competence 2021-2023: 27 source states, 12 months
and three years, or 972 files. File names follow `RD{UF}{YY}{MM}.dbc`.

`access_sih_sus.R` constructs every official URL, downloads without changing the
provider file and writes a manifest containing the URL, local path, byte count,
SHA-256 and retrieval time. Existing non-empty files are reused unless
`--overwrite=true` is supplied.

The access script does not classify admissions or redistribute the DBC files.
In the analysis, municipality attribution is based on residence (`MUNIC_RES`),
the time axis is processing competence, and primary care-sensitive conditions
are classified from the primary diagnosis using the versioned rule table in
`config/icsap_portaria_221_2008.csv`.

Official documentation:

- https://datasus.saude.gov.br/acesso-a-informacao/producao-hospitalar-sih-sus/
- https://tabnet.datasus.gov.br/cgi/sih/sxdescr.htm
- https://bvsms.saude.gov.br/bvs/saudelegis/sas/2008/prt0221_17_04_2008.html
