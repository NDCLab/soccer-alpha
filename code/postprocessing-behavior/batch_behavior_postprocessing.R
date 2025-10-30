# batch_behavioral_postprocessing.r - main pipeline for behavioral postprocessing
# author: marlene buch

# === setup ===
cat("=== BEHAVIORAL POSTPROCESSING STARTED ===\n")
cat("session started:", as.character(Sys.time()), "\n\n")

# clear environment
rm(list = ls())

# load required libraries
library(tidyverse)
library(jsonlite)

# load configuration & functions
source("config/paths.R")

# get repo root from paths
repo_root <- file.path(here::here(), "..", "..")

source("config/settings.R")
source("functions/load_behavioral_data.R")
source("functions/load_eeg_trial_info.R")
source("functions/apply_eeg_exclusions.R")
source("functions/apply_rt_trimming.R")
source("functions/check_inclusion_criteria.R")
source("functions/generate_reports.R")

# === user input: define subject list ===
# slash-separated string of subject IDs to be processed in this run
# leave empty ("") to process all available subjects
# subjects_to_process = "390001/390002/390003/390004/390005/390006/390007/390008/390009/390010/390011/390012/390013/390014/390015/390020/390021/390022/390023/390024/390025/390026/390027/390028/390030/390031/390032/390033/390034/390036/390037/390038/390039/390041/390042/390043/390044";
subjects_to_process = "390035"

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

processing_params <- list(
  rt_lower_bound = RT_LOWER_BOUND,
  rt_outlier_threshold = RT_OUTLIER_THRESHOLD,
  min_accuracy = MIN_ACCURACY,
  min_trials_per_code = MIN_EPOCHS_PER_CODE
)

# === SAVE CSV OUTPUTS FOR MATLAB ===
cat("\n=== SAVING CSV OUTPUTS FOR MATLAB ===\n")

# 1. save behavioral summary as CSV for MATLAB
behavioral_summary_csv <- inclusion_summary %>%
  select(
    subject,
    included,
    exclusion_reason,
    accuracy,
    total_trials,
    n_code_102, n_code_104, n_code_111, n_code_112, n_code_113,
    n_code_202, n_code_204, n_code_211, n_code_212, n_code_213
  ) %>%
  mutate(
    included = as.numeric(included),  # convert TRUE/FALSE to 1/0
    exclusion_reason = replace_na(exclusion_reason, "none")
  )

behavioral_summary_file <- file.path(output_dir, "behavioral_summary.csv")
write_csv(behavioral_summary_csv, behavioral_summary_file)
cat("saved behavioral summary csv to:", behavioral_summary_file, "\n")

# 2. save trial-level data as CSV for MATLAB (if needed for future analyses)
behavioral_trials_csv <- behavioral_with_rt %>%
  select(
    subject,
    trial_idx,
    code,
    rt = flankerResponse.rt, 
    accuracy = responseType,
    in_eeg,
    eeg_analysis_ready,
    eeg_exclusion_reason,
    rt_exclusion_reason
  ) %>%
  mutate(
    in_eeg = as.numeric(in_eeg),
    eeg_analysis_ready = as.numeric(eeg_analysis_ready),
    accuracy = as.numeric(accuracy),
    eeg_exclusion_reason = replace_na(eeg_exclusion_reason, "none"),
    rt_exclusion_reason = replace_na(rt_exclusion_reason, "none")
  )

behavioral_trials_file <- file.path(output_dir, "behavioral_trials.csv")
write_csv(behavioral_trials_csv, behavioral_trials_file)
cat("saved trial-level data csv to:", behavioral_trials_file, "\n")

# 3. save processing metadata as JSON for documentation
metadata <- list(
  processing_date = Sys.time(),
  parameters = processing_params,
  n_subjects_processed = n_distinct(behavioral_data$subject),
  n_subjects_included = sum(inclusion_summary$included),
  n_subjects_excluded = sum(!inclusion_summary$included),
  output_files = list(
    behavioral_summary = "behavioral_summary.csv",
    behavioral_trials = "behavioral_trials.csv",
    subject_summary_table = paste0("subject_summary_table_", format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".txt")
  )
)

metadata_file <- file.path(output_dir, "processing_metadata.json")
jsonlite::write_json(metadata, metadata_file, pretty = TRUE)
cat("saved processing metadata to:", metadata_file, "\n")

# generate reports
cat("\n=== GENERATING REPORTS ===\n")

# generate reports
cat("\n=== GENERATING REPORTS ===\n")

# generate both summary tables
behavioral_table <- generate_behavioral_summary_table(
  behavioral_with_rt,
  inclusion_summary,
  output_dir,
  verbose = TRUE
)

erp_table <- generate_erp_summary_table(
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

summary_report <- generate_postprocessing_summary(
  behavioral_with_rt,
  inclusion_summary,
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