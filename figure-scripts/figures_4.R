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

#FIGURE 4: GTAP

library(dplyr)
library(tidyr)
library(ggplot2)
library(grid)

# Common data directory
data_dir <- "../data/outputs/casestudy_01/"
df_GTAP <- read.csv(paste0(data_dir, "GTAP.csv"))

# Filter GBR
df_gbr <- df_GTAP %>%
  dplyr::filter(country == "gbr")

# Sector mapping
sector_map <- c(
  "allprimary" = "1",
  "manufac" = "2",
  "utilities" = "3",
  "constr" = "4",
  "retail" = "5",
  "transport" = "6",
  "hosp" = "7",
  "ict_prof_serv" = "8",
  "pubadm" = "9",
  "arts_rec_other" = "10"
)

# Labels
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

# =========================
# Total GDP (only for p1)
# =========================
df_total <- df_gbr %>%
  dplyr::transmute(
    sector = "total",
    value = dgdp
  )

# Legend theme (correctly placed, no guides() issue)
legend_theme <- theme(
  legend.position = "bottom",
  legend.box = "horizontal",
  legend.direction = "horizontal",
  panel.spacing = unit(0.75, "lines"),
  axis.text.x = element_text(angle = 55, hjust = 1)
)

# =========================
# p1: dqgdp (WITH total)
# =========================

df_long_q <- df_gbr %>%
  dplyr::select(dplyr::starts_with("dqgdp_")) %>%
  tidyr::pivot_longer(
    cols = dplyr::everything(),
    names_to = "sector",
    values_to = "value"
  ) %>%
  dplyr::mutate(
    sector = gsub("dqgdp_", "", sector)
  )

df_plot_q <- dplyr::bind_rows(df_total, df_long_q) %>%
  dplyr::mutate(
    group = ifelse(sector == "total", "total", sector_map[sector]),
    sector_label = dplyr::case_when(
      sector == "total" ~ "Total GDP",
      TRUE ~ group_labs[group]
    )
  )

df_plot_q$sector_label <- factor(
  df_plot_q$sector_label,
  levels = c("Total GDP", group_labs)
)

p1 <- ggplot(df_plot_q, aes(x = sector_label, y = value, fill = group)) +
  geom_col(colour = "black", linewidth = 0.2) +
  theme_bw() +
  scale_fill_manual(
    values = c(group_cols, "total" = "brown"),
    breaks = c("Total", names(group_labs)),
    labels = c("Total GDP", group_labs)
  ) +
  scale_y_continuous(expand = c(0, 0), limits = c(-12, 0), breaks = seq(-12, 0, by = 3)) +
  legend_theme +
  guides(fill = guide_legend(nrow = 2, byrow = FALSE, title = "Economic Sector")) +
  labs(x = "", y = "Real GDP (% deviation)")

# =========================
# p2: dpgdp (NO total)
# =========================

df_long_p <- df_gbr %>%
  dplyr::select(dplyr::starts_with("dpgdp_")) %>%
  tidyr::pivot_longer(
    cols = dplyr::everything(),
    names_to = "sector",
    values_to = "value"
  ) %>%
  dplyr::mutate(
    sector = gsub("dpgdp_", "", sector)
  )

df_plot_p <- df_long_p %>%
  dplyr::mutate(
    group = sector_map[sector],
    sector_label = group_labs[group]
  )

df_plot_p$sector_label <- factor(
  df_plot_p$sector_label,
  levels = group_labs
)

p2 <- ggplot(df_plot_p, aes(x = sector_label, y = value, fill = group)) +
  geom_col(colour = "black", linewidth = 0.2) +
  theme_bw() +
  scale_fill_manual(
    values = group_cols,
    breaks = names(group_labs),
    labels = group_labs
  ) +
  scale_y_continuous(expand = c(0, 0), limits = c(0, 15), breaks = seq(0, 15, by = 3)) +
  legend_theme +
  guides(fill = "none") +
  labs(x = "", y = "GDP Deflator (% deviation)")


gg <- (p1 / p2) +
  plot_layout(guides = "collect") &
  theme(legend.position = "bottom")

# Add subplot labels
gg <- gg + plot_annotation(tag_levels = "A")

# Save
ggsave("figure_4.png", plot = gg, height = 14, width = 10)