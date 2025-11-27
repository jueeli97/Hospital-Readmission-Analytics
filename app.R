#install.packages("shinydashboard")

library(shiny)
library(shinydashboard)
library(dplyr)
library(ggplot2)
library(DT)
library(scales) 



# Load clean data
df <- read.csv("data/processed/diabetes_readmission_clean.csv")

# Prepare modeling data (same as in 02_eda_modeling.R)
df_model <- df %>%
  select(
    readmit_30,
    age_mid,
    gender,
    time_in_hospital,
    num_lab_procedures,
    num_procedures,
    num_medications,
    number_outpatient,
    number_emergency,
    number_inpatient
  ) %>%
  na.omit()

df_model$readmit_30 <- factor(df_model$readmit_30, levels = c(0, 1))
df_model$gender <- factor(df_model$gender)

# Fit logistic model globally (so it's reused in Risk Calculator)
logit_model <- glm(
  readmit_30 ~ .,
  data = df_model,
  family = binomial
)

# UI
ui <- dashboardPage(
  dashboardHeader(title = "Hospital Readmission Analytics"),
  
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Risk Calculator", tabName = "risk", icon = icon("heartbeat")),
      menuItem("Data Explorer", tabName = "data", icon = icon("table"))
    )
  ),
  
  dashboardBody(
    tabItems(
      
      # ------------------- DASHBOARD --------------------
      tabItem(tabName = "dashboard",
              
              fluidRow(
                box(width = 12, title = "Filters", status = "primary", solidHeader = TRUE,
                    sliderInput("age_range", "Age range:",
                                min = min(df$age_mid), max = max(df$age_mid),
                                value = c(40, 75)),
                    checkboxGroupInput("gender_filter", "Gender:",
                                       choices = c("Male", "Female"),
                                       selected = c("Male", "Female"))
                )
              ),
              
              fluidRow(
                infoBox("Total Patients", textOutput("kpi_patients"), 
                        icon = icon("users"), color = "blue", fill = TRUE),
                infoBox("30-day Readmission Rate", textOutput("kpi_readmit"), 
                        icon = icon("heartbeat"), color = "green", fill = TRUE),
                infoBox("Avg Length of Stay", textOutput("kpi_los"), 
                        icon = icon("clock"), color = "yellow", fill = TRUE)
              ),
              
              fluidRow(
                box(width = 6, title = "Readmission by Age Group", status = "primary",
                    solidHeader = TRUE, plotOutput("plot_readmit_age")),
                
                box(width = 6, title = "Readmission by Prior Inpatient Visits", status = "primary",
                    solidHeader = TRUE, plotOutput("plot_readmit_inpatient"))
              )
      ),
      
      # ------------------- RISK CALCULATOR --------------------
      tabItem(tabName = "risk",
              box(width = 4, title = "Inputs", status = "warning", solidHeader = TRUE,
                  numericInput("inp_age", "Age:", 60),
                  selectInput("inp_gender", "Gender:", c("Male", "Female")),
                  numericInput("inp_los", "Length of stay:", 3),
                  numericInput("inp_labs", "Lab procedures:", 40),
                  numericInput("inp_procs", "Procedures:", 1),
                  numericInput("inp_meds", "Medications:", 10),
                  numericInput("inp_out", "Outpatient visits:", 0),
                  numericInput("inp_emerg", "Emergency visits:", 0),
                  numericInput("inp_inpat", "Inpatient visits:", 0),
                  actionButton("calc_btn", "Calculate Risk", class = "btn btn-primary")
              ),
              
              box(width = 8, title = "Predicted 30-day Readmission Risk",
                  status = "danger", solidHeader = TRUE,
                  h2(textOutput("risk_text")),
                  plotOutput("risk_bar"))
      ),
      
      # ------------------- DATA EXPLORER --------------------
      tabItem(tabName = "data",
              box(width = 12, title = "Patient Data", status = "primary", solidHeader = TRUE,
                  DTOutput("table_patients")))
    )
  )
)

