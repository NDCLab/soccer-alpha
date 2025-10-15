# load_data.r - load processed behavioral data for analyses
# author: marlene buch

library(tidyverse)

load_analysis_data <- function(subjects_to_include = NULL, 
                               eeg_ready_only = FALSE,
                               verbose = TRUE) {
  # load processed behavioral data & filter to included subjects
  #
  # inputs:
  #   subjects_to_include - character vector of subject IDs to include
  #                        if NULL, uses all subjects marked as included
  #   eeg_ready_only - if TRUE, only include trials marked as eeg_analysis_ready
  #                    if FALSE, include all behavioral trials (default for behavioral analyses)
  #   verbose - print loading info
  #
  # outputs:
  #   list containing:
  #     - data: tibble with behavioral data for included subjects
  #     - inclusion: tibble with inclusion summary
  #     - n_subjects: number of subjects included
  #     - subject_list: vector of included subject IDs
  
  if (verbose) cat("\n=== LOADING ANALYSIS DATA ===\n")
  
  # load processed behavioral data
  if (verbose) cat("loading behavioral data from:", basename(behavioral_data_file), "\n")
  behavioral_data <- readRDS(behavioral_data_file)
  
  # load inclusion summary
  if (verbose) cat("loading inclusion summary from:", basename(inclusion_summary_file), "\n")
  inclusion_summary <- readRDS(inclusion_summary_file)
  
  # filter to included subjects based on postprocessing criteria
  included_subjects <- inclusion_summary %>%
    filter(included == TRUE) %>%
    pull(subject)
  
  if (verbose) {
    cat("total subjects in dataset:", n_distinct(behavioral_data$subject), "\n")
    cat("subjects meeting inclusion criteria:", length(included_subjects), "\n")
  }
  
  # apply user-specified subject filter if provided
  if (!is.null(subjects_to_include)) {
    # check that requested subjects are in the included list
    not_included <- setdiff(subjects_to_include, included_subjects)
    
    if (length(not_included) > 0) {
      warning("the following subjects are not in the included list: ",
              paste(not_included, collapse = ", "))
    }
    
    # filter to requested subjects that are also included
    included_subjects <- intersect(subjects_to_include, included_subjects)
    
    if (verbose) {
      cat("user requested", length(subjects_to_include), "subjects\n")
      cat("final subjects to analyze:", length(included_subjects), "\n")
    }
  }
  
  # filter data to included subjects
  analysis_data <- behavioral_data %>%
    filter(subject %in% included_subjects)
  
  # optionally filter to eeg-ready trials only
  if (eeg_ready_only) {
    analysis_data <- analysis_data %>%
      filter(eeg_analysis_ready == TRUE)
    
    if (verbose) cat("filtered to eeg-analysis-ready trials only\n")
  } else {
    if (verbose) cat("using all behavioral trials (not filtered to eeg-ready)\n")
  }
  
  if (verbose) {
    cat("total trials after filtering:", nrow(analysis_data), "\n")
    cat("trials per subject (mean):", 
        round(nrow(analysis_data) / length(included_subjects), 1), "\n")
  }
  
  # return list with data & metadata
  result <- list(
    data = analysis_data,
    inclusion = inclusion_summary %>% filter(subject %in% included_subjects),
    n_subjects = length(included_subjects),
    subject_list = included_subjects
  )
  
  if (verbose) cat("\n✓ data loaded successfully\n\n")
  
  return(result)
}