#!/usr/bin/env Rscript
args = commandArgs(trailingOnly = TRUE)

# PRE SETUP ---------------------------------------------------------------

suppressMessages(suppressWarnings(library(tidyverse)))
suppressMessages(suppressWarnings(library(data.table)))
suppressMessages(suppressWarnings(library(Rsamtools)))

# FUNCTION DEFINITION -----------------------------------------------------

#' READ GFF3 FILE 
#' 
#' This function takes gff file path and open it. Only retain those lines
#' corresponding with coding regions
#' 
#' @param gff_file  path to gff3 file
#'
#' @return tibble with 3 columns (cds, start, end)
#' @export
#'
#' @examples
read_gff <- function(gff_file) {
  ape::read.gff(gff_file) %>%
    as_tibble() %>%
    mutate(attributes = str_remove_all(attributes, '.*gene=|;.*'),
           type = as.character(type)) %>%
    filter(type == 'CDS') %>%
    select(attributes, start, end)
}

#' READ BAM FILE
#'
#' Function that takes a bam file and load it in a data.table object
#' 
#' @param bam_file path to bam file
#'
#' @return bam in data.table format
#' @export
#'
#' @examples
read_bam <- function(bam_file) {
  bam <- scanBam(bam_file)
  .unlist <- function (x) {
    x1 <- x[[1L]]
    if (is.factor(x1)) {
      structure(unlist(x), class = "factor", levels = levels(x1))
    } else {
      do.call(c, x)
    }
  }
  bam_field <- names(bam[[1]])
  list <-
    lapply(bam_field, function(y)
      .unlist(lapply(bam, "[[", y)))
  bam_df <- do.call("DataFrame", list)
  names(bam_df) <- bam_field
  
  bam_df %>%
    as_tibble() %>%
    mutate(end = pos + qwidth) %>%
    as.data.table()
}

#' BAM PREPROCESSING
#' 
#' @param bam output of read_bam function
#'
#' @return
#' @export
#'
#' @examples
prepro_bam <- function(bam = bam) {
  map(1:nrow(bam), function(read) {
    dat <- bam %>%
      .[read,]
    
    data.table(
      read = read,
      strand = dat$strand,
      pos = dat$pos:(dat$end - 1),
      seq = unlist(str_split(dat$seq, pattern = ''))
    )
  })
}

#' Title
#'
#' @param prepro_bam output of read_bam function
#' @param gff output of read_gff function
#'
#' @return
#' @export
#'
#' @examples
codfreq <- function(prepro_bam, gff) {
  map_dfr(1:nrow(gff), function(i) {
    start = filter(gff, row_number() == i) %>% pull(start)
    end = filter(gff, row_number() == i) %>% pull(end)
    gene = filter(gff, row_number() == i) %>% pull(attributes)
        
    prep <- mclapply(prepro_bam, function(read) {
      if (max(read$pos) > start & min(read$pos) < end) {
        dat2 <- read %>%
          .[, .(pos, seq)] %>%
          merge(., data.table(pos = start:end), all.y = TRUE) %>%
          .[is.na(seq), seq := '-']
        
        dat3 <- tibble(cds_pos = seq(start, end, by = 3),
                       codon = paste0(dat2$seq[c(T, F, F)],
                                      dat2$seq[c(F, T, F)],
                                      dat2$seq[c(F, F, T)])) %>%
          mutate(aa_pos = 1:length(codon),
                 gene = gene) %>% 
          as.data.table()
      }
    })
    
    return(prep)
  })
}

# CODON FREQUENCY CALCULATION ---------------------------------------------

bam_file <- args[1]
gff_file <- args[2]
out_file <- args[3]

gff <- read_gff(gff_file)
bam <- read_bam(bam_file)
prepro <- prepro_bam(bam)
codfreq <- codfreq(prepro, gff)  
  
results <- map_dfr(1:length(codfreq), function(y) { 
    codfreq[[y]] 
  }) %>%
  as_tibble() %>%
  group_by(codon, aa_pos, cds_pos, gene) %>%
  count(codon) %>%
  arrange(aa_pos) %>%
  ungroup() %>%
  filter(!str_detect(codon, '-')) %>% 
  fwrite(file = out_file, sep = '\t')