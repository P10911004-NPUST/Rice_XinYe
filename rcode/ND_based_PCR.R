rm(list = ls())
dev.off()

library(tidyverse)
library(Hmisc)
library(caret)
library(car)
library(plotly)
library(pls)

set.seed(512)

crop_season_year <- "2022"       # "2021" for single year or "2021_2022"
                                 # or "2021_2022" for two year

work_path <- dirname(getwd())
year_ <- paste("year", crop_season_year, sep = "_")
save_csv_path <- paste0(work_path, "/tidy_data")
save_figure_path <- paste(work_path, "result", year_, sep = "/")
windowsFonts(palatino = windowsFont("Palatino Linotype"))

se <- function(x){ sd(x) / sqrt(length(x)) }
max2 <- function(x){ max(x, na.rm = T) }
mean2 <- function(x){ mean(x, na.rm = T) }

lcc_data <- read.csv(
    paste0(work_path, "/tidy_data/all_LCC_data.csv")
)

lab_data <- read.csv(
    paste0(work_path, "/tidy_data/lab_data.csv")
)

lcc_data$DATE <- as.Date.character(lcc_data$DATE, format = "%Y-%m-%d")
lab_data$DATE <- as.Date.character(lab_data$DATE, format = "%Y-%m-%d")

lab_data <- lab_data%>% 
    group_by(DATE, DAT, TREAT, SAMP_PART, NO) %>% 
    summarise(DW = mean(DW),
              N = mean(N))

##################################################################################
################################ ND-based #######################################

widen_lcc <- lcc_data %>% 
    #filter(CHN == "Red") %>% 
    group_by(DATE, DAT, TREAT, NO, LCC, CHN) %>%    # Average the sampling points
    summarise(VALUE = mean2(VALUE)) %>% 
    pivot_wider(names_from = "LCC", values_from = "VALUE", names_prefix = "LCC") %>% 
    ungroup()

ND_based <- widen_lcc %>% 
    mutate(ND_LCC2 = (LCC6 - LCC2) / (LCC2 + LCC6),
           ND_LCC3 = (LCC6 - LCC3) / (LCC3 + LCC6),
           ND_LCC4 = (LCC6 - LCC4) / (LCC4 + LCC6),
           ND_LCC5 = (LCC6 - LCC5) / (LCC5 + LCC6),
           .keep = "unused")

widen_ND <- ND_based %>% 
    pivot_wider(names_from = CHN, values_from = ND_LCC2:ND_LCC5)

joinND <- widen_ND %>% 
    left_join(lab_data, by = c('DATE', 'DAT', 'TREAT', 'NO')) %>% 
    filter_all(all_vars(!(is.na(.)))) %>%
    filter(SAMP_PART == 'Leaf') %>% 
    select(-SAMP_PART, -DW) 

if(crop_season_year == "2021"){
    joinND <- filter(joinND, DATE < "2022-01-01") 
}

if(crop_season_year == "2022"){
    joinND <- filter(joinND, DATE > "2022-01-01") 
}

pcr_data <- joinND %>% 
    select(-DATE, -DAT, -TREAT, -NO) 

# ------------------------ PCR --------------------------------
pcr_mod <- pcr(N ~ ., data = pcr_data,
                 scale = T, validation = 'CV')

summary(pcr_mod)
plot(explvar(pcr_mod))

PVE <- data.frame(PVE = explvar(pcr_mod))
PVE <- PVE %>% 
    mutate(PC = row_number(),
           cumPVE = cumsum(PVE))

loading_ <- pcr_mod$loading.weights[1:ncol(pcr_data)-1, 1:ncol(pcr_data)-1]

write.csv(PVE, row.names = F,
          file = paste(save_figure_path, "ND_PCR_PVE.csv", sep = "/"))

select_ncomp <- 2

loading_ <- loading_[, 1:select_ncomp]

# ---------------------------- Validation -----------------

joinND <- joinND %>% 
    group_by(DATE, TREAT) %>% 
    mutate(row_num = row_number()) %>% 
    ungroup()

splitList <- createDataPartition(y = joinND$row_num,
                                 times = 1, p = .6, list = F)

training <- joinND[splitList, ] %>% 
    select(-DATE, -DAT, -TREAT, -NO, -row_num)

testing <- joinND[-splitList, ]%>% 
    select(-DATE, -DAT, -TREAT, -NO, -row_num)

