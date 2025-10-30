# settings.r - postprocessing parameters matching matlab postprocessing
# CRITICAL: these must match batch_eeg_postprocessing.m exactly
# author: marlene buch

# === BEHAVIORAL CODES ===

# tier 1: primary hypothesis codes (all-or-nothing for dataset inclusion)
PRIMARY_CODES <- c(102, 104, 202, 204)
PRIMARY_CODE_NAMES <- c("social-invis-FE", "social-invis-NFG", 
                        "nonsoc-invis-FE", "nonsoc-invis-NFG")

# tier 2: secondary analysis codes (condition-specific inclusion)
SECONDARY_CODES <- c(111, 112, 113, 211, 212, 213)
SECONDARY_CODE_NAMES <- c("social-vis-corr", "social-vis-FE", "social-vis-NFE",
                          "nonsoc-vis-corr", "nonsoc-vis-FE", "nonsoc-vis-NFE")

# all codes combined
ALL_CODES <- c(PRIMARY_CODES, SECONDARY_CODES)
ALL_CODE_NAMES <- setNames(
  c(PRIMARY_CODE_NAMES, SECONDARY_CODE_NAMES),
  ALL_CODES
)

# === INCLUSION THRESHOLDS (MUST MATCH MATLAB) ===

# minimum trials per condition for inclusion
MIN_EPOCHS_PER_CODE <- 10

# minimum overall accuracy (calculated on visible target trials only)
MIN_ACCURACY <- 0.60

# === RT TRIMMING PARAMETERS (MUST MATCH MATLAB) ===

# rt lower bound (trials < 150ms excluded)
RT_LOWER_BOUND <- 150  # milliseconds

# rt outlier threshold (per condition)
RT_OUTLIER_THRESHOLD <- 3  # standard deviations

# === CONDITION GROUPINGS FOR ANALYSES ===

# visibility conditions
VISIBLE_CODES <- SECONDARY_CODES
INVISIBLE_CODES <- PRIMARY_CODES

# social conditions
SOCIAL_CODES <- c(111, 112, 113, 102, 104)
NONSOCIAL_CODES <- c(211, 212, 213, 202, 204)

# response types
CORRECT_CODES <- c(111, 211)
FLANKER_ERROR_CODES <- c(112, 212, 102, 202)
NONFLANKER_CODES <- c(113, 213, 104, 204)  # nfe in visible, nfg in invisible