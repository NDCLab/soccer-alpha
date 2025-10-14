# prepare_data.r - data transformation functions
# author: marlene buch

library(tidyverse)

apply_transformations <- function(data, verbose = TRUE) {
  # apply preregistered transformations to data
  #
  # inputs:
  #   data - tibble with behavioral data
  #   verbose - print transformation info
  #
  # outputs:
  #   tibble with added transformed columns:
  #     - rt_log: log-transformed reaction time
  #     - (proportions get transformed in separate functions per analysis)
  
  if (verbose) cat("\napplying data transformations...\n")
  
  # ensure rt is numeric & rename for convenience
  data <- data %>%
    mutate(rt = as.numeric(flankerResponse.rt))
  
  # log-transform reaction times (preregistered)
  if (TRANSFORM_RT) {
    data <- data %>%
      mutate(rt_log = log(rt))
    
    if (verbose) cat("  ✓ log-transformed reaction times\n")
  }
  
  return(data)
}

arcsine_transform <- function(proportion) {
  # arcsine transformation for proportions (preregistered)
  # uses arcsine square root transformation: asin(sqrt(p))
  #
  # inputs:
  #   proportion - numeric vector of proportions (0 to 1)
  #
  # outputs:
  #   transformed values
  
  if (any(proportion < 0 | proportion > 1, na.rm = TRUE)) {
    warning("some values are outside [0,1] range for arcsine transformation")
  }
  
  return(asin(sqrt(proportion)))
}

prepare_error_rate_data <- function(data, verbose = TRUE) {
  # calculate error rates per subject & condition
  #
  # inputs:
  #   data - tibble with trial-level behavioral data
  #   verbose - print summary info
  #
  # outputs:
  #   tibble with error rates per subject/condition (wide format)
  #   note: error rates are percentages (0-100), not proportions (0-1)
  
  if (verbose) cat("\ncalculating error rates...\n")
  
  # define correct vs error codes for visible condition
  # correct: 111 (social), 211 (nonsocial)
  # errors: 112, 113 (social), 212, 213 (nonsocial)
  
  # visible condition: overall error rate (as percentage)
  visible_errors <- data %>%
    filter(code %in% c(111, 112, 113, 211, 212, 213)) %>%
    mutate(
      social = ifelse(code %in% c(111, 112, 113), "social", "nonsocial"),
      is_error = code %in% c(112, 113, 212, 213)
    ) %>%
    group_by(subject, social) %>%
    summarise(
      n_trials = n(),
      n_errors = sum(is_error),
      error_rate = (n_errors / n_trials) * 100,  # convert to percentage
      .groups = "drop"
    ) %>%
    mutate(error_rate_arcsin = arcsine_transform(error_rate / 100))  # transform proportion, not percentage
  
  # visible condition: proportion flanker errors (out of all errors, as percentage)
  flanker_prop <- data %>%
    filter(code %in% c(112, 113, 212, 213)) %>%
    mutate(
      social = ifelse(code %in% c(112, 113), "social", "nonsocial"),
      is_flanker = code %in% c(112, 212)
    ) %>%
    group_by(subject, social) %>%
    summarise(
      n_errors = n(),
      n_flanker = sum(is_flanker),
      prop_flanker = (n_flanker / n_errors) * 100,  # as percentage
      .groups = "drop"
    ) %>%
    mutate(prop_flanker_arcsin = arcsine_transform(prop_flanker / 100))
  
  # invisible condition: proportion flanker errors (as percentage)
  invisible_flanker <- data %>%
    filter(code %in% c(102, 104, 202, 204)) %>%
    mutate(
      social = ifelse(code %in% c(102, 104), "social", "nonsocial"),
      is_flanker = code %in% c(102, 202)
    ) %>%
    group_by(subject, social) %>%
    summarise(
      n_trials = n(),
      n_flanker = sum(is_flanker),
      prop_flanker_invis = (n_flanker / n_trials) * 100,  # as percentage
      .groups = "drop"
    ) %>%
    mutate(prop_flanker_invis_arcsin = arcsine_transform(prop_flanker_invis / 100))
  
  # combine all error rate measures
  error_data <- visible_errors %>%
    left_join(flanker_prop %>% select(subject, social, prop_flanker, prop_flanker_arcsin),
              by = c("subject", "social")) %>%
    left_join(invisible_flanker %>% select(subject, social, prop_flanker_invis, prop_flanker_invis_arcsin),
              by = c("subject", "social"))
  
  if (verbose) {
    cat("  error rates calculated for", n_distinct(error_data$subject), "subjects\n")
    cat("  mean overall error rate (visible):", 
        round(mean(error_data$error_rate, na.rm = TRUE), 2), "%\n")
  }
  
  return(error_data)
}


prepare_rt_data <- function(data, verbose = TRUE) {
  # prepare response time data for anova analyses
  #
  # inputs:
  #   data - tibble with trial-level behavioral data
  #   verbose - print summary info
  #
  # outputs:
  #   tibble with trial-level rt data, ready for anova
  
  if (verbose) cat("\npreparing response time data...\n")
  
  # filter to trials with valid rt & no exclusions
  rt_data <- data %>%
    filter(
      !is.na(rt),
      !rt_excluded | is.na(rt_excluded),  # include trials without rt exclusion
      code %in% c(102, 104, 111, 112, 113, 202, 204, 211, 212, 213)
    ) %>%
    mutate(
      # determine social condition
      social = case_when(
        code %in% c(102, 104, 111, 112, 113) ~ "social",
        code %in% c(202, 204, 211, 212, 213) ~ "nonsocial"
      ),
      
      # determine visibility
      visibility = case_when(
        code %in% c(111, 112, 113, 211, 212, 213) ~ "visible",
        code %in% c(102, 104, 202, 204) ~ "invisible"
      ),
      
      # determine correctness (visible only)
      is_correct = code %in% c(111, 211),
      is_error = code %in% c(112, 113, 212, 213),
      
      # determine error type (visible errors only)
      is_flanker_error = code %in% c(112, 212),
      is_nonflanker_error = code %in% c(113, 213),
      
      # determine response type (invisible only)
      is_flanker_error_invis = code %in% c(102, 202),
      is_nonflanker_guess = code %in% c(104, 204),
      
      # factorize for anova
      subject = factor(subject),
      social = factor(social, levels = c("social", "nonsocial")),
      visibility = factor(visibility)
    )
  
  if (verbose) {
    cat("  rt data prepared for", n_distinct(rt_data$subject), "subjects\n")
    cat("  visible trials:", sum(rt_data$visibility == "visible"), "\n")
    cat("  invisible trials:", sum(rt_data$visibility == "invisible"), "\n")
    cat("  mean rt:", round(mean(rt_data$rt, na.rm = TRUE), 3), "s\n")
  }
  
  return(rt_data)
}


cat("✓ data preparation functions loaded\n")