# SERVER
server <- function(input, output, session) {
  
  # Reactive filtered data for Dashboard
  filtered_df <- reactive({
    df %>%
      filter(
        age_mid >= input$age_range[1],
        age_mid <= input$age_range[2],
        gender %in% input$gender_filter
      )
  })
  
  # KPIs
  output$kpi_patients <- renderText({
    paste("Total Patients:", nrow(filtered_df()))
  })
  
  output$kpi_readmit <- renderText({
    rate <- mean(filtered_df()$readmit_30 == 1, na.rm = TRUE)
    paste("30-day Readmission Rate:", round(rate * 100, 1), "%")
  })
  
  output$kpi_los <- renderText({
    avg_los <- mean(filtered_df()$time_in_hospital, na.rm = TRUE)
    paste("Avg Length of Stay:", round(avg_los, 1), "days")
  })
  
  # Plot: Readmission by age group
  output$plot_readmit_age <- renderPlot({
    filtered_df() %>%
      mutate(age_group = cut(
        age_mid,
        breaks = c(0, 30, 45, 60, 75, 100),
        labels = c("0-30", "31-45", "46-60", "61-75", "76+")
      )) %>%
      group_by(age_group) %>%
      summarise(readmit_rate = mean(readmit_30 == 1, na.rm = TRUE),
                .groups = "drop") %>%
      ggplot(aes(x = age_group, y = readmit_rate)) +
      geom_col(fill = "#3c8dbc") +
      scale_y_continuous(
        labels = percent_format(accuracy = 1),
        limits = c(0, NA)
      ) +
      labs(
        title = "30-day Readmission Rate by Age Group",
        x = "Age Group",
        y = "Readmission Rate (%)"
      ) +
      theme_minimal() +
      theme(
        panel.grid.minor = element_blank(),
        text = element_text(size = 12)
      )
  })
  
  
  # Plot: Readmission by prior inpatient visits
  output$plot_readmit_inpatient <- renderPlot({
    filtered_df() %>%
      mutate(inpatient_bucket = pmin(number_inpatient, 5)) %>%  # cap at 5+
      group_by(inpatient_bucket) %>%
      summarise(readmit_rate = mean(readmit_30 == 1, na.rm = TRUE),
                .groups = "drop") %>%
      ggplot(aes(x = as.factor(inpatient_bucket), y = readmit_rate)) +
      geom_col(fill = "#3c8dbc") +
      scale_y_continuous(
        labels = percent_format(accuracy = 1),
        limits = c(0, NA)
      ) +
      labs(
        title = "Readmission Rate by Prior Inpatient Visits",
        x = "Prior Inpatient Visits (capped at 5+)",
        y = "Readmission Rate (%)"
      ) +
      theme_minimal() +
      theme(
        panel.grid.minor = element_blank(),
        text = element_text(size = 12)
      )
  })
  
  
  # Risk Calculator logic
  observeEvent(input$calc_btn, {
    new_patient <- data.frame(
      age_mid = input$inp_age,
      gender = factor(input$inp_gender, levels = levels(df_model$gender)),
      time_in_hospital = input$inp_los,
      num_lab_procedures = input$inp_labs,
      num_procedures = input$inp_procs,
      num_medications = input$inp_meds,
      number_outpatient = input$inp_out,
      number_emergency = input$inp_emerg,
      number_inpatient = input$inp_inpat
    )
    
    prob <- predict(logit_model, newdata = new_patient, type = "response")
    
    risk_label <- ifelse(
      prob < 0.3, "Low",
      ifelse(prob < 0.6, "Medium", "High")
    )
    
    output$risk_text <- renderText({
      paste0(round(prob * 100, 1), "% (", risk_label, " risk)")
    })
    
    output$risk_bar <- renderPlot({
      ggplot(data.frame(prob = prob), aes(x = "", y = prob)) +
        geom_col(fill = "#3c8dbc") +
        ylim(0, 1) +
        labs(y = "Predicted Readmission Probability", x = "") +
        coord_flip()
    }) 
  })
  
  # Data Explorer
  output$table_patients <- renderDT({
    datatable(
      df %>%
        select(
          readmit_30,
          age_mid,
          gender,
          time_in_hospital,
          num_medications,
          number_outpatient,
          number_emergency,
          number_inpatient
        ),
      options = list(pageLength = 10)
    )
  })
}

shinyApp(ui, server)
