# 02_response_times.r - response time analyses
# author: marlene buch
#
# this script runs all preregistered RT analyses:
# 1. visible condition: 2x2 ANOVA (correctness × social)
# 2. visible condition: 2x2 ANOVA (error type × social)
# 3. invisible condition: 2x2 ANOVA (response type × social)

library(tidyverse)
library(ez)  # for ezANOVA

cat("\n--- response time analyses ---\n")

# prepare RT data
rt_data <- prepare_rt_data(transformed_data, verbose = TRUE)

# create output directory
response_times_dir <- file.path(session_dir, "response_times")
dir.create(response_times_dir, showWarnings = FALSE)

# tables_dir comes from batch script
tables_dir <- results_tables_dir

# === analysis 1: correctness × social (visible condition) ===
if (RT_ANALYSES$visible_correctness) {
  cat("\n1. response time: correctness × social (visible)\n")
  
  # prepare data for ANOVA - visible trials only
  rt_correctness <- rt_data %>%
    filter(visibility == "visible") %>%
    mutate(
      correctness = factor(ifelse(is_correct, "correct", "error"),
                           levels = c("correct", "error"))
    )
  
  # step 1: aggregate to subject level & convert to ms
  subject_means <- rt_correctness %>%
    group_by(subject, social, correctness) %>%
    summarise(mean_rt = mean(rt, na.rm = TRUE) * 1000, .groups = "drop")
  
  # run repeated measures ANOVA on subject means
  anova_result <- ezANOVA(
    data = subject_means,
    dv = mean_rt,
    wid = subject,
    within = .(correctness, social),
    detailed = TRUE,
    type = 3, 
    return_aov = FALSE
  )
  
  # extract ANOVA table & calculate partial eta squared
  anova_table <- anova_result$ANOVA %>%
    mutate(
      partial_eta_sq = SSn / (SSn + SSd)
    )
  
  # step 2: calculate descriptives across subjects
  descriptives <- subject_means %>%
    group_by(social, correctness) %>%
    summarise(
      n = n(),
      mean = mean(mean_rt, na.rm = TRUE),
      sd = sd(mean_rt, na.rm = TRUE),
      se = sd / sqrt(n),
      .groups = "drop"
    )
  
  # print results
  cat("\n   descriptive statistics:\n")
  print(descriptives)
  cat("\n   repeated measures ANOVA results:\n")
  
  for (i in 1:nrow(anova_table)) {
    effect <- anova_table$Effect[i]
    f_val <- anova_table$F[i]
    df_num <- anova_table$DFn[i]
    df_den <- anova_table$DFd[i]
    p_val <- anova_table$p[i]
    eta_sq <- anova_table$partial_eta_sq[i]
    
    cat("   ", effect, ":\n")
    cat("      F(", df_num, ", ", df_den, ") = ", 
        round(f_val, 3), ", p = ", round(p_val, 4), "\n", sep = "")
    cat("      partial η² = ", round(eta_sq, 3), "\n", sep = "")
  }
  
  # generate plot (using subject means)
  plot_path <- file.path(results_figures_dir, "rt_correctness_visible.png")
  plot_rt_interaction(subject_means, "correctness", save_path = plot_path)
  
  # save tables
  save_descriptives_table(descriptives, "rt_correctness_visible_descriptives", tables_dir)
  save_anova_results(anova_table, "rt_correctness_visible", tables_dir)
  
  # save results
  results_1 <- list(
    analysis = "rt_correctness_visible",
    test = "repeated_measures_anova",
    descriptives = descriptives,
    anova_table = anova_table
  )
  
  saveRDS(results_1, file.path(response_times_dir, "rt_correctness_visible.rds"))
  cat("   ✓ results saved\n")
}

