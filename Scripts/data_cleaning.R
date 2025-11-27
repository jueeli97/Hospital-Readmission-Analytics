library(dplyr)



# 2. Load raw data and convert "?" to NA directly
df_raw <- read.csv(
  "Data/diabetic_data.csv",
  na.strings = c("?", "NA", "")
)

# 3. Clean + transform
df_clean <- df_raw %>%
  # Keep only Male / Female
  filter(gender %in% c("Male", "Female")) %>%
  
  # Binary target: 1 = readmitted within 30 days, 0 = otherwise
  mutate(
    readmit_30 = ifelse(readmitted == "<30", 1, 0),
    
    # Convert age bracket to numeric midpoint
    age_mid = dplyr::case_when(
      age == "[0-10)"   ~ 5,
      age == "[10-20)"  ~ 15,
      age == "[20-30)"  ~ 25,
      age == "[30-40)"  ~ 35,
      age == "[40-50)"  ~ 45,
      age == "[50-60)"  ~ 55,
      age == "[60-70)"  ~ 65,
      age == "[70-80)"  ~ 75,
      age == "[80-90)"  ~ 85,
      age == "[90-100)" ~ 95,
      TRUE ~ NA_real_
    )
  ) %>%
  
  # Make sure key numeric columns are numeric
  mutate(across(
    c(time_in_hospital,
      num_lab_procedures,
      num_procedures,
      num_medications,
      number_outpatient,
      number_emergency,
      number_inpatient),
    as.numeric
  )) %>%
  
  # Keep only the columns we actually need for modeling + Shiny
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
    number_inpatient,
    A1Cresult,
    max_glu_serum
  ) %>%
  
  # Drop rows missing basic essentials
  filter(
    !is.na(age_mid),
    !is.na(time_in_hospital)
  )

# 4. Create processed folder if it doesn't exist
if (!dir.exists("data/processed")) {
  dir.create("data/processed", recursive = TRUE)
}

# 5. Save cleaned data
write.csv(
  df_clean,
  "data/processed/diabetes_readmission_clean.csv",
  row.names = FALSE
)

cat("Cleaning complete! Saved to data/processed/diabetes_readmission_clean.csv\n")



df_clean <- read.csv("Data/processed/diabetes_readmission_clean.csv")
str(df_clean)
head(df_clean)
