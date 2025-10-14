# 03_confidence-ratings.r - error confidence rating analyses
# author: [your name]

# this script assumes it's sourced from batch_behavioral-analyses.r
# with data & directories already loaded

library(tidyverse)
library(ez)
library(effsize)

cat("\n=== CONFIDENCE RATING ANALYSES ===\n")
cat("started:", as.character(Sys.time()), "\n\n")

# create output directory for confidence analyses
confidence_dir <- file.path(session_dir, "confidence_ratings")
dir.create(confidence_dir, showWarnings = FALSE)

# === prepare confidence data ===
prepare_confidence_data <- function(data, condition_type, verbose = TRUE) {
  # prepare data for confidence analyses
  #
  # inputs:
  #   data - trial-level behavioral data
  #   condition_type - "visible_correctness", "visible_error_type", or "invisible_response_type"
  #   verbose - print info
  #
  # outputs:
  #   tibble ready for anova
  
  if (condition_type == "visible_correctness") {
    # visible: correct vs error × social vs nonsocial
    conf_data <- data %>%
      filter(
        code %in% c(111, 112, 113, 211, 212, 213),
        !is.na(confidenceRating)
      ) %>%
      mutate(
        subject = factor(subject),
        social = factor(ifelse(code %in% c(111, 112, 113), "social", "nonsocial")),
        correctness = factor(ifelse(code %in% c(111, 211), "correct", "error"))
      ) %>%
      select(subject, social, correctness, confidenceRating)
    
  } else if (condition_type == "visible_error_type") {
    # visible: flanker vs nonflanker error × social vs nonsocial (errors only)
    conf_data <- data %>%
      filter(
        code %in% c(112, 113, 212, 213),  # errors only
        !is.na(confidenceRating)
      ) %>%
      mutate(
        subject = factor(subject),
        social = factor(ifelse(code %in% c(112, 113), "social", "nonsocial")),
        error_type = factor(ifelse(code %in% c(112, 212), "flanker", "nonflanker"))
      ) %>%
      select(subject, social, error_type, confidenceRating)
    
  } else if (condition_type == "invisible_response_type") {
    # invisible: flanker error vs nonflanker guess × social vs nonsocial
    conf_data <- data %>%
      filter(
        code %in% c(102, 104, 202, 204),
        !is.na(confidenceRating)
      ) %>%
      mutate(
        subject = factor(subject),
        social = factor(ifelse(code %in% c(102, 104), "social", "nonsocial")),
        response_type = factor(ifelse(code %in% c(102, 202), "flanker_error", "nonflanker_guess"))
      ) %>%
      select(subject, social, response_type, confidenceRating)
  }
  
  if (verbose) {
    cat("  prepared", nrow(conf_data), "trials for", condition_type, "\n")
  }
  
  return(conf_data)
}

# === run confidence analyses ===

# 1. visible: correctness × social
if (CONFIDENCE_ANALYSES$visible_correctness) {
  cat("\n1. visible condition: correctness × social\n")
  cat("   2×2 anova: correct/error × social/nonsocial\n")
  
  # prepare data
  conf_correctness <- prepare_confidence_data(transformed_data, "visible_correctness")
  
  # calculate descriptives
  descriptives_correctness <- conf_correctness %>%
    group_by(social, correctness) %>%
    summarise(
      n = n(),
      mean = mean(confidenceRating, na.rm = TRUE),
      sd = sd(confidenceRating, na.rm = TRUE),
      se = sd / sqrt(n),
      .groups = "drop"
    )
  
  cat("\n   descriptive statistics:\n")
  print(descriptives_correctness)
  
  # run 2×2 repeated measures anova
  anova_correctness <- ezANOVA(
    data = conf_correctness,
    dv = confidenceRating,
    wid = subject,
    within = .(social, correctness),
    detailed = TRUE,
    type = 3
  )
  
  cat("\n   anova results:\n")
  print(anova_correctness$ANOVA)
  
  # extract ANOVA table & calculate partial eta squared
  anova_table_correctness <- anova_correctness$ANOVA %>%
    mutate(
      partial_eta_sq = SSn / (SSn + SSd)
    )
  
  # save results
  results_correctness <- list(
    descriptives = descriptives_correctness,
    anova = anova_correctness,
    anova_table = anova_table_correctness,
    data = conf_correctness
  )
  saveRDS(results_correctness, file.path(confidence_dir, "visible_correctness.rds"))
  
  # save tables to tables directory
  save_descriptives_table(descriptives_correctness, "confidence_visible_correctness_descriptives", tables_dir)
  save_anova_results(anova_table_correctness, "confidence_visible_correctness", tables_dir)
  
  # create plot
  plot_path <- file.path(confidence_dir, "confidence_visible_correctness.png")
  plot_confidence_interaction(conf_correctness %>%
                                mutate(is_error = correctness == "error"),
                              plot_type = "correctness",
                              save_path = plot_path)
}

