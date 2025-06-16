# ⛏️ Mining Directories: Tau PET Static Imaging Pipeline

This repository contains a script to extract and process static tau PET scan records from structured imaging data. It is part of the Imaging Core’s internal pipeline for validating longitudinal PET imaging directories.

---

## 📜 Script Summary

### 📂 `tPET_static.R`

This script performs:
- Static scan extraction from multi-source directories
- Directory name harmonization and tracer/phase validation
- Summary statistics by scan type and participant

---

## 📁 Required Data Files (Internal Access Only)

> 🔒 These files reside in a **shared lab directory** accessible only to approved Imaging Core personnel. Place them in a local `data/` folder when running this script.

| Filename                                                                 | Description                                      |
|--------------------------------------------------------------------------|--------------------------------------------------|
| `ImagingCoreDatabase-Stub_DATA_2025-06-04_1233.csv`                      | Participant Demographic information                |
| `ImagingCoreDatabase-ICTauPETReads_DATA_2025-06-04_1233.csv`            | Clinical read summaries for tau PET              |

---

## ▶️ How to Run

1. Open `tPET_static.R` in **RStudio**.
2. Install required R packages (if not already):
   ```r
   install.packages(c("dplyr", "stringr", "readr"))
