# Run the production report with configurable data, cache and output locations.
all_args <- commandArgs(trailingOnly = FALSE)
script <- sub("^--file=", "", grep("^--file=", all_args, value = TRUE)[1])
script <- gsub("~+~", " ", script, fixed = TRUE)
root <- normalizePath(dirname(script), winslash = "/", mustWork = TRUE)
args <- commandArgs(trailingOnly = TRUE)
if ("--help" %in% args) {
  cat(paste0("Usage: Rscript run_pipeline.R [--refit | --from-dhs] [--check-paths] ",
    "[--input-dir PATH] [--fit-cache FILE] [--output-dir PATH] [--work-dir PATH] ",
    "[--counterfactual-csv FILE]\n"))
  quit(status = 0)
}
fit_rel <- "joint_ks_fpet_style/fits/joint_histflex_low_persist_global_full_ge2_high_ess.rds"
options <- list(input_dir = ".", fit_cache = fit_rel, output_dir = "output",
                work_dir = "work", counterfactual_csv = "")
flags <- character()
i <- 1L
while (i <= length(args)) {
  arg <- args[i]
  if (arg %in% c("--refit", "--from-dhs", "--check-paths")) {
    flags <- c(flags, arg); i <- i + 1L
  } else {
    key <- gsub("-", "_", sub("^--", "", arg))
    if (!startsWith(arg, "--") || !key %in% names(options)) stop("Unknown argument: ", arg)
    if (i == length(args) || startsWith(args[i + 1L], "--") || !nzchar(args[i + 1L]))
      stop("Provide a path after ", arg)
    options[[key]] <- args[i + 1L]; i <- i + 2L
  }
}
resolve <- function(path) {
  path <- path.expand(path)
  if (!grepl("^/|^[A-Za-z]:|^\\\\", path)) path <- file.path(root, path)
  normalizePath(path, winslash = "/", mustWork = FALSE)
}
if (!file.exists(file.path(root, "mcpr_trajectories.Rproj"))) stop("Project files not found beside run_pipeline.R")
input_dir <- resolve(options$input_dir)
fit_cache <- resolve(options$fit_cache)
output <- resolve(options$output_dir)
work_dir <- resolve(options$work_dir)
input_names <- c("mcpr_data.csv", "wb_surveys.xlsx", "country_pop_weights_15_49.csv")
missing_inputs <- input_names[!file.exists(file.path(input_dir, input_names))]
if (length(missing_inputs)) stop("Input files missing from --input-dir: ", paste(missing_inputs, collapse = ", "))
refit <- any(flags %in% c("--refit", "--from-dhs"))
if (!refit) {
  pinned <- read.csv(file.path(root, "docs/PINNED_INPUT_MD5.csv"), stringsAsFactors = FALSE)
  actual <- unname(tools::md5sum(file.path(input_dir, pinned$path)))
  if (anyNA(actual) || any(actual != pinned$md5))
    stop("Pinned inputs changed. Use --refit rather than reusing the saved production cache.")
  if (!file.exists(fit_cache)) stop("Provide the production cache with --fit-cache, extract the companion ZIP, or use --refit")
}
if ("--check-paths" %in% flags) {
  cat("Input directory: ", input_dir, "\nOutput directory: ", output,
      "\nWork directory: ", work_dir, "\n", sep = "")
  if (!refit) cat("Fit-cache file: ", fit_cache, "\nPinned input hashes match.\n", sep = "")
  cat("Path checks passed. No download, model fit or report render was run.\n")
  quit(status = 0)
}
dir.create(work_dir, recursive = TRUE, showWarnings = FALSE)
runtime <- tempfile(paste0("run_", format(Sys.time(), "%Y%m%d_%H%M%S"), "_"), tmpdir = work_dir)
dir.create(runtime, recursive = TRUE)
for (name in c("scripts", "holdout_model_comparison_30", "production_report.Rmd", "get_dhs.Rmd", "dhs_analysis_production.Rmd")) {
  if (!file.copy(file.path(root, name), runtime, recursive = TRUE)) stop("Copy failed: ", name)
}
for (name in input_names) {
  if (!file.copy(file.path(input_dir, name), runtime)) stop("Input copy failed: ", name)
}
if (!refit) {
  dir.create(file.path(runtime, dirname(fit_rel)), recursive = TRUE)
  if (!file.copy(fit_cache, file.path(runtime, fit_rel))) stop("Fit copy failed")
}
setwd(runtime)
if ("--from-dhs" %in% flags) {
  extracted <- tempfile(fileext = ".R")
  knitr::purl("get_dhs.Rmd", output = extracted, documentation = 0, quiet = TRUE)
  sys.source(extracted, envir = globalenv())
  unlink(extracted)
  if (nrow(mCPR_errors)) stop("DHS extraction errors: inspect mcpr_data_extraction_errors.csv in ", runtime)
}
if (refit) source("scripts/fit_production_model.R")
dir.create(output, recursive = TRUE, showWarnings = FALSE)
csv_file <- if (nzchar(options$counterfactual_csv)) resolve(options$counterfactual_csv) else
  file.path(runtime, "priority_geographies_counterfactual_ssa_2045_fpet_best_compromise.csv")
dir.create(dirname(csv_file), recursive = TRUE, showWarnings = FALSE)
rmarkdown::render("production_report.Rmd", output_dir = output, knit_root_dir = runtime,
  params = list(counterfactual_csv = csv_file), envir = new.env(parent = globalenv()), encoding = "UTF-8")
message("Full report: ", file.path(output, "production_report.html"))
message("Counterfactual CSV: ", csv_file)
message("Internal outputs and the exact render sources: ", runtime)
