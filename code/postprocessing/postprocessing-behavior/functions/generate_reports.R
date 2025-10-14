# generate_reports.r - create human-readable summary tables & reports
# author: marlene buch

library(tidyverse)

generate_subject_summary_table <- function(behavioral_data, 
                                           inclusion_summary,
                                           output_dir,
                                           verbose = TRUE) {
  # generate per-subject summary table matching eeg postprocessing format
  #
  # inputs:
  #   behavioral_data - processed behavioral data with all flags
  #   inclusion_summary - subject-level inclusion decisions
  #   output_dir - where to save the table
  #   verbose - print progress
  #
  # outputs:
  #   writes tab-separated table to output_dir
  #   returns the summary table
  
  if (verbose) message("generating subject summary table...")
  
  # calculate per-subject statistics
  subject_stats <- behavioral_data %>%
    group_by(subject) %>%
    summarise(
      total_trials = n(),
      in_eeg = sum(in_eeg, na.rm = TRUE),
      eeg_ready = sum(eeg_analysis_ready, na.rm = TRUE),
      
      # eeg exclusions (codes ending in 7 or 8)
      multiple_key_n = sum(eeg_exclusion_reason == "multiple_keypresses", na.rm = TRUE),
      too_slow_n = sum(eeg_exclusion_reason == "too_slow", na.rm = TRUE),
      
      # rt exclusions (only calculated on eeg-ready trials)
      rt_min_n = sum(eeg_analysis_ready & rt_exclusion_reason == "too_fast", na.rm = TRUE),
      rt_outliers_n = sum(eeg_analysis_ready & rt_exclusion_reason == "outlier", na.rm = TRUE),
      
      .groups = "drop"
    ) %>%
    mutate(
      # calculate percentages relative to total trials
      multiple_key_pct_total = (multiple_key_n / total_trials) * 100,
      too_slow_pct_total = (too_slow_n / total_trials) * 100,
      rt_min_pct_total = (rt_min_n / total_trials) * 100,
      rt_outliers_pct_total = (rt_outliers_n / total_trials) * 100,
      
      # calculate percentages relative to eeg-ready trials
      multiple_key_pct_eeg = (multiple_key_n / eeg_ready) * 100,
      too_slow_pct_eeg = (too_slow_n / eeg_ready) * 100,
      rt_min_pct_eeg = (rt_min_n / eeg_ready) * 100,
      rt_outliers_pct_eeg = (rt_outliers_n / eeg_ready) * 100
    )
  
  # merge with inclusion decisions
  summary_table <- inclusion_summary %>%
    select(subject, included, exclusion_reason, accuracy,
           n_code_102, n_code_104, n_code_111, n_code_112, n_code_113,
           n_code_202, n_code_204, n_code_211, n_code_212, n_code_213) %>%
    left_join(subject_stats, by = "subject") %>%
    mutate(
      # calculate total usable
      usable_trials = n_code_102 + n_code_104 + n_code_111 + n_code_112 + n_code_113 +
        n_code_202 + n_code_204 + n_code_211 + n_code_212 + n_code_213,
      
      # format status & reason
      status = if_else(included, "included", "excluded"),
      exclusion_reason = if_else(is.na(exclusion_reason), "", exclusion_reason),
      
      # format accuracy as percentage
      accuracy = sprintf("%.1f%%", accuracy * 100)
    ) %>%
    select(
      ID = subject,
      `Dataset Status` = status,
      `Exclusion Reason` = exclusion_reason,
      `Overall Accuracy` = accuracy,
      `Total Trials` = total_trials,
      `In EEG` = in_eeg,
      `EEG Ready` = eeg_ready,
      `Multiple Key (n)` = multiple_key_n,
      `Multiple Key (% total)` = multiple_key_pct_total,
      `Multiple Key (% eeg)` = multiple_key_pct_eeg,
      `Too Slow (n)` = too_slow_n,
      `Too Slow (% total)` = too_slow_pct_total,
      `Too Slow (% eeg)` = too_slow_pct_eeg,
      `RT<150ms (n)` = rt_min_n,
      `RT<150ms (% total)` = rt_min_pct_total,
      `RT<150ms (% eeg)` = rt_min_pct_eeg,
      `RT Outliers (n)` = rt_outliers_n,
      `RT Outliers (% total)` = rt_outliers_pct_total,
      `RT Outliers (% eeg)` = rt_outliers_pct_eeg,
      `102` = n_code_102,
      `104` = n_code_104,
      `111` = n_code_111,
      `112` = n_code_112,
      `113` = n_code_113,
      `202` = n_code_202,
      `204` = n_code_204,
      `211` = n_code_211,
      `212` = n_code_212,
      `213` = n_code_213,
      `Usable Trials` = usable_trials
    ) %>%
    arrange(ID)
  
  # format percentages
  summary_table <- summary_table %>%
    mutate(
      across(contains("(%)"), ~sprintf("%.1f%%", .))
    )
  
  # save to file
  timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
  output_file <- file.path(output_dir, paste0("subject_summary_table_", timestamp, ".txt"))
  
  write_delim(summary_table, output_file, delim = "\t")
  
  if (verbose) message("  saved to: ", basename(output_file))
  
  return(summary_table)
}