# === analysis 2: error type × social (visible condition) ===
if (RT_ANALYSES$visible_error_type) {
  cat("\n2. response time: error type × social (visible)\n")
  
  # prepare data - visible error trials only
  rt_error_type <- rt_data %>%
    filter(visibility == "visible", is_error) %>%
    mutate(
      error_type = factor(ifelse(is_flanker_error, "flanker", "nonflanker"),
                          levels = c("flanker", "nonflanker"))
    )
  
  # step 1: aggregate to subject level & convert to ms
  subject_means <- rt_error_type %>%
    group_by(subject, social, error_type) %>%
    summarise(mean_rt = mean(rt, na.rm = TRUE) * 1000, .groups = "drop")
  
  # run repeated measures ANOVA on subject means
  anova_result <- ezANOVA(
    data = subject_means,
    dv = mean_rt,
    wid = subject,
    within = .(error_type, social),
    detailed = TRUE,
    type = 3, 
    return_aov = FALSE
  )
  
  # extract ANOVA table & calculate partial eta squared
  anova_table <- anova_result$ANOVA %>%
    mutate(
      partial_eta_sq = SSn / (SSn + SSd)
    )
  
  # step 2: calculate descriptives across subjects
  descriptives <- subject_means %>%
    group_by(social, error_type) %>%
    summarise(
      n = n(),
      mean = mean(mean_rt, na.rm = TRUE),
      sd = sd(mean_rt, na.rm = TRUE),
      se = sd / sqrt(n),
      .groups = "drop"
    )
  
  # print results
  cat("\n   descriptive statistics:\n")
  print(descriptives)
  cat("\n   repeated measures ANOVA results:\n")
  
  for (i in 1:nrow(anova_table)) {
    effect <- anova_table$Effect[i]
    f_val <- anova_table$F[i]
    df_num <- anova_table$DFn[i]
    df_den <- anova_table$DFd[i]
    p_val <- anova_table$p[i]
    eta_sq <- anova_table$partial_eta_sq[i]
    
    cat("   ", effect, ":\n")
    cat("      F(", df_num, ", ", df_den, ") = ", 
        round(f_val, 3), ", p = ", round(p_val, 4), "\n", sep = "")
    cat("      partial η² = ", round(eta_sq, 3), "\n", sep = "")
  }
  
  # generate plot (using subject means)
  plot_path <- file.path(results_figures_dir, "rt_error_type_visible.png")
  plot_rt_interaction(subject_means, "error_type", save_path = plot_path)
  
  # save tables
  save_descriptives_table(descriptives, "rt_error_type_visible_descriptives", tables_dir)
  save_anova_results(anova_table, "rt_error_type_visible", tables_dir)
  
  # save results
  results_2 <- list(
    analysis = "rt_error_type_visible",
    test = "repeated_measures_anova",
    descriptives = descriptives,
    anova_table = anova_table
  )
  
  saveRDS(results_2, file.path(response_times_dir, "rt_error_type_visible.rds"))
  cat("   ✓ results saved\n")
}

# === analysis 3: response type × social (invisible condition) ===
if (RT_ANALYSES$invisible_response_type) {
  cat("\n3. response time: response type × social (invisible)\n")
  
  # prepare data - invisible trials only
  rt_response_type <- rt_data %>%
    filter(visibility == "invisible") %>%
    mutate(
      response_type = factor(ifelse(is_flanker_error_invis, "flanker_error", "nonflanker_guess"),
                             levels = c("flanker_error", "nonflanker_guess"))
    )
  
  # step 1: aggregate to subject level & convert to ms
  subject_means <- rt_response_type %>%
    group_by(subject, social, response_type) %>%
    summarise(mean_rt = mean(rt, na.rm = TRUE) * 1000, .groups = "drop")
  
  # run repeated measures ANOVA on subject means
  anova_result <- ezANOVA(
    data = subject_means,
    dv = mean_rt,
    wid = subject,
    within = .(response_type, social),
    detailed = TRUE,
    type = 3, 
    return_aov = FALSE
  )
  
  # extract ANOVA table & calculate partial eta squared
  anova_table <- anova_result$ANOVA %>%
    mutate(
      partial_eta_sq = SSn / (SSn + SSd)
    )
  
  # step 2: calculate descriptives across subjects
  descriptives <- subject_means %>%
    group_by(social, response_type) %>%
    summarise(
      n = n(),
      mean = mean(mean_rt, na.rm = TRUE),
      sd = sd(mean_rt, na.rm = TRUE),
      se = sd / sqrt(n),
      .groups = "drop"
    )
  
  # print results
  cat("\n   descriptive statistics:\n")
  print(descriptives)
  cat("\n   repeated measures ANOVA results:\n")
  
  for (i in 1:nrow(anova_table)) {
    effect <- anova_table$Effect[i]
    f_val <- anova_table$F[i]
    df_num <- anova_table$DFn[i]
    df_den <- anova_table$DFd[i]
    p_val <- anova_table$p[i]
    eta_sq <- anova_table$partial_eta_sq[i]
    
    cat("   ", effect, ":\n")
    cat("      F(", df_num, ", ", df_den, ") = ", 
        round(f_val, 3), ", p = ", round(p_val, 4), "\n", sep = "")
    cat("      partial η² = ", round(eta_sq, 3), "\n", sep = "")
  }
  
  # generate plot (using subject means)
  plot_path <- file.path(results_figures_dir, "rt_response_type_invisible.png")
  plot_rt_interaction(subject_means, "response_type", save_path = plot_path)
  
  # save tables
  save_descriptives_table(descriptives, "rt_response_type_invisible_descriptives", tables_dir)
  save_anova_results(anova_table, "rt_response_type_invisible", tables_dir)
  
  # save results
  results_3 <- list(
    analysis = "rt_response_type_invisible",
    test = "repeated_measures_anova",
    descriptives = descriptives,
    anova_table = anova_table
  )
  
  saveRDS(results_3, file.path(response_times_dir, "rt_response_type_invisible.rds"))
  cat("   ✓ results saved\n")
}

cat("\n--- response time analyses complete ---\n")