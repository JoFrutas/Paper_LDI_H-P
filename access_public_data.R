#!/usr/bin/env Rscript

# Public-source access layer for the LDI pipeline.
#
# This script never redistributes provider files. It downloads them directly
# from the official endpoints recorded in config/public_data_sources.csv and
# writes an access manifest with URL, timestamp, size and SHA-256.

args_all <- commandArgs(trailingOnly = FALSE)
file_arg <- sub("^--file=", "", args_all[grepl("^--file=", args_all)])
root <- if (length(file_arg)) dirname(normalizePath(file_arg[[1]], winslash = "/")) else
  normalizePath(getwd(), winslash = "/", mustWork = TRUE)
args <- commandArgs(trailingOnly = TRUE)
mode <- if (length(args)) tolower(args[[1]]) else "catalog"
if (!mode %in% c("catalog", "check", "fetch"))
  stop("Mode must be catalog, check or fetch", call. = FALSE)

value_after <- function(prefix, default = "") {
  hit <- args[startsWith(args, prefix)]
  if (!length(hit)) default else sub(prefix, "", hit[[length(hit)]], fixed = TRUE)
}

data_root <- value_after("--data-dir=", Sys.getenv(
  "LDI_SOURCE_DATA_DIR", unset = file.path(root, "data")))
data_root <- normalizePath(data_root, winslash = "/", mustWork = FALSE)
only <- value_after("--only=", "")
overwrite <- identical(tolower(value_after("--overwrite=", "false")), "true")
catalog_path <- file.path(root, "config", "public_data_sources.csv")
if (!file.exists(catalog_path)) stop("Missing source catalog: ", catalog_path, call. = FALSE)
sources <- read.csv(catalog_path, stringsAsFactors = FALSE, check.names = FALSE,
                    na.strings = c("", "NA"), encoding = "UTF-8")
if (nzchar(only)) {
  wanted <- trimws(strsplit(only, ",", fixed = TRUE)[[1]])
  unknown <- setdiff(wanted, sources$id)
  if (length(unknown)) stop("Unknown source id(s): ", paste(unknown, collapse = ", "), call. = FALSE)
  sources <- sources[sources$id %in% wanted, , drop = FALSE]
}

sha256_file <- function(path) {
  if (!file.exists(path) || dir.exists(path)) return(NA_character_)
  if (requireNamespace("digest", quietly = TRUE))
    return(digest::digest(path, algo = "sha256", file = TRUE))
  bin <- Sys.which("certutil")
  if (!nzchar(bin)) return(NA_character_)
  out <- suppressWarnings(system2(bin, c("-hashfile", shQuote(path), "SHA256"), stdout = TRUE))
  hit <- grep("^[0-9A-Fa-f ]{64,}$", out, value = TRUE)
  if (!length(hit)) NA_character_ else tolower(gsub(" ", "", hit[[1]], fixed = TRUE))
}

target_for <- function(row) {
  target <- row$target_path[[1]]
  if (startsWith(target, "pipeline://"))
    file.path(root, sub("^pipeline://", "", target)) else
      file.path(data_root, target)
}
status_table <- function(tab) {
  rows <- lapply(seq_len(nrow(tab)), function(i) {
    row <- tab[i, , drop = FALSE]
    target <- target_for(row)
    exists <- file.exists(target) || dir.exists(target)
    sha <- if (file.exists(target) && !dir.exists(target)) sha256_file(target) else NA_character_
    pinned <- row$pinned_sha256[[1]]
    data.frame(
      id = row$id[[1]], provider = row$provider[[1]], access_mode = row$access_mode[[1]],
      target = normalizePath(target, winslash = "/", mustWork = FALSE),
      exists = exists,
      bytes = if (file.exists(target) && !dir.exists(target)) file.info(target)$size else NA_real_,
      sha256 = sha,
      pinned_sha256 = if (is.na(pinned)) "" else pinned,
      pinned_match = if (!exists || is.na(sha) || is.na(pinned)) NA else identical(tolower(sha), tolower(pinned)),
      official_url = if (!is.na(row$direct_url[[1]])) row$direct_url[[1]] else row$landing_page[[1]],
      stringsAsFactors = FALSE
    )
  })
  do.call(rbind, rows)
}

