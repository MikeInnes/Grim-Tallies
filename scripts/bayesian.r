beta <- c(9.9029, -3.3733,  4.3080,  1.2049, -0.4126,  0.4739, -0.0366)

startDate <- as.Date("2020-3-2")

logistic <- function (x) 1 / (1 + exp(-x))
logit <- function (x) log(x / (1 - x))

pred <- function (case_ir, death_r, log_gdp_ppp, date, pop) {
  death_r <- death_r + 1e-5
  logistic(beta[1] +
           beta[2]*logit(case_ir) + beta[3]*logit(death_r) +
           (beta[4] + beta[5]*logit(case_ir) + beta[6]*logit(death_r)) * log_gdp_ppp +
           beta[7] * date/30)
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

prediction_df$pred_ir <- pred(prediction_df$case_ir, prediction_df$death_r, prediction_df$log_gdp_ppp, prediction_df$day, prediction_df$population)

prediction_df$pred_ir_low <- qbinom(0.05, 1000, prediction_df$pred_ir)/1000
prediction_df$pred_ir_high <- qbinom(0.95, 1000, prediction_df$pred_ir)/1000

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
  # geom_line(aes(y=pred_world_cases_low), col = "white")+
  # geom_line(aes(y=pred_world_cases_high), col = "black")+
  scale_y_continuous(labels = scales::comma)+
  theme(legend.title = element_blank(), legend.position = "bottom")+xlab("")+ylab("")

latest <- prediction_df[prediction_df$date == max(prediction_df$date),]
# latest <- latest[latest$pred_ir > 0.8,]

ggplot(latest, aes(x=country,y=pred_ir)) + geom_bar(stat="identity")

# To generate the large plot, we first-differences and by continent and a select few large countries:

# These lines define our groups (colors in the large plot)
prediction_df$continents_plus <- prediction_df$continent
prediction_df$continents_plus[prediction_df$country == "United States"] <- "United States"
prediction_df$continents_plus[prediction_df$country == "China"] <- "China"
prediction_df$continents_plus[prediction_df$country == "India"] <- "India"
prediction_df$continents_plus[prediction_df$country == "Brazil"] <- "Brazil"

# This function takes first differences by country and sums countries together by day and group: 
big_chart_data <- function(prediction_df, grouping = "continent_plus"){
  
  prediction_df$region <- prediction_df[, grouping]
  
  regions <- prediction_df
  
  regions$region_cases <- ave(regions$cases, paste0(regions$date, "_", regions$region), FUN = sum)
  regions$pred_region_cases <- ave(regions$pred_cases, paste0(regions$date, "_", regions$region), FUN = sum)
  regions$pred_region_cases_low <- ave(regions$pred_cases_low, paste0(regions$date, "_", regions$region), FUN = sum)
  regions$pred_region_cases_high <- ave(regions$pred_cases_high, paste0(regions$date, "_", regions$region), FUN = sum)
  
  new_cases_fun <- function(x) {
    x <- x - c(0, x)[1:length(x)]
    x <- make_average(x, n = 10)
    x }
  regions <- regions[!duplicated(paste0(regions$date, "_", regions$region)), ]
  
  regions$pred_region_cases <- ave(regions$pred_region_cases, regions$region, FUN = function(x) make_average(x, n = 10))
  regions$pred_region_cases_low <- ave(regions$pred_region_cases_low, regions$region, FUN = function(x) make_average(x, n = 10))
  regions$pred_region_cases_high <- ave(regions$pred_region_cases_high, regions$region, FUN = function(x) make_average(x, n = 10))
  
  regions$new_cases <- ave(regions$region_cases, regions$region, FUN = new_cases_fun)
  regions$new_pred_cases <- ave(regions$pred_region_cases, regions$region, FUN = new_cases_fun)
  regions$new_pred_cases_high <- ave(regions$pred_region_cases_high, regions$region, FUN = new_cases_fun)
  regions$new_pred_cases_low <- ave(regions$pred_region_cases_low, regions$region, FUN = new_cases_fun)
  return(regions)}
continents_plus <- big_chart_data(prediction_df, grouping = "continents_plus") # This runs the above function

# This reproduces our first large plot:
ggplot(continents_plus, 
       aes(x=date, ymin = 0))+geom_area(aes(y=-new_pred_cases, fill = continents_plus), col = "white")+
  theme_minimal()+geom_ribbon(aes(ymin = 0, ymax = -new_cases, fill = "Reported Cases"))+
  #  geom_line(aes(y=new_pred_cases_high), col = "white")+
  # geom_line(aes(y=new_pred_cases_low), col = "black")+
  scale_y_continuous(labels = scales::comma)+ylab("")+
  theme(legend.title = element_blank(), legend.position = "bottom")+xlab("")

