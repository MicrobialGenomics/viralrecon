#!/usr/bin/bash

### 2021-01-15 08:30:08 MNJ 
### Will either:
# - Take a txt file with the samples file used by viralrecon (with names and fastq locations) to run the nextflow pipeline
# - Scan s3 bucket for fastq, check if they are analyzed, if not select those that have not been analyzed.

### After Analysis DB needs to be updated with the analysis info (to be defined) and files for GISAID/ENA upload need to be created

