# ============================================================
# Question 1: College Football Win Probability
# 2025 FBS College Football Data
# ============================================================

# Load required packages
library(cfbfastR)
library(tidyverse)
library(scales)

# Load 2025 college football play-by-play data
pbp_2025 <- cfbfastR::load_cfb_pbp(2025)


# ============================================================
# Select a 2025 Game
# ============================================================

# Create a list of unique games in the 2025 play-by-play data
games_2025 <- pbp_2025 %>%
  distinct(game_id, home, away) %>%
  arrange(game_id)

# View the first 20 games
head(games_2025, 20)

# Choose one game for testing
test_game_id <- 401752677

# Filter play-by-play data to the selected game
test_game <- pbp_2025 %>%
  filter(game_id == test_game_id)


# ============================================================
# Prepare Win Probability Data
# ============================================================

# Store the home and away team names
home_team <- first(test_game$home)
away_team <- first(test_game$away)

# Get the school colors for the two teams
team_colors <- cfb_teams %>%
  filter(school %in% c(home_team, away_team)) %>%
  select(school, color)

# Store each team's color
home_color <- team_colors %>%
  filter(school == home_team) %>%
  pull(color)

away_color <- team_colors %>%
  filter(school == away_team) %>%
  pull(color)

# Create a named vector of team colors for the graph
team_color_values <- c(home_color, away_color)
names(team_color_values) <- c(home_team, away_team)

# Prepare win probability data for plotting
wp_plot_data <- test_game %>%
  filter(
    period <= 4,
    !is.na(home_wp_after),
    !is.na(away_wp_after)
  ) %>%
  mutate(
    game_seconds_remaining =
      (4 - period) * 900 +
      clock_minutes * 60 +
      clock_seconds,

    game_seconds_elapsed =
      3600 - game_seconds_remaining
  ) %>%
  arrange(game_seconds_elapsed) %>%
  select(
    game_seconds_elapsed,
    home_wp_after,
    away_wp_after
  ) %>%
  pivot_longer(
    cols = c(home_wp_after, away_wp_after),
    names_to = "team_side",
    values_to = "win_probability"
  ) %>%
  mutate(
    team = case_when(
      team_side == "home_wp_after" ~ home_team,
      team_side == "away_wp_after" ~ away_team
    )
  )


# ============================================================
# Create Win Probability Plot
# ============================================================

ggplot(
  wp_plot_data,
  aes(
    x = game_seconds_elapsed,
    y = win_probability,
    color = team
  )
) +
  geom_step(linewidth = 1.2) +

  # Use actual school colors
  scale_color_manual(
    values = team_color_values
  ) +

  # 50% win probability reference line
  geom_hline(
    yintercept = 0.5,
    linetype = "dashed",
    color = "gray40",
    linewidth = 0.7
  ) +

  # Quarter separators
  geom_vline(
    xintercept = c(900, 1800, 2700),
    linetype = "dotted",
    color = "gray60",
    linewidth = 0.6
  ) +

  # Game progress labels
  scale_x_continuous(
    breaks = c(0, 900, 1800, 2700, 3600),
    labels = c("Q1", "Q2", "Halftime", "Q4", "Final")
  ) +

  # Win probability shown as percentages
  scale_y_continuous(
    limits = c(0, 1),
    labels = percent_format(accuracy = 1)
  ) +

  # Titles and labels
  labs(
    title = paste(away_team, "at", home_team),
    subtitle = paste(
      "2025 College Football Win Probability | Game ID:",
      test_game_id
    ),
    x = "Game Progress",
    y = "Win Probability",
    color = "Team",
    caption = "Source: cfbfastR play-by-play data"
  ) +

  # Formatting
  theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(
      face = "bold",
      size = 16
    ),
    plot.subtitle = element_text(
      size = 11
    ),
    axis.title = element_text(
      face = "bold"
    ),
    legend.position = "right",
    panel.grid.minor = element_blank()
  )