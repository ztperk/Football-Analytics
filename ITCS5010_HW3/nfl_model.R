# ============================================================
# Question 2: NFL Post-Game Win Probability Model
# 2021-2025 NFL Data
# ============================================================


# ============================================================
# Load Packages and Data
# ============================================================

# Load required packages
library(nflreadr)
library(tidyverse)
library(rsample)
library(yardstick)
library(scales)
library(recipes)

# Define the last five completed NFL seasons
seasons <- 2021:2025

# Load NFL play-by-play data
nfl_pbp <- nflreadr::load_pbp(seasons)


# ============================================================
# Create Game-Level Team Statistics
# ============================================================

team_game_stats <- nfl_pbp %>%
  filter(
    season_type == "REG",
    posteam_type %in% c("home", "away")
  ) %>%
  group_by(
    game_id,
    season,
    week,
    home_team,
    away_team,
    posteam_type
  ) %>%
  summarise(
    pass_yards = sum(if_else(pass_attempt == 1, yards_gained, 0), na.rm = TRUE),
    rush_yards = sum(if_else(rush_attempt == 1, yards_gained, 0), na.rm = TRUE),

    turnovers = sum(
      coalesce(interception, 0) + coalesce(fumble_lost, 0),
      na.rm = TRUE
    ),

    first_downs = sum(
      coalesce(first_down_pass, 0) +
        coalesce(first_down_rush, 0) +
        coalesce(first_down_penalty, 0),
      na.rm = TRUE
    ),

    third_down_conversions = sum(third_down_converted, na.rm = TRUE),
    third_down_failures = sum(third_down_failed, na.rm = TRUE),

    epa_per_play = mean(epa, na.rm = TRUE),
    success_rate = mean(success, na.rm = TRUE),

    .groups = "drop"
  ) %>%
  mutate(
    third_down_attempts = third_down_conversions + third_down_failures,
    third_down_pct = if_else(
      third_down_attempts > 0,
      third_down_conversions / third_down_attempts,
      0
    )
  )

# ============================================================
# Create Game-Level Penalty Statistics
# ============================================================

penalty_game_stats <- nfl_pbp %>%
  filter(
    season_type == "REG",
    !is.na(penalty_team)
  ) %>%
  group_by(
    game_id,
    season,
    week,
    home_team,
    away_team
  ) %>%
  summarise(
    home_penalty_yards = sum(
      if_else(penalty_team == home_team, penalty_yards, 0),
      na.rm = TRUE
    ),

    away_penalty_yards = sum(
      if_else(penalty_team == away_team, penalty_yards, 0),
      na.rm = TRUE
    ),

    .groups = "drop"
  )

# ============================================================
# Create One Row Per Game
# ============================================================

game_level_stats <- team_game_stats %>%

  pivot_wider(
    id_cols = c(
      game_id,
      season,
      week,
      home_team,
      away_team
    ),
    names_from = posteam_type,
    values_from = c(
      pass_yards,
      rush_yards,
      turnovers,
      first_downs,
      third_down_pct,
      epa_per_play,
      success_rate
    ),
    names_glue = "{posteam_type}_{.value}"
  ) %>%

  left_join(
    penalty_game_stats,
    by = c("game_id", "season", "week", "home_team", "away_team")
  ) %>%

  mutate(

    # Home team performance differentials
    pass_yards_diff =
      home_pass_yards - away_pass_yards,

    rush_yards_diff =
      home_rush_yards - away_rush_yards,

    first_downs_diff =
      home_first_downs - away_first_downs,

    third_down_pct_diff =
      home_third_down_pct - away_third_down_pct,

    penalty_yards_diff =
      home_penalty_yards - away_penalty_yards,

    # Positive turnover margin favors the home team
    turnover_margin =
      away_turnovers - home_turnovers,

    # Advanced efficiency differentials
    epa_diff =
      home_epa_per_play - away_epa_per_play,

    success_rate_diff =
      home_success_rate - away_success_rate
  )

# ============================================================
# Create Modeling Dataset
# ============================================================

