# apply_rt_trimming.r - flag rt exclusions in behavioral data
# author: marlene buch

library(tidyverse)

apply_rt_trimming <- function(behavioral_data, 
                              rt_lower_bound = 150,
                              rt_outlier_threshold = 3,
                              verbose = TRUE) {
  # flag trials for rt exclusion without removing them
  #
  # inputs:
  #   behavioral_data - tibble with eeg inclusion flags already added
  #   rt_lower_bound - minimum rt in ms (default 150)
  #   rt_outlier_threshold - sd threshold for outliers (default 3)
  #   verbose - print diagnostic info
  #
  # outputs:
  #   behavioral data with added columns:
  #     - rt_excluded: TRUE if trial should be excluded based on rt
  #     - rt_exclusion_reason: "none", "too_fast", or "outlier"
  
  if (verbose) message("applying rt trimming criteria...")
  
  # check required columns exist
  required_cols <- c("subject", "code", "flankerResponse.rt", "eeg_analysis_ready")
  missing_cols <- setdiff(required_cols, names(behavioral_data))
  if (length(missing_cols) > 0) {
    stop("missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # convert rt from seconds to milliseconds
  data_with_rt_ms <- behavioral_data %>%
    mutate(rt_ms = flankerResponse.rt * 1000)
  
  # filter to only eeg-ready trials for rt calculations
  eeg_ready_trials <- data_with_rt_ms %>%
    filter(eeg_analysis_ready == TRUE)
  
  if (verbose) {
    message("  calculating rt statistics on ", nrow(eeg_ready_trials), " eeg-ready trials")
  }
  
  # flag trials that are too fast
  eeg_ready_with_flags <- eeg_ready_trials %>%
    mutate(
      too_fast = rt_ms < rt_lower_bound,
      rt_excluded = too_fast,
      rt_exclusion_reason = if_else(too_fast, "too_fast", "none")
    )
  
  # calculate per-subject per-code rt statistics (only on non-too-fast trials)
  rt_stats <- eeg_ready_with_flags %>%
    filter(!too_fast) %>%
    group_by(subject, code) %>%
    summarise(
      rt_mean = mean(rt_ms, na.rm = TRUE),
      rt_sd = sd(rt_ms, na.rm = TRUE),
      n_trials = n(),
      .groups = "drop"
    )
  
  # join stats back & flag outliers
  eeg_ready_with_outliers <- eeg_ready_with_flags %>%
    left_join(rt_stats, by = c("subject", "code")) %>%
    mutate(
      # only check for outliers if: not already flagged as too_fast & have valid stats
      is_outlier = if_else(
        !too_fast & !is.na(rt_sd) & n_trials > 1,
        abs(rt_ms - rt_mean) > (rt_outlier_threshold * rt_sd),
        FALSE
      ),
      # update exclusion flags
      rt_excluded = too_fast | is_outlier,
      rt_exclusion_reason = case_when(
        too_fast ~ "too_fast",
        is_outlier ~ "outlier",
        TRUE ~ "none"
      )
    ) %>%
    select(-rt_mean, -rt_sd, -n_trials, -too_fast, -is_outlier)
  
  # merge flags back into full dataset using trial_idx (the same unique identifier used in EEG preprocessing)
  result <- data_with_rt_ms %>%
    left_join(
      eeg_ready_with_outliers %>% 
        select(subject, trial_idx, rt_excluded, rt_exclusion_reason),
      by = c("subject", "trial_idx")
    ) %>%
    mutate(
      # trials not eeg_analysis_ready get NA for rt exclusion flags
      rt_excluded = if_else(eeg_analysis_ready, 
                            coalesce(rt_excluded, FALSE), 
                            NA),
      rt_exclusion_reason = if_else(eeg_analysis_ready,
                                    coalesce(rt_exclusion_reason, "none"),
                                    NA_character_)
    ) %>%
    select(-rt_ms)
  
  if (verbose) {
    n_too_fast <- sum(result$rt_exclusion_reason == "too_fast", na.rm = TRUE)
    n_outliers <- sum(result$rt_exclusion_reason == "outlier", na.rm = TRUE)
    n_rt_excluded <- sum(result$rt_excluded, na.rm = TRUE)
    
    message("  rt exclusions:")
    message("    too fast (< ", rt_lower_bound, "ms): ", n_too_fast)
    message("    outliers (> ", rt_outlier_threshold, "sd): ", n_outliers)
    message("    total rt excluded: ", n_rt_excluded)
  }
  
  return(result)
}