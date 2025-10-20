# paths.r - path configuration for behavioral analysis
# author: marlene buch

library(here)
library(stringr)

# read link to preprocessed data (same file used by matlab)
# here() gives us the r project root, need to go up to repo root
repo_root <- file.path(here(), "..", "..", "..")
preprocessed_link <- file.path(repo_root, "input", "preprocessed")
preprocessed_path <- readLines(preprocessed_link, warn = FALSE) %>% str_trim()

# construct paths to data
behavioral_dir <- file.path(preprocessed_path, "s1_r1", "behavior")
eeg_dir <- file.path(preprocessed_path, "s1_r1", "eeg")

# output directory (matching erp-postprocessing naming convention)
output_dir <- file.path(repo_root, "derivatives", 
                        paste0(Sys.Date(), "_behavior-postprocessing"))

# logs go in main output directory (flat structure like erp-postprocessing)
logs_dir <- output_dir

# derivatives directory for validation
derivatives_dir <- file.path(repo_root, "derivatives")

# create output directory
create_output_dirs <- function() {
  dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)
  
  message("output directory created:")
  message("  ", output_dir)
}

# validate paths exist
validate_paths <- function() {
  if (!file.exists(preprocessed_link)) {
    stop("link file not found: ", preprocessed_link)
  }
  
  if (!dir.exists(behavioral_dir)) {
    stop("behavioral data directory not found: ", behavioral_dir)
  }
  
  message("paths validated")
  message("  behavioral data: ", behavioral_dir)
}