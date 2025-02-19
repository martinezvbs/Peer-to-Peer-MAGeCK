#!/bin/bash

# Allow mismatches for read mapping
# Since version 0.5.5, MAGeCK count module supports collecting read counts from BAM files
# This will allow you to use a third-party aligner to map reads to the library with mismatches, providing more usable reads for the analysis.

# (1) Determine the 5' and 3' trimming length and sgRNA length with cutadapt
module load cutadapt/3.4-GCCcore-10.2.0

# Create output directory
mkdir -p Trimmed

# Process all fastq.gz files
for input_file in *.fastq.gz; do
    # Create output filename
    output_file="Trimmed/trimmed_${input_file}"

    echo "Processing ${input_file}..."

    # Run cutadapt with optimized parameters
    cutadapt \
      -a "GTTTTAGAGCTA" \
      -g "TATCTTGTGGAAAGGACGAAACACC" \
      -o "${output_file}" \
      "${input_file}" \
      --minimum-length=15 \
      --error-rate=0.1 \
      --cores=0 \
      --trim-n \
      --quality-cutoff=20
done

# (2) Convert the library file into fasta format
module purge
module load Bowtie2/2.5.1-GCC-12.2.0
module load SAMtools/1.21-GCC-12.2.0

awk -F ',' '{print ">"$1"\n"$2}' 	EpiDrug_library.csv > EpiDrug_library.fa

# (3) Build the Bowtie2 index
bowtie2-build EpiDrug_library.fa EpiDrug_library

# (4) Map the trimmed reads to the library with Bowtie2

# Create output directory
mkdir -p Mapped

# Process all trimmed files
for input_file in *.fastq.gz; do
    # Create output filename
    output_file="Mapped/$(basename "${input_file}" .fastq.gz).bam"

    echo "Mapping ${input_file} to library..."

    # Run Bowtie2
    bowtie2 -x EpiDrug_library -U "${input_file}" --np 0 --norc -N 2 | samtools view -bS - | samtools sort -o "${output_file}"
done

# (5) Run MAGeCK count module to collect read counts from BAM files

# Activate the conda environment
module purge
module load miniconda/24.3.0
module load texlive/20220321-GCC-12.2.0
conda activate mageckenv

# Variables for file names and common options
SGRNA_LIST="EpiDrug_library.csv"

# FASTQ files
FASTQ=(
    "Mapped/trimmed_A549_D0_R1.bam"
    "Mapped/trimmed_A549_D0_R2.bam"
    "Mapped/trimmed_A549_InVitro_R1.bam"
    "Mapped/trimmed_A549_InVitro_R2.bam"
    "Mapped/trimmed_A549_XENO_R1.bam"
    "Mapped/trimmed_A549_XENO_R2.bam"
    "Mapped/trimmed_A549_XENO_R3.bam"
    "Mapped/trimmed_A549_XENO_R4.bam"
    "Mapped/trimmed_A549_XENO_R5.bam")

# Generate a count table from raw FASTQ files for the first group
mageck count -l "$SGRNA_LIST" -n A549 \
--sample-label "D0R1,D0R2,IVR1,IVR2,XENOR1,XENOR2,XENOR3,XENOR4,XENOR5" \
--fastq "${FASTQ[@]}" \
--norm-method total --pdf-report

# Run MAGeCK RRA tests for various comparisons
declare -A TEST=(
    ["D0-IV-v-D21-IV"]="D0R1,D0R2 IVR1,IVR2"
    ["D0-IV-v-D21-XE"]="D0R1,D0R2 XENOR1,XENOR2,XENOR3,XENOR4,XENOR5"
    ["D21-IV-v-D21-XE"]="IVR1,IVR2 XENOR1,XENOR2,XENOR3,XENOR4,XENOR5")

for test_name in "${!TEST[@]}"; do
    IFS=' ' read -r -a test_comparison <<< "${TEST[$test_name]}"
    mageck test -k A549.count.txt -c "${test_comparison[0]}" -t "${test_comparison[1]}" \
    --norm-method total --adjust-method fdr --pdf-report -n "$test_name"
done