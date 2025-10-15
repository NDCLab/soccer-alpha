# plot_response-times.r - plotting functions for RT analyses
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
                      "flanker" = "#CC79A7", "nonflanker" = "#F0E442",
                      "flanker_error" = "#CC79A7", "nonflanker_guess" = "#0072B2")

# === response time interaction plot ===
plot_rt_interaction <- function(subject_means, plot_type, save_path = NULL) {
  # create interaction plot for RT analyses using subject-level means
  #
  # inputs:
  #   subject_means - tibble with subject-level mean RTs (already aggregated)
  #   plot_type - "correctness", "error_type", or "response_type"
  #   save_path - if provided, save plot to this path
  
  # determine grouping & labels based on plot type
  if (plot_type == "correctness") {
    # rename correctness levels for display
    plot_data <- subject_means %>%
      mutate(correctness = recode(correctness, 
                                  "correct" = "Correct",
                                  "error" = "Error"))
    x_var <- "social"
    color_var <- "correctness"
    title <- "Response Time: Correctness × Social Condition"
    colors <- c("Correct" = "#009E73", 
                "Error" = "#D55E00")
  } else if (plot_type == "error_type") {
    # rename error_type levels for display
    plot_data <- subject_means %>%
      mutate(error_type = recode(error_type,
                                 "flanker" = "Flanker Error",
                                 "nonflanker" = "Non-flanker Error"))
    x_var <- "social"
    color_var <- "error_type"
    title <- "Response Time: Error Type × Social Condition"
    colors <- c("Flanker Error" = "#CC79A7",
                "Non-flanker Error" = "#F0E442")
  } else if (plot_type == "response_type") {
    # rename response_type levels for display
    plot_data <- subject_means %>%
      mutate(response_type = recode(response_type,
                                    "flanker_error" = "Flanker Error",
                                    "nonflanker_guess" = "Non-flanker Guess"))
    x_var <- "social"
    color_var <- "response_type"
    title <- "Response Time: Response Type × Social Condition (Invisible)"
    colors <- c("Flanker Error" = "#CC79A7",
                "Non-flanker Guess" = "#0072B2")
  }
  
  # calculate summary statistics across subjects
  summary_data <- plot_data %>%
    group_by(across(all_of(c(x_var, color_var)))) %>%
    summarise(
      mean = mean(mean_rt, na.rm = TRUE),
      se = sd(mean_rt, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    ) %>%
    mutate(social = factor(social, levels = c("social", "nonsocial")))
  
  # create plot
  p <- ggplot(summary_data, aes(x = .data[[x_var]], y = mean, 
                                color = .data[[color_var]], 
                                group = .data[[color_var]])) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = mean - se, ymax = mean + se), 
                  width = 0.1, linewidth = 0.8) +
    scale_color_manual(values = colors, name = "") +
    scale_x_discrete(labels = c("Social", "Non-social")) +
    labs(x = "Social Condition", y = "Response Time (ms)", title = title) +
    theme_behavioral()
  
  # save if path provided
  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 7, height = 5, dpi = 300)
    cat("   plot saved to:", basename(save_path), "\n")
  }
  
  return(p)
}

cat("✓ response time plotting functions loaded\n")