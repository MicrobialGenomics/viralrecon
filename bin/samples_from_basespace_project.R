# Load libraries ----------------------------------------------------------
library(tidyverse)
library(stringi)
library(DBI)
library(dbplyr)
library(RMySQL)
library(optparse)

# Helper functions -------------------------------------------------------
connect_db <- function(dbname) {
    DBI::dbConnect(
        drv = RMySQL::MySQL(),
        username = Sys.getenv("mysql_user"),
        password = Sys.getenv("mysql_pass"),
        host = Sys.getenv("mysql_host"),
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
    dplyr::mutate(across(everything(), function(x) {
                    stri_encode(x, from = "ISO-8859-1", to = "latin1")
    })) %>%
    dplyr::mutate(
        fastq_id = stringr::str_c(run_id, library_id, sep = ""),
        .before = 1
    ) %>%
    readr::write_delim(
        file = stringr::str_c(opt$out_dir, "/metadata_to_fetch_run_", run_name, ".csv"),
        delim = ";"
    )

