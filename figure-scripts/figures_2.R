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

#FIGURE 2: DATA

# Sector labels A–T
sector_labels <- LETTERS[1:20]

N_WORK <- c(
  358891, 53525, 2445007, 131789, 201530, 2141882, 4532352, 1644253, 2412496, 1492821,
  1110370, 629758, 2975812, 2734434, 1567856, 2723349, 4545941, 963524, 889977, 57176
)

P_FURL <- c(
  0.134, 0.209, 0.357, 0.209, 0.209, 0.397, 0.382, 0.216, 0.692, 0.216,
  0.232, 0.232, 0.232, 0.232, 0.069, 0.174, 0.117, 0.556, 0.345, 0.345
)

A_WFH <- c(
  0.154, 0.154, 0.154, 0.154, 0.154, 0.14, 0.198, 0.112, 0.061, 0.769,
  0.769, 0.4, 0.604, 0.273, 0.273, 0.472, 0.2, 0.193, 0.098, 0.098
)

E_HHC <- c(
  28978.715, 4717.879, 360055.722, 55604.819, 17992.213,
  7976.728, 231374.941, 43813.051, 82393.223, 70985.688,
  113279.043, 373852.584, 16552.634, 41389.457, 10245.339,
  56213.19, 48317.408, 40611.289, 44670.928, 2893.169
)

# Group assignment for each sector (1–20)
group <- c(
  1,1,      # 1-2
  2,        # 3
  3,3,      # 4-5
  4,        # 6
  5,        # 7
  6,        # 8
  7,        # 9
  8,8,8,8,8,# 10-14
  9,9,9,    # 15-17
  10,10,10  # 18-20
)

# Group labels
group_labs <- c(
  "1"  = "Primary Industries",
  "2"  = "Manufacturing",
  "3"  = "Utilities",
  "4"  = "Construction",
  "5"  = "Retail",
  "6"  = "Transport",
  "7"  = "Hospitality",
  "8"  = "ICT, Professional & Support Services",
  "9"  = "Public Administration",
  "10" = "Arts, Recreation & Other"
)

# Group colours
group_cols <- c(
  "1" = "green",
  "2" = "grey",
  "3" = "cyan",
  "4" = "orange",
  "5" = "red",
  "6" = "black",
  "7" = "purple",
  "8" = "darkblue",
  "9" = "yellow",
  "10" = "white"
)

# Shared fill scale
fill_scale <- scale_fill_manual(
  values = group_cols,
  labels = group_labs,
  name = "Economic Sector")

# Plot A: Workers
dfA <- data.frame(
  sector = factor(sector_labels, levels = sector_labels),
  value = N_WORK,
  group = factor(group)
)

pA <- ggplot(dfA, aes(x = sector, y = value/10^6, fill = group)) +
  geom_col(colour = "black", linewidth = 0.2) +
  theme_bw() +
  fill_scale +
  scale_y_continuous(
    limits = c(0, 5),
    expand = c(0, 0)
  ) +
  theme(
    panel.spacing = unit(0.75, "lines"),
    axis.text.x = element_text(angle = 55, hjust = 1)
  ) +
  labs(x = "", y = "Workforce (millions)")

# Plot B: Furlough rate
dfB <- data.frame(
  sector = factor(sector_labels, levels = sector_labels),
  value = P_FURL,
  group = factor(group)
)

pB <- ggplot(dfB, aes(x = sector, y = value, fill = group)) +
  geom_col(colour = "black", linewidth = 0.2) +
  theme_bw() +
  fill_scale +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    expand = c(0, 0),
    labels = scales::label_number(scale = 100)
  ) +
  theme(
    panel.spacing = unit(0.75, "lines"),
    axis.text.x = element_text(angle = 55, hjust = 1)
  ) +
  labs(x = "", y = "Furloughed at any Time (%)")

# Plot C: WFH share
dfC <- data.frame(
  sector = factor(sector_labels, levels = sector_labels),
  value = A_WFH,
  group = factor(group)
)

pC <- ggplot(dfC, aes(x = sector, y = value, fill = group)) +
  geom_col(colour = "black", linewidth = 0.2) +
  theme_bw() +
  fill_scale +
  scale_y_continuous(
    limits = c(0, 1),
    breaks = seq(0, 1, 0.2),
    expand = c(0, 0),
    labels = scales::label_number(scale = 100)
  ) +
  theme(
    panel.spacing = unit(0.75, "lines"),
    axis.text.x = element_text(angle = 55, hjust = 1)
  ) +
  labs(x = "", y = "Capable of Home-Working (%)")

# Plot D: Consumption
dfD <- data.frame(
  sector = factor(sector_labels, levels = sector_labels),
  value = E_HHC,
  group = factor(group)
)

pD <- ggplot(dfD, aes(x = sector, y = value/1000, fill = group)) +
  geom_col(colour = "black", linewidth = 0.2) +
  theme_bw() +
  fill_scale +
  scale_y_continuous(
    limits = c(0, 400),
    expand = c(0, 0)
  ) +
  theme(
    panel.spacing = unit(0.75, "lines"),
    axis.text.x = element_text(angle = 55, hjust = 1)
  ) +
  labs(x = "", y = "Household Consumption ($ billion)")

# Combine plots with shared legend
gg <- (pA / pB / pC / pD) +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom")

# Add subplot labels
gg <- gg + plot_annotation(tag_levels = "A")

# Save
ggsave("figure_2.png", plot = gg, height = 14, width = 10)