generate_postprocessing_summary <- function(behavioral_data,
                                            inclusion_summary,
                                            validation_results,
                                            output_dir,
                                            processing_params = list(),
                                            verbose = TRUE) {
  # generate overall processing summary report
  #
  # inputs:
  #   behavioral_data - processed behavioral data
  #   inclusion_summary - subject-level decisions
  #   validation_results - validation against eeg
  #   output_dir - where to save
  #   processing_params - list with rt_lower_bound, rt_outlier_threshold, etc.
  #   verbose - print progress
  #
  # outputs:
  #   writes text report to output_dir
  
  if (verbose) message("generating postprocessing summary report...")
  
  # create output file
  timestamp <- format(Sys.time(), "%Y-%m-%d_%H-%M-%S")
  output_file <- file.path(output_dir, paste0("behavior_postprocessing_summary_", timestamp, ".txt"))
  
  # open file connection
  f <- file(output_file, "w")
  
  # header
  writeLines("=== BEHAVIORAL POSTPROCESSING SUMMARY ===", f)
  writeLines(paste("processing date:", Sys.time()), f)
  writeLines("", f)
  
  # processing parameters
  writeLines("=== PROCESSING PARAMETERS ===", f)
  if (!is.null(processing_params$rt_lower_bound)) {
    writeLines(paste("rt lower bound:", processing_params$rt_lower_bound, "ms"), f)
  }
  if (!is.null(processing_params$rt_outlier_threshold)) {
    writeLines(paste("rt outlier threshold:", processing_params$rt_outlier_threshold, "sd"), f)
  }
  if (!is.null(processing_params$min_accuracy)) {
    writeLines(paste("minimum accuracy:", processing_params$min_accuracy * 100, "%"), f)
  }
  if (!is.null(processing_params$min_trials_per_code)) {
    writeLines(paste("minimum trials per primary code:", processing_params$min_trials_per_code), f)
  }
  writeLines("", f)
  
  # overall statistics
  writeLines("=== OVERALL STATISTICS ===", f)
  writeLines(paste("total subjects:", n_distinct(behavioral_data$subject)), f)
  writeLines(paste("total behavioral trials:", nrow(behavioral_data)), f)
  writeLines(paste("trials in eeg epochs:", sum(behavioral_data$in_eeg, na.rm = TRUE)), f)
  writeLines(paste("trials eeg-analysis-ready:", sum(behavioral_data$eeg_analysis_ready, na.rm = TRUE)), f)
  writeLines("", f)
  
  # exclusion statistics
  writeLines("=== EXCLUSION STATISTICS ===", f)
  
  # eeg exclusions
  n_multiple_key <- sum(behavioral_data$eeg_exclusion_reason == "multiple_keypresses", na.rm = TRUE)
  n_too_slow <- sum(behavioral_data$eeg_exclusion_reason == "too_slow", na.rm = TRUE)
  n_eeg_rejected <- sum(behavioral_data$eeg_exclusion_reason == "rejected_during_eeg_preprocessing", na.rm = TRUE)
  
  writeLines(paste("trials with multiple keypresses (code X17):", n_multiple_key), f)
  writeLines(paste("trials too slow (code X18):", n_too_slow), f)
  writeLines(paste("trials rejected during eeg preprocessing:", n_eeg_rejected), f)
  writeLines("", f)
  
  # rt exclusions
  n_rt_min <- sum(behavioral_data$rt_exclusion_reason == "too_fast", na.rm = TRUE)
  n_rt_outliers <- sum(behavioral_data$rt_exclusion_reason == "outlier", na.rm = TRUE)
  n_eeg_ready <- sum(behavioral_data$eeg_analysis_ready, na.rm = TRUE)
  
  writeLines(paste("trials excluded rt < 150ms:", n_rt_min, 
                   sprintf("(%.1f%% of eeg-ready)", (n_rt_min/n_eeg_ready)*100)), f)
  writeLines(paste("trials excluded rt outliers:", n_rt_outliers,
                   sprintf("(%.1f%% of eeg-ready)", (n_rt_outliers/n_eeg_ready)*100)), f)
  writeLines("", f)
  
  # per-subject statistics (mean, sd)
  subject_stats <- behavioral_data %>%
    filter(eeg_analysis_ready) %>%
    group_by(subject) %>%
    summarise(
      rt_min_excluded = sum(rt_exclusion_reason == "too_fast", na.rm = TRUE),
      rt_outliers_excluded = sum(rt_exclusion_reason == "outlier", na.rm = TRUE),
      n_eeg_ready = n(),
      .groups = "drop"
    ) %>%
    mutate(
      rt_min_pct = (rt_min_excluded / n_eeg_ready) * 100,
      rt_outliers_pct = (rt_outliers_excluded / n_eeg_ready) * 100
    )
  
  writeLines("=== PER-SUBJECT EXCLUSION RATES (mean ± sd) ===", f)
  writeLines(sprintf("rt < 150ms: %.1f ± %.1f trials (%.2f ± %.2f%%)",
                     mean(subject_stats$rt_min_excluded),
                     sd(subject_stats$rt_min_excluded),
                     mean(subject_stats$rt_min_pct),
                     sd(subject_stats$rt_min_pct)), f)
  writeLines(sprintf("rt outliers: %.1f ± %.1f trials (%.2f ± %.2f%%)",
                     mean(subject_stats$rt_outliers_excluded),
                     sd(subject_stats$rt_outliers_excluded),
                     mean(subject_stats$rt_outliers_pct),
                     sd(subject_stats$rt_outliers_pct)), f)
  writeLines("", f)
  
  # subject-level inclusion
  writeLines("=== SUBJECT-LEVEL INCLUSION ===", f)
  writeLines(paste("subjects included:", sum(inclusion_summary$included)), f)
  writeLines(paste("subjects excluded:", sum(!inclusion_summary$included)), f)
  
  # breakdown by exclusion reason
  exclusion_counts <- inclusion_summary %>%
    filter(!included) %>%
    count(exclusion_reason)
  
  if (nrow(exclusion_counts) > 0) {
    writeLines("", f)
    writeLines("exclusion reasons:", f)
    for (i in 1:nrow(exclusion_counts)) {
      writeLines(paste("  -", exclusion_counts$exclusion_reason[i], ":", 
                       exclusion_counts$n[i], "subjects"), f)
    }
  }
  writeLines("", f)
  
  # validation results
  writeLines("=== VALIDATION AGAINST EEG POSTPROCESSING ===", f)
  writeLines(paste("validation status:", validation_results$status), f)
  writeLines(paste("subjects compared:", length(validation_results$common_subjects)), f)
  writeLines(paste("total discrepancies:", nrow(validation_results$discrepancies)), f)
  
  if (nrow(validation_results$discrepancies) > 0) {
    writeLines("", f)
    writeLines("discrepancies:", f)
    for (i in 1:nrow(validation_results$discrepancies)) {
      d <- validation_results$discrepancies[i,]
      writeLines(sprintf("  - subject %s, code %d: R=%d, MATLAB=%d (diff=%+d)",
                         d$subject, d$code, d$behavioral_count, d$eeg_count, d$difference), f)
    }
  }
  writeLines("", f)
  
  # footer
  writeLines("=== END OF SUMMARY ===", f)
  
  close(f)
  
  if (verbose) message("  saved to: ", basename(output_file))
  
  return(output_file)
}