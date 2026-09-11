# ============================================================
# ITCS 5010 Homework 3
# Interactive College Football Win Probability App
# ============================================================

# Load required packages
library(shiny)
library(cfbfastR)
library(tidyverse)
library(scales)

# Load NFL model results
if (file.exists("nfl_app_results.rds")) {

  nfl_app_results <- readRDS("nfl_app_results.rds")

  model_performance <- nfl_app_results$model_performance
  calibration_plot <- nfl_app_results$calibration_plot

} else {

  source("nfl_model.R")

}

# Load College Football data
if (file.exists("cfb_app_results.rds")) {

  cfb_app_results <- readRDS("cfb_app_results.rds")

  pbp_2025 <- cfb_app_results$pbp
  cfb_teams <- cfb_app_results$teams

} else {

  pbp_2025 <- cfbfastR::load_cfb_pbp(2025) %>%
    select(
      game_id,
      home,
      away,
      period,
      clock_minutes,
      clock_seconds,
      home_wp_after,
      away_wp_after
    )

  cfb_teams <- cfbfastR::load_cfb_teams()

}


# ============================================================
# User Interface
# ============================================================

ui <- fluidPage(

  titlePanel("Football Analytics Homework 3"),

  tabsetPanel(

    tabPanel(
      "College Football Win Probability",

      sidebarLayout(

        sidebarPanel(

          numericInput(
            inputId = "game_id",
            label = "Enter a 2025 Game ID:",
            value = 401752677,
            min = 1
          ),

          actionButton(
            inputId = "plot_game",
            label = "Plot Game"
          )

        ),

        mainPanel(

          plotOutput(
            outputId = "win_probability_plot",
            height = "650px"
          )

        )

      )
    ),

    tabPanel(
  "NFL Post-Game Model",

  h3("NFL Post-Game Win Probability Model"),

  tableOutput("model_performance_table"),

  h4("Model Comparison"),

p(
  "I created 3 logistic regression models and compared them using the out-of-sample test data. ",
  "Model 1 used traditional box-score data like passing yards, rushing yards, ",
  "turnovers, first downs, etc. ",
  "Model 2 used more advanced statistics like EPA and success rate. ",
  "Model 3 used both traditional box-score data and advanced statistics"
),

p(
  "Model 1 had the weakest results, with an accuracy of 82.85% and a ROC AUC of 0.9197. ",
  "Model 2 performed much better, with an accuracy of 97.08% and a high ROC AUC of 0.9958. ",
  "This shows us that EPA and success rate were very useful for explaining which team won the game. ",
  "Model 3 performed slightly better than model 2, reaching an accuracy of 97.81%."
),

p(
  "I selected model 3 as the best overall model. It had the highest accuracy of all of them and had ",
  "the lowest log loss and Brier score, this means its predicted win probabilities were more accurate overall. ",
  "Model 2 had a slightly higher ROC AUC, but the difference was very small. "
),

h4("Calibration"),

p(
  "The calibration plots below compare the different model's predicted win probability to what actually happened. ",
  "The red dashed line represents the correct calibration, so points closer to this line indicate more accurate probability estimates. ",
  "Models 2 and 3 produced many predictions close to 0% or 100%, this is why it shows larger jumps in the middle of their plots where there were not as many games available."
),

  plotOutput(
    "calibration_plot",
    height = "650px"
  )

    )

  )

)

# ============================================================
# Server
# ============================================================

server <- function(input, output) {

  selected_game <- eventReactive(input$plot_game, {

    pbp_2025 %>%
      filter(game_id == input$game_id)

  })

  output$win_probability_plot <- renderPlot({

    game_data <- selected_game()

    validate(
      need(
        nrow(game_data) > 0,
        "No 2025 game was found with that Game ID."
      )
    )

    home_team <- first(game_data$home)
    away_team <- first(game_data$away)

    team_colors <- cfb_teams %>%
      filter(school %in% c(home_team, away_team)) %>%
      select(school, color)

    home_color <- team_colors %>%
      filter(school == home_team) %>%
      pull(color)

    away_color <- team_colors %>%
      filter(school == away_team) %>%
      pull(color)

    team_color_values <- c(home_color, away_color)
    names(team_color_values) <- c(home_team, away_team)

    wp_plot_data <- game_data %>%
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

    ggplot(
      wp_plot_data,
      aes(
        x = game_seconds_elapsed,
        y = win_probability,
        color = team
      )
    ) +
      geom_step(linewidth = 1.2) +

      scale_color_manual(
        values = team_color_values
      ) +

      geom_hline(
        yintercept = 0.5,
        linetype = "dashed",
        color = "gray40",
        linewidth = 0.7
      ) +

      geom_vline(
        xintercept = c(900, 1800, 2700),
        linetype = "dotted",
        color = "gray60",
        linewidth = 0.6
      ) +

      scale_x_continuous(
        breaks = c(0, 900, 1800, 2700, 3600),
        labels = c("Q1", "Q2", "Halftime", "Q4", "Final")
      ) +

      scale_y_continuous(
        limits = c(0, 1),
        labels = percent_format(accuracy = 1)
      ) +

      labs(
        title = paste(away_team, "at", home_team),
        subtitle = paste(
          "2025 College Football Win Probability | Game ID:",
          input$game_id
        ),
        x = "Game Progress",
        y = "Win Probability",
        color = "Team",
        caption = "Source: cfbfastR play-by-play data"
      ) +

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

  })

output$model_performance_table <- renderTable({
  model_performance
}, digits = 4)

output$calibration_plot <- renderPlot({
  calibration_plot
})

}


# ============================================================
# Run Application
# ============================================================

shinyApp(ui = ui, server = server)