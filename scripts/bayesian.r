beta <- c(-5.5251e+00,  5.3506e+00,  7.3302e-01, -6.3526e-01,
          5.6928e-01,  6.2498e+00, -1.0087e-03)

startDate <- as.Date("2020-3-2")

logistic <- function (x) 1 / (1 + exp(-x))

pred <- function (case_ir, death_r, log_gdp_ppp, date) {
  death_r <- death_r + (death_r == 0) * 1e-7
  logistic(beta[1]*log(case_ir) + beta[2]*log(death_r) +
           (beta[3] + beta[4]*log(case_ir) + beta[5]*log(death_r)) * log_gdp_ppp +
           beta[6] + beta[7] * date)
}

prediction_df <- read.csv("source-data/cases_deaths_gdp.csv")
prediction_df$date <- as.Date(prediction_df$date)
prediction_df <- prediction_df[order(prediction_df$date), ]

prediction_df$day <- as.integer(prediction_df$date - startDate)

library(runner)
make_average <- function(x, n){
  temp <- x
  for(i in 1:length(x)){
    x[i] <- mean(temp[max(c(1, i-n)):min(c(length(x), i+n))], na.rm = T)
  }
  x
}

prediction_df$pred_ir <- pred(prediction_df$case_ir, prediction_df$death_r, prediction_df$log_gdp_ppp, prediction_df$day)

prediction_df$pred_ir_low <- predict(lm_model, newdata = prediction_df, interval = "confidence")[, 2]
prediction_df$pred_ir_high <- predict(lm_model, newdata = prediction_df, interval = "confidence")[, 3]

prediction_df$pred_ir_low[prediction_df$pred_ir_low < 0] <- 0
prediction_df$pred_ir_high[prediction_df$pred_ir_high < 0] <- 0

prediction_df$pred_ir <- ave(prediction_df$pred_ir, prediction_df$iso3c, FUN = function(x) max_run(make_average(x, n = 5)))
prediction_df$pred_ir_low <- ave(prediction_df$pred_ir_low, prediction_df$iso3c, FUN = function(x) max_run(make_average(x, n = 5)))
prediction_df$pred_ir_high <- ave(prediction_df$pred_ir_high, prediction_df$iso3c, FUN = function(x) max_run(make_average(x, n = 5)))

# From predicted sero-prevalence rates, we extract implied case counts
prediction_df$pred_cases <- prediction_df$pred_ir*prediction_df$population
prediction_df$pred_cases_low <- prediction_df$pred_ir_low*prediction_df$population
prediction_df$pred_cases_high <- prediction_df$pred_ir_high*prediction_df$population

# The following five lines creates world totals:
prediction_df$world_cases <- ave(prediction_df$cases, prediction_df$date, FUN = sum)
prediction_df$pred_world_cases <- ave(prediction_df$pred_cases, prediction_df$date, FUN = sum)
prediction_df$pred_world_cases_low <- ave(prediction_df$pred_cases_low, prediction_df$date, FUN = sum)
prediction_df$pred_world_cases_high <- ave(prediction_df$pred_cases_high, prediction_df$date, FUN = sum)

# This re-produces our inset plot:
library(ggplot2)
ggplot(prediction_df[!duplicated(prediction_df$date), ],
       aes(x=as.Date(date), ymin = 0))+geom_ribbon(aes(ymax=pred_world_cases, fill = "Probably Infected, World"))+
  theme_minimal()+geom_ribbon(aes(ymin = 0, ymax = world_cases, fill = "Reported Cases, World"))+
  geom_line(aes(y=pred_world_cases_low), col = "white")+
  geom_line(aes(y=pred_world_cases_high), col = "black")+
  scale_y_continuous(labels = scales::comma)+
  theme(legend.title = element_blank(), legend.position = "bottom")+xlab("")+ylab("")
