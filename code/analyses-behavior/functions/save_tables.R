# save_tables.r - functions to export statistical results as tables
# author: marlene buch

library(tidyverse)
library(writexl)

save_descriptives_table <- function(descriptives, filename, save_dir) {
  # save descriptive statistics to CSV & Excel
  #
  # inputs:
  #   descriptives - tibble with descriptive stats
  #   filename - name for files (without extension)
  #   save_dir - directory to save to
  
  # remove extension if provided
  filename_base <- tools::file_path_sans_ext(filename)
  
  # save CSV
  csv_path <- file.path(save_dir, paste0(filename_base, ".csv"))
  write_csv(descriptives, csv_path)
  
  # save Excel
  xlsx_path <- file.path(save_dir, paste0(filename_base, ".xlsx"))
  write_xlsx(descriptives, xlsx_path)
  
  cat("   tables saved to:", filename_base, ".csv & .xlsx\n")
  
  return(invisible(list(csv = csv_path, xlsx = xlsx_path)))
}

save_ttest_results <- function(test_result, analysis_name, descriptives, save_dir) {
  # save t-test results to CSV & Excel
  #
  # inputs:
  #   test_result - output from t.test()
  #   analysis_name - descriptive name for the analysis
  #   descriptives - tibble with descriptive stats (optional)
  #   save_dir - directory to save to
  
  # calculate Cohen's d for paired t-test
  # d = t / sqrt(n), where n is the number of pairs
  n_pairs <- test_result$parameter + 1
  cohens_d <- as.numeric(test_result$statistic / sqrt(n_pairs))
  
  # create results table
  results_table <- tibble(
    analysis = analysis_name,
    test = "paired t-test",
    t_statistic = test_result$statistic,
    df = test_result$parameter,
    p_value = test_result$p.value,
    cohens_d = cohens_d,
    mean_difference = test_result$estimate,
    ci_lower = test_result$conf.int[1],
    ci_upper = test_result$conf.int[2],
    significant = p_value < 0.05
  )
  
  # if descriptives provided, add them
  if (!missing(descriptives)) {
    desc_wide <- descriptives %>%
      select(social, mean, sd) %>%
      pivot_wider(
        names_from = social,
        values_from = c(mean, sd),
        names_glue = "{social}_{.value}"
      )
    
    results_table <- bind_cols(results_table, desc_wide)
  }
  
  # save CSV
  filename_base <- paste0(analysis_name, "_ttest")
  csv_path <- file.path(save_dir, paste0(filename_base, ".csv"))
  write_csv(results_table, csv_path)
  
  # save Excel
  xlsx_path <- file.path(save_dir, paste0(filename_base, ".xlsx"))
  write_xlsx(results_table, xlsx_path)
  
  cat("   tables saved to:", filename_base, ".csv & .xlsx\n")
  
  return(invisible(list(csv = csv_path, xlsx = xlsx_path, cohens_d = cohens_d)))
}

save_anova_results <- function(anova_table, analysis_name, save_dir) {
  # save ANOVA results to CSV & Excel (for ezANOVA output)
  #
  # inputs:
  #   anova_table - ANOVA table from ezANOVA with partial_eta_sq column added
  #   analysis_name - descriptive name for the analysis
  #   save_dir - directory to save to
  
  # format table for export
  results_table <- anova_table %>%
    select(Effect, F, DFn, DFd, p, partial_eta_sq) %>%
    mutate(
      across(c(F, p, partial_eta_sq), ~round(., 4)),
      significant = p < 0.05
    ) %>%
    rename(
      effect = Effect,
      F_statistic = F,
      df_num = DFn,
      df_den = DFd,
      p_value = p,
      `partial_η²` = partial_eta_sq
    )
  
  # save CSV
  filename_base <- paste0(analysis_name, "_anova")
  csv_path <- file.path(save_dir, paste0(filename_base, ".csv"))
  write_csv(results_table, csv_path)
  
  # save Excel
  xlsx_path <- file.path(save_dir, paste0(filename_base, ".xlsx"))
  tryCatch({
    writexl::write_xlsx(results_table, xlsx_path)
  }, error = function(e) {
    warning("could not write xlsx file: ", xlsx_path, "\n  ", e$message)
  })
  
  cat("   tables saved to:", filename_base, ".csv & .xlsx\n")
  
  return(invisible(list(csv = csv_path, xlsx = xlsx_path, results = results_table)))
}

create_results_summary <- function(results_list, save_dir, filename = "all_results_summary.csv") {
  # combine all statistical results into one summary table
  #
  # inputs:
  #   results_list - list of result objects from analyses
  #   save_dir - directory to save to
  #   filename - output filename
  
  # extract key info from each result
  summary_rows <- map_df(results_list, function(result) {
    if (result$test == "paired_t_test") {
      tibble(
        analysis = result$analysis,
        test = result$test,
        statistic = result$t_statistic,
        df = result$df,
        p_value = result$p_value,
        significant = p_value < 0.05
      )
    }
    # will add ANOVA handling later
  })
  
  # save
  filepath <- file.path(save_dir, filename)
  write_csv(summary_rows, filepath)
  cat("\nall results summary saved to:", filename, "\n")
  
  return(invisible(filepath))
}

cat("✓ table saving functions loaded\n")