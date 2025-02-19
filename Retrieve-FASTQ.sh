# Description: Download FASTQ files from the SRA using fasterq-dump

# Create a directory for the fastq files
mkdir -p FASTQ
# shellcheck disable=SC2164
cd FASTQ

# Array of SRA accession numbers
declare -a sra_ids=(
    "SRR17735712"
    "SRR17735713"
    "SRR17735714"
    "SRR17735715"
    "SRR17735716"
    "SRR17735717"
    "SRR17735718"
    "SRR17735719"
    "SRR17735720"
)

# Download each SRA file using fasterq-dump
for sra_id in "${sra_ids[@]}"; do
    echo "Downloading $sra_id..."
    fasterq-dump \
        --split-files \
        --threads 8 \
        --progress \
        --outdir . \
        "$sra_id"
done

# Optional: Compress the resulting fastq files to save space
echo "Compressing fastq files..."
# shellcheck disable=SC2035
gzip *.fastq

echo "Download and compression complete!"