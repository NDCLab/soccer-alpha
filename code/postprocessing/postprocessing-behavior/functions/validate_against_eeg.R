# validate_against_eeg.r - compare behavioral postprocessing to eeg postprocessing
# author: marlene buch

library(tidyverse)

load_eeg_summary_table <- function(eeg_date, derivatives_dir) {
  # load most recent eeg subject summary table from specified date
  #
  # inputs:
  #   eeg_date - date string (e.g., "2025-10-08")
  #   derivatives_dir - path to derivatives folder
  #
  # outputs:
  #   tibble with eeg summary data
  
  # construct path to eeg postprocessing folder for that date
  eeg_folder <- file.path(derivatives_dir, paste0(eeg_date, "_erp-postprocessing"))
  
  if (!dir.exists(eeg_folder)) {
    stop("eeg postprocessing folder not found: ", eeg_folder)
  }
  
  # find all subject_summary_table files in that folder
  table_files <- list.files(eeg_folder, 
                            pattern = "^subject_summary_table_.*\\.txt$",
                            full.names = TRUE)
  
  if (length(table_files) == 0) {
    stop("no subject_summary_table files found in: ", eeg_folder)
  }
  
  # extract timestamps from filenames to find most recent
  # pattern: subject_summary_table_YYYY-MM-DD_HH-MM-SS.txt
  timestamps <- str_extract(basename(table_files), "\\d{4}-\\d{2}-\\d{2}_\\d{2}-\\d{2}-\\d{2}")
  timestamps <- as.POSIXct(timestamps, format = "%Y-%m-%d_%H-%M-%S")
  
  # find most recent file
  most_recent_idx <- which.max(timestamps)
  most_recent_file <- table_files[most_recent_idx]
  
  message("loading eeg summary table:")
  message("  ", basename(most_recent_file))
  
  # read tab-separated file
  eeg_data <- read_delim(most_recent_file, delim = "\t", show_col_types = FALSE)
  
  message("  loaded ", nrow(eeg_data), " subjects from eeg postprocessing")
  
  return(eeg_data)
}

validate_trial_counts <- function(behavioral_inclusion, eeg_summary, verbose = TRUE) {
  # compare trial counts between behavioral & eeg postprocessing
  #
  # inputs:
  #   behavioral_inclusion - tibble from check_inclusion_criteria()
  #   eeg_summary - tibble from load_eeg_summary_table()
  #   verbose - print diagnostic info
  #
  # outputs:
  #   list with validation results & any discrepancies
  
  if (verbose) message("\nvalidating trial counts against eeg postprocessing...")
  
  # prepare eeg data for comparison
  eeg_clean <- eeg_summary %>%
    mutate(subject = as.character(ID)) %>%
    select(subject, Status, 
           code_102 = `102 (soc-invis-FE)`,
           code_104 = `104 (soc-invis-NFG)`,
           code_111 = `111 (soc-vis-corr)`,
           code_112 = `112 (soc-vis-FE)`,
           code_113 = `113 (soc-vis-NFE)`,
           code_202 = `202 (nonsoc-invis-FE)`,
           code_204 = `204 (nonsoc-invis-NFG)`,
           code_211 = `211 (nonsoc-vis-corr)`,
           code_212 = `212 (nonsoc-vis-FE)`,
           code_213 = `213 (nonsoc-vis-NFE)`)
  
  # prepare behavioral data for comparison
  beh_clean <- behavioral_inclusion %>%
    select(subject, included,
           code_102 = n_code_102, code_104 = n_code_104,
           code_111 = n_code_111, code_112 = n_code_112, code_113 = n_code_113,
           code_202 = n_code_202, code_204 = n_code_204,
           code_211 = n_code_211, code_212 = n_code_212, code_213 = n_code_213)
  
  # find common subjects
  common_subjects <- intersect(beh_clean$subject, eeg_clean$subject)
  
  if (verbose) message("  subjects in both datasets: ", length(common_subjects))
  
  # compare trial counts
  all_codes <- c(102, 104, 111, 112, 113, 202, 204, 211, 212, 213)
  discrepancies <- tibble()
  
  for (subj in common_subjects) {
    beh_row <- beh_clean %>% filter(subject == subj)
    eeg_row <- eeg_clean %>% filter(subject == subj)
    
    for (code in all_codes) {
      code_col <- paste0("code_", code)
      beh_count <- beh_row[[code_col]]
      eeg_count <- eeg_row[[code_col]]
      
      if (!is.na(beh_count) && !is.na(eeg_count) && beh_count != eeg_count) {
        discrepancies <- bind_rows(discrepancies, tibble(
          subject = subj,
          code = code,
          behavioral_count = beh_count,
          eeg_count = eeg_count,
          difference = beh_count - eeg_count
        ))
      }
    }
  }
  
  # summary
  if (nrow(discrepancies) == 0) {
    if (verbose) message("  ✓ all trial counts match between behavioral & eeg!")
    validation_status <- "PASS"
  } else {
    if (verbose) {
      message("  ✗ found ", nrow(discrepancies), " discrepancies:")
      print(discrepancies)
    }
    validation_status <- "FAIL"
  }
  
  return(list(
    status = validation_status,
    common_subjects = common_subjects,
    n_compared = length(common_subjects) * length(all_codes),
    n_discrepancies = nrow(discrepancies),
    discrepancies = discrepancies
  ))
}