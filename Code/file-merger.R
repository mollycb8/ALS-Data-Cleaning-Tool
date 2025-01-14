# ALS to AWQP Data Clean and Merge Tool
# AJ Brown, ansley.brown@colostate.edu
# Started: 13 July 2022
# Updated: 21 Feb 2023

# Tool to clean and merge multiple .htm files directly downloaded
# from the ALS global portal into one master file and create categories for
# further analysis.

# TODO:
# make this script a package for use in future analysis scripts

# Script work flow:
  # 0) Import libraries
  # 1) Define global variables
  # 1a) Working file_path
  # 1b) Set the default file directory
  # 1c) Define dictionaries for interpreting sample ID codes
  # 2) Define functions
  # 2a) map_values <-- a function to map sample ID text to dictionary values
  # 2b) import data
  # 2c) clean data
  # 2d) process data
  # 2e) execute previous functions
  # 2f) repeat for all files in a directory
  # 4) View resulting dataframe(s) for QA/QC
  # 3) Export data as csv

# Example code execution for users
# df_test <- returnSingleFile(path=file_path, export=FALSE)
# df_all <- returnAllFiles(d=directory, export=FALSE)
 




# Then take df_test or df_all and do whatever you want with it (e.g., graph)


# Import libraries
package.list <- c("magrittr",
                  "dplyr",
                  "readr",
                  "readxl",
                  "ggplot2",
                  "lattice",
                  "rvest",
                  "xml2",
                  "stringr",
                  'tidyverse',
                  'lubridate',
                  'stringr'
                  )
packageLoad <- function(packages){
  for (i in packages) {
    if (!require(i, character.only = TRUE)) {
      install.packages(i)
      library(i, character.only = TRUE)
    }
  }
}
packageLoad(package.list)

# Global Variables
 # Working file paths
  # For GitHub  Repo
directory <- "./Data"
tss_file_path <- './TSS/TSS_Master_2023.xlsx'

  # For sharepoint
# directory <- '../Web_Portal'
# tss_file_path <- '../../../../TSS General/2023/TSS_Master_2023.xlsx'

  # To choose file manually via popup
# file_path <- file.choose()
# Set the default file directory to the directory containing the selected file

tss_directory<- dirname(tss_file_path)
# file_path <- file.choose()
 # Set the default file directory to the directory containing the selected file

 # Dictionaries for interpreting sample ID codes
  # Add to these at needed for new locations, treatments, methods, etc.
location.dict <- c(
  "ARDEC 2200" = "A2",
  "ARDEC South - Conv" = "ASC",
  "ARDEC South - Org" = "ASO",
  "AVRC STAR" = c("AV", "AVST1", "AVST2", "AVCT1", "AVCT2"),
  "Barley" = "BAR",
  "Berthoud" = "BT",
  "Big Hollow" = "HOL",
  "Boulder Lake" = "BOL",
  "Below Stagecoach Dam" = "SCO",
  "Gunnison" = "GU",
  "Kerbel" = c("K", "KB", "ST1", "ST2", "CT1", "CT2", "MT1", "MT2", "INF"),
  "Legacy" = "LG",
  "Molina" = "MOL",
  "Morrison Creek" = "MOR",
  "Stage Coach Above" = "SCA",
  "Stage Coach In" = "SCI",
  "Stagecoach" = "SB",
  "The Ranch" = "TR", # Formerly, "Todd's Ranch"
  "Upper Yampa" = "UYM",
  "Yellow Jacket " = "YJ"
)

trt.dict <- c(
  "ST1" = c("ST1", "AVST1"),
  "ST2" = c("ST2", "AVST2"),
  "CT1" = c("CT1", "AVCT1"),
  "CT2" = c("CT2", "AVCT2"),
  "MT1" = "MT1",
  "MT2" = "MT2",
  "Inflow" = "INF",
  "River A" = "RVA",
  "River B" = "RVB",
  "River Middle" = "RVMID",
  "Piezometer East" = "PZE",
  "Piezometer West" = "PZW",
  "Tile Drainage River" = "TDR",
  "Tile Drainage Lake" = "TDL",
  "Confluence" = "CON",
  "Upstream of Bridge" = "UP",
  "Downstream of Bridge" = "DOWN",
  "Middle at Bridge" = "MID",
  "Arapahoe Natl. Forest" = "ANF",
  "Willow Creek" = "WC",
  "Duck Pond" = "DP",
  "Upper willow at @ culvert (swale)" = "CUL",
  "Fish Pond" = "FP",
  "Fire 2" = "FR2"
  )
method.dict <- c(
  "ISCO" = c("ISC", "IN", "OT"),
  "Low-Cost Sampler" = c("LC", "INLC", "OTLC"),
  "Grab Sample" = c("GB", "G1", "G2", "G3", "G4", "G5", "G6", "G7", "G8", "G9")
  )
