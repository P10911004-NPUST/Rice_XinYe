rm(list = ls())

library(readxl)
library(readr)

work_path <- dirname(getwd())
save_csv_path <- paste0(work_path, "/tidy_data")

rawdata_list <- list.files(paste0(work_path, "/rawdata"), pattern = "202", full.names = T)
print(rawdata_list)

df <- data.frame()
for(i in rawdata_list){
    inFile <- list.files(i, full.names = T)

    for(j in inFile){
        
        if(endsWith(j, ".xlsx")){
            df0 <- read_excel(j)
        }else{
            if(endsWith(j, ".csv")){
                df0 <- read_csv(j, col_types = cols())
            }else{
                print("File format != .csv | .xlsx")
            }
        }
        
        df <- rbind(df, df0)
    }
}

head(df)

attach(df, warn.conflicts = F)
par(mfrow = c(2, 4))
barplot(table(DATE), main = 'DATE')
barplot(table(DAT), main = "DAT")
barplot(table(TREAT), main = "TREAT")
barplot(table(NO), main = "NO")
barplot(table(SP), main = "SP")
barplot(table(LCC), main = "LCC")
barplot(table(CHN), main = "CHN")
hist(VALUE, main = "VALUE")
detach(df)

write.csv(df, row.names = F, 
          file = paste(save_csv_path, "all_LCC_data.csv", sep = "/"))


lab_data <- read_excel(paste0(work_path, "/rawdata/rice_N_DW.xlsx"))
head(lab_data)
lab_data$DATE <- with(lab_data,
    case_when(DATE == as.Date('2022-05-10') ~ as.Date('2022-05-09'),
              DATE == as.Date('2022-05-17') ~ as.Date('2022-05-16'),
              TRUE ~ as.Date(DATE)))

write.csv(lab_data, row.names = F,
          file = paste(save_csv_path, "lab_data.csv", sep = "/"))

attach(lab_data, warn.conflicts = F)
par(mfrow = c(2, 4))
barplot(table(DATE), main = 'DATE')
barplot(table(DAT), main = "DAT")
barplot(table(TREAT), main = "TREAT")
barplot(table(NO), main = "NO")
barplot(table(SAMP_PART), main = "SAMP_PART")
hist(DW, main = "DW")
hist(N, main = "N")
detach(lab_data)

table(df$DATE)
table(lab_data$DATE)

table(df$DAT)
table(lab_data$DAT)

