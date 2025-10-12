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

compare_behavioral_to_eeg <- function(behavioral_results, eeg_data) {
  # compare behavioral postprocessing results to eeg postprocessing
  # flag any discrepancies in trial counts
  #
  # inputs:
  #   behavioral_results - list from check_all_subjects()
  #   eeg_data - tibble from load_eeg_summary_table()
  #
  # outputs:
  #   comparison results with discrepancies flagged
  
  message("\nvalidating behavioral postprocessing against eeg postprocessing...")
  
  # extract behavioral stats into comparable format
  behavioral_summary <- map_dfr(names(behavioral_results), function(subj) {
    result <- behavioral_results[[subj]]
    
    # get counts for each code
    counts <- result$condition_counts %>%
      select(code, final_trials)
    
    # get exclusion counts from original data (need to pass this in separately)
    tibble(
      subject = subj,
      included = result$included_in_dataset,
      accuracy = result$overall_accuracy
    ) %>%
      bind_cols(
        counts %>% 
          pivot_wider(names_from = code, values_from = final_trials, names_prefix = "code_")
      )
  })
  
  # match subjects between behavioral & eeg
  eeg_clean <- eeg_data %>%
    mutate(subject = as.character(ID))
  
  common_subjects <- intersect(behavioral_summary$subject, eeg_clean$subject)
  
  message("  subjects in both datasets: ", length(common_subjects))
  
  if (length(common_subjects) == 0) {
    warning("no common subjects found between behavioral and eeg data")
    return(NULL)
  }
  
  # compare trial counts for common subjects
  discrepancies <- tibble()
  
  for (subj in common_subjects) {
    beh_row <- behavioral_summary %>% filter(subject == subj)
    eeg_row <- eeg_clean %>% filter(subject == subj)
    
    # compare each code
    for (code in ALL_CODES) {
      beh_col <- paste0("code_", code)
      eeg_col <- paste0(code, " (", ALL_CODE_NAMES[as.character(code)], ")")
      
      if (beh_col %in% names(beh_row) && eeg_col %in% names(eeg_row)) {
        beh_count <- beh_row[[beh_col]]
        eeg_count <- eeg_row[[eeg_col]]
        
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
  }
  
  if (nrow(discrepancies) == 0) {
    message("  ✓ all trial counts match between behavioral and eeg!")
  } else {
    warning(nrow(discrepancies), " discrepancies found:")
    print(discrepancies)
  }
  
  return(list(
    common_subjects = common_subjects,
    discrepancies = discrepancies,
    match_rate = 1 - (nrow(discrepancies) / (length(common_subjects) * length(ALL_CODES)))
  ))
}