# Determine the winner of each regular-season game
game_outcomes <- nfl_pbp %>%
  filter(season_type == "REG") %>%
  group_by(game_id, season, week, home_team, away_team) %>%
  summarise(
    home_score = max(total_home_score, na.rm = TRUE),
    away_score = max(total_away_score, na.rm = TRUE),
    .groups = "drop"
  ) %>%
  filter(home_score != away_score) %>%
  transmute(
    game_id,
    season,
    week,
    home_team,
    away_team,
    home_win = as.integer(home_score > away_score)
  )

# Join game outcomes to the game-level statistics
nfl_model_data <- game_level_stats %>%
  inner_join(
    game_outcomes,
    by = c("game_id", "season", "week", "home_team", "away_team")
  ) %>%
  select(
    game_id,
    season,
    week,
    home_team,
    away_team,
    home_win,
    turnover_margin,
    pass_yards_diff,
    rush_yards_diff,
    first_downs_diff,
    third_down_pct_diff,
    penalty_yards_diff,
    epa_diff,
    success_rate_diff
  ) %>%
  drop_na()

# ============================================================
# Split Data into Training and Test Sets
# ============================================================

# Convert season to a factor for season-stratified sampling
nfl_model_data <- nfl_model_data %>%
  mutate(
    season = factor(season)
  )

# Set seed so the split can be reproduced
set.seed(2026)

# Create 80/20 train-test split stratified by season
game_split <- initial_split(
  nfl_model_data,
  prop = 0.80,
  strata = season
)

train_data <- training(game_split)
test_data <- testing(game_split)


# ============================================================
# Prepare Predictors for Modeling
# ============================================================

# Traditional box-score predictors
traditional_predictors <- c(
  "turnover_margin",
  "pass_yards_diff",
  "rush_yards_diff",
  "first_downs_diff",
  "third_down_pct_diff",
  "penalty_yards_diff"
)

# Advanced efficiency predictors
advanced_predictors <- c(
  "epa_diff",
  "success_rate_diff"
)

# All predictors
all_predictors <- c(
  traditional_predictors,
  advanced_predictors
)


# Create preprocessing recipe using training data only
nfl_recipe <- recipe(
  home_win ~ .,
  data = train_data %>%
    select(home_win, all_of(all_predictors))
) %>%
  step_normalize(all_of(all_predictors)) %>%
  prep()

# Apply the same scaling to training and test data
train_scaled <- bake(
  nfl_recipe,
  new_data = NULL
)

test_scaled <- bake(
  nfl_recipe,
  new_data = test_data
)

# ============================================================
# Model 1: Traditional Box-Score Logistic Regression
# ============================================================

model_1 <- glm(
  home_win ~
    turnover_margin +
    pass_yards_diff +
    rush_yards_diff +
    first_downs_diff +
    third_down_pct_diff +
    penalty_yards_diff,
  data = train_scaled,
  family = binomial(link = "logit")
)

# ============================================================
# Model 2: Advanced Efficiency Logistic Regression
# ============================================================

model_2 <- glm(
  home_win ~
    epa_diff +
    success_rate_diff,
  data = train_scaled,
  family = binomial(link = "logit")
)

# ============================================================
# Model 3: Combined Logistic Regression
# ============================================================

model_3 <- glm(
  home_win ~
    turnover_margin +
    pass_yards_diff +
    rush_yards_diff +
    first_downs_diff +
    third_down_pct_diff +
    penalty_yards_diff +
    epa_diff +
    success_rate_diff,
  data = train_scaled,
  family = binomial(link = "logit")
)

# ============================================================
# Out-of-Sample Predictions
# ============================================================

test_predictions <- test_data %>%
  mutate(
    model_1_prob = predict(model_1, newdata = test_scaled, type = "response"),
    model_2_prob = predict(model_2, newdata = test_scaled, type = "response"),
    model_3_prob = predict(model_3, newdata = test_scaled, type = "response"),

    actual_class = factor(
      home_win,
      levels = c(1, 0),
      labels = c("Win", "Loss")
    ),

    model_1_class = factor(
      if_else(model_1_prob >= 0.50, 1, 0),
      levels = c(1, 0),
      labels = c("Win", "Loss")
    ),

    model_2_class = factor(
      if_else(model_2_prob >= 0.50, 1, 0),
      levels = c(1, 0),
      labels = c("Win", "Loss")
    ),

    model_3_class = factor(
      if_else(model_3_prob >= 0.50, 1, 0),
      levels = c(1, 0),
      labels = c("Win", "Loss")
    )
  )

