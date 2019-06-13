#!/bin/bash
##################################
# Alexandra Jansen van Rensburg
# alexjvr@gmail.com
# Last modified 24/10/2018 14:28
##################################

# Creates submission script to check quality of demultiplexed raw reads using fastqc

00_parallel_fastqc_barkla.sh -i 00_raw_reads_modern/ -o /00_raw_reads_modern/ -n 1 -t 8 -m 4;
