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

# Checks ------------------------------------------------------------------
option_list <- list(
    make_option(c("-v", "--viralrecon"),
                type = "character",
                default = NULL,
                help = "Comma-separated file with viralrecon results",
                metavar = "file"),
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
    make_option(c("-o", "--out_dir"),
                type = "character",
                default = "./",
                help = "Output directory",
                metavar = "path"),
    make_option(c("-s", "--ingest_sql"),
                type = "character",
                default = "true",
                help = "boolean indicating if data must be ingested to de db. (true or false)",
                metavar = "boolean")
)

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

if(!all(file.exists(opt$viralrecon, opt$nextclade, opt$pangolin))) {
    message("You need to specify NFSamplesFile NextCladeOutputFile MetadataFile all in csv format.")
    message("Metadata file needs to include library_id, at least")
}

if (!opt$ingest_sql %in% c("true", "false")) {
    message("ingest_sql must be true or false")
}

# Load file result data ---------------------------------------------------
nfcore <- opt$viralrecon %>%
    read_delim(delim = ",") %>%
    hablar::retype()

nextclade <- opt$nextclade %>%
    read_delim(delim = ";") %>%
    rename(library_id = seqName)

pangolin <- opt$pangolin %>%
    read_delim(delim = ",") %>%
    rename(library_id = taxon)

# Extract metadata from database ------------------------------------------
cn <- connect_db(dbname = "mysql_covid_seq")
on.exit(DBI::dbDisconnect(cn))

if (is.null(opt$metadata)) {
    metadata <- tbl(cn, "samples") %>%
        left_join(tbl(cn, "plate_design"), by = "s_idx") %>%
        left_join(tbl(cn, "library_info"), by = "library_id") %>%
        collect() %>%
        filter(library_id %in% nfcore$library_id)
} else {
    metadata <- opt$metadata %>%
        readr::read_csv() %>%
        filter(library_id %in% nfcore$library_id)
}

# Merge -------------------------------------------------------------------
metadata %>%
    left_join(nfcore, by = "library_id") %>%
    left_join(nextclade, by = "library_id") %>%
    left_join(pangolin, by = "library_id")

# Ingest db ---------------------------------------------------------------
if (opt$ingest_sql == "true") {
    nfcore %>% ingest_db("viralrecon", cn = cn)
    nextclade %>%
        setNames(names(.) %>% str_replace_all("[.]", "_")) %>%
        ingest_db("nextclade", cn = cn)
    pangolin %>% ingest_db("pangolin", cn = cn)
}

# Extract tables by study    -----------------------------------------------
metadata %>%
    pull(StudyID) %>%
    unique() %>%
    map(function(study) {
        run_id <- metadata %>% pull(run_id) %>% unique()
        metadata %>%
            filter(StudyID == study) %>%
            write_delim(
                file = str_c(opt$out_dir, "covid_", run_id, "_", study, ".csv"),
                delim = ";"
            )
    })

metadata %>% write_delim(file = str_c(opt$out_dir, "covid_", run_id, ".csv"), delim = ";")


