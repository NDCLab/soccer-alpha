# plot_confidence-ratings.r - plotting functions for confidence rating analyses
# author: marlene buch

library(tidyverse)
library(ggplot2)

# === theme & colors ===
theme_behavioral <- function() {
  theme_classic() +
    theme(
      text = element_text(size = 12, family = "sans"),
      axis.title = element_text(size = 13, face = "bold"),
      axis.text = element_text(size = 11, color = "black"),
      legend.title = element_text(size = 12, face = "bold"),
      legend.text = element_text(size = 11),
      legend.position = "right",
      strip.text = element_text(size = 12, face = "bold"),
      strip.background = element_rect(fill = "grey90", color = "black"),
      panel.grid.major.y = element_line(color = "grey90", linewidth = 0.3)
    )
}

COLORS_CONDITION <- c("correct" = "#009E73", "error" = "#D55E00", 
                      "flanker_error" = "#CC79A7", "nonflanker_error" = "#F0E442",
                      "nonflanker_guess" = "#0072B2")

# === confidence rating interaction plot ===
plot_confidence_interaction <- function(conf_data, plot_type, save_path = NULL) {
  # create interaction plot for confidence analyses
  #
  # inputs:
  #   conf_data - tibble with confidence data (long format)
  #   plot_type - "correctness", "error_type", or "response_type"
  #   save_path - if provided, save plot to this path
  
  # determine grouping & labels based on plot type
  if (plot_type == "correctness") {
    conf_data <- conf_data %>%
      mutate(condition = factor(ifelse(is_error, "Error", "Correct"),
                                levels = c("Correct", "Error")))
    x_var <- "social"
    color_var <- "condition"
    title <- "Confidence Rating: Correctness × Social Condition"
    colors <- c("Correct" = COLORS_CONDITION["correct"], 
                "Error" = COLORS_CONDITION["error"])
  } else if (plot_type == "error_type") {
    conf_data <- conf_data %>%
      filter(is_error) %>%
      mutate(error_type = factor(ifelse(is_flanker_error, "Flanker Error", "Non-flanker Error"),
                                 levels = c("Flanker Error", "Non-flanker Error")))
    x_var <- "social"
    color_var <- "error_type"
    title <- "Confidence Rating: Error Type × Social Condition"
    colors <- c("Flanker Error" = COLORS_CONDITION["flanker_error"],
                "Non-flanker Error" = COLORS_CONDITION["nonflanker_error"])
  } else if (plot_type == "response_type") {
    conf_data <- conf_data %>%
      mutate(response_type = factor(ifelse(is_flanker_error, "Flanker Error", "Non-flanker Guess"),
                                    levels = c("Flanker Error", "Non-flanker Guess")))
    x_var <- "social"
    color_var <- "response_type"
    title <- "Confidence Rating: Response Type × Social Condition (Invisible)"
    colors <- c("Flanker Error" = COLORS_CONDITION["flanker_error"],
                "Non-flanker Guess" = COLORS_CONDITION["nonflanker_guess"])
  }
  
  # calculate summary statistics
  plot_data <- conf_data %>%
    group_by(across(all_of(c(x_var, color_var)))) %>%
    summarise(
      mean = mean(confidenceRating, na.rm = TRUE),
      se = sd(confidenceRating, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    ) %>%
    mutate(social = factor(social, levels = c("social", "nonsocial")))
  
  # create plot
  p <- ggplot(plot_data, aes(x = .data[[x_var]], y = mean, 
                             color = .data[[color_var]], 
                             group = .data[[color_var]])) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = mean - se, ymax = mean + se), 
                  width = 0.1, linewidth = 0.8) +
    scale_color_manual(values = colors, name = "") +
    scale_x_discrete(labels = c("Social", "Non-social")) +
    labs(x = "Social Condition", y = "Confidence Rating (1-4)", title = title) +
    theme_behavioral()
  
  # save if path provided
  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 7, height = 5, dpi = 300)
    cat("   plot saved to:", basename(save_path), "\n")
  }
  
  return(p)
}

cat("✓ confidence rating plotting functions loaded\n")