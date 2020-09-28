#!/usr/bin/env Rscript
args = commandArgs(trailingOnly = TRUE)

library(tidyverse)

gff_file <- args[1]

dat <- ape::read.gff(gff_file) %>%
    #dplyr::as_tibble() %>%
    dplyr::mutate(gene = stringr::str_remove_all(attributes, '.*gene=|;.*'),
           type = as.character(type)) %>%
    dplyr::filter(type == 'CDS') %>%
    dplyr::select(gene, start, end) %>% 
    dplyr::mutate(offset = (start %% 3) - 1, 
           s = dplyr::if_else(offset == 1, (start + 1) / 3, NaN ),
           s = dplyr::if_else(offset == 0, (start + 2) / 3, s),
           s = dplyr::if_else(offset == -1, (start + 3) / 3, s),
           e = round(((end - start + 1) / 3) + s - 1),0) %>% 
    dplyr::select(gene, start = s, end = e, offset)

purrr::map(levels(factor(dat$offset)), function(off){
           dat_2 <- dplyr::filter(dat, offset == off)
           if (nrow(dat_2) == 1) {
              dplyr::bind_rows(dat_2, tibble(gene = 'debug',
                                             start = 10000000000,
                                             end = 100000000000,
                                             offset = dat_2$offset)) %>%
              readr::write_csv(paste0('codfreq_gff_offset_', off, '.csv'))
           } else {
              dat_2  %>%
              readr::write_csv(paste0('codfreq_gff_offset_', off, '.csv'))
           }
})
           