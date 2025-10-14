# batch_behavioral_analyses.r - main analysis pipeline
# author: marlene buch

# === setup ===
cat("=== BEHAVIORAL ANALYSES STARTED ===\n")
cat("session started:", as.character(Sys.time()), "\n\n")

# clear environment
rm(list = ls())

# load configuration & functions
source("config/paths.R")
source("config/settings.R")
source("functions/load_data.R")
source("functions/prepare_data.R")
source("functions/save_tables.R")
source("functions/plot_error-rates.R")
source("functions/plot_response-times.R")
source("functions/plot_confidence-ratings.R")

# === analysis selection flags ===
RUN_ERROR_RATES <- TRUE
RUN_RESPONSE_TIMES <- TRUE
RUN_CONFIDENCE <- TRUE
RUN_REPORT <- TRUE

# specific analyses within each category
ERROR_RATE_ANALYSES <- list(
  overall_error_rate_visible = TRUE,      # visible: social vs nonsocial
  proportion_flanker_visible = TRUE,      # visible: proportion flanker errors
  proportion_flanker_invisible = TRUE     # invisible: flanker error proportion
)

RT_ANALYSES <- list(
  visible_correctness = TRUE,             # 2x2 ANOVA: correctness × social
  visible_error_type = TRUE,              # 2x2 ANOVA: error type × social
  invisible_response_type = TRUE          # 2x2 ANOVA: response type × social
)

CONFIDENCE_ANALYSES <- list(
  visible_correctness = TRUE,             # 2x2 ANOVA: correctness × social
  visible_error_type = TRUE,              # 2x2 ANOVA: error type × social
  invisible_response_type = TRUE          # 2x2 ANOVA: response type × social
)

# === subject selection ===
# slash-separated string of subject IDs to analyze
# leave empty ("") to use all included subjects
subjects_to_analyze <- ""

# parse subject list
if (subjects_to_analyze == "") {
  subjects_list <- NULL
  cat("analyzing all included subjects\n\n")
} else {
  subjects_list <- str_split(subjects_to_analyze, "/")[[1]]
  subjects_list <- subjects_list[subjects_list != ""]
  cat("analyzing", length(subjects_list), "specified subjects\n\n")
}

# === create output directories ===
# session-specific directory for this analysis run
session_dir <- file.path(output_dir, format(Sys.time(), "%H-%M-%S"))
dir.create(session_dir, recursive = TRUE, showWarnings = FALSE)

cat("output directory:", session_dir, "\n\n")

# === load data ===
cat("=== LOADING DATA ===\n")
analysis_data <- load_analysis_data(
  subjects_to_include = subjects_list,
  eeg_ready_only = FALSE,  # use all behavioral trials
  verbose = TRUE
)

# apply transformations
transformed_data <- apply_transformations(analysis_data$data, verbose = TRUE)

# define shared directories for analysis scripts
error_rates_dir <- file.path(session_dir, "error_rates")
dir.create(error_rates_dir, showWarnings = FALSE)

tables_dir <- results_tables_dir  # this makes it available to analysis scripts

# start logging (after data is loaded)
log_file <- file.path(logs_dir, 
                      paste0("analysis_log_", 
                             format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), 
                             ".txt"))
sink(log_file, split = TRUE)
cat("logging started\n")
cat("log file:", log_file, "\n\n")

# === run selected analyses ===
if (RUN_ERROR_RATES) {
  cat("\n=== RUNNING ERROR RATE ANALYSES ===\n")
  source("01_error-rates.R")
}

if (RUN_RESPONSE_TIMES) {
  cat("\n=== RUNNING RESPONSE TIME ANALYSES ===\n")
  source("02_response-times.R")
}

if (RUN_CONFIDENCE) {
  cat("\n=== RUNNING CONFIDENCE RATING ANALYSES ===\n")
  source("03_confidence-ratings.R")
}

if (RUN_REPORT) {
  cat("\n=== GENERATING REPORT ===\n")
  
  # render report to session directory (timestamped)
  session_report <- file.path(session_dir, "analysis_report.html")
  rmarkdown::render("04_generate-report.Rmd",
                    output_file = session_report)
  cat("timestamped report saved to:", session_report, "\n")
  
  # copy to results directory (final version)
  final_report <- file.path(results_dir, "analysis_report.html")
  file.copy(session_report, final_report, overwrite = TRUE)
  cat("final report saved to:", final_report, "\n")
}

# === summary ===
cat("\n=== ANALYSIS COMPLETE ===\n")
cat("session ended:", as.character(Sys.time()), "\n")
cat("results saved to:", session_dir, "\n")

# stop logging
sink()

cat("\nlog saved to:", log_file, "\n")