pcr_mod_1 <- pcr(N ~ ., data = training, 
                 ncomp = select_ncomp, scale = T)

val <- predict(pcr_mod_1, newdata = testing[, 1:ncol(testing)-1], ncomp = select_ncomp)

val_table <- data.frame(Observed = testing$N,
                        Predicted = val[,1,1])

##################################################################################
##################################  Plot  ########################################

plot_data <- data.frame(Predicted = val_table$Predicted,
                        Observed = val_table$Observed)

plot_data <- plot_data %>%
    filter(Observed > mean(Observed) - sd(Observed) * 2 & 
               Observed < mean(Observed) + sd(Observed) * 2) %>% 
    filter(Predicted > mean(Predicted) - sd(Predicted) * 2 & 
               Predicted < mean(Predicted) + sd(Predicted) * 2) 

lin_mod <- lm(Observed ~ Predicted, data = plot_data, na.action = na.omit)
lin_summary <- summary(lin_mod)

corr_mod <- rcorr(as.matrix(plot_data))
corr_r <- corr_mod$r
corr_p <- corr_mod$P
Rsqr <- round(lin_summary$r.squared, 2)
p_value <- round(lin_summary$coefficients[2,4], 5)
slope <- round(lin_summary$coefficients[2,1], 2)
intercept <- round(lin_summary$coefficients[1,1], 2)
rmse0 <- round(with(plot_data, RMSE(Predicted, Observed, na.rm = T)), 2)

ifelse(intercept < 0,
       intercept <- paste('-', abs(intercept), sep = ' '),
       intercept <- paste('+', abs(intercept), sep = ' '))

if(p_value < 0.001){
    significant <- "***"
}else{
    if(p_value < 0.01){
        significant <- "**"
    }else{
        if(p_value < 0.05){
            significant <- "*"
        }else{
            significant <- "ns"
        }
    }
}

#--------------------------------------------------------------------------------

plot_device <- 'jpeg'
plot_unit <- 'cm'
plot_dpi <- 330
plot_height <- 10
plot_width <- 1.618*plot_height

xmin = round(min(plot_data$Observed) - abs(min(plot_data$Observed) / 100), 2)
xmax = round(max(plot_data$Observed) + abs(max(plot_data$Observed) / 100), 2)
xinterval = abs((xmax - xmin) / 5)

ymin = round(min(plot_data$Predicted) - abs(min(plot_data$Predicted) / 100), 2)
ymax = round(max(plot_data$Predicted) + abs(max(plot_data$Predicted) / 100), 2)
yinterval = round(abs((ymax - ymin) / 5), 2)

equation_x = xmax - (xinterval * 0.75)
equation_y = ymin + (yinterval * 1.5)
equation_interval = yinterval / 3

ggplot(plot_data, aes(Observed, Predicted)) +
    geom_point(size = 2, color = '#E65100') +
    geom_line(stat = 'smooth', formula = y ~ x, method = lm, se = FALSE,
                size = 1, color = '#4DD0E1', alpha = 0.7) +
    labs(x = 'Observed (%)', y = 'Predicted (%)') +
    scale_x_continuous(limits = c(xmin, xmax), n.breaks = 10) +
    scale_y_continuous(limits = c(ymin, ymax), n.breaks = 10) +
    annotate(geom = 'text', family = 'serif', size = 3, fontface = 'plain',
             x = equation_x,
             y = equation_y,
             label = bquote('y ='~.(slope)*'x'~.(intercept))) +
    annotate(geom = 'text', family = 'serif', size = 3, fontface = 'plain',
             x = equation_x,
             y = equation_y - equation_interval,
             label = bquote('R'^2~'='~.(Rsqr)^~.(significant))) +
    annotate(geom = 'text', family = 'serif', size = 3, fontface = 'plain',
             x = equation_x,
             y = equation_y - equation_interval - equation_interval*1.1,
             label = bquote('RMSE'~'='~.(rmse0))) +
    theme_bw() +
    theme(axis.title.x.bottom = element_text(margin = margin(t = 9)),
          axis.title.y.left = element_text(margin = margin(r = 9))) +
    theme(text = element_text(family = 'serif', size = 18, face = 'bold'))

ggsave(filename = paste0("ND_based_PCR_", crop_season_year, ".", plot_device),            
       path = save_figure_path,
       device = plot_device,
       dpi = plot_dpi,
       units = plot_unit,
       height = plot_height,
       width = plot_width)






















