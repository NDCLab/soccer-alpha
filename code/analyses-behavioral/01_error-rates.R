# 01_error_rates.r - error rate analyses
# author: marlene buch
#
# this script runs all preregistered error rate analyses:
# 1. visible condition: overall error rate (social vs nonsocial)
# 2. visible condition: proportion flanker errors (social vs nonsocial)
# 3. invisible condition: proportion flanker errors (social vs nonsocial)

library(tidyverse)

cat("\n--- error rate analyses ---\n")

# prepare error rate data
error_data <- prepare_error_rate_data(transformed_data, verbose = TRUE)

# tables_dir comes from batch script (results_tables_dir)
tables_dir <- results_tables_dir

# === analysis 1: overall error rate (visible condition) ===
if (ERROR_RATE_ANALYSES$overall_error_rate_visible) {
  cat("\n1. overall error rate (visible condition)\n")
  cat("   comparing social vs nonsocial conditions\n")
  
  # prepare data for t-test (wide format)
  error_rate_wide <- error_data %>%
    select(subject, social, error_rate_arcsin) %>%
    pivot_wider(names_from = social, 
                values_from = error_rate_arcsin,
                names_prefix = "error_rate_")
  
  # paired t-test on arcsine-transformed error rates
  t_test_result <- t.test(
    error_rate_wide$error_rate_social,
    error_rate_wide$error_rate_nonsocial,
    paired = TRUE,
    alternative = "two.sided"
  )
  
  # calculate cohen's d for paired t-test
  n_pairs <- t_test_result$parameter + 1
  cohens_d <- as.numeric(t_test_result$statistic / sqrt(n_pairs))
  
  # calculate descriptive statistics (using untransformed percentages)
  descriptives <- error_data %>%
    group_by(social) %>%
    summarise(
      n = n(),
      mean = mean(error_rate, na.rm = TRUE),
      sd = sd(error_rate, na.rm = TRUE),
      se = sd / sqrt(n),
      .groups = "drop"
    )
  
  # print results
  cat("\n   descriptive statistics:\n")
  print(descriptives)
  cat("\n   paired t-test results:\n")
  cat("   t(", t_test_result$parameter, ") = ", 
      round(t_test_result$statistic, 3), 
      ", p = ", round(t_test_result$p.value, 4), "\n", sep = "")
  cat("   cohen's d = ", round(cohens_d, 3), "\n", sep = "")
  cat("   mean difference = ", 
      round(t_test_result$estimate, 3), "\n", sep = "")
  
  # generate plot
  plot_path <- file.path(results_figures_dir, "error_rate_overall_visible.png")
  plot_error_rates(error_data, "overall", save_path = plot_path)
  
  # save tables
  save_descriptives_table(descriptives, "error_rate_overall_visible_descriptives.csv", tables_dir)
  save_ttest_results(t_test_result, "error_rate_overall_visible", descriptives, tables_dir)
  
  # save results
  results_1 <- list(
    analysis = "overall_error_rate_visible",
    test = "paired_t_test",
    descriptives = descriptives,
    t_statistic = t_test_result$statistic,
    df = t_test_result$parameter,
    p_value = t_test_result$p.value,
    cohens_d = cohens_d,
    mean_difference = t_test_result$estimate,
    confidence_interval = t_test_result$conf.int
  )
  
  saveRDS(results_1, file.path(error_rates_dir, "overall_error_rate_visible.rds"))
  cat("   ✓ results saved\n")
}

