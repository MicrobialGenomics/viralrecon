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
                default = "false",
                help = "boolean indicating if data must be ingested to de db. (true or false)",
                metavar = "boolean"),
    make_option(c("-S","--s3Dir"),
                type = "character",
                default = NULL,
                help = "Character indicating the s3Location of the output files)",
                metavar = "path")
)

opt_parser <- OptionParser(option_list=option_list)
opt <- parse_args(opt_parser)

# if(!all( file.exists(opt$viralrecon, opt$nextclade, opt$pangolin)) & is.null(opt$s3Dir)) {
#     message("You need to specify NFSamplesFile NextCladeOutputFile MetadataFile all in csv format.")
#
# }
if (!opt$ingest_sql %in% c("true", "false")) {
    message("ingest_sql must be true or false")
}

if(!is.null(opt$s3Dir)) {
    bucket <- "s3://covidseq-14012021-eu-west-1"
    ### Going to guess File locations from s3 path
    projectString <- opt$s3Dir
    s3NFOutput <- bucket %>%
        aws.s3::get_bucket_df(prefix = paste("Runs/", projectString, sep = "")) %>%
        filter(str_detect(Key, projectString)) %>%
        filter(str_detect(Key, "NFResults.csv" ))

    nfcore <- s3NFOutput %>%
        pull(Key) %>%
        aws.s3::s3read_using(
            object = .,
            FUN = readr::read_csv,
            col_type = cols(),
            bucket = bucket
        )
    print(nrow(nfcore))

    #### Read Pangoling from S3
    s3PGOutput <- bucket %>%
        aws.s3::get_bucket_df(prefix = paste("Runs/", projectString, sep = "")) %>%
        filter(str_detect(Key, projectString)) %>%
        filter(str_detect(Key, "Pangolin_output.csv" ))

    pangolin <- s3PGOutput %>%
        pull(Key) %>%
        aws.s3::s3read_using(
            object = .,
            FUN = readr::read_csv,
            col_types = cols(),
            bucket = bucket,
        ) %>%
        dplyr::rename(library_id = taxon)
    print(nrow(pangolin))

    ### Read NextClade from S3.
    s3NCOutput <- bucket %>%
        aws.s3::get_bucket_df(prefix = paste("Runs/", projectString, sep = "")) %>%
        filter(str_detect(Key, projectString)) %>%
        filter(str_detect(Key, "NextCladeSequences_output.csv"))

    nextclade <- s3NCOutput %>%
        pull(Key) %>%
        aws.s3::s3read_using(
            object = .,
            FUN = readr::read_delim,
            delim = ";",
            col_types = cols(),
            bucket = bucket
        ) %>%
        dplyr::rename(library_id = seqName)
    print(nrow(nextclade))

} else if (all(file.exists(opt$viralrecon, opt$nextclade, opt$pangolin))) {

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

} else { break("No input available") }

# Extract metadata from database ------------------------------------------
cn <- connect_db(dbname = opt$dbname)
on.exit(DBI::dbDisconnect(cn))

### Reformat library_id for coherence into database
nfcore$library_id <- substr(nfcore$library_id, 5, length(nfcore$library_id))
pangolin$library_id <- substr(pangolin$library_id, 5, length(pangolin$library_id))
nextclade$library_id <- substr(nextclade$library_id, 5, length(nextclade$library_id))

if (is.null(opt$metadata)) {
    metadata <- dplyr::tbl(cn, "samples") %>%
        dplyr::left_join(dplyr::tbl(cn, "plate_design"), by = "s_idx") %>%
        dplyr::left_join(dplyr::tbl(cn, "library_info"), by = "library_id") %>%
        dplyr::collect() %>%
        dplyr::mutate(across(everything(), function(x) {
            stri_encode(x, from = "ISO-8859-1", to = "latin1")
        })) %>%
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
        mutate(sample_status = "sequenced") %>%
        sql_update_table(pk_cols = "library_id",
                         table_name = "sample_status",
                         dbname = opt$dbname)
}

# Extracted Elsewhere
# # Extract tables by study    -----------------------------------------------
# metadata %>%
#     pull(StudyID) %>%
#     unique() %>%
#     map(function(study) {
#         run_id <- metadata %>% pull(run_id) %>% unique()
#         metadata %>%
#             filter(StudyID == study) %>%
#             write_delim(
#                 file = str_c(opt$out_dir, "covid_", run_id, "_", study, ".csv"),
#                 delim = ";"
#             )
#     })
#
# metadata %>% write_delim(file = str_c(opt$out_dir, "covid_", run_id, ".csv"), delim = ";")
#

