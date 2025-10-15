# plot_confidence-ratings.r - plotting functions for confidence analyses
# author: marlene buch

# === confidence rating plotting functions ===

plot_confidence_interaction <- function(conf_data, plot_type = "correctness", 
                                        save_path = NULL, title = NULL) {
  # create interaction plot for confidence ratings
  #
  # inputs:
  #   conf_data - data with subject-level mean confidence ratings
  #   plot_type - "correctness", "error_type", or "response_type"
  #   save_path - optional path to save plot
  #   title - optional title
  
  # set up variables based on plot type
  if (plot_type == "correctness") {
    x_var <- "social"
    color_var <- "correctness"
    colors <- c("correct" = "#56B4E9", "error" = "#E69F00")
    if (is.null(title)) title <- "Confidence Ratings: Correctness × Social"
    
  } else if (plot_type == "error_type") {
    x_var <- "social"
    color_var <- "error_type"
    colors <- c("flanker" = "#CC79A7", "nonflanker" = "#0072B2")
    if (is.null(title)) title <- "Confidence Ratings: Error Type × Social (Errors Only)"
    
  } else if (plot_type == "response_type") {
    x_var <- "social"
    color_var <- "response_type"
    colors <- c("flanker_error" = "#CC79A7", "nonflanker_guess" = "#0072B2")
    if (is.null(title)) title <- "Confidence Ratings: Response Type × Social (Invisible)"
  }
  
  # calculate summary statistics from subject means
  plot_data <- conf_data %>%
    group_by(across(all_of(c(x_var, color_var)))) %>%
    summarise(
      mean = mean(mean_confidence, na.rm = TRUE),
      se = sd(mean_confidence, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    ) %>%
    mutate(social = factor(social, levels = c("social", "nonsocial")))
  
  # create plot with proper y-axis labels
  # scale is: 1 = certainly correct, 6 = certainly wrong
  p <- ggplot(plot_data, aes(x = .data[[x_var]], y = mean, 
                             color = .data[[color_var]], 
                             group = .data[[color_var]])) +
    geom_line(linewidth = 1.2) +
    geom_point(size = 3) +
    geom_errorbar(aes(ymin = mean - se, ymax = mean + se), 
                  width = 0.1, linewidth = 0.8) +
    scale_color_manual(values = colors, name = "") +
    scale_x_discrete(labels = c("Social", "Non-social")) +
    # fixed y-axis with correct labels
    scale_y_continuous(
      limits = c(1, 6),
      breaks = 1:6,
      labels = c("1\nCertainly\nCorrect", "2\nProbably\nCorrect", "3\nMaybe\nCorrect",
                 "4\nMaybe\nWrong", "5\nProbably\nWrong", "6\nCertainly\nWrong")
    ) +
    labs(x = "Social Condition", 
         y = "Confidence Rating", 
         title = title) +
    theme_behavioral() +
    theme(axis.text.y = element_text(size = 8, hjust = 0.5))  # adjust size for readability
  
  # save if path provided
  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 8, height = 6, dpi = 300)
    cat("   plot saved to:", basename(save_path), "\n")
  }
  
  return(p)
}

# alternative simple bar plot function
plot_confidence_bars <- function(conf_data, group_var, save_path = NULL, title = NULL) {
  # create bar plot for confidence ratings
  #
  # inputs:
  #   conf_data - data with subject-level mean confidence ratings
  #   group_var - variable to group by (e.g., "social", "correctness")
  #   save_path - optional path to save plot
  #   title - optional title
  
  # calculate summary statistics from subject means
  plot_data <- conf_data %>%
    group_by(across(all_of(group_var))) %>%
    summarise(
      mean = mean(mean_confidence, na.rm = TRUE),
      se = sd(mean_confidence, na.rm = TRUE) / sqrt(n()),
      .groups = "drop"
    )
  
  # create bar plot
  p <- ggplot(plot_data, aes(x = .data[[group_var]], y = mean, fill = .data[[group_var]])) +
    geom_bar(stat = "identity", width = 0.7) +
    geom_errorbar(aes(ymin = mean - se, ymax = mean + se), 
                  width = 0.2, linewidth = 0.8) +
    scale_fill_manual(values = c("#56B4E9", "#E69F00")) +
    # fixed y-axis with correct labels
    scale_y_continuous(
      limits = c(0, 6),
      breaks = 1:6,
      labels = c("1\nCertainly\nCorrect", "2\nProbably\nCorrect", "3\nMaybe\nCorrect",
                 "4\nMaybe\nWrong", "5\nProbably\nWrong", "6\nCertainly\nWrong")
    ) +
    labs(x = "", 
         y = "Confidence Rating", 
         title = title) +
    theme_behavioral() +
    theme(legend.position = "none",
          axis.text.y = element_text(size = 8, hjust = 0.5))
  
  # save if path provided
  if (!is.null(save_path)) {
    ggsave(save_path, p, width = 7, height = 6, dpi = 300)
    cat("   plot saved to:", basename(save_path), "\n")
  }
  
  return(p)
}

cat("✔ confidence rating plotting functions loaded\n")