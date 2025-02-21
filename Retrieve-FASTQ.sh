#!/bin/bash

#===============================================================================
# Title: Download and Rename FASTQ Files from SRA
# Description: Downloads FASTQ files from SRA and renames them according to experimental conditions
# GEO: GSE194349
#===============================================================================

# Load the SRA-Toolkit module
echo "Loading SRA-Toolkit..."
module load SRA-Toolkit/3.1.1-gompi-2022b

# Create a directory for the fastq files
echo "Creating FASTQ directory..."
mkdir -p FASTQ
cd FASTQ || exit 1  # Exit if cd fails

# Create associative arrays for mapping SRA IDs to final names
declare -A sra_to_name=(
    ["SRR17735715"]="D0R1"        # Day 0, Replicate 1, 2D
    ["SRR17735714"]="D0R2"        # Day 0, Replicate 2, 2D
    ["SRR17735713"]="IVR1"        # Day 21, In vitro Replicate 1, 2D
    ["SRR17735712"]="IVR2"        # Day 21, In vitro Replicate 2, 2D
    ["SRR17735720"]="XENOR1"      # Day 21, Xenograft Replicate 1, 3D
    ["SRR17735719"]="XENOR2"      # Day 21, Xenograft Replicate 2, 3D
    ["SRR17735718"]="XENOR3"      # Day 21, Xenograft Replicate 3, 3D
    ["SRR17735717"]="XENOR4"      # Day 21, Xenograft Replicate 4, 3D
    ["SRR17735716"]="XENOR5"      # Day 21, Xenograft Replicate 5, 3D
)

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

# Download and rename each SRA file
for sra_id in "${sra_ids[@]}"; do
    echo "Processing $sra_id (${sra_to_name[$sra_id]})..."

    # Download the SRA file
    echo "  Downloading..."

    # Check if download was successful
    if ! fasterq-dump \
        --split-files \
        --threads 8 \
        --progress \
        --outdir . \
        "$sra_id"; then
        echo "Error downloading $sra_id. Skipping..."
        continue
    fi

    # Rename the file
    echo "  Renaming..."
    mv "${sra_id}.fastq" "${sra_to_name[$sra_id]}.fastq"

    # Compress the file
    echo "  Compressing..."
    gzip "${sra_to_name[$sra_id]}.fastq"

    echo "  Completed processing ${sra_to_name[$sra_id]}"
done

# Verify all files were downloaded and renamed
echo "Verifying files..."
for sra_id in "${sra_ids[@]}"; do
    expected_file="${sra_to_name[$sra_id]}.fastq.gz"
    if [ ! -f "$expected_file" ]; then
        echo "Warning: Missing file $expected_file"
    else
        echo "Verified: $expected_file"
    fi
done

echo "Download, renaming, and compression complete!"

# Print summary of downloaded files
echo -e "\nSummary of downloaded files:"
echo "----------------------------------------"
printf "%-20s %-20s\n" "Original SRA ID" "New Filename"
echo "----------------------------------------"
for sra_id in "${sra_ids[@]}"; do
    printf "%-20s %-20s\n" "$sra_id" "${sra_to_name[$sra_id]}.fastq.gz"
done
echo "----------------------------------------"

#===============================================================================
# Expected output files:
# - D0R1.fastq.gz    (from SRR17735715) - Day 0, Replicate 1
# - D0R2.fastq.gz    (from SRR17735714) - Day 0, Replicate 2
# - IVR1.fastq.gz    (from SRR17735713) - In vitro, Replicate 1
# - IVR2.fastq.gz    (from SRR17735712) - In vitro, Replicate 2
# - XENOR1.fastq.gz  (from SRR17735720) - Xenograft, Replicate 1
# - XENOR2.fastq.gz  (from SRR17735719) - Xenograft, Replicate 2
# - XENOR3.fastq.gz  (from SRR17735718) - Xenograft, Replicate 3
# - XENOR4.fastq.gz  (from SRR17735717) - Xenograft, Replicate 4
# - XENOR5.fastq.gz  (from SRR17735716) - Xenograft, Replicate 5
#===============================================================================