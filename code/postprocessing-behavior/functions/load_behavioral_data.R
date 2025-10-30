# load_behavioral_data.r - load cleaned behavioral csvs from preprocessing
# author: marlene buch

library(tidyverse)

load_behavioral_data <- function(behavioral_dir, subjects = NULL) {
  # load all cleaned behavioral csvs from soccer-dataset preprocessing
  #
  # inputs:
  #   behavioral_dir - path to preprocessed behavior folder
  #   subjects - optional vector of subject ids to load (e.g., c("390001", "390002"))
  #
  # outputs:
  #   tibble with all subjects' behavioral data
  
  message("loading behavioral data from: ", behavioral_dir)
  
  # find all subject directories
  subject_dirs <- list.dirs(behavioral_dir, recursive = FALSE, full.names = TRUE)
  
  if (length(subject_dirs) == 0) {
    stop("no subject directories found in: ", behavioral_dir)
  }
  
  # filter to requested subjects if specified
  if (!is.null(subjects)) {
    subject_pattern <- paste0("sub-", subjects, collapse = "|")
    subject_dirs <- subject_dirs[str_detect(basename(subject_dirs), subject_pattern)]
  }
  
  message("found ", length(subject_dirs), " subject directories")
  
  # load all csvs
  all_data <- map_dfr(subject_dirs, function(subject_dir) {
    # extract subject id
    subject_id <- str_extract(basename(subject_dir), "\\d+")
    
    # find csv file (should be exactly one per subject)
    csv_files <- list.files(subject_dir, pattern = "*_clean\\.csv$", full.names = TRUE)
    
    if (length(csv_files) == 0) {
      warning("no clean csv found for subject ", subject_id)
      return(NULL)
    }
    
    if (length(csv_files) > 1) {
      warning("multiple csvs found for subject ", subject_id, ", using first")
    }
    
    # read csv
    data <- read_csv(csv_files[1], show_col_types = FALSE) %>%
      mutate(subject = subject_id) %>%
      relocate(subject)
    
    return(data)
  })
  
  message("loaded data for ", n_distinct(all_data$subject), " subjects")
  message("total trials: ", nrow(all_data))
  
  return(all_data)
}

# helper function to get list of available subjects
get_available_subjects <- function(behavioral_dir) {
  subject_dirs <- list.dirs(behavioral_dir, recursive = FALSE, full.names = FALSE)
  subjects <- str_extract(subject_dirs, "\\d+")
  return(sort(subjects[!is.na(subjects)]))
}

# validate loaded data structure
validate_behavioral_data <- function(data) {
  # check required columns exist
  required_cols <- c(
    "subject", "code", "flankerResponse.rt", "flankerResponse.keys",
    "confidenceRating", "responseType", "visInvis", "block_condition",
    "target", "flanker", "correctKey", "flankerKey"
  )
  
  missing_cols <- setdiff(required_cols, names(data))
  
  if (length(missing_cols) > 0) {
    stop("missing required columns: ", paste(missing_cols, collapse = ", "))
  }
  
  # check for expected codes
  unexpected_codes <- setdiff(unique(data$code), ALL_CODES)
  if (length(unexpected_codes) > 0) {
    warning("unexpected behavioral codes found: ", paste(unexpected_codes, collapse = ", "))
  }
  
  message("behavioral data structure validated")
  return(invisible(TRUE))
}