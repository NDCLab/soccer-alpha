# apply_eeg_exclusions.r - mark which behavioral trials are included in eeg analyses
# author: marlene buch

library(tidyverse)

mark_eeg_inclusion <- function(behavioral_data, eeg_trial_info, verbose = TRUE) {
  # add eeg inclusion flags to behavioral data
  #
  # inputs:
  #   behavioral_data - tibble from load_behavioral_data()
  #   eeg_trial_info - tibble from load_eeg_trial_info()
  #   verbose - print diagnostic info
  #
  # outputs:
  #   behavioral data with added columns:
  #     - trial_idx: row number within subject (matches eeg trial_idx)
  #     - in_eeg: TRUE if trial survived eeg preprocessing & made it to epochs
  #     - eeg_analysis_ready: TRUE if trial is used in eeg analyses (not code ending in 7/8)
  #     - eeg_exclusion_reason: "none", "multiple_keypresses", "too_slow", or "rejected_during_eeg_preprocessing"
  
  if (verbose) message("marking eeg inclusion in behavioral data...")
  
  if (!("subject" %in% names(behavioral_data))) {
    stop("behavioral_data must have 'subject' column")
  }
  
  if (!("subject" %in% names(eeg_trial_info))) {
    stop("eeg_trial_info must have 'subject' column")
  }
  
  behavioral_with_idx <- behavioral_data %>%
    group_by(subject) %>%
    mutate(trial_idx = row_number()) %>%
    ungroup()
  
  if (verbose) {
    message("  behavioral data: ", nrow(behavioral_with_idx), " trials from ", 
            n_distinct(behavioral_with_idx$subject), " subjects")
    message("  eeg data: ", nrow(eeg_trial_info), " trials from ", 
            n_distinct(eeg_trial_info$subject), " subjects")
  }
  
  behavioral_with_eeg <- behavioral_with_idx %>%
    left_join(
      eeg_trial_info %>% 
        select(subject, trial_idx, eeg_included, exclusion_reason, analysis_ready),
      by = c("subject", "trial_idx")
    ) %>%
    mutate(
      in_eeg = !is.na(eeg_included),
      eeg_analysis_ready = coalesce(analysis_ready, FALSE),
      eeg_exclusion_reason = case_when(
        is.na(exclusion_reason) ~ "rejected_during_eeg_preprocessing",
        TRUE ~ exclusion_reason
      )
    ) %>%
    select(-eeg_included, -exclusion_reason, -analysis_ready)
  
  if (verbose) {
    n_in_eeg <- sum(behavioral_with_eeg$in_eeg)
    n_not_in_eeg <- sum(!behavioral_with_eeg$in_eeg)
    n_analysis_ready <- sum(behavioral_with_eeg$eeg_analysis_ready)
    n_multiple_key <- sum(behavioral_with_eeg$eeg_exclusion_reason == "multiple_keypresses")
    n_too_slow <- sum(behavioral_with_eeg$eeg_exclusion_reason == "too_slow")
    n_rejected_eeg <- sum(behavioral_with_eeg$eeg_exclusion_reason == "rejected_during_eeg_preprocessing")
    
    message("\n=== EEG INCLUSION SUMMARY ===")
    message("  trials in eeg epochs: ", n_in_eeg, " (", round(100 * n_in_eeg / nrow(behavioral_with_eeg), 1), "%)")
    message("  trials rejected during eeg preprocessing: ", n_rejected_eeg)
    message("  trials eeg-analysis-ready: ", n_analysis_ready)
    message("  trials excluded (multiple key): ", n_multiple_key)
    message("  trials excluded (too slow): ", n_too_slow)
  }
  
  return(behavioral_with_eeg)
}