# check_inclusion_criteria.r - determine subject-level inclusion
# author: marlene buch

library(tidyverse)

check_inclusion_criteria <- function(behavioral_data,
                                     min_accuracy = 0.60,
                                     min_trials_per_code = 10,
                                     verbose = TRUE) {
  # check subject-level inclusion criteria
  #
  # inputs:
  #   behavioral_data - tibble with eeg & rt flags already added
  #   min_accuracy - minimum overall accuracy (default 0.60)
  #   min_trials_per_code - minimum trials per primary code (default 10)
  #   verbose - print diagnostic info
  #
  # outputs:
  #   tibble with one row per subject containing:
  #     - subject
  #     - total_trials
  #     - eeg_ready_trials
  #     - analysis_ready_trials (eeg_ready & !rt_excluded)
  #     - accuracy (on visible target trials)
  #     - n_code_XXX (trial counts per code)
  #     - meets_accuracy (TRUE/FALSE)
  #     - meets_trial_counts (TRUE/FALSE)
  #     - included (TRUE/FALSE)
  #     - exclusion_reason
  
  if (verbose) message("checking subject-level inclusion criteria...")
  
  # check required columns
  required_cols <- c("subject", "code", "responseType", "eeg_analysis_ready", "rt_excluded")
  missing_cols <- setdiff(required_cols, names(behavioral_data))
  if (length(missing_cols) > 0) {
    stop("missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # define visible target codes for accuracy calculation
  visible_target_codes <- c(111, 112, 113, 211, 212, 213)
  
  # define primary codes for trial count check
  primary_codes <- c(102, 104, 202, 204)
  
  # calculate per-subject statistics
  subject_stats <- behavioral_data %>%
    group_by(subject) %>%
    summarise(
      total_trials = n(),
      eeg_ready_trials = sum(eeg_analysis_ready, na.rm = TRUE),
      analysis_ready_trials = sum(eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      
      # accuracy: visible target trials that are correct (responseType == 1)
      # only count trials that are eeg_ready & not rt_excluded
      n_visible_target = sum(
        code %in% visible_target_codes & 
          eeg_analysis_ready & 
          !rt_excluded, 
        na.rm = TRUE
      ),
      n_visible_correct = sum(
        code %in% visible_target_codes & 
          eeg_analysis_ready & 
          !rt_excluded & 
          responseType == 1,
        na.rm = TRUE
      ),
      accuracy = if_else(n_visible_target > 0, 
                         n_visible_correct / n_visible_target, 
                         NA_real_),
      
      # trial counts per primary code
      n_code_102 = sum(code == 102 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_104 = sum(code == 104 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_202 = sum(code == 202 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_204 = sum(code == 204 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      
      # trial counts per secondary code (for reference)
      n_code_111 = sum(code == 111 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_112 = sum(code == 112 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_113 = sum(code == 113 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_211 = sum(code == 211 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_212 = sum(code == 212 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_213 = sum(code == 213 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      
      .groups = "drop"
    ) %>%
    mutate(
      # check inclusion criteria
      meets_accuracy = !is.na(accuracy) & accuracy >= min_accuracy,
      meets_trial_counts = (n_code_102 >= min_trials_per_code &
                              n_code_104 >= min_trials_per_code &
                              n_code_202 >= min_trials_per_code &
                              n_code_204 >= min_trials_per_code),
      
      # overall inclusion
      included = meets_accuracy & meets_trial_counts,
      
      # exclusion reason
      exclusion_reason = case_when(
        !meets_accuracy & !meets_trial_counts ~ "accuracy & insufficient trials",
        !meets_accuracy ~ "accuracy < 60%",
        !meets_trial_counts ~ "insufficient trials primary codes",
        TRUE ~ NA_character_
      )
    )
  
  if (verbose) {
    n_included <- sum(subject_stats$included)
    n_excluded_accuracy <- sum(!subject_stats$meets_accuracy)
    n_excluded_trials <- sum(!subject_stats$meets_trial_counts & subject_stats$meets_accuracy)
    
    message("  inclusion summary:")
    message("    total subjects: ", nrow(subject_stats))
    message("    included: ", n_included)
    message("    excluded (accuracy): ", n_excluded_accuracy)
    message("    excluded (trial counts): ", n_excluded_trials)
  }
  
  return(subject_stats)
}