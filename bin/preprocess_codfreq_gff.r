#!/usr/bin/env Rscript
args = commandArgs(trailingOnly = TRUE)

library(tidyverse)

gff_file <- args[1]

ape::read.gff(gff_file) %>%
    dplyr::as_tibble() %>%
    dplyr::mutate(gene = stringr::str_remove_all(attributes, '.*gene=|;.*'),
           type = as.character(type)) %>%
    dplyr::filter(type == 'CDS') %>%
    dplyr::select(gene, start, end) %>% 
    dplyr::mutate(offset = (start %% 3) - 1, 
           s = dplyr::if_else(offset == 1, (start + 1) / 3, NaN ),
           s = dplyr::if_else(offset == 0, (start + 2) / 3, s),
           s = dplyr::if_else(offset == -1, (start + 3) / 3, s),
           e = ((end - start + 1) / 3) + s - 1) %>% 
    dplyr::select(gene, start = s, end = e, offset) %>% 
    readr::write_csv('codfreq_gff.csv')
                         
               
               
               
               