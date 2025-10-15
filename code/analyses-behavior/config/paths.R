# paths.r - central path configuration for behavioral analyses
# author: marlene buch

# load required packages
if (!require("here")) install.packages("here")
library(here)

# === repository root ===
# get repo root (navigate up from code/analyses-behavioral to soccer-alpha)
# here() gives us: soccer-alpha/code/analyses-behavioral
# we need to go up 2 levels to get to soccer-alpha
repo_root <- file.path(here::here(), "..", "..")
repo_root <- normalizePath(repo_root, winslash = "/")

# === input paths ===
# processed behavioral data from postprocessing pipeline
derivatives_dir <- file.path(repo_root, "derivatives")

# function to find most recent behavioral postprocessing folder
get_most_recent_behavioral_postprocessing <- function() {
  # debug: print derivatives_dir path
  cat("looking in:", derivatives_dir, "\n")
  cat("directory exists:", dir.exists(derivatives_dir), "\n")
  
  dirs <- list.dirs(derivatives_dir, full.names = FALSE, recursive = FALSE)
  cat("all folders found:", length(dirs), "\n")
  if (length(dirs) > 0) {
    cat("folder names:", paste(head(dirs, 5), collapse = ", "), "\n")
  }
  
  behavior_dirs <- dirs[grepl("behavior-postprocessing$", dirs)]
  cat("behavioral postprocessing folders:", length(behavior_dirs), "\n")
  
  if (length(behavior_dirs) == 0) {
    stop("no behavioral postprocessing folders found in derivatives/")
  }
  
  most_recent <- sort(behavior_dirs, decreasing = TRUE)[1]
  return(file.path(derivatives_dir, most_recent))
}

behavioral_postprocessing_dir <- get_most_recent_behavioral_postprocessing()

# key input files
behavioral_data_file <- file.path(behavioral_postprocessing_dir, "behavioral_data_processed.rds")
inclusion_summary_file <- file.path(behavioral_postprocessing_dir, "inclusion_summary.rds")

# === output paths ===
# create dated output folder in derivatives
today_str <- format(Sys.Date(), "%Y-%m-%d")
output_dir <- file.path(derivatives_dir, paste0(today_str, "_behavioral-analyses"))
dir.create(output_dir, recursive = TRUE, showWarnings = FALSE)

# logs
logs_dir <- file.path(output_dir, "logs")
dir.create(logs_dir, showWarnings = FALSE)

# results (final outputs)
results_dir <- file.path(repo_root, "results", "behavioral")
results_tables_dir <- file.path(results_dir, "tables")
results_figures_dir <- file.path(results_dir, "figures")

# create results directories if they don't exist
dir.create(results_tables_dir, recursive = TRUE, showWarnings = FALSE)
dir.create(results_figures_dir, recursive = TRUE, showWarnings = FALSE)

# === verification ===
cat("\n=== PATHS CONFIGURED ===\n")
cat("repo root:", repo_root, "\n")
cat("input data from:", basename(behavioral_postprocessing_dir), "\n")
cat("output to:", basename(output_dir), "\n")
cat("results saved to:", results_dir, "\n\n")

# check that required input files exist
if (!file.exists(behavioral_data_file)) {
  stop("behavioral data file not found: ", behavioral_data_file)
}

if (!file.exists(inclusion_summary_file)) {
  stop("inclusion summary file not found: ", inclusion_summary_file)
}

cat("✓ all required input files found\n\n")