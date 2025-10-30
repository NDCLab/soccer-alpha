# generate_reports.r - create human-readable summary tables & reports
# author: marlene buch

library(tidyverse)

# function 1: generate behavioral analysis summary table
generate_behavioral_summary_table <- function(behavioral_data, 
                                              inclusion_summary,
                                              output_dir,
                                              verbose = TRUE) {
  
  if (verbose) message("generating behavioral analysis summary table...")
  
  # calculate stats on ALL behavioral trials (not just EEG-ready)
  subject_stats <- behavioral_data %>%
    group_by(subject) %>%
    summarise(
      total_trials = n(),
      
      # count behavioral exclusions from original data
      multiple_key_n = sum(responseType == 7, na.rm = TRUE),
      too_slow_n = sum(responseType == 8, na.rm = TRUE),
      
      # accuracy on ALL visible trials
      n_visible_correct = sum(code %in% c(111, 211) & responseType == 1, na.rm = TRUE),
      n_visible_error = sum(code %in% c(112, 113, 212, 213), na.rm = TRUE),
      n_visible_total = n_visible_correct + n_visible_error,
      accuracy = n_visible_correct / n_visible_total,
      
      # trial counts per code (ALL behavioral trials)
      n_code_102 = sum(code == 102, na.rm = TRUE),
      n_code_104 = sum(code == 104, na.rm = TRUE),
      n_code_111 = sum(code == 111, na.rm = TRUE),
      n_code_112 = sum(code == 112, na.rm = TRUE),
      n_code_113 = sum(code == 113, na.rm = TRUE),
      n_code_202 = sum(code == 202, na.rm = TRUE),
      n_code_204 = sum(code == 204, na.rm = TRUE),
      n_code_211 = sum(code == 211, na.rm = TRUE),
      n_code_212 = sum(code == 212, na.rm = TRUE),
      n_code_213 = sum(code == 213, na.rm = TRUE),
      
      .groups = "drop"
    ) %>%
    mutate(
      # calculate percentages relative to total behavioral trials
      multiple_key_pct = (multiple_key_n / total_trials) * 100,
      too_slow_pct = (too_slow_n / total_trials) * 100,
      
      # sum columns
      sum_soc_vis_err = n_code_112 + n_code_113,
      sum_nonsoc_vis_err = n_code_212 + n_code_213
    )
  
  # merge with inclusion decisions
  summary_table <- inclusion_summary %>%
    select(subject, included, exclusion_reason) %>%
    left_join(subject_stats, by = "subject") %>%
    mutate(
      status = if_else(included, "included", "excluded"),
      exclusion_reason = if_else(is.na(exclusion_reason), "", exclusion_reason),
      accuracy_display = sprintf("%.1f%%", accuracy * 100)
    )
  
  # find lowest trial count
  summary_table <- summary_table %>%
    rowwise() %>%
    mutate(
      lowest_count = min(n_code_102, n_code_104, n_code_111, n_code_112, 
                         n_code_113, n_code_202, n_code_204, n_code_211, 
                         n_code_212, n_code_213)
    ) %>%
    ungroup()
  
  # write tab-separated file in MATLAB column order
  output_file <- file.path(output_dir, 
                           paste0("behavioral_summary_table_", 
                                  format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".txt"))
  
  # create formatted output
  output_data <- summary_table %>%
    select(
      ID = subject,
      Status = status,
      `Exclusion Reason` = exclusion_reason,
      `Overall Accuracy` = accuracy_display,
      `Total Behavioral Trials` = total_trials,
      `Multiple Key (n)` = multiple_key_n,
      `Multiple Key (%)` = multiple_key_pct,
      `Too Slow (n)` = too_slow_n,
      `Too Slow (%)` = too_slow_pct,
      `111 (soc-vis-corr)` = n_code_111,
      `112 (soc-vis-FE)` = n_code_112,
      `113 (soc-vis-NFE)` = n_code_113,
      `sum soc-vis-err` = sum_soc_vis_err,
      `102 (soc-invis-FE)` = n_code_102,
      `104 (soc-invis-NFG)` = n_code_104,
      `211 (nonsoc-vis-corr)` = n_code_211,
      `212 (nonsoc-vis-FE)` = n_code_212,
      `213 (nonsoc-vis-NFE)` = n_code_213,
      `sum nonsoc-vis-err` = sum_nonsoc_vis_err,
      `202 (nonsoc-invis-FE)` = n_code_202,
      `204 (nonsoc-invis-NFG)` = n_code_204,
      `Lowest Trial Count` = lowest_count
    ) %>%
    mutate(
      across(contains("(%)"), ~sprintf("%.2f", .))
    )
  
  write_delim(output_data, output_file, delim = "\t")
  
  if (verbose) message("  saved behavioral summary to: ", basename(output_file))
  
  return(output_data)
}

