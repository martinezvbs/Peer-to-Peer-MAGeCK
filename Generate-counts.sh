# Load modules
module load MAGeCK/0.5.9.5-gfbf-2022b

# Define sgRNA library file
SGRNA_LIST="EpiDrug_library.csv"

# Supplementary Table 1: sgRNA sequences and target genes in the Epi-Drug library

# FASTQ files
FASTQ=(
    "D0R1.fastq.gz"
    "D0R2.fastq.gz"
    "IVR1.fastq.gz"
    "IVR2.fastq.gz"
    "XENOR1.fastq.gz"
    "XENOR2.fastq.gz"
    "XENOR3.fastq.gz"
    "XENOR4.fastq.gz"
    "XENOR5.fastq.gz")

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