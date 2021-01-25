#!/usr/bin/bash

### 2021-01-15 08:30:08 MNJ 
### Will either:
# - Take a txt file with the samples file used by viralrecon (with names and fastq locations) to run the nextflow pipeline
# - Scan s3 bucket for fastq, check if they are analyzed, if not select those that have not been analyzed.

### After Analysis DB needs to be updated with the analysis info (to be defined) and files for GISAID/ENA upload need to be created

### Where to locate control layer with the no-repeat analysis
### nextflow manages this based on scratch dir contents, but these are remove in 15 days.

### - opts s3 Dir or single file (auto-detect)
###    --> Need to generate samples.txt file from s3Dir content

### - file with s3 routes
###    --
s3Bucket="s3://***REMOVED***/"

NFSamplesFile=$1
NFOutDir=$2

#### Need to source a file with credentials an
#### AWS credentials are IAM managed
#### NextFlow credentials 
cd /tmp/

git clone https://github.com/MicrobialGenomics/viralrecon.git


### Try with modified version of viralrecon/Full Dataset
### s3:///microbialgenomics-scratch is for temporary files, will keep files for 15 day time
### All config files for analysis are on s3://***REMOVED***/NextFlow/Configs/
nextflow run /Users/mnoguera/Documents/Work/Development/viralrecon/main.nf --input $NFSamplesFile  \
 --fasta /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.fasta \
 --gff /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/Reference/NC_045512.2.gff3 \
  -profile awsbatch --skip_assembly \
 --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 \
  -bucket-dir 's3://microbialgenomics-scratch/' \
  -w 's3://microbialgenomics-scratch/' \
 --outdir ${NFOutDir}results --with-tower \
 --leading 20 --trailing 20 --minlen 50 --sliding_window 5 --sliding_window_quality 20

### Manual Inspection of results
### Note that when running on cloud, results dir needs to be on s3
### Need to download it and select results to import into DB or csv?
aws s3 cp --recursive ${NFOutDir}results /tmp/results


### Variables to extract 
# FlowCellID	
# InstrumentID	
# s3FastqR1
# s3FastqR2	
# s3BamFile	
# s3CovFile	
# RawDataSeqs	
# COVIDSeqs	
# FastaSequence	
# PercCoverage	
# MedianCoverage	
# QPassBool	

### Files of interest
### BCFTools section
### s3FastqR1, and s3FastqR2 from NFSamplesFile
### s3BamFile results/variants/bam/*.mkD.sorted.bam || contains unmapped reads
### RawDataSeqs samtools view results/variants/bam/*.mkD.sorted.bam | wc -l
### COVIDSeqs samtools vied -F 4 results/variants/bam/*.mkD.sorted.bam | wc -l
### results/variants/consensus/*masked*fa    --> consensus sequence, No degenerate positions
### results/variants/consensus/base_qc/*base_counts.tsv   --> Sequence composition  || percN=`tail -n 1 $file | awk '{print $3}'` || PercCoverage=100-percN
# base    freq    percI
# A   5492    18.3863408101774
# C   3447    11.5400066956813
# T   5788    19.3773016404419
# G   3728    12.480749916304
# N   11415   38.2156009373954
### results/variants/bam/picard_metrics/*coverage_metrics  --> coverage
# samtools  depth results/variants/bam/*.mkD.sorted.bam | awk '{sum+=$3} END { print "Average = ",sum/NR}' > ${sample}_depthOfCoverage.txt
### results/    --> bedfile
### No Results for insufficient coverage

### Ivar
### results/variants/consensus/*masked*fa    --> consensus sequence
### results/variants/consensus/base_qc/*base_counts.tsv   --> Sequence composition 
### results/variants/bam/picard_metrics/*coverage_metrics  --> coverage
### results/    --> bedfile
### No Results for insufficient coverage

### varscan2

### Custom
### results/    --> consensus sequence
### results/    --> Sequence composition
### results/    --> coverage
### results/    --> bedfile




### Contamination?
### Coverage?
### Number of reads(raw/filtered/aligned) 
### Use kraken2 output to report contamination?

### Scan results files to keep selected variables
### Download to local