eventType.dict <- c(
  "Inflow" = c("IN", "INLC", "IN1", "IN2", "IN3", "IN4", "IN5", "IN6", "IN7", 
    "IN8", "IN9"),
  "Outflow" = c("OUT", "OT", "OTLC")
  )
tssUnits.dict <- c(
  "TSS" = "mg/L",
  "EC" = "mS/cm",
  "pH" = "pH"
   )


# Define Private Functions (i.e., do not call them directly)
map_values <- function(text, dict) {
 # function to map sample ID text to dictionary values
  # Split the text by spaces
  text_values <- unlist(strsplit(text, "-"))

  # Map each value to the corresponding dictionary value
  mapped_values <- lapply(text_values, function(x) {
    for (key in names(dict)) {
      if (x %in% dict[[key]]) {
        return(key)
      }
    }
    return(NA)
  })

  # Combine the mapped values into a single vector
  combined_values <- unlist(mapped_values)

  # Remove any NAs
  combined_values <- combined_values[!is.na(combined_values)]

  # Return the first combined value (or NA if there are no values)
  if (length(combined_values) > 0) {
    return(combined_values[1])
  } else {
    return(NA)
  }
}

importData <- function(file_path) {
  # ALS exports data as xls, but it is actually htm,
   # so it requires some cleaning here.
  df <- read_html(file_path) %>% # read in html file
    html_table() %>% # convert to table
    data.frame() # convert to dataframe
  return(df) # return dataframe
}

importDataXls <- function(file_path) {
  # ALS exports meta data as xls. Very confusing.
   # so we have to import it differently
  df <- read_excel(file_path) %>% # read in html file
    data.frame() # convert to dataframe
  return(df) # return dataframe
}

cleanData <- function(df) {

   # Drop unnecessary rows containing the word "sample:"
  df <- df[!grepl("Sample:", df$SAMPLE.ID),] %>% 
    # other cleaning processes:
    mutate(
      # convert values containing "<" to 0
      RESULT = ifelse(grepl("<", RESULT), 0, RESULT),
      # remove "H" values     
      RESULT = gsub("H", "", RESULT),
      # remove "See Attached" values, code 9999 set for flagging in flagData()
      RESULT = gsub("See Attached", 9999, RESULT),
      # make results numeric
      RESULT = as.numeric(ifelse(RESULT == "N/A", NA, RESULT)),
      # remove the scentific notation from results
      RESULT = ifelse(!is.na(RESULT), format(RESULT, scientific = FALSE), NA),
      # create column to indicate if a result value was a non-detect
      non.detect = ifelse(RESULT == 0, TRUE, FALSE),
      # change "N/A" to NA in any column
      across(everything(), ~ ifelse(. == "N/A", NA, .))) %>%
    # convert select columns to numeric if needed
    mutate_at(c("RESULT",
                "DILUTION",
                "MDL",
                "RL",
                "PERCENT.MOISTURE",
                "PERCENT.SOLID"),
               as.numeric)
  

  
  
  
  return(df)
}

processData <- function(df) {
  # Process data to create new columns for analysis based on ID codes
    # create a list of columns for post-processing
  text_cols <- c("location.name",
                   "treatment.name",
                   "method.name",
                   "event.type")
    # create new columns based on ID codes
  df %>%
    mutate(
      # create duplicate column
      duplicate = ifelse(grepl("-D", SAMPLE.ID, fixed = FALSE), TRUE, FALSE),
      # create location name column based on Sample ID
      location.name = sapply(SAMPLE.ID,
                             function(x) map_values(x, location.dict)),
      # create treatment name column based on Sample ID
      treatment.name = sapply(SAMPLE.ID, function(x) map_values(x, trt.dict)),
      # create method name column based on Sample ID
      method.name = sapply(SAMPLE.ID, function(x) map_values(x, method.dict)),
      # create event type name column based on Sample ID
      event.type = sapply(SAMPLE.ID, function(x) map_values(x, eventType.dict))
      ) %>%
    # remove numbers from new columns due to dict mapping
     # caution: if there are more than 10 dict keys, this will not work
     # note: avoid naming future locations with numbers in the name
    mutate_at(c("location.name",
                "method.name",
                "event.type"), ~ gsub("[0-9]", "", .)) %>%
     # treatment.name needs special treament because of CT/MT/ST 1/2 having #'s
     # TODO: detect number first, then do this, else leave it alone
    mutate_at("treatment.name", ~ substr(., 1, nchar(.) - 1)) %>%
    # if event.type is NA, use "Point Sample" as default
    mutate(event.type = if_else(is.na(event.type), "Point Sample", event.type))
}

