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

ingest_db <- function(data, table, cn, dbname = "mysql_covid_seq") {
    DBI::dbWriteTable(
        conn = cn,
        name = table,
        value = data,
        append = TRUE,
        row.names = FALSE
    )
}

sql_update_table <- function(df, pk_cols, table_name, dbname = used_db) {

    if (length(pk_cols) > 1) { stop("This function only works with one column PK") }

    cn <- connect_db(dbname)
    on.exit(DBI::dbDisconnect(cn))

    df %>%
        dplyr::pull(!!pk_cols) %>%
        purrr::map(function(lev) {
            x <- df %>% filter(!!sym(pk_cols) == !!lev)
            if (nrow(x) != 1) stop("Input dataframe must be exactly 1 row")
            if (!all(pk_cols %in% colnames(x))) stop("All columns specified in 'pk_cols' must be present in 'x'")

            # Build the update string --------------------------------------------------
            df_key <- dplyr::select(x,  one_of(pk_cols))
            df_upt <- dplyr::select(x, -one_of(pk_cols))

            set_str <- purrr::map_chr(colnames(df_upt), ~glue::glue_sql('{`.x`} = {x[[.x]]}', .con = cn))
            set_str <- paste(set_str, collapse = ", ")

            where_str <- purrr::map_chr(colnames(df_key), ~glue::glue_sql("{`.x`} = {x[[.x]]}", .con = cn))
            where_str <- paste(where_str, collapse = " AND ")

            update_str <- glue::glue('UPDATE {dbname}.{table_name} SET {set_str} WHERE {where_str}')

            # Execute ------------------------------------------------------------------
            query_res <- DBI::dbSendQuery(cn, update_str)
            DBI::dbClearResult(query_res)

            return(invisible(TRUE))
        })
    return(invisible(TRUE))
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
    make_option(c("-d", "--dbname"),
                type = "character",
                default = "mysql_covid_seq",
                help = "database name, two options = mysql_covid_seq or mysql_test",
                metavar = "text"),
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
cn <- connect_db(dbname = opt$dbname)
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

    nfcore %>%
        select(library_id) %>%
        mutate(sample_statue = "sequenced") %>%
        sql_update_table(pk_cols = "library_id",
                         table_name = "sample_status",
                         dbname = opt$dbname)
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


