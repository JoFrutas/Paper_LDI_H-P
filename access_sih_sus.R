#!/usr/bin/env Rscript

# Download the official monthly SIH/SUS RD files used in the study and record
# their provenance. No patient-level file is redistributed by this repository.

args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args) && !startsWith(args[[1]], "--")) tolower(args[[1]]) else "catalog"
if (!mode %in% c("catalog", "fetch"))
  stop("Mode must be catalog or fetch", call. = FALSE)

value_after <- function(prefix, default = "") {
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) default else sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}
split_values <- function(value, default) {
  if (!nzchar(value)) return(default)
  trimws(strsplit(value, ",", fixed = TRUE)[[1]])
}

years <- as.integer(split_values(value_after("--years=", ""), 2021:2023))
months <- as.integer(split_values(value_after("--months=", ""), 1:12))
all_ufs <- c(
  "RO", "AC", "AM", "RR", "PA", "AP", "TO", "MA", "PI", "CE", "RN",
  "PB", "PE", "AL", "SE", "BA", "MG", "ES", "RJ", "SP", "PR", "SC",
  "RS", "MS", "MT", "GO", "DF"
)
ufs <- toupper(split_values(value_after("--ufs=", ""), all_ufs))
if (any(!years %in% 2008:2099) || any(!months %in% 1:12) || any(!ufs %in% all_ufs))
  stop("Invalid year, month or UF selection", call. = FALSE)

script_arg <- sub("^--file=", "", commandArgs(trailingOnly = FALSE)[
  grepl("^--file=", commandArgs(trailingOnly = FALSE))
])
root <- if (length(script_arg)) dirname(normalizePath(script_arg[[1]], winslash = "/")) else
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
output <- value_after("--output=", file.path(root, "data", "sih_sus"))
output <- normalizePath(output, winslash = "/", mustWork = FALSE)
overwrite <- tolower(value_after("--overwrite=", "false")) %in% c("1", "true", "yes")
base_url <- "ftp://ftp.datasus.gov.br/dissemin/publicos/SIHSUS/200801_/Dados"

catalog <- expand.grid(
  source_uf = ufs, year = years, month = months,
  KEEP.OUT.ATTRS = FALSE, stringsAsFactors = FALSE
)
catalog <- catalog[order(catalog$year, catalog$source_uf, catalog$month), ]
catalog$filename <- sprintf(
  "RD%s%02d%02d.dbc", catalog$source_uf, catalog$year %% 100L, catalog$month
)
catalog$url <- paste0(base_url, "/", catalog$filename)
catalog$local_path <- file.path(output, as.character(catalog$year), catalog$filename)

if (identical(mode, "catalog")) {
  cat(sprintf("%d SIH/SUS files selected.\n", nrow(catalog)))
  print(utils::head(catalog[c("source_uf", "year", "month", "filename", "url")], 12L),
        row.names = FALSE)
  quit(save = "no", status = 0L)
}

sha256_file <- function(path) {
  if (requireNamespace("digest", quietly = TRUE))
    return(digest::digest(path, algo = "sha256", file = TRUE))
  certutil <- Sys.which("certutil")
  if (!nzchar(certutil)) return(NA_character_)
  out <- suppressWarnings(system2(certutil, c("-hashfile", shQuote(path), "SHA256"),
                                  stdout = TRUE))
  hit <- grep("^[0-9A-Fa-f ]{64,}$", out, value = TRUE)
  if (!length(hit)) NA_character_ else tolower(gsub(" ", "", hit[[1]], fixed = TRUE))
}

download_binary <- function(url, destination) {
  dir.create(dirname(destination), recursive = TRUE, showWarnings = FALSE)
  temporary <- paste0(destination, ".partial")
  on.exit(if (file.exists(temporary)) unlink(temporary), add = TRUE)
  ok <- tryCatch({
    status <- suppressWarnings(utils::download.file(
      url, temporary, mode = "wb", quiet = TRUE, method = "libcurl"
    ))
    identical(status, 0L) && file.exists(temporary) && file.info(temporary)$size > 0
  }, error = function(e) FALSE)
  curl <- Sys.which("curl")
  if (!ok && nzchar(curl)) {
    status <- suppressWarnings(system2(curl, c(
      "--fail", "--location", "--ftp-pasv", "--retry", "3",
      "--connect-timeout", "30", "--output", temporary, url
    )))
    ok <- identical(status, 0L) && file.exists(temporary) && file.info(temporary)$size > 0
  }
  if (!ok) stop("Download failed: ", url, call. = FALSE)
  if (file.exists(destination)) unlink(destination)
  if (!file.rename(temporary, destination))
    stop("Could not move downloaded file: ", destination, call. = FALSE)
}

rows <- vector("list", nrow(catalog))
for (i in seq_len(nrow(catalog))) {
  destination <- catalog$local_path[[i]]
  cached <- file.exists(destination) && file.info(destination)$size > 0
  if (!cached || overwrite) {
    message(sprintf("Download %d/%d: %s", i, nrow(catalog), catalog$filename[[i]]))
    download_binary(catalog$url[[i]], destination)
  } else {
    message(sprintf("Cached %d/%d: %s", i, nrow(catalog), catalog$filename[[i]]))
  }
  rows[[i]] <- data.frame(
    source_uf = catalog$source_uf[[i]], year = catalog$year[[i]],
    month = catalog$month[[i]], filename = catalog$filename[[i]],
    url = catalog$url[[i]], local_path = normalizePath(destination, winslash = "/"),
    bytes = file.info(destination)$size, sha256 = sha256_file(destination),
    cached = cached && !overwrite,
    retrieved_utc = format(Sys.time(), tz = "UTC", usetz = TRUE),
    stringsAsFactors = FALSE
  )
}
manifest <- do.call(rbind, rows)
manifest_path <- file.path(output, "sih_sus_access_manifest.csv")
utils::write.csv(manifest, manifest_path, row.names = FALSE, na = "")
cat("Manifest: ", normalizePath(manifest_path, winslash = "/"), "\n", sep = "")
