# load_eeg_trial_info.r - extract trial-level info from preprocessed eeg .set files
# author: marlene buch

library(tidyverse)
library(R.matlab)

load_eeg_trial_info <- function(eeg_dir, subjects = NULL, verbose = TRUE) {
  # read preprocessed eeg .set files & extract which behavioral trials survived eeg preprocessing
  #
  # inputs:
  #   eeg_dir - path to preprocessed eeg folder (e.g., derivatives/preprocessed/s1_r1/eeg)
  #   subjects - optional vector of subject ids to load (e.g., c("390001", "390002"))
  #   verbose - print diagnostic info while loading
  #
  # outputs:
  #   tibble with columns:
  #     - subject: subject id
  #     - trial_idx: original behavioral trial number (from csv row)
  #     - beh_code: behavioral code for this trial
  #     - eeg_included: TRUE (all trials in output survived eeg preprocessing)
  #     - exclusion_reason: "none", "multiple_keypresses", or "too_slow"
  #     - analysis_ready: TRUE if trial is used in analyses (exclusion_reason == "none")
  
  if (verbose) message("loading eeg trial info from .set files...")
  if (verbose) message("  eeg directory: ", eeg_dir)
  
  subject_dirs <- list.dirs(eeg_dir, recursive = FALSE, full.names = TRUE)
  
  if (length(subject_dirs) == 0) {
    stop("no subject directories found in: ", eeg_dir)
  }
  
  if (!is.null(subjects)) {
    subject_pattern <- paste0("sub-", subjects, collapse = "|")
    subject_dirs <- subject_dirs[str_detect(basename(subject_dirs), subject_pattern)]
  }
  
  if (verbose) message("  found ", length(subject_dirs), " subject directories")
  
  all_trial_info <- map_dfr(subject_dirs, function(subject_dir) {
    subject_id <- str_extract(basename(subject_dir), "\\d+")
    if (verbose) message("  processing subject ", subject_id)
    
    set_files <- list.files(subject_dir, pattern = ".*_processed_data_.*\\.set$", full.names = TRUE)
    
    if (length(set_files) == 0) {
      warning("  no processed .set file found for subject ", subject_id)
      return(NULL)
    }
    
    if (length(set_files) > 1) {
      warning("  multiple .set files found for subject ", subject_id, ", using first")
    }
    
    tryCatch({
      eeg_data <- readMat(set_files[1])
      EEG <- eeg_data$EEG
      epochs <- EEG[,, 1]$epoch
      
      if (is.null(epochs) || length(epochs) == 0) {
        warning("  no epoch info found for subject ", subject_id)
        return(NULL)
      }
      
      n_epochs <- dim(epochs)[3]
      if (verbose) message("    found ", n_epochs, " epochs in .set file")
      
      trial_indices <- numeric(n_epochs)
      beh_codes <- numeric(n_epochs)
      
      epoch_fields <- dimnames(epochs)[[1]]
      beh_trial_nr_idx <- which(epoch_fields == "beh.trial.nr")
      beh_code_idx <- which(epoch_fields == "beh.code")
      
      if (length(beh_trial_nr_idx) == 0 || length(beh_code_idx) == 0) {
        warning("  cannot find required fields in epochs for subject ", subject_id)
        return(NULL)
      }
      
      for (i in 1:n_epochs) {
        trial_nr_value <- epochs[beh_trial_nr_idx, 1, i]
        if (is.list(trial_nr_value) && length(trial_nr_value) > 0) {
          trial_indices[i] <- as.numeric(trial_nr_value[[1]])
        } else if (is.numeric(trial_nr_value)) {
          trial_indices[i] <- trial_nr_value
        } else {
          trial_indices[i] <- NA
        }
        
        code_value <- epochs[beh_code_idx, 1, i]
        if (is.list(code_value) && length(code_value) > 0) {
          beh_codes[i] <- as.numeric(code_value[[1]])
        } else if (is.numeric(code_value)) {
          beh_codes[i] <- code_value
        } else {
          beh_codes[i] <- NA
        }
      }
      
      trial_info <- tibble(
        subject = subject_id,
        trial_idx = trial_indices,
        beh_code = beh_codes,
        eeg_included = TRUE
      ) %>%
        filter(!is.na(trial_idx) & !is.na(beh_code)) %>%
        mutate(
          exclusion_reason = case_when(
            beh_code %% 10 == 7 ~ "multiple_keypresses",
            beh_code %% 10 == 8 ~ "too_slow",
            TRUE ~ "none"
          ),
          analysis_ready = exclusion_reason == "none"
        )
      
      if (verbose) {
        n_total <- nrow(trial_info)
        n_analysis <- sum(trial_info$analysis_ready)
        n_multiple_key <- sum(trial_info$exclusion_reason == "multiple_keypresses")
        n_too_slow <- sum(trial_info$exclusion_reason == "too_slow")
        
        message("    loaded ", n_total, " epochs")
        message("      analysis-ready: ", n_analysis)
        message("      excluded (multiple key): ", n_multiple_key)
        message("      excluded (too slow): ", n_too_slow)
        message("    behavioral codes present: ", 
                paste(sort(unique(trial_info$beh_code)), collapse = ", "))
      }
      
      return(trial_info)
      
    }, error = function(e) {
      warning("  error reading .set file for subject ", subject_id, ": ", e$message)
      return(NULL)
    })
  })
  
  if (nrow(all_trial_info) == 0) {
    stop("no trial info loaded from any subjects")
  }
  
  if (verbose) {
    message("\n=== LOADING COMPLETE ===")
    message("  subjects loaded: ", n_distinct(all_trial_info$subject))
    message("  total eeg epochs: ", nrow(all_trial_info))
    message("  analysis-ready trials: ", sum(all_trial_info$analysis_ready))
    message("  excluded (multiple key): ", sum(all_trial_info$exclusion_reason == "multiple_keypresses"))
    message("  excluded (too slow): ", sum(all_trial_info$exclusion_reason == "too_slow"))
    message("  trials per subject (mean): ", round(nrow(all_trial_info) / n_distinct(all_trial_info$subject), 1))
  }
  
  return(all_trial_info)
}


