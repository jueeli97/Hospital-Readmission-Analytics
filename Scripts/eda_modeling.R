


# 2. Load libraries
library(dplyr)
library(ggplot2)
library(caret)
library(pROC)

# 3. Load clean data
df <- read.csv("Data/processed/diabetes_readmission_clean.csv")

# Quick structure check
str(df)

# -----------------------------
# BASIC EDA
# -----------------------------

# Overall 30-day readmission rate
overall_rate <- mean(df$readmit_30 == 1)
cat("Overall 30-day readmission rate:", round(overall_rate * 100, 2), "%\n")

# Readmission by gender
df %>%
  group_by(gender) %>%
  summarise(
    readmit_rate = mean(readmit_30 == 1),
    n = n()
  ) %>%
  arrange(desc(readmit_rate)) %>%
  print()

# Readmission by age group
df_age <- df %>%
  mutate(age_group = cut(
    age_mid,
    breaks = c(0, 30, 45, 60, 75, 100),
    labels = c("0-30", "31-45", "46-60", "61-75", "76+")
  )) %>%
  group_by(age_group) %>%
  summarise(readmit_rate = mean(readmit_30 == 1),
            n = n())

print(df_age)

# Optional: plot readmission rate by age group
ggplot(df_age, aes(x = age_group, y = readmit_rate)) +
  geom_col() +
  labs(title = "30-day Readmission Rate by Age Group",
       x = "Age Group",
       y = "Readmission Rate")

# -----------------------------
# MODELING – LOGISTIC REGRESSION
# -----------------------------

# Prepare data for modeling
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

# Convert to factors where needed
df_model$readmit_30 <- factor(df_model$readmit_30, levels = c(0, 1))
df_model$gender <- factor(df_model$gender)

set.seed(123)

train_idx <- createDataPartition(df_model$readmit_30, p = 0.7, list = FALSE)
train <- df_model[train_idx, ]
test  <- df_model[-train_idx, ]

# Fit logistic regression
logit_model <- glm(
  readmit_30 ~ .,
  data = train,
  family = binomial
)

summary(logit_model)

# Predict probabilities on test set
test$pred_prob <- predict(logit_model, newdata = test, type = "response")

# Convert probabilities to class labels (0.5 threshold)
test$pred_class <- ifelse(test$pred_prob >= 0.5, 1, 0)
test$pred_class <- factor(test$pred_class, levels = c(0, 1))

# Confusion matrix
cm <- confusionMatrix(test$pred_class, test$readmit_30, positive = "1")
print(cm)

# ROC & AUC
roc_obj <- roc(
  response = test$readmit_30,
  predictor = test$pred_prob,
  levels = c("0", "1")
)

auc_value <- auc(roc_obj)
cat("AUC:", auc_value, "\n")

# -----------------------------
# Save model if you want to reuse outside this script
# -----------------------------
saveRDS(logit_model, "Data/processed/logit_model_readmit30.rds")
cat("Model saved to Data/processed/logit_model_readmit30.rds\n")
