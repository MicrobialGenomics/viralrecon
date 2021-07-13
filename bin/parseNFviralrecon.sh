#!/usr/bin/bash

NFSamplesFile=$1
NFOutDir=$2
NFDirPath=`basename $NFOutDir`
rm -rf $NFDirPath
mkdir $NFDirPath

### Manual Inspection of results

### (MNJ 2021-01-25 10:16:37 By now, this is a bash script and generate csv, in time should be transferred to python when interacting with DB.)

### Note that when running on cloud, results dir needs to be on s3
### Need to download it and select results to import into DB or csv?
aws s3 cp  ${NFOutDir}results /tmp/${NFDirPath}/results --recursive --exclude "*" --include "*mkD.sorted.bam*" --include "*.AF0.75.consensus.fa" --include "*.base_counts.tsv" --include "*.mkD.sorted.cov.tsv" --include "*fileInfo.txt"


### Variables to extractin, in csv Format.
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


### BCFTools section ---> Will use output from BCF tools
### s3FastqR1, and s3FastqR2 from NFSamplesFile
### s3BamFile results/variants/bam/*.mkD.sorted.bam || contains unmapped reads
### s3CovFile samtools depth results/variants/bam/*.mkD.sorted.bam
### RawDataSeqs samtools view results/variants/bam/*.mkD.sorted.bam | wc -l
### COVIDSeqs samtools vied-F 4 results/variants/bam/*.mkD.sorted.bam | wc -l
### s3FastaFile results/variants/bcftools/consensus/*masked*fa 
### results/variants/bcftools/consensus/*masked*fa    --> consensus sequence, No degenerate positions
### results/variants/bcftools/consensus/base_qc/*base_counts.tsv   --> Sequence composition  || percN=`tail -n 1 $file | awk '{print $3}'` || PercCoverage=100-percN
# base    freq    percI
# A   5492    18.3863408101774
# C   3447    11.5400066956813
# T   5788    19.3773016404419
# G   3728    12.480749916304
# N   11415   38.2156009373954
### results/variants/bam/picard_metrics/*coverage_metrics  --> coverage
# samtools  depth results/variants/bam/*.mkD.sorted.bam | awk '{sum+=$3} END { print "Average = ",sum/NR}' > ${sample}_depthOfCoverage.txt

