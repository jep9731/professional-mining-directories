# Import libraries --------------------------------------------------------
library(reader)
library(tidyverse)
library(writexl)

# Import data -------------------------------------------------------------
stub <- read_csv("/Volumes/fsmresfiles/CNADC/Imaging_Core/Imaging/imaging_projects/Individuals/Joshua_Pasaye/R scripts/Tau_PET/ImagingCoreDatabase-Stub_DATA_2025-06-04_1233.csv")
tau_metrics <- read_csv("/Volumes/fsmresfiles/CNADC/Imaging_Core/Imaging/imaging_projects/Individuals/Joshua_Pasaye/R scripts/Tau_PET/ImagingCoreDatabase-ICTauPETReads_DATA_2025-06-04_1233.csv")

stub <- stub %>%
  select(global_id, ptid, case_num_tau_pet) %>%
  mutate(ptid = str_remove(ptid, "^0+"))

tau_metrics <- tau_metrics %>%
  select(global_id, tau_date, tau_ppa_visitid, study_affiliation_tau, tau_read_researcherclinician___2) %>%
  rename(has_clinical_read = tau_read_researcherclinician___2) %>%
  mutate(has_clinical_read = case_when(
    has_clinical_read == "1" ~ "Yes",
    TRUE ~ "No")
  )

# Merge data --------------------------------------------------------------
merged <- inner_join(stub, tau_metrics, by = "global_id")

merged_final <- merged %>%
  mutate(study_id = case_when(
    study_affiliation_tau == "ADRC_IC" ~ ptid,
    study_affiliation_tau == "PPA" ~ case_num_tau_pet,
    TRUE ~ ptid),
    study_id = if_else(str_detect(study_id, "^\\d{3}$"), str_pad(study_id, 4, pad = "0"), study_id),
    session_id = case_when(
      study_affiliation_tau == "PPA" & !is.na(tau_ppa_visitid) ~ str_c(study_id, "_t", tau_ppa_visitid),
      study_affiliation_tau == "ADRC_IC" ~ str_c(study_id, "_Tau"),
      TRUE ~ NA_character_
    ),
  .after = global_id) %>%
  arrange(desc(tau_date))

# Check for static --------------------------------------------------------
base_dir <- "/Volumes/fsmresfiles/CNADC/Imaging_Core/Imaging/imaging_raw" # create base directory

# Only look in IC sub directories
adc_ic_path   <- file.path(base_dir, "ADC_IC", "PET-Tau")
ic_static_dirs <- c()

if (dir.exists(adc_ic_path)) {
  subject_dirs <- list.dirs(adc_ic_path, recursive = FALSE, full.names = TRUE)
  
  for (subj in subject_dirs) {
    level1_dirs <- list.dirs(subj, recursive = FALSE, full.names = TRUE)
    
    for (inner in level1_dirs) {
      level2_dirs <- list.dirs(inner, recursive = FALSE, full.names = TRUE)
      matches <- level2_dirs[grepl("TAU_30minStatic*", basename(level2_dirs))]
      ic_static_dirs <- c(ic_static_dirs, matches)
    }
  }
}

# Output result
print(ic_static_dirs)

# Only look in PPA sub directories
ppa_path <- file.path(base_dir, "PPA", "PET-Tau")
ppa_static_dirs <- c()

# Loop through PPA directory
if (dir.exists(ppa_path)) {
  visit_dirs <- list.dirs(ppa_path, recursive = FALSE, full.names = TRUE)  # t1-t4 folders
  
  for (visit in visit_dirs) {
    subject_dirs <- list.dirs(visit, recursive = FALSE, full.names = TRUE)  # subject ID folders
    
    for (subject in subject_dirs) {
      inner_dirs <- list.dirs(subject, recursive = FALSE, full.names = TRUE)  # one more level
      
      for (inner in inner_dirs) {
        static_dirs <- list.dirs(inner, recursive = FALSE, full.names = TRUE)
        matches <- static_dirs[grepl("(TAU_30minStatic*|BrainStatic_*)", basename(static_dirs))]
        ppa_static_dirs <- c(ppa_static_dirs, matches)
      }
    }
  }
}

# Output result
print(ppa_static_dirs)

# Combine results
all_static_dirs <- c(ic_static_dirs, ppa_static_dirs)
print(all_static_dirs)

# Paste ID & path ---------------------------------------------------------
static_info <- tibble(full_path = all_static_dirs) %>%
  mutate(
    raw_folder_name = basename(dirname(dirname(full_path))),
    session_id = case_when(
      str_detect(full_path, "ADC_IC") ~ raw_folder_name,
      str_detect(full_path, "PPA") ~ str_extract(raw_folder_name, "X\\d{2}.*?[Tt](\\d)") %>%
        str_replace(".*(X\\d{2}).*?[Tt](\\d)", "\\1_t\\2"),
      TRUE ~ NA_character_
    ),
    study_id = case_when(
      str_detect(full_path, "ADC_IC") ~ str_remove_all(raw_folder_name, "_Tau"),
      str_detect(full_path, "PPA") ~ str_extract(raw_folder_name, "X\\d{2}"),
      TRUE ~ NA_character_
    )
  )