# ============================================================
# Model Performance Summary
# ============================================================

model_performance <- tibble(
  Model = c(
    "Model 1: Traditional",
    "Model 2: Advanced",
    "Model 3: Combined"
  ),

  Accuracy = c(
    accuracy_vec(
      test_predictions$actual_class,
      test_predictions$model_1_class
    ),
    accuracy_vec(
      test_predictions$actual_class,
      test_predictions$model_2_class
    ),
    accuracy_vec(
      test_predictions$actual_class,
      test_predictions$model_3_class
    )
  ),

  ROC_AUC = c(
    roc_auc_vec(
      test_predictions$actual_class,
      test_predictions$model_1_prob,
      event_level = "first"
    ),
    roc_auc_vec(
      test_predictions$actual_class,
      test_predictions$model_2_prob,
      event_level = "first"
    ),
    roc_auc_vec(
      test_predictions$actual_class,
      test_predictions$model_3_prob,
      event_level = "first"
    )
  ),

  Log_Loss = c(
    mn_log_loss_vec(
      test_predictions$actual_class,
      test_predictions$model_1_prob
    ),
    mn_log_loss_vec(
      test_predictions$actual_class,
      test_predictions$model_2_prob
    ),
    mn_log_loss_vec(
      test_predictions$actual_class,
      test_predictions$model_3_prob
    )
  ),

  Brier_Score = c(
    mean((test_predictions$home_win - test_predictions$model_1_prob)^2),
    mean((test_predictions$home_win - test_predictions$model_2_prob)^2),
    mean((test_predictions$home_win - test_predictions$model_3_prob)^2)
  )
)
# ============================================================
# Calibration Data
# ============================================================

calibration_data <- test_predictions %>%
  select(
    home_win,
    model_1_prob,
    model_2_prob,
    model_3_prob
  ) %>%

  pivot_longer(
    cols = c(
      model_1_prob,
      model_2_prob,
      model_3_prob
    ),
    names_to = "Model",
    values_to = "pred_prob"
  ) %>%

  mutate(
    Model = case_when(
      Model == "model_1_prob" ~ "Model 1: Traditional",
      Model == "model_2_prob" ~ "Model 2: Advanced",
      Model == "model_3_prob" ~ "Model 3: Combined"
    ),

    prob_bin = cut(
      pred_prob,
      breaks = seq(0, 1, by = 0.1),
      include.lowest = TRUE
    )
  ) %>%

  group_by(Model, prob_bin) %>%

  summarise(
    mean_pred = mean(pred_prob),
    actual_win_rate = mean(home_win),
    game_count = n(),
    .groups = "drop"
  ) %>%

  drop_na()

# ============================================================
# Calibration Plots
# ============================================================

calibration_plot <- ggplot(
  calibration_data,
  aes(
    x = mean_pred,
    y = actual_win_rate
  )
) +
  geom_abline(
    slope = 1,
    intercept = 0,
    linetype = "dashed",
    color = "firebrick",
    linewidth = 0.8
  ) +
  geom_line(
    color = "royalblue",
    linewidth = 1
  ) +
  geom_point(
    aes(size = game_count),
    color = "royalblue",
    alpha = 0.8
  ) +
  facet_wrap(
    ~ Model,
    ncol = 3
  ) +
  scale_x_continuous(
    limits = c(0, 1),
    labels = percent_format(accuracy = 1)
  ) +
  scale_y_continuous(
    limits = c(0, 1),
    labels = percent_format(accuracy = 1)
  ) +
  labs(
    title = "NFL Post-Game Win Probability Calibration",
    subtitle = "Out-of-Sample Test Set",
    x = "Mean Predicted Win Probability",
    y = "Observed Win Rate",
    size = "Test Games"
  ) +
  theme_minimal()

