# settings.r - analysis parameters & settings
# author: marlene buch

# === statistical parameters ===
ALPHA <- 0.05  # significance level
BONFERRONI_CORRECTION <- TRUE  # apply bonferroni for multiple comparisons
GREENHOUSE_GEISSER_CORRECTION <- TRUE  # apply GG correction for sphericity violations

# === data transformations ===
# these match the preregistration
TRANSFORM_RT <- TRUE  # log-transform reaction times
TRANSFORM_ERROR_RATES <- TRUE  # arcsine-transform proportions/error rates

# === trial codes ===
# condition codes for analyses
CODES <- list(
  # visible condition
  social_vis_correct = 111,
  social_vis_flanker_error = 112,
  social_vis_nonflanker_error = 113,
  nonsocial_vis_correct = 211,
  nonsocial_vis_flanker_error = 212,
  nonsocial_vis_nonflanker_error = 213,
  
  # invisible condition
  social_invis_flanker_error = 102,
  social_invis_nonflanker_guess = 104,
  nonsocial_invis_flanker_error = 202,
  nonsocial_invis_nonflanker_guess = 204
)

# === condition labels for output ===
CONDITION_LABELS <- list(
  social = "Social",
  nonsocial = "Non-social",
  visible = "Visible",
  invisible = "Invisible",
  correct = "Correct",
  error = "Error",
  flanker_error = "Flanker Error",
  nonflanker_error = "Non-flanker Error",
  nonflanker_guess = "Non-flanker Guess"
)

# === output settings ===
SAVE_INTERMEDIATE_DATA <- TRUE  # save transformed data in derivatives
FIGURE_FORMAT <- c("png", "pdf")  # save figures in these formats
FIGURE_DPI <- 300  # resolution for raster figures
TABLE_FORMAT <- "csv"  # format for result tables

# === display settings ===
VERBOSE <- TRUE  # print progress messages
DECIMAL_PLACES <- 3  # decimal places for reported statistics

cat("\n=== ANALYSIS SETTINGS LOADED ===\n")
cat("alpha level:", ALPHA, "\n")
cat("transformations: RT =", TRANSFORM_RT, ", error rates =", TRANSFORM_ERROR_RATES, "\n")
cat("corrections: bonferroni =", BONFERRONI_CORRECTION, ", GG =", GREENHOUSE_GEISSER_CORRECTION, "\n\n")