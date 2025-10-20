# batch_behavioral_postprocessing.r - main pipeline for behavioral postprocessing
# author: marlene buch

# === setup ===
cat("=== BEHAVIORAL POSTPROCESSING STARTED ===\n")
cat("session started:", as.character(Sys.time()), "\n\n")

# clear environment
rm(list = ls())

# load configuration & functions
source("config/paths.R")

# get repo root from paths
repo_root <- file.path(here::here(), "..", "..", "..")

source("config/settings.R")
source("functions/load_behavioral_data.R")
source("functions/load_eeg_trial_info.R")
source("functions/apply_eeg_exclusions.R")
source("functions/apply_rt_trimming.R")
source("functions/check_inclusion_criteria.R")
source("functions/validate_against_eeg.R")
source("functions/generate_reports.R")

# === user input: define subject list ===
# slash-separated string of subject IDs to be processed in this run
# leave empty ("") to process all available subjects
subjects_to_process = "390002/390003/390004/390005/390006/390007/390008/390009/390010/390011/390012/390013/390014/390015/390020/390021/390022/390023/390024/390025/390026/390027/390028/390030/390031/390032/390033/390034/390036/390037/390038/390039/390041/390042";

# parse subject list
if (subjects_to_process == "") {
  subjects_list <- NULL  # process all subjects
  cat("processing all available subjects\n")
} else {
  subjects_list <- str_split(subjects_to_process, "/")[[1]]
  subjects_list <- subjects_list[subjects_list != ""]
  cat("processing", length(subjects_list), "specified subjects\n")
}

# create output directories
create_output_dirs()

# start logging
log_file <- file.path(logs_dir, 
                      paste0("console_log_", 
                             format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), 
                             ".txt"))
sink(log_file, split = TRUE)

cat("\n=== LOADING DATA ===\n")

# load behavioral data (all subjects or specified subset)
if (is.null(subjects_list)) {
  behavioral_data <- load_behavioral_data(behavioral_dir)
} else {
  behavioral_data <- load_behavioral_data(behavioral_dir, subjects = subjects_list)
}

# load eeg trial info (this takes ~5 minutes for all subjects)
cat("\nnote: loading eeg data takes ~5 minutes for all subjects...\n")
if (is.null(subjects_list)) {
  eeg_trial_info <- load_eeg_trial_info(eeg_dir, verbose = TRUE)
} else {
  eeg_trial_info <- load_eeg_trial_info(eeg_dir, subjects = subjects_list, verbose = TRUE)
}

# save eeg trial info for future runs
eeg_rds_file <- file.path(output_dir, "eeg_trial_info_all_subjects.rds")
saveRDS(eeg_trial_info, eeg_rds_file)
cat("\nsaved eeg trial info to:", eeg_rds_file, "\n")

cat("\n=== PROCESSING PIPELINE ===\n")

# step 1: mark eeg inclusion
cat("\nstep 1: marking eeg inclusion...\n")
behavioral_with_eeg <- mark_eeg_inclusion(behavioral_data, eeg_trial_info, verbose = TRUE)

# step 2: apply rt trimming
cat("\nstep 2: applying rt trimming...\n")
behavioral_with_rt <- apply_rt_trimming(behavioral_with_eeg, 
                                        rt_lower_bound = RT_LOWER_BOUND,
                                        rt_outlier_threshold = RT_OUTLIER_THRESHOLD,
                                        verbose = TRUE)

# step 3: check inclusion criteria
cat("\nstep 3: checking subject-level inclusion...\n")
inclusion_summary <- check_inclusion_criteria(behavioral_with_rt,
                                              min_accuracy = MIN_ACCURACY,
                                              min_trials_per_code = MIN_EPOCHS_PER_CODE,
                                              verbose = TRUE)

# save processed data
processed_data_file <- file.path(output_dir, "behavioral_data_processed.rds")
saveRDS(behavioral_with_rt, processed_data_file)
cat("\nsaved processed behavioral data to:", processed_data_file, "\n")

# save inclusion summary
inclusion_file <- file.path(output_dir, "inclusion_summary.rds")
saveRDS(inclusion_summary, inclusion_file)
cat("saved inclusion summary to:", inclusion_file, "\n")

# generate reports
cat("\n=== GENERATING REPORTS ===\n")

# subject summary table
subject_table <- generate_subject_summary_table(
  behavioral_with_rt,
  inclusion_summary,
  output_dir,
  verbose = TRUE
)

# overall summary report
processing_params <- list(
  rt_lower_bound = RT_LOWER_BOUND,
  rt_outlier_threshold = RT_OUTLIER_THRESHOLD,
  min_accuracy = MIN_ACCURACY,
  min_trials_per_code = MIN_EPOCHS_PER_CODE
)

cat("\n=== VALIDATION ===\n")

# validate against most recent eeg postprocessing
# find most recent eeg postprocessing date
eeg_dates <- list.dirs(derivatives_dir, 
                       full.names = FALSE, recursive = FALSE)
eeg_dates <- eeg_dates[grepl("_erp-postprocessing$", eeg_dates)]

if (length(eeg_dates) > 0) {
  most_recent_eeg <- sort(eeg_dates, decreasing = TRUE)[1]
  eeg_date <- gsub("_erp-postprocessing", "", most_recent_eeg)
  
  cat("\nvalidating against eeg postprocessing from:", eeg_date, "\n")
  
  eeg_summary <- load_eeg_summary_table(eeg_date, derivatives_dir)
  validation_results <- validate_trial_counts(inclusion_summary, eeg_summary, verbose = TRUE)
  
  # save validation results
  validation_file <- file.path(output_dir, "validation_results.rds")
  saveRDS(validation_results, validation_file)
  cat("\nsaved validation results to:", validation_file, "\n")
} else {
  cat("\nwarning: no eeg postprocessing folders found, skipping validation\n")
}

# generate final summary report (needs validation results)
summary_report <- generate_postprocessing_summary(
  behavioral_with_rt,
  inclusion_summary,
  validation_results,
  output_dir,
  processing_params,
  verbose = TRUE
)

cat("\n=== SUMMARY ===\n")
cat("total subjects processed:", n_distinct(behavioral_data$subject), "\n")
cat("subjects included:", sum(inclusion_summary$included), "\n")
cat("subjects excluded:", sum(!inclusion_summary$included), "\n")

cat("\nprocessed data saved to:", output_dir, "\n")

# stop logging
sink()

cat("\n=== BEHAVIORAL POSTPROCESSING COMPLETE ===\n")
cat("session ended:", as.character(Sys.time()), "\n")
cat("log saved to:", log_file, "\n")