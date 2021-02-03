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
        password = "c0v1drul3s",
        host = "mncovidseqdb-instance.cyu1oiz4la9s.eu-west-1.rds.amazonaws.com",
        port = 3306,
        dbname = dbname,
        ":memory:"
    )
}

# Arguments ---------------------------------------------------------------
option_list <- list(
    make_option(c("-i", "--basespace_name"),
                type = "character",
                default = NULL,
                help = "basespace project name",
                metavar = "input"),
    make_option(c("-o", "--out_dir"),
                type = "character",
                default = "./",
                help = "Output directory",
                metavar = "path")
)

opt_parser <- OptionParser(option_list = option_list)
opt <- parse_args(opt_parser)

run_name <- opt$basespace_name %>%
    stringr::str_remove_all(".*-")

# db query ----------------------------------------------------------------
cn <- connect_db(dbname = "mysql_covid_seq")
on.exit(DBI::dbDisconnect(cn))

metadata <- dplyr::tbl(cn, "samples") %>%
    dplyr::left_join(dplyr::tbl(cn, "plate_design"), by = "s_idx") %>%
    dplyr::left_join(dplyr::tbl(cn, "library_info"), by = "library_id") %>%
    dplyr::filter(run_id == run_name) %>%
    dplyr::collect() %>%
    dplyr::mutate(
        fastq_id = stringr::str_c(run_id, plate_id, library_id, sep = "_"),
        .before = 1
    ) %>%
    readr::write_delim(
        file = stringr::str_c(opt$out_dir, "/metadata_to_fetch_run_", run_name, ".csv"),
        delim = ";"
    )