# 2. visible: error type × social (errors only)
if (CONFIDENCE_ANALYSES$visible_error_type) {
  cat("\n2. visible condition: error type × social (errors only)\n")
  cat("   2×2 anova: flanker/nonflanker × social/nonsocial\n")
  
  # prepare data
  conf_error_type <- prepare_confidence_data(transformed_data, "visible_error_type")
  
  # check sample sizes per cell
  cell_counts <- conf_error_type %>%
    group_by(subject, social, error_type) %>%
    summarise(n_trials = n(), .groups = "drop") %>%
    group_by(social, error_type) %>%
    summarise(n_subjects = n(), .groups = "drop")
  
  cat("\n   subjects per cell:\n")
  print(cell_counts)
  
  # only run if sufficient data
  if (all(cell_counts$n_subjects >= 10)) {
    # calculate descriptives
    descriptives_error_type <- conf_error_type %>%
      group_by(social, error_type) %>%
      summarise(
        n = n(),
        mean = mean(confidenceRating, na.rm = TRUE),
        sd = sd(confidenceRating, na.rm = TRUE),
        se = sd / sqrt(n),
        .groups = "drop"
      )
    
    cat("\n   descriptive statistics:\n")
    print(descriptives_error_type)
    
    # run 2×2 repeated measures anova
    anova_error_type <- ezANOVA(
      data = conf_error_type,
      dv = confidenceRating,
      wid = subject,
      within = .(social, error_type),
      detailed = TRUE,
      type = 3
    )
    
    cat("\n   anova results:\n")
    print(anova_error_type$ANOVA)
    
    # extract ANOVA table & calculate partial eta squared
    anova_table_error_type <- anova_error_type$ANOVA %>%
      mutate(
        partial_eta_sq = SSn / (SSn + SSd)
      )
    
    # save results
    results_error_type <- list(
      descriptives = descriptives_error_type,
      anova = anova_error_type,
      anova_table = anova_table_error_type,
      data = conf_error_type
    )
    saveRDS(results_error_type, file.path(confidence_dir, "visible_error_type.rds"))
    
    # save tables to tables directory
    save_descriptives_table(descriptives_error_type, "confidence_visible_error_type_descriptives", tables_dir)
    save_anova_results(anova_table_error_type, "confidence_visible_error_type", tables_dir)
    
    # create plot
    plot_path <- file.path(confidence_dir, "confidence_visible_error_type.png")
    plot_confidence_interaction(conf_error_type %>%
                                  mutate(is_flanker = error_type == "flanker"),
                                plot_type = "error_type",
                                save_path = plot_path)
    
  } else {
    cat("\n   insufficient data for error type analysis\n")
  }
}

# 3. invisible: response type × social
if (CONFIDENCE_ANALYSES$invisible_response_type) {
  cat("\n3. invisible condition: response type × social\n")
  cat("   2×2 anova: flanker error/nonflanker guess × social/nonsocial\n")
  
  # prepare data
  conf_response_type <- prepare_confidence_data(transformed_data, "invisible_response_type")
  
  # calculate descriptives
  descriptives_response_type <- conf_response_type %>%
    group_by(social, response_type) %>%
    summarise(
      n = n(),
      mean = mean(confidenceRating, na.rm = TRUE),
      sd = sd(confidenceRating, na.rm = TRUE),
      se = sd / sqrt(n),
      .groups = "drop"
    )
  
  cat("\n   descriptive statistics:\n")
  print(descriptives_response_type)
  
  # run 2×2 repeated measures anova
  anova_response_type <- ezANOVA(
    data = conf_response_type,
    dv = confidenceRating,
    wid = subject,
    within = .(social, response_type),
    detailed = TRUE,
    type = 3
  )
  
  cat("\n   anova results:\n")
  print(anova_response_type$ANOVA)
  
  # extract ANOVA table & calculate partial eta squared
  anova_table_response_type <- anova_response_type$ANOVA %>%
    mutate(
      partial_eta_sq = SSn / (SSn + SSd)
    )
  
  # save results
  results_response_type <- list(
    descriptives = descriptives_response_type,
    anova = anova_response_type,
    anova_table = anova_table_response_type,
    data = conf_response_type
  )
  saveRDS(results_response_type, file.path(confidence_dir, "invisible_response_type.rds"))
  
  # save tables to tables directory
  save_descriptives_table(descriptives_response_type, "confidence_invisible_response_type_descriptives", tables_dir)
  save_anova_results(anova_table_response_type, "confidence_invisible_response_type", tables_dir)
  
  # create plot
  plot_path <- file.path(confidence_dir, "confidence_invisible_response_type.png")
  plot_confidence_interaction(conf_response_type %>%
                                mutate(is_flanker_error = response_type == "flanker_error"),
                              plot_type = "response_type",
                              save_path = plot_path)
}

# === save summary table ===
cat("\n=== saving confidence rating summary tables ===\n")

# combine all descriptives for summary
all_descriptives <- list()

if (exists("descriptives_correctness")) {
  all_descriptives$visible_correctness <- descriptives_correctness %>%
    mutate(analysis = "Visible: Correctness")
}

if (exists("descriptives_error_type")) {
  all_descriptives$visible_error_type <- descriptives_error_type %>%
    mutate(analysis = "Visible: Error Type")
}

if (exists("descriptives_response_type")) {
  all_descriptives$invisible_response_type <- descriptives_response_type %>%
    mutate(analysis = "Invisible: Response Type")
}

if (length(all_descriptives) > 0) {
  summary_table <- bind_rows(all_descriptives) %>%
    mutate(across(c(mean, sd, se), ~round(., 3)))
  
  # save as csv
  write_csv(summary_table, file.path(tables_dir, "confidence_summary.csv"))
  cat("   summary table saved to confidence_summary.csv\n")
}

cat("\n=== confidence rating analyses complete ===\n")
cat("results saved to:", confidence_dir, "\n")