# === analysis 2: proportion flanker errors (visible condition) ===
if (ERROR_RATE_ANALYSES$proportion_flanker_visible) {
  cat("\n2. proportion flanker errors (visible condition)\n")
  cat("   comparing social vs nonsocial conditions\n")
  
  # prepare data for t-test (wide format)
  flanker_prop_wide <- error_data %>%
    select(subject, social, prop_flanker_arcsin) %>%
    pivot_wider(names_from = social, 
                values_from = prop_flanker_arcsin,
                names_prefix = "prop_flanker_")
  
  # paired t-test on arcsine-transformed proportions
  t_test_result <- t.test(
    flanker_prop_wide$prop_flanker_social,
    flanker_prop_wide$prop_flanker_nonsocial,
    paired = TRUE,
    alternative = "two.sided"
  )
  
  # calculate cohen's d
  n_pairs <- t_test_result$parameter + 1
  cohens_d <- as.numeric(t_test_result$statistic / sqrt(n_pairs))
  
  # descriptive statistics (using untransformed percentages)
  descriptives <- error_data %>%
    filter(!is.na(prop_flanker)) %>%
    group_by(social) %>%
    summarise(
      n = n(),
      mean = mean(prop_flanker, na.rm = TRUE),
      sd = sd(prop_flanker, na.rm = TRUE),
      se = sd / sqrt(n),
      .groups = "drop"
    )
  
  # print results
  cat("\n   descriptive statistics:\n")
  print(descriptives)
  cat("\n   paired t-test results:\n")
  cat("   t(", t_test_result$parameter, ") = ", 
      round(t_test_result$statistic, 3), 
      ", p = ", round(t_test_result$p.value, 4), "\n", sep = "")
  cat("   cohen's d = ", round(cohens_d, 3), "\n", sep = "")
  cat("   mean difference = ", 
      round(t_test_result$estimate, 3), "\n", sep = "")
  
  # generate plot
  plot_path <- file.path(results_figures_dir, "error_rate_flanker_visible.png")
  plot_error_rates(error_data, "flanker_visible", save_path = plot_path)
  
  # save tables
  save_descriptives_table(descriptives, "error_rate_flanker_visible_descriptives.csv", tables_dir)
  save_ttest_results(t_test_result, "error_rate_flanker_visible", descriptives, tables_dir)
  
  # save results
  results_2 <- list(
    analysis = "proportion_flanker_visible",
    test = "paired_t_test",
    descriptives = descriptives,
    t_statistic = t_test_result$statistic,
    df = t_test_result$parameter,
    p_value = t_test_result$p.value,
    cohens_d = cohens_d,
    mean_difference = t_test_result$estimate,
    confidence_interval = t_test_result$conf.int
  )
  
  saveRDS(results_2, file.path(error_rates_dir, "proportion_flanker_visible.rds"))
  cat("   ✓ results saved\n")
}

# === analysis 3: proportion flanker errors (invisible condition) ===
if (ERROR_RATE_ANALYSES$proportion_flanker_invisible) {
  cat("\n3. proportion flanker errors (invisible condition)\n")
  cat("   comparing social vs nonsocial conditions\n")
  
  # prepare data for t-test (wide format)
  flanker_invis_wide <- error_data %>%
    select(subject, social, prop_flanker_invis_arcsin) %>%
    pivot_wider(names_from = social, 
                values_from = prop_flanker_invis_arcsin,
                names_prefix = "prop_flanker_invis_")
  
  # paired t-test on arcsine-transformed proportions
  t_test_result <- t.test(
    flanker_invis_wide$prop_flanker_invis_social,
    flanker_invis_wide$prop_flanker_invis_nonsocial,
    paired = TRUE,
    alternative = "two.sided"
  )
  
  # calculate cohen's d
  n_pairs <- t_test_result$parameter + 1
  cohens_d <- as.numeric(t_test_result$statistic / sqrt(n_pairs))
  
  # descriptive statistics (using untransformed percentages)
  descriptives <- error_data %>%
    filter(!is.na(prop_flanker_invis)) %>%
    group_by(social) %>%
    summarise(
      n = n(),
      mean = mean(prop_flanker_invis, na.rm = TRUE),
      sd = sd(prop_flanker_invis, na.rm = TRUE),
      se = sd / sqrt(n),
      .groups = "drop"
    )
  
  # print results
  cat("\n   descriptive statistics:\n")
  print(descriptives)
  cat("\n   paired t-test results:\n")
  cat("   t(", t_test_result$parameter, ") = ", 
      round(t_test_result$statistic, 3), 
      ", p = ", round(t_test_result$p.value, 4), "\n", sep = "")
  cat("   cohen's d = ", round(cohens_d, 3), "\n", sep = "")
  cat("   mean difference = ", 
      round(t_test_result$estimate, 3), "\n", sep = "")
  
  # generate plot
  plot_path <- file.path(results_figures_dir, "error_rate_flanker_invisible.png")
  plot_error_rates(error_data, "flanker_invisible", save_path = plot_path)
  
  # save tables
  save_descriptives_table(descriptives, "error_rate_flanker_invisible_descriptives.csv", tables_dir)
  save_ttest_results(t_test_result, "error_rate_flanker_invisible", descriptives, tables_dir)
  
  # save results
  results_3 <- list(
    analysis = "proportion_flanker_invisible",
    test = "paired_t_test",
    descriptives = descriptives,
    t_statistic = t_test_result$statistic,
    df = t_test_result$parameter,
    p_value = t_test_result$p.value,
    cohens_d = cohens_d,
    mean_difference = t_test_result$estimate,
    confidence_interval = t_test_result$conf.int
  )
  
  saveRDS(results_3, file.path(error_rates_dir, "proportion_flanker_invisible.rds"))
  cat("   ✓ results saved\n")
}

cat("\n--- error rate analyses complete ---\n")