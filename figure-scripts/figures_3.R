library(dplyr)
library(purrr)
library(tidyr)
library(readr)
library(stringr)
library(fBasics)
library(fitdistrplus)
library(forecast)
library(scam)
library(ggplot2)
library(ggh4x)
library(ggdensity)
library(cowplot)
library(ggpattern)
library(patchwork)
# source("functions/add_scenario_cols.R")
# source("functions/order_scenario_cols.R")
# source("functions/calc_loss_pc.R")
# source("functions/parse_inputs.R")
# source("functions/format_table.R")

#FIGURE 3: SHOCKS

# Common data directory
data_dir <- "../data/outputs/casestudy_01/"

# Read CSVs
df_times <- read.csv(paste0(data_dir, "shock_times.csv"))
df_samples <- read.csv(paste0(data_dir, "shock_samples.csv"))

# Define x-axis limits if needed (optional)
x_limits <- range(df_times$times, na.rm = TRUE)

# --- Convert to Date ---
df_times$times <- as.Date(df_times$times)

# Define x-axis limits
x_limits <- range(df_times$times, na.rm = TRUE)

# --- Plot 1 ---
p1 <- ggplot(df_times, aes(x = times, y = wf_pcred)) +
  geom_line(color = "steelblue", linewidth = 0.8) +
  theme_bw() +
  scale_y_continuous(limits = c(-40, 10), breaks = seq(-40,10, by =10), expand = c(0, 0)) +
  scale_x_date(
    limits = x_limits,
    expand = c(0, 0),
    date_breaks = "1 month",
    date_labels = "%B %Y"
  ) +
  labs(x = NULL, y = "Workforce Shock\n(% deviation)") +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# --- Plot 2 ---
p2 <- ggplot(df_times, aes(x = times, y = ccf_pcred)) +
  geom_line(color = "darkorange", linewidth = 0.8) +
  theme_bw() +
  scale_y_continuous(limits = c(-20, 5), breaks = seq(-20,5, by = 5), expand = c(0, 0)) +
  scale_x_date(
    limits = x_limits,
    expand = c(0, 0),
    date_breaks = "1 month",
    date_labels = "%B %Y"
  ) +
  labs(
    x = NULL,
    y = "Consumption Shock\n(% deviation for customer-facing sectors)"
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))

# --- Histogram 3 ---
p3 <- ggplot(df_samples, aes(x = wf_pcred, y = after_stat(density))) +
  geom_histogram(fill = "steelblue", colour = "black", linewidth = 0.2, bins = 30) +
  theme_bw() +
  scale_x_continuous(limits = c(-20, 0), expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  labs(x = "Workforce Shock\n(% time-averaged deviation)", y = "Relative Frequency")

# --- Histogram 4 ---
p4 <- ggplot(df_samples, aes(x = ccf_pcred, y = after_stat(density))) +
  geom_histogram(fill = "darkorange", colour = "black", linewidth = 0.2, bins = 30) +
  theme_bw() +
  scale_x_continuous(limits = c(-10, 0), expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  labs(
    x = "Consumption Shock\n(% time-averaged deviation for customer-facing sectors)",
    y = "Relative Frequency"
  )

# --- Histogram 5 ---
p5 <- ggplot(df_samples, aes(x = lf_pcred, y = after_stat(density))) +
  geom_histogram(fill = "forestgreen", colour = "black", linewidth = 0.2, bins = 30) +
  theme_bw() +
  scale_x_continuous(limits = c(-25, 0), expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  labs(x = "Labour Force Shock\n(% time-averaged deviation)", y = "Relative Frequency")

# --- Histogram 6 ---
p6 <- ggplot(df_samples, aes(x = cagg_pcred, y = after_stat(density))) +
  geom_histogram(fill = "purple", colour = "black", linewidth = 0.2, bins = 30) +
  theme_bw() +
  scale_x_continuous(limits = c(-5, 0), expand = c(0, 0)) +
  scale_y_continuous(expand = c(0, 0)) +
  labs(x = "Consumption Shock\n(% time-averaged deviation sector-averaged)", y = "Relative Frequency")
# Combine plots with patchwork
gg <- (p1 / p2) / (p3 + p4) / (p5 + p6) +
  plot_annotation(tag_levels = "A")

ggsave("figure_3.png", plot = gg, height = 14, width = 10)