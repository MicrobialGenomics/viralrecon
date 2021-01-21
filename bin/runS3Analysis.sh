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
s3Bucket="s3://covidseq-14012021-eu-west-1/"

NFSamplesFile=$1

cd /tmp/

git clone https://github.com/MicrobialGenomics/viralrecon.git

nextflow run ./main.nf --input $NFSamplesFile \ 
    --fasta ${s3Bucket}/NextFlow/Configs/NC_045512.2.fasta 
    --amplicon_bed ${s3Bucket}/NextFlow/Configs/ArticPrimers_BediVar.bed 
    --skip_assembly -profile docker --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 
s3://covidseq-14012021-eu-west-1/NextFlow/Configs/

    nextflow run ./main.nf  --input  s3://covidseq-14012021-eu-west-1/Runs/IrsiCaixa_Covid-16S_208813606_2021-01-21/IrsiCaixa_Covid-16S_NFSamples.csv  --fasta s3://covidseq-14012021-eu-west-1/NextFlow/Configs/NC_045512.2.fasta \
     --amplicon_bed /tmp/ArticPrimers_BediVar.bed --skip_assembly -profile awsbatch --protocol metagenomic --outdir s3://covidseq-14012021-eu-west-1/Runs/IrsiCaixa_Covid-16S_208813606_2021-01-21/viralrecon\
     --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 -work-dir work -bucket-dir s3://microbialgenomics-scratch/
      
      
      /tmp/IrsiCaixa_Covid-16S_NFSamples.csv 
      --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 --outdir s3://covidseq-14012021-eu-west-1/Runs/IrsiCaixa_Covid-16S_208813606_2021-01-21/viralrecon \
        -w s3://microbialgenomics-scratch/work
-bucket-dir s3://microbialgenomics-scratch/ 

        nextflow run ./main.nf  --input  s3://covidseq-14012021-eu-west-1/Runs/IrsiCaixa_Covid-16S_208813606_2021-01-21/IrsiCaixa_Covid-16S_NFSamples.csv  \
                    --fasta s3://covidseq-14012021-eu-west-1/NextFlow/Configs/NC_045512.2.fasta   \
                       --amplicon_bed /tmp/ArticPrimers_BediVar.bed --skip_assembly \
                       -profile awsbatch --protocol metagenomic --outdir s3://covidseq-14012021-eu-west-1/Runs/IrsiCaixa_Covid-16S_208813606_2021-01-21/viralrecon \ 
                            --awsqueue NextFlow_Queue_1 --awsregion eu-west-1 --workDir s3://microbialgenomics-scratch/work \




nextflow run /Users/mnoguera/Documents/Work/Development/viralrecon/main.nf --input /tmp/IrsiCaixa_Covid-16S_NFSamples.csv \
--awsqueue NextFlow_Queue_1 -w 's3://microbialgenomics-scratch/' -bucket-dir 's3://microbialgenomics-scratch' --outdir 's3://covidseq-14012021-eu-west-1/Runs/IrsiCaixa_Covid-16S_208813606_2021-01-21/viralrecon' \
--genome NC_045512.2 --amplicon_bed /Users/mnoguera/Documents/Work/Projects/Coronavirus_2020/SequenciacioNGS/ArticPrimers_BediVar.bed -profile awsbatch -resume