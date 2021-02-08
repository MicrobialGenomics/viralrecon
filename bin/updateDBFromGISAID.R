

### This script is intended to run after data has been filtered and analyzed with NextClade and Pangolin


### Trying to do it well!

# Load libraries ----------------------------------------------------------
library(tidyverse)
library(DBI)
library(dbplyr)
library(RMySQL)
library(optparse)

# Helper functions -------------------------------------------------------
connect_db <- function(dbname) {
    DBI::dbConnect(
        drv = RMySQL::MySQL(),
        username = "admin",
        password = "***REMOVED***",
        host = "***REMOVED***",
        port = 3306,
        dbname = dbname,
        ":memory:"
    )
}

ingest_db <- function(data, table, cn, dbname = "mysql_covid_seq") {
    DBI::dbWriteTable(
        conn = cn,
        name = table,
        value = data,
        append = TRUE,
        row.names = FALSE
    )
}


option_list <- list(
    make_option(c("-c", "--nextclade"),
                type = "character",
                default = NULL,
                help = "Semicolon-separated file with nextclade results",
                metavar = "file"),
    make_option(c("-p", "--pangolin"),
                type = "character",
                default = NULL,
                help = "Comma-separated file with pangolin results",
                metavar = "file"),
    make_option(c("-m", "--metadata"),
                type = "character",
                default = NULL,
                help = "Comma-separated file with metadata information",
                metavar = "file"),
    make_option(c("-f", "--fasta"),
                type="character",
                default=NULL,
                help =" Fasta File of sequences being analyzed",
                metavar="file"),
    make_option(c("-o", "--out_dir"),
                type = "character",
                default = "./",
                help = "Output directory",
                metavar = "path"),
    make_option(c("-s", "--ingest_sql"),
                type = "character",
                default = "false",
                help = "boolean indicating if data must be ingested to de db. (true or false)",
                metavar = "boolean")
)

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

if(!all(file.exists(opt$metadata,opt$fasta, opt$nextclade, opt$pangolin))) {
    message("You need to specify FastaFile, Metadata, Pangoling and  NextCladeOutputFile. All(except fasta)s in csv format.")
}


if (!opt$ingest_sql %in% c("true", "false")) {
    message("Not ingesting data into DB")
    opt$ingest_sql<-"false"
}

# Load file result data ---------------------------------------------------
gisaidcore <- opt$metadata %>%
    read_delim(delim = "\t") %>%
    hablar::retype() %>%
    rename(seqName=strain)

spec(gisaidcore)
summary(gisaidcore)

nextclade <- opt$nextclade %>%
    read_delim(delim = ";")

pangolin <- opt$pangolin %>%
    read_delim(delim = ",") %>%
    rename(seqName = taxon)

# Merge -------------------------------------------------------------------
mergedData<-gisaidcore %>%
    left_join(nextclade, by = "seqName") %>%
    left_join(pangolin, by = "seqName")


write.table(mergedData,file=paste0(opt$out_dir,"/MergedData.csv"),sep=";",row.names = F)

mergedData<-read.table(file=paste0("~/Downloads/MergedData.csv"),sep=";")
colnames(mergedData)<-mergedData[1,]
mergedData<-mergedData[-1,]
mergedData<-tibble::as_tibble(mergedData)
mergedData$date<-as.Date(mergedData$date,format = "%Y-%m-%d")

### Export Core Data for Plotting
### Header Looks like
##collection_date;sample_id;library_id;QPass;RawReads;PercCov;DepthOfCoverage;NCClade;PassReads;WeekNumber
require(dplyr)

provinces<-xlsx::read.xlsx("~/Downloads/16codmun_en.xls",sheetIndex = 1)
colnames(provinces)<-c("ProvinceCode","MunicipalCode","ComarcaCode","MunicipalName","ProvinceName")
provinces<-provinces[-1,]
sum(mergedData$location %in% provinces$MunicipalName) ### All MunicipalNames have a province assigned
dim(mergedData)

mergedData$week<-as.factor(paste(strftime(mergedData$date, format = "%y"),strftime(mergedData$date, format = "%V"),sep="-"))
mergedData$month<-as.factor(paste(strftime(mergedData$date, format = "%y"),strftime(mergedData$date, format = "%m"),sep="-"))
mergedData %>%
    dplyr::filter(country == "Spain") %>%
    dplyr::select(c(seqName,date,region,country,division,location,sex,qc.overallStatus,aaSubstitutions,clade,lineage))%>%
    dplyr::rename(collection_date=date,sample_id=seqName,NCClade=clade,WeekNumber=week,)

mergedData$week<-as.factor(paste(strftime(mergedData$date, format = "%y"),strftime(mergedData$date, format = "%V"),sep="-"))
mergedData$month<-as.factor(paste(strftime(mergedData$date, format = "%y"),strftime(mergedData$date, format = "%m"),sep="-"))

require(ggplot2)
mergedData %>%
    dplyr::filter(division=="Catalunya") %>%
    dplyr::filter(! is.na(date)) %>%
ggplot(aes(x=week,fill=Province))+geom_bar(stat="count")+ theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

mergedData %>%
    dplyr::filter(division=="Catalunya") %>%
    dplyr::filter(! is.na(date)) %>%
    ggplot(aes(x=month,fill=Province))+geom_bar(stat="count")+ theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))

require(viridis)
mergedData %>%
    dplyr::filter(country=="Spain") %>%
    dplyr::filter(! is.na(date)) %>%
    ggplot(aes(x=month,fill=division))+geom_bar(stat="count")+ theme(axis.text.x = element_text(angle = 90, vjust = 0.5, hjust=1))+scale_color_brewer("Set3")

+theme_minimal()