download_with_retry <- function(url, dest, attempts = 3L) {
  dir.create(dirname(dest), recursive = TRUE, showWarnings = FALSE)
  tmp <- paste0(dest, ".part")
  on.exit(if (file.exists(tmp)) unlink(tmp), add = TRUE)
  last <- NULL
  for (attempt in seq_len(attempts)) {
    ok <- tryCatch({
      status <- suppressWarnings(utils::download.file(
        url, tmp, mode = "wb", quiet = FALSE, method = "libcurl"))
      identical(status, 0L) && file.exists(tmp) && file.info(tmp)$size > 0
    }, error = function(e) { last <<- conditionMessage(e); FALSE })
    if (ok) {
      if (file.exists(dest)) unlink(dest)
      if (!file.rename(tmp, dest)) stop("Could not move completed download to ", dest, call. = FALSE)
      return(invisible(dest))
    }
  }
  # Windows installations occasionally reject an otherwise valid provider TLS
  # chain in R/libcurl. Python's standard urllib uses the operating-system
  # certificate path differently, so it is a useful dependency-free fallback.
  py <- Sys.getenv("LDI_PYTHON", unset = "")
  if (!nzchar(py)) py <- Sys.which("python")
  if (!nzchar(py)) py <- Sys.which("python3")
  if (nzchar(py)) {
    code <- paste(
      "import sys, urllib.request;",
      "req=urllib.request.Request(sys.argv[1],headers={'User-Agent':'LDI-public-data-access/1.0'});",
      "open(sys.argv[2],'wb').write(urllib.request.urlopen(req,timeout=180).read())"
    )
    out <- tryCatch(suppressWarnings(system2(
      py, c("-c", shQuote(code), shQuote(url), shQuote(tmp)),
      stdout = TRUE, stderr = TRUE
    )), error = function(e) structure(conditionMessage(e), status = 1L))
    py_status <- attr(out, "status")
    if (is.null(py_status)) py_status <- 0L
    if (identical(as.integer(py_status), 0L) && file.exists(tmp) && file.info(tmp)$size > 0) {
      if (file.exists(dest)) unlink(dest)
      if (!file.rename(tmp, dest)) stop("Could not move completed download to ", dest, call. = FALSE)
      return(invisible(dest))
    }
    if (length(out)) last <- paste(tail(out, 3L), collapse = " | ")
  }
  stop("Download failed: ", url, if (!is.null(last)) paste0(" (", last, ")") else "", call. = FALSE)
}

extract_matching <- function(zip_path, pattern, target) {
  members <- utils::unzip(zip_path, list = TRUE)$Name
  chosen <- members[grepl(pattern, members, perl = TRUE)]
  if (!length(chosen)) stop("No archive member matched ", pattern, " in ", basename(zip_path), call. = FALSE)
  tmpdir <- tempfile("ldi_source_")
  dir.create(tmpdir)
  on.exit(unlink(tmpdir, recursive = TRUE, force = TRUE), add = TRUE)
  utils::unzip(zip_path, files = chosen, exdir = tmpdir, overwrite = TRUE)
  extracted <- file.path(tmpdir, chosen)
  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  if (length(extracted) == 1L) {
    file.copy(extracted, target, overwrite = TRUE)
  } else {
    # Shapefile archives contain several components. Preserve their names in
    # the target directory and use the requested .shp name as the anchor.
    file.copy(extracted, dirname(target), overwrite = TRUE)
  }
  if (!file.exists(target)) stop("Expected extracted target is missing: ", target, call. = FALSE)
  invisible(target)
}

fetch_one <- function(row) {
  id <- row$id[[1]]
  access <- row$access_mode[[1]]
  target <- target_for(row)
  if ((file.exists(target) || dir.exists(target)) && !overwrite) {
    message("SKIP ", id, ": target already exists")
    return(invisible(NULL))
  }
  if (access %in% c("documented_public_source", "pipeline_generated")) {
    message("INFO ", id, ": ", row$snapshot_note[[1]], " | ", row$landing_page[[1]])
    return(invisible(NULL))
  }
  url <- row$direct_url[[1]]
  if (is.na(url) || !nzchar(url)) stop("No direct URL for ", id, call. = FALSE)
  message("FETCH ", id, " from ", url)
  if (identical(access, "direct_zip")) {
    archive <- file.path(data_root, "_downloads", basename(sub("[?].*$", "", url)))
    download_with_retry(url, archive)
    extract_matching(archive, row$archive_member_pattern[[1]], target)
  } else {
    download_with_retry(url, target)
  }
}

if (identical(mode, "catalog")) {
  print(sources[c("id", "provider", "description", "access_mode", "landing_page")], row.names = FALSE)
  cat("\nUse: Rscript access_public_data.R check\n")
  cat("     Rscript access_public_data.R fetch --only=pt_illiteracy,pt_income\n")
  quit(save = "no", status = 0L)
}

dir.create(data_root, recursive = TRUE, showWarnings = FALSE)
if (identical(mode, "fetch")) for (i in seq_len(nrow(sources))) fetch_one(sources[i, , drop = FALSE])
status <- status_table(sources)
manifest_dir <- file.path(data_root, "_provenance")
dir.create(manifest_dir, recursive = TRUE, showWarnings = FALSE)
manifest_path <- file.path(manifest_dir, "PUBLIC_SOURCE_ACCESS_MANIFEST.csv")
write.csv(status, manifest_path, row.names = FALSE, na = "")
print(status[c("id", "access_mode", "exists", "bytes", "pinned_match")], row.names = FALSE)
cat("\nAccess manifest: ", normalizePath(manifest_path, winslash = "/", mustWork = FALSE), "\n", sep = "")