# === TESTING FUNCTION ===

test_eeg_trial_loading <- function(eeg_dir, test_subject = NULL) {
  # test the eeg trial info loading with diagnostic output
  #
  # inputs:
  #   eeg_dir - path to preprocessed eeg folder
  #   test_subject - optional single subject id to test (e.g., "390002")
  
  cat("\n=== TESTING EEG TRIAL INFO LOADING ===\n\n")
  
  if (!is.null(test_subject)) {
    cat("TEST 1: loading single subject (", test_subject, ")\n")
    cat("-------------------------------------------\n")
    
    trial_info <- load_eeg_trial_info(eeg_dir, subjects = test_subject, verbose = TRUE)
    
    cat("\nRESULTS:\n")
    print(head(trial_info, 10))
    
    cat("\nEXCLUSION SUMMARY:\n")
    print(trial_info %>% count(exclusion_reason, analysis_ready))
    
    cat("\nEXCLUDED TRIALS BY CODE:\n")
    excluded_summary <- trial_info %>% 
      filter(!analysis_ready) %>% 
      count(beh_code, exclusion_reason)
    if (nrow(excluded_summary) > 0) {
      print(excluded_summary)
    } else {
      cat("  no excluded trials\n")
    }
    
    cat("\nVALIDATION CHECKS:\n")
    if (any(is.na(trial_info$trial_idx))) {
      cat("  ✗ WARNING: found", sum(is.na(trial_info$trial_idx)), "NA trial_idx values\n")
    } else {
      cat("  ✓ no NA trial_idx values\n")
    }
    
    if (any(duplicated(trial_info$trial_idx))) {
      cat("  ✗ WARNING: found duplicate trial_idx values\n")
    } else {
      cat("  ✓ no duplicate trial_idx values\n")
    }
    
    return(trial_info)
  }
  
  # test all subjects
  cat("TEST 2: loading all subjects\n")
  cat("-------------------------------------------\n")
  
  all_trial_info <- load_eeg_trial_info(eeg_dir, verbose = TRUE)
  
  cat("\nPER-SUBJECT SUMMARY:\n")
  subject_summary <- all_trial_info %>%
    group_by(subject) %>%
    summarise(
      n_total = n(),
      n_analysis_ready = sum(analysis_ready),
      n_multiple_key = sum(exclusion_reason == "multiple_keypresses"),
      n_too_slow = sum(exclusion_reason == "too_slow"),
      codes_present = paste(sort(unique(beh_code)), collapse = ",")
    ) %>%
    arrange(subject)
  
  print(subject_summary, n = 50)
  
  cat("\n=== OVERALL SUMMARY ===\n")
  cat("total subjects:", n_distinct(all_trial_info$subject), "\n")
  cat("total epochs:", nrow(all_trial_info), "\n")
  cat("analysis-ready trials:", sum(all_trial_info$analysis_ready), "\n")
  cat("excluded (multiple key):", sum(all_trial_info$exclusion_reason == "multiple_keypresses"), "\n")
  cat("excluded (too slow):", sum(all_trial_info$exclusion_reason == "too_slow"), "\n")
  
  return(all_trial_info)
}