# Combine static_info with merged_final
static_info_merged <- inner_join(merged_final, static_info, by = c("study_id", "session_id"), relationship = "many-to-many")

static_final <- static_info_merged %>%
  select(global_id, ptid, study_id, tau_date, study_affiliation_tau,
         has_clinical_read, session_id, full_path) %>%
  arrange(ptid)

# Write to CSV
write.csv(static_final, "/Volumes/fsmresfiles/CNADC/Imaging_Core/Imaging/imaging_projects/Individuals/Joshua_Pasaye/R scripts/Tau_PET/all_tau_statics.csv", row.names = FALSE)

# Create new directories for data -----------------------------------------
data_dir <- "/Volumes/fsmresfiles/CNADC/Imaging_Core/Imaging/imaging_projects/Individuals/Joshua_Pasaye/R scripts/Tau_PET/data"

for (i in seq_len(nrow(static_final))) {
  subject <- static_final$ptid[i]
  session <- static_final$session_id[i]
  static_src <- static_final$full_path[i]  # This is the Static directory path
  
  # Construct target directory paths
  subject_dir <- file.path(data_dir, paste0("sub-", subject))
  session_dir <- file.path(subject_dir, paste0("ses-", session))
  dest_static <- file.path(session_dir, basename(static_src))  # Keep same folder name
  
  # Create folders
  if (!dir.exists(session_dir)) {
    dir.create(session_dir, recursive = TRUE, showWarnings = FALSE)
  }
  
  # Copy Static directory
  if (dir.exists(static_src) && !dir.exists(dest_static)) {
    file.copy(from = static_src, to = session_dir, recursive = TRUE)
  }
}

# Add new ids to excel file -----------------------------------------------
library(readxl)

# Read in excel file with multiple sheets
sheet_names <- excel_sheets("Tauvid Clinical Reads 2025.xlsx")
read_list <- lapply(sheet_names, read_excel, path = "Tauvid Clinical Reads 2025.xlsx")
names(read_list) <- sheet_names
list2env(read_list, .GlobalEnv)

# Combine datasets
all_reads <- bind_rows(Ryan, Hatice, Derek, Todd) %>% 
  distinct(`Study label (four digit number)`)

# Find non-matching IDs
new_ids <- static_final %>%
  filter(!(ptid %in% all_reads$`Study label (four digit number)`)) %>%
  select(ptid, session_id) %>%
  rename(`Study label (four digit number)` = ptid,
         Session_id = session_id)

# Append new IDs
Ryan <- bind_rows(Ryan, new_ids)
Hatice <- bind_rows(Hatice, new_ids)
Derek <- bind_rows(Derek, new_ids)
Todd <- bind_rows(Todd, new_ids)

# Reorder columns
Ryan <- Ryan %>% 
  select(`Study label (four digit number)`, Session_id, `Read (1 for positive, 0 for negative)`) %>%
  mutate(
    Session_id = ifelse(is.na(Session_id), paste0(`Study label (four digit number)`, "_Tau"), Session_id)
         )

Hatice <- Hatice %>% 
  select(`Study label (four digit number)`, Session_id, `Read (1 for positive, 0 for negative)`) %>%
  mutate(
    Session_id = ifelse(is.na(Session_id), paste0(`Study label (four digit number)`, "_Tau"), Session_id)
  )

Derek <- Derek %>% 
  select(`Study label (four digit number)`, Session_id, `Read (1 for positive, 0 for negative)`, ...3, ...4) %>%
  mutate(
    Session_id = ifelse(is.na(Session_id), paste0(`Study label (four digit number)`, "_Tau"), Session_id)
  ) %>%
  rename(" " = ...3, "  " = ...4)

Todd <- Todd %>% 
  select(`Study label (four digit number)`, Session_id, `Read (1 for positive, 0 for negative)`) %>%
  mutate(
    Session_id = ifelse(is.na(Session_id), paste0(`Study label (four digit number)`, "_Tau"), Session_id)
  )

# Write to excel
library(openxlsx)

# Create a workbook
wb <- createWorkbook()

# Add sheets and write data
addWorksheet(wb, "Ryan")
writeData(wb, "Ryan", Ryan)

addWorksheet(wb, "Hatice")
writeData(wb, "Hatice", Hatice)

addWorksheet(wb, "Derek")
writeData(wb, "Derek", Derek)

addWorksheet(wb, "Todd")
writeData(wb, "Todd", Todd)

# Save workbook
saveWorkbook(wb, "Tauvid Clinical Reads 2025_updated_6.5.25.xlsx", overwrite = TRUE)
