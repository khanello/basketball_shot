library(shiny)

shinyServer(function(input, output, session) {
  current_player = reactive({
    req(input$player_name)
    find_player_by_name(input$player_name)
  })
  
  current_player_seasons = reactive({
    req(current_player())
    
    first = max(current_player()$from_year, first_year_of_data)
    last = current_player()$to_year
    as.character(season_strings[as.character(first:last)])
  })
  
  current_season = reactive({
    req(input$season)
    input$season
  })
  
  update_season_input = observe({
    req(current_player(), current_player_seasons())
    
    isolate({
      if (current_season() %in% current_player_seasons()) {
        selected_value = current_season()
      } else {
        selected_value = rev(current_player_seasons())[1]
      }
      
      updateSelectInput(session,
                        "season",
                        choices = rev(current_player_seasons()),
                        selected = selected_value)
    })
  })
  
  shots = reactive({
    req(current_player(), current_season())
    req(current_season() %in% current_player_seasons())
    
    use_default_shots = current_player()$person_id == default_player$person_id & current_season() == default_season
    
    if (use_default_shots) {
      default_shots
    } else {
      fetch_shots_by_player_id_and_season(current_player()$person_id, current_season())
    }
  })
  
  filtered_shots = reactive({
    req(input$shot_result_filter, shots()$player)
    
    filter(shots()$player,
           input$shot_result_filter == "all" | shot_made_flag == input$shot_result_filter,
           shot_zone_basic != "Backcourt",
           is.null(input$shot_zone_basic_filter) | shot_zone_basic %in% input$shot_zone_basic_filter,
           is.null(input$shot_zone_angle_filter) | shot_zone_area %in% input$shot_zone_angle_filter,
           is.null(input$shot_distance_filter) | shot_zone_range %in% input$shot_distance_filter
    )
  })
  
  hexbin_data = reactive({
    req(filtered_shots(), shots(), hexbinwidths(), input$hex_radius)
    
    calculate_hexbins_from_shots(filtered_shots(), shots()$league_averages,
                                 binwidths = hexbinwidths(),
                                 min_radius_factor = input$hex_radius)
  })
  
  output$hexbinwidth_slider = renderUI({
    req(input$chart_type == "Hexagonal")
    
    sliderInput("hexbinwidth",
                "Hexagon Size (feet)",
                min = 0.5,
                max = 4,
                value = 1.5,
                step = 0.25)
  })
  
  hexbinwidths = reactive({
    req(input$hexbinwidth)
    rep(input$hexbinwidth, 2)
  })
  
  output$hex_radius_slider = renderUI({
    req(input$chart_type == "Hexagonal")
    
    sliderInput("hex_radius",
                "Min Hexagon Size Adjustment",
                min = 0,
                max = 1,
                value = 0.4,
                step = 0.05)
  })
  
  alpha_range = reactive({
    req(input$chart_type == "Hexagonal", input$hex_radius)
    max_alpha = 0.98
    min_alpha = max_alpha - 0.25 * input$hex_radius
    c(min_alpha, max_alpha)
  })
  
  output$hex_metric_buttons = renderUI({
    req(input$chart_type == "Hexagonal")
    
    selectInput("hex_metric",
                "Hexagon Colors",
                choices = c("FG% vs. League Avg" = "bounded_fg_diff",
                            "FG%" = "bounded_fg_pct",
                            "Points Per Shot" = "bounded_points_per_shot"),
                selected = "bounded_fg_diff",
                selectize = FALSE)
  })
  
  shot_chart = reactive({
    req(filtered_shots(), current_player(), current_season(), input$chart_type)
    
    short_three = current_season() %in% short_three_seasons
    filters_applied()
    
    if (input$chart_type == "Hexagonal") {
      req(input$hex_metric, alpha_range())
      
      generate_hex_chart(
        hex_data = hexbin_data(),
        use_short_three = short_three,
        metric = input$hex_metric,
        alpha_range = alpha_range()
      )
    } else if (input$chart_type == "Scatter") {
      generate_scatter_chart(filtered_shots(), use_short_three = short_three)
    } else if (input$chart_type == "Heat Map") {
      generate_heatmap_chart(filtered_shots(), use_short_three = short_three)
    } else if (input$chart_type == "Bar Chart") {
      generate_bar_chart(filtered_shots())
    } else {
      stop("invalid chart type")
    }
  })
  
  output$chart_header_player = renderText({
    req(current_player())
    current_player()$name
  })
  
  output$chart_header_info = renderText({
    req(current_season(), shots())
    paste(current_season(), "Regular Season")
  })
  
  output$chart_header_team = renderText({
    req(shots()$player)
    paste0(unique(shots()$player$team_name), collapse = ", ")
  })
  
  
  output$player_photo = renderUI({
    if (input$player_name == "") {
      tags$img(src = "http://i.imgur.com/hXWPTOF.png", alt = "photo")
    } else if (req(current_player()$person_id)) {
      tags$img(src = player_photo_url(current_player()$person_id), alt = "photo")
    }
  })
  
  output$court = renderPlot({
    req(shot_chart())
    withProgress({
      shot_chart()
    }, message = "Calculating...")
  }, height = 600, width = 800, bg = bg_color)
  
  filters_applied = reactive({
    req(filtered_shots())
    filters = list()
    
    if (!is.null(input$shot_zone_basic_filter)) {
      filters[["Zone"]] = paste("Zone:", paste(input$shot_zone_basic_filter, collapse = ", "))
    }
    
    if (!is.null(input$shot_zone_angle_filter)) {
      filters[["Angle"]] = paste("Angle:", paste(input$shot_zone_angle_filter, collapse = ", "))
    }
    
    if (!is.null(input$shot_distance_filter)) {
      filters[["Distance"]] = paste("Distance:", paste(input$shot_distance_filter, collapse = ", "))
    }
    
    if (input$shot_result_filter != "all") {
      filters[["Result"]] = paste("Result:", input$shot_result_filter)
    }
    
    filters
  })
  
  output$shot_filters_applied = renderUI({
    req(length(filters_applied()) > 0)
    
    div(class = "shot-filters",
        tags$h5("Shot Filters Applied"),
        lapply(filters_applied(), function(text) {
          div(text)
        })
    )
  })
  
  output$summary_stats_header = renderText({
    req(current_player())
    paste(current_player()$name, current_season(), "Summary Stats")
  })
  
  output$summary_stats = renderUI({
    req(filtered_shots(), shots())
    req(nrow(filtered_shots()) > 0)
    
    player_zone = filtered_shots() %>%
      group_by(shot_zone_basic) %>%
      summarize(fgm = sum(shot_made_numeric),
                fga = n(),
                pct = mean(shot_made_numeric),
                pct_as_text = fraction_to_percent_format(pct),
                points_per_shot = mean(shot_value * shot_made_numeric)) %>%
      arrange(desc(fga), desc(fgm))
    
    league_zone = shots()$league_averages %>%
      group_by(shot_zone_basic) %>%
      summarize(lg_fgm = sum(fgm),
                lg_fga = sum(fga),
                lg_pct = lg_fgm / lg_fga,
                lg_pct_as_text = fraction_to_percent_format(lg_pct),
                lg_points_per_shot = round(mean(shot_value * lg_pct), 2))
    
    merged = inner_join(player_zone, league_zone, by = "shot_zone_basic")
    
    overall = summarize(merged,
                        total_fgm = sum(fgm),
                        total_fga = sum(fga),
                        pct = total_fgm / total_fga,
                        pct_as_text = fraction_to_percent_format(pct),
                        points_per_shot = sum(points_per_shot * fga) / sum(fga),
                        lg_pct = sum(lg_fgm) / sum(lg_fga),
                        lg_pct_as_text = fraction_to_percent_format(lg_pct),
                        lg_points_per_shot = sum(lg_points_per_shot * lg_fga) / sum(lg_fga)
    )
    
    html = list(div(class = "row headers",
                    span(class = "col-xs-4 col-md-3 zone-label", "Zone"),
                    span(class = "col-xs-2 col-md-1 numeric", "FGM"),
                    span(class = "col-xs-2 col-md-1 numeric", "FGA"),
                    span(class = "col-xs-2 col-md-2 numeric", "FG%"),
                    span(class = "col-xs-2 col-md-1 numeric", "Lg FG%"),
                    span(class = "hidden-xs hidden-sm col-md-2 numeric", "Pts/Shot"),
                    span(class = "hidden-xs hidden-sm col-md-1 numeric", "Lg Pts/Shot")
    ))
    
    for (i in 1:nrow(merged)) {
      html[[i + 2]] = div(class = paste("row", ifelse(i %% 2 == 0, "even", "odd")),
                          span(class = "col-xs-4 col-md-3 zone-label", merged$shot_zone_basic[i]),
                          span(class = "col-xs-2 col-md-1 numeric", merged$fgm[i]),
                          span(class = "col-xs-2 col-md-1 numeric", merged$fga[i]),
                          span(class = "col-xs-2 col-md-2 numeric", merged$pct_as_text[i]),
                          span(class = "col-xs-2 col-md-1 numeric", merged$lg_pct_as_text[i]),
                          span(class = "hidden-xs hidden-sm col-md-2 numeric", round(merged$points_per_shot[i], 2)),
                          span(class = "hidden-xs hidden-sm col-md-1 numeric", round(merged$lg_points_per_shot[i], 2))
      )
    }
    
    html[[length(html) + 1]] = div(class = "row overall",
                                   span(class = "col-xs-4 col-md-3 zone-label", "Overall"),
                                   span(class = "col-xs-2 col-md-1 numeric", overall$total_fgm),
                                   span(class = "col-xs-2 col-md-1 numeric", overall$total_fga),
                                   span(class = "col-xs-2 col-md-2 numeric", overall$pct_as_text),
                                   span(class = "col-xs-2 col-md-1 numeric", overall$lg_pct_as_text),
                                   span(class = "hidden-xs hidden-sm col-md-2 numeric", round(overall$points_per_shot, 2)),
                                   span(class = "hidden-xs hidden-sm col-md-1 numeric", round(overall$lg_points_per_shot, 2))
    )
    
    html
  })
})