rm /tmp/${NFDirPath}/NFResults.csv
rm /tmp/${NFDirPath}/NextCladeSequences.fasta
echo "library_id,InstrumentID,FlowcellID,s3FastqR1,s3FastqR2,s3BamFile,s3CovFile,RawDataSeqs,CovidSeqs,FastqSequence,PercCov,DepthOfCov,s3FastaFile" > /tmp/${NFDirPath}/NFResults.csv
for line in `cat $NFSamplesFile | tail -n +2`
do
   echo $line
   sampleName=`echo $line | awk 'BEGIN{FS=","}{print $1}'`
   instrumentID=`samtools view /tmp/${NFDirPath}/results/variants/bam/${sampleName}.mkD.sorted.bam | head -n 1 | awk '{print $1}' | awk 'BEGIN{FS=":"}{print $1}'`
   flowcellID=`samtools view /tmp/${NFDirPath}/results/variants/bam/${sampleName}.mkD.sorted.bam | head -n 1 | awk '{print $1}' | awk 'BEGIN{FS=":"}{print $3}'`

  echo "sampleName is $sampleName"
    s3FastqR1=`echo $line | awk 'BEGIN{FS=","}{print $2}'`
    s3FastqR2=`echo $line | awk 'BEGIN{FS=","}{print $3}'`
   echo "s3 Files are $s3FastqR1 and $s3FastqR2"
    s3BamFile=${NFOutDir}results/variants/bam/${sampleName}.mkD.sorted.bam
   echo "s3 Bam File is $s3BamFile"
    s3FastaFile=${NFOutDir}results/variants/ivar/consensus/${sampleName}.AF0.75.consensus.fa
    cat /tmp/${NFDirPath}/results/variants/ivar/consensus/${sampleName}.AF0.75.consensus.fa  >> /tmp/${NFDirPath}/NextCladeSequences.fasta
  #  echo "s3 consensus File is $s3FastaFile"
   # samtools depth -q 20 -Q 10 /tmp/${NFDirPath}/results/variants/bam/${sampleName}.mkD.sorted.bam > /tmp/${NFDirPath}/results/variants/bam/${sampleName}.mkD.sorted.cov.tsv
   # aws s3 cp /tmp/${NFDirPath}/results/variants/bam/${sampleName}.mkD.sorted.cov.tsv ${NFOutDir}results/variants/bam/
    s3CovFile=${NFOutDir}results/variants/bam/samtools_stats/${sampleName}.mkD.sorted.cov.tsv
   # echo "s3 Coverage file is $s3CovFile"
    RawDataSeqs=`samtools view /tmp/${NFDirPath}/results/variants/bam/${sampleName}.mkD.sorted.bam | wc -l`
     echo "RawDataSeqs is :$RawDataSeqs"	  
   # echo "File has $RawDataSeqs raw sequences"
    CovidSeqs=`samtools view -F 4 /tmp/${NFDirPath}/results/variants/bam/${sampleName}.mkD.sorted.bam | wc -l`
    echo "CovidSeqs is: $CovidSeqs"
   # echo "File has $CovidSeqs covid sequences"
    ConsensusSequence=`tail -n +2 /tmp/${NFDirPath}/results/variants/ivar/consensus/${sampleName}.AF0.75.consensus.fa | tr -d '\n'`
    DepthOfCoverage=`cat /tmp/${NFDirPath}/results/variants/bam/samtools_stats/${sampleName}.mkD.sorted.cov.tsv | awk '{sum+=$3} END { print sum/NR}'`
    PercN=`tail -n 1 /tmp/${NFDirPath}/results/variants/ivar/consensus/base_qc/${sampleName}.AF0.75.base_counts.tsv | awk '{print $3}'`
    NumberN=`seqtk comp /tmp/${NFDirPath}/results/variants/ivar/consensus/${sampleName}.AF0.75.consensus.fa | awk '{x+=$9}END{print x}'`
    ls -la /tmp/${NFDirPath}/results/variants/ivar/consensus/${sampleName}.AF0.75.consensus.fa
    echo "Number of N is: $NumberN"
    #echo "$PercN of genome is N"
    PercCov=`echo "100*(1-($NumberN/29930))" | bc -l`
    echo "Percentage covered is $PercCov"
   # echo "$PercCov of genome is covered"
    echo "${sampleName},${instrumentID},${flowcellID},${s3FastqR1},${s3FastqR2},${s3BamFile},${s3CovFile},${RawDataSeqs},${CovidSeqs},${ConsensusSequence},${PercCov},${DepthOfCoverage},${s3FastaFile}," >> /tmp/${NFDirPath}/NFResults.csv
done

aws s3 cp /tmp/${NFDirPath}/NFResults.csv ${NFOutDir}


### To run Nextclade to call mutations on sequences and signature mutation-based phylotyping
docker pull neherlab/nextclade
docker run -t --rm -u 1000 --volume="/tmp/${NFDirPath}/:/seq" \
neherlab/nextclade nextclade --input-fasta '/seq/NextCladeSequences.fasta' \
--output-csv='/seq/NextCladeSequences_output.csv'

aws s3 cp /tmp/${NFDirPath}/NextCladeSequences_output.csv ${NFOutDir}


### To run Pangolin for phylogenetic classification
docker pull staphb/pangolin
docker run -t --rm --volume="/tmp/${NFDirPath}/:/seq" \
staphb/pangolin pangolin -o '/seq/lineage_report.csv' '/seq/NextCladeSequences.fasta' 

cp /tmp/${NFDirPath}/lineage_report.csv/lineage_report.csv /tmp/${NFDirPath}/Pangolin_output.csv
aws s3 cp /tmp/${NFDirPath}/Pangolin_output.csv ${NFOutDir}


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