# function 2: generate erp analysis summary table
generate_erp_summary_table <- function(behavioral_data,
                                       inclusion_summary,
                                       output_dir,
                                       verbose = TRUE) {
  
  if (verbose) message("generating ERP analysis summary table...")
  
  # calculate stats for EEG-ready trials only
  subject_stats <- behavioral_data %>%
    group_by(subject) %>%
    summarise(
      total_beh_trials = n(),
      total_epochs = sum(in_eeg, na.rm = TRUE),
      
      # behavioral exclusions (for reference)
      too_slow_n_beh = sum(responseType == 8, na.rm = TRUE),
      
      # eeg exclusions
      multiple_key_n = sum(eeg_exclusion_reason == "multiple_keypresses", na.rm = TRUE),
      
      # rt exclusions (only on eeg_analysis_ready trials)
      rt_min_n = sum(eeg_analysis_ready & rt_exclusion_reason == "too_fast", na.rm = TRUE),
      rt_outliers_n = sum(eeg_analysis_ready & rt_exclusion_reason == "outlier", na.rm = TRUE),
      
      # accuracy on visible EEG trials only
      n_visible_correct_eeg = sum(code %in% c(111, 211) & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_visible_error_eeg = sum(code %in% c(112, 113, 212, 213) & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_visible_total_eeg = n_visible_correct_eeg + n_visible_error_eeg,
      accuracy_eeg = n_visible_correct_eeg / n_visible_total_eeg,
      
      # final trial counts (after all exclusions)
      n_code_102 = sum(code == 102 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_104 = sum(code == 104 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_111 = sum(code == 111 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_112 = sum(code == 112 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_113 = sum(code == 113 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_202 = sum(code == 202 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_204 = sum(code == 204 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_211 = sum(code == 211 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_212 = sum(code == 212 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      n_code_213 = sum(code == 213 & eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      
      .groups = "drop"
    ) %>%
    mutate(
      # calculate percentages relative to epochs
      too_slow_pct_beh = (too_slow_n_beh / total_beh_trials) * 100,
      multiple_key_pct = if_else(total_epochs > 0, (multiple_key_n / total_epochs) * 100, 0),
      rt_min_pct = if_else(total_epochs > 0, (rt_min_n / total_epochs) * 100, 0),
      rt_outliers_pct = if_else(total_epochs > 0, (rt_outliers_n / total_epochs) * 100, 0),
      
      # total usable
      total_usable = n_code_102 + n_code_104 + n_code_111 + n_code_112 + n_code_113 +
        n_code_202 + n_code_204 + n_code_211 + n_code_212 + n_code_213,
      
      # sum columns
      sum_soc_vis_err = n_code_112 + n_code_113,
      sum_nonsoc_vis_err = n_code_212 + n_code_213
    )
  
  # merge with inclusion
  summary_table <- inclusion_summary %>%
    select(subject, included, exclusion_reason) %>%
    left_join(subject_stats, by = "subject") %>%
    mutate(
      status = if_else(included, "included", "excluded"),
      exclusion_reason = if_else(is.na(exclusion_reason), "", exclusion_reason),
      accuracy_display = sprintf("%.1f%%", accuracy_eeg * 100)
    )
  
  # find lowest trial count
  summary_table <- summary_table %>%
    rowwise() %>%
    mutate(
      lowest_count = min(n_code_102, n_code_104, n_code_111, n_code_112, 
                         n_code_113, n_code_202, n_code_204, n_code_211, 
                         n_code_212, n_code_213)
    ) %>%
    ungroup()
  
  # write in MATLAB column order
  output_file <- file.path(output_dir, 
                           paste0("erp_summary_table_", 
                                  format(Sys.time(), "%Y-%m-%d_%H-%M-%S"), ".txt"))
  
  output_data <- summary_table %>%
    select(
      ID = subject,
      Status = status,
      `Exclusion Reason` = exclusion_reason,
      `Total Beh Trials` = total_beh_trials,
      `Too Slow (n)` = too_slow_n_beh,
      `Too Slow (%)` = too_slow_pct_beh,
      `Overall Accuracy` = accuracy_display,
      `Total Epochs Loaded` = total_epochs,
      `Multiple Key (n)` = multiple_key_n,
      `Multiple Key (%)` = multiple_key_pct,
      `RT Min Removed (n)` = rt_min_n,
      `RT Min Removed (%)` = rt_min_pct,
      `RT Outliers Removed (n)` = rt_outliers_n,
      `RT Outliers Removed (%)` = rt_outliers_pct,
      `Total Usable Epochs` = total_usable,
      `111 (soc-vis-corr)` = n_code_111,
      `112 (soc-vis-FE)` = n_code_112,
      `113 (soc-vis-NFE)` = n_code_113,
      `sum soc-vis-err` = sum_soc_vis_err,
      `102 (soc-invis-FE)` = n_code_102,
      `104 (soc-invis-NFG)` = n_code_104,
      `211 (nonsoc-vis-corr)` = n_code_211,
      `212 (nonsoc-vis-FE)` = n_code_212,
      `213 (nonsoc-vis-NFE)` = n_code_213,
      `sum nonsoc-vis-err` = sum_nonsoc_vis_err,
      `202 (nonsoc-invis-FE)` = n_code_202,
      `204 (nonsoc-invis-NFG)` = n_code_204,
      `Lowest Trial Count` = lowest_count
    ) %>%
    mutate(
      across(contains("(%)"), ~sprintf("%.2f", .))
    )
  
  write_delim(output_data, output_file, delim = "\t")
  
  if (verbose) message("  saved ERP summary to: ", basename(output_file))
  
  return(output_data)
}

# function 3: generate overall processing summary report
generate_postprocessing_summary <- function(behavioral_data,
                                            inclusion_summary,
                                            output_dir,
                                            processing_params = list(),
                                            verbose = TRUE) {
  # generate overall processing summary report
  #
  # inputs:
  #   behavioral_data - processed behavioral data
  #   inclusion_summary - subject-level decisions
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
  
  writeLines(paste("eeg exclusions:", f))
  writeLines(paste("  multiple keypresses:", n_multiple_key), f)
  writeLines(paste("  too slow:", n_too_slow), f)
  
  # rt exclusions
  rt_excluded <- behavioral_data %>%
    filter(eeg_analysis_ready) %>%
    summarise(
      rt_too_fast = sum(rt_exclusion_reason == "too_fast", na.rm = TRUE),
      rt_outliers = sum(rt_exclusion_reason == "outlier", na.rm = TRUE)
    )
  
  writeLines("", f)
  writeLines("rt exclusions (from eeg-ready trials):", f)
  writeLines(paste("  too fast (< ", processing_params$rt_lower_bound, "ms): ", 
                   rt_excluded$rt_too_fast, sep = ""), f)
  writeLines(paste("  outliers (> ", processing_params$rt_outlier_threshold, "sd): ", 
                   rt_excluded$rt_outliers, sep = ""), f)
  
  # per-subject statistics
  subject_stats <- behavioral_data %>%
    group_by(subject) %>%
    summarise(
      total = n(),
      in_eeg = sum(in_eeg, na.rm = TRUE),
      eeg_ready = sum(eeg_analysis_ready, na.rm = TRUE),
      rt_excluded = sum(rt_excluded, na.rm = TRUE),
      final_usable = sum(eeg_analysis_ready & !rt_excluded, na.rm = TRUE),
      .groups = "drop"
    )
  
  writeLines("", f)
  writeLines(sprintf("average trials per subject: %.1f ± %.1f", 
                     mean(subject_stats$total), sd(subject_stats$total)), f)
  writeLines(sprintf("average eeg epochs per subject: %.1f ± %.1f",
                     mean(subject_stats$in_eeg), sd(subject_stats$in_eeg)), f)
  writeLines(sprintf("average usable trials per subject: %.1f ± %.1f",
                     mean(subject_stats$final_usable), sd(subject_stats$final_usable)), f)
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
  
  # footer
  writeLines("=== END OF SUMMARY ===", f)
  
  close(f)
  
  if (verbose) message("  saved to: ", basename(output_file))
  
  return(output_file)
}