flagData <- function(df){
  # function to flag data for QA/QC after merging both htm and xls files
  # check water data for flags such as:
    # H = past hold time
    # J = minimum detection limit (MDL) > value > reporting limit (RL)
    # N = non-EPA method used
    # P = Ortho-P > Total P
    # more?
  # create flag column
  df$flag <- NA
  df %>%
    
    mutate(
      # search for J values
      flag = ifelse(RESULT > MDL & RESULT < RL, "J", NA),
      # identify samples past hold time, based on ALS "HOLD" column
      flag = ifelse(HOLD == 'Yes', paste0(flag, "H"), flag),
      # identify "See Attached" results as marked in cleanData()
      flag = ifelse(RESULT == 9999, "See Attached", flag),
      )
  return(df)
}

executeFxns <- function(file_path) {
  # execute all previous functions and return final dataframe
  df <- importData(file_path) %>%
    cleanData() %>%
    processData()
  #print(file_path)
  #print(names(df))
  #print(length(colnames(df)))   # Print column names after importData
  return(df)
}
dfTss <- function(tss_fp) {
  df <- read_excel(tss_fp, sheet = "MasterData") %>%
    select(c('Sample_ID', 'Collection_date', 'TSS_mg/L', 'pH', 'EC_mS/cm')) %>%
    rename("SAMPLE.ID" = "Sample_ID",
           "COLLECTED" = "Collection_date",
           "TSS" = "TSS_mg/L",
           "EC" = "EC_mS/cm") %>%
    filter(!(SAMPLE.ID %in% c("Stock Solution", "DI"))) %>%
    na.omit() %>%
    mutate(
      duplicate = ifelse(grepl("-D", SAMPLE.ID, fixed = FALSE), TRUE, FALSE),
      location.name = sapply(SAMPLE.ID, function(x) map_values(x, location.dict)),
      treatment.name = sapply(SAMPLE.ID, function(x) map_values(x, trt.dict)),
      method.name = sapply(SAMPLE.ID, function(x) map_values(x, method.dict)),
      event.type = sapply(SAMPLE.ID, function(x) map_values(x, eventType.dict))
    ) %>%
    gather(key = "ANALYTE", value = "RESULT", c(pH, TSS, EC )) %>%
    mutate_at(c("location.name", "method.name", "event.type"), ~ gsub("[0-9]", "", .)) %>%
    mutate_at("treatment.name", ~ substr(., 1, nchar(.) - 1)) %>%
    mutate(event.type = if_else(is.na(event.type), "Point Sample", event.type)) %>%
    mutate(METHOD = case_when(
      ANALYTE == "pH" ~ "EPA150.1",
      ANALYTE == "TSS" ~ "EPA160.2",
      ANALYTE == "EC" ~ "EPA120.1",
      TRUE ~ NA_character_)) %>%
     mutate(RESULT = as.numeric(RESULT)) %>%
    mutate(UNITS = tssUnits.dict[ANALYTE])
  
  return(df)
}

mergeFiles <- function(directory, tss_fp) {
  # import all htm files in the directory, merge, and return df
  print("Merging files...")
  file_list <- list.files(path = directory,
                          pattern = "*.xls", 
                          full.names = TRUE)
  print("Data files to be merged:")
  data_files <- file_list[!grepl("-Samples", file_list)]
  print(data_files)
  print("Metadata files to be merged:")
  meta_files <- file_list[grepl("-Samples", file_list)]
  print(meta_files)
  # merge data files
  df_data <- data_files %>%
    # pair and merge files here
    lapply(executeFxns) %>%
    bind_rows
  # merge metadata files
  df_meta <- meta_files %>%
    # pair and merge files here
    lapply(importDataXls) %>%
    bind_rows
  # merge data and metadata
  df_merge <- df_data %>%
    left_join(df_meta, by = 'SAMPLE.ID' ) %>%
    flagData()

  # change to posixct
  df_merge$COLLECTED <- as.POSIXct(df_merge$COLLECTED, format = '%d %b %Y %H:%M')
  # import TSS data to df w/ metadata
  df_tss <- dfTss(tss_fp)
  
  
  # merge tss data with als data
  df <- bind_rows(df_merge, df_tss) %>%
    filter(!grepl("Analysis", ANALYTE, ignore.case = TRUE)) 
  

  return(df)
  
}

# Define public functions (i.e., to be called by user)
returnSingleFile <- function(path = file_path, export = FALSE) {
  # return and optionally export a single file for QA/QC
  df <- executeFxns(path)
  if (export == TRUE) {
    write.csv(df, file = "single_file.csv", row.names = FALSE)
  }
  return(df)
}

returnAllFiles <- function(d = directory, tss_fp = tss_file_path, export = TRUE) {
  # return and optionally export all files for QA/QC
  df <- mergeFiles(d, tss_fp)
  # for debugging only; uncomment as necessary
  #View(df)
  if (export == TRUE) {
    write.csv(df, file = "all_files.csv", row.names = FALSE)
  }
  return(df)
}



