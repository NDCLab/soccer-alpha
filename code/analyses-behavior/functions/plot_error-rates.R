# plot_error_rates.r - plotting functions for error rate analyses
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

COLORS_SOCIAL <- c("social" = "#E69F00", "nonsocial" = "#56B4E9")

# === error rate plot ===
plot_error_rates <- function(error_data, analysis_type, save_path = NULL) {
  # create barplot with error bars for error rates
  #
  # inputs:
  #   error_data - tibble from prepare_error_rate_data()
  #   analysis_type - "overall", "flanker_visible", or "flanker_invisible"
  #   save_path - if provided, save plot to this path
  
  # determine which variable to plot
  if (analysis_type == "overall") {
    y_var <- "error_rate"
    y_lab <- "Error Rate (%)"
    title <- "Overall Error Rate by Social Condition"
  } else if (analysis_type == "flanker_visible") {
    y_var <- "prop_flanker"
    y_lab <- "Proportion Flanker Errors (%)"
    title <- "Flanker Errors (Visible Target)"
    error_data <- error_data %>% filter(!is.na(prop_flanker))
  } else if (analysis_type == "flanker_invisible") {
    y_var <- "prop_flanker_invis"
    y_lab <- "Proportion Flanker Errors (%)"
    title <- "Flanker Errors (Invisible Target)"
    error_data <- error_data %>% filter(!is.na(prop_flanker_invis))
  }
  
  # calculate summary statistics
  plot_data <- error_data %>%
    group_by(social) %>%
    summarise(
      mean = mean(.data[[y_var]], na.rm = TRUE),
      se = sd(.data[[y_var]], na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    ) %>%
    mutate(social = factor(social, levels = c("social", "nonsocial")))
  
  # create plot
  p <- ggplot(plot_data, aes(x = social, y = mean, fill = social)) +
    geom_bar(stat = "identity", width = 0.6, color = "black") +
    geom_errorbar(aes(ymin = mean - se, ymax = mean + se), 
                  width = 0.2, linewidth = 0.8) +
    scale_fill_manual(values = COLORS_SOCIAL, 
                      labels = c("Social", "Non-social")) +
    scale_x_discrete(labels = c("Social", "Non-social")) +
    labs(x = "Condition", y = y_lab, title = title) +
    theme_behavioral() +
    theme(legend.position = "none")
  
  # save if path provided
  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 5, height = 4, dpi = 300)
    cat("   plot saved to:", basename(save_path), "\n")
  }
  
  return(p)
}

cat("✓ error rate plotting functions loaded\n")