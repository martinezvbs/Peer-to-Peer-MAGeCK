#!/bin/bash
# The above line is called a shebang - it tells the system this is a bash script

#===============================================================================
# Every line in this script is documented for beginners to understand bash scripting
# and MAGeCK analysis for CRISPR screens
#===============================================================================

# Three steps to run this script:
# 1. Save this file as 'mageck_analysis.sh'
# 2. Make it executable: chmod +x mageck_analysis.sh
# 3. Run it: ./mageck_analysis.sh

#-------------------------------------------------------------------------------
# 1. Environment Setup
#-------------------------------------------------------------------------------
# 'echo' prints text to the screen - useful for tracking progress
echo "Setting up environment..."

# 'module load' makes software available in your environment
# Here we're loading MAGeCK version 0.5.9.5
module load MAGeCK/0.5.9.5-gfbf-2022b

# This checks if MAGeCK is properly installed
# 'command -v' checks if a command exists
# '&> /dev/null' redirects both standard output and errors to nowhere
# '!' negates the result, so the if statement runs if the command fails
if ! command -v mageck &> /dev/null; then
    # If MAGeCK isn't found, print error and exit
    echo "Error: MAGeCK not found. Please ensure it's properly installed."
    # 'exit 1' stops the script with an error status
    exit 1
fi

#-------------------------------------------------------------------------------
# 2. Input Files Setup
#-------------------------------------------------------------------------------
# Create a variable for the sgRNA library file
# Variables in bash are created by writing VARIABLE_NAME=value (no spaces around =)
SGRNA_LIST="EpiDrug_library.csv"

# Check if the library file exists
# '-f' checks if a file exists
# '$SGRNA_LIST' gets the value of the variable SGRNA_LIST
if [ ! -f "$SGRNA_LIST" ]; then
    echo "Error: sgRNA library file not found: $SGRNA_LIST"
    exit 1
fi

# Create an array of FASTQ files
# Arrays in bash are created with parentheses () and elements separated by spaces
# Each line is a different FASTQ file - the backslash \ allows breaking into multiple lines
FASTQ=(
    # These are your sequencing data files
    # The naming indicates the conditions and replicates
    "D0R1.fastq.gz"     # Day 0, Replicate 1
    "D0R2.fastq.gz"     # Day 0, Replicate 2
    "IVR1.fastq.gz"     # In vitro, Replicate 1
    "IVR2.fastq.gz"     # In vitro, Replicate 2
    "XENOR1.fastq.gz"   # Xenograft, Replicate 1
    "XENOR2.fastq.gz"   # Xenograft, Replicate 2
    "XENOR3.fastq.gz"   # Xenograft, Replicate 3
    "XENOR4.fastq.gz"   # Xenograft, Replicate 4
    "XENOR5.fastq.gz"   # Xenograft, Replicate 5
)

# Check if all FASTQ files exist
# 'for' loop goes through each element in the array
# "${FASTQ[@]}" gets all elements of the FASTQ array
for file in "${FASTQ[@]}"; do
    # Check each file
    if [ ! -f "$file" ]; then
        echo "Error: FASTQ file not found: $file"
        exit 1
    fi
done

#-------------------------------------------------------------------------------
# 3. Generate Count Table
#-------------------------------------------------------------------------------
echo "Generating count table..."

# Run MAGeCK count command
# Backslash \ allows breaking a long command into multiple lines for readability
mageck count \
    -l "$SGRNA_LIST" \
    -n A549 \
    --sample-label "D0R1,D0R2,IVR1,IVR2,XENOR1,XENOR2,XENOR3,XENOR4,XENOR5" \
    --fastq "${FASTQ[@]}" \
    --norm-method total \
    --pdf-report

# Command explanation:
# -l "$SGRNA_LIST"     : Input sgRNA library file
# -n A549              : Prefix for output files
# --sample-label       : Labels for each sample
# --fastq              : Input FASTQ files
# --norm-method total  : Normalization method
# --pdf-report         : Generate PDF report

# Check if count generation worked
if [ ! -f "A549.count.txt" ]; then
    echo "Error: Count table generation failed"
    exit 1
fi

#-------------------------------------------------------------------------------
# 4. Differential Analysis
#-------------------------------------------------------------------------------
echo "Performing differential analysis..."

# Create an associative array (dictionary) for test comparisons
# '-A' makes it an associative array where you can use strings as keys
declare -A TEST=(
    # Format: ["test_name"]="control_samples treatment_samples"
    # Spaces separate control and treatment, commas separate replicates
    ["D0-IV-v-D21-IV"]="D0R1,D0R2 IVR1,IVR2"                    # Day 0 vs In vitro
    ["D0-IV-v-D21-XE"]="D0R1,D0R2 XENOR1,XENOR2,XENOR3"        # Day 0 vs Xenograft
    ["D21-IV-v-D21-XE"]="IVR1,IVR2 XENOR1,XENOR2,XENOR3"       # In vitro vs Xenograft
)

# Run MAGeCK test for each comparison
# "${!TEST[@]}" gets all keys from the TEST array
for test_name in "${!TEST[@]}"; do
    echo "Processing comparison: $test_name"

    # Split the test string into control and treatment
    # 'IFS' (Internal Field Separator) is set to space to split on spaces
    # 'read' puts the split parts into the array 'test_comparison'
    IFS=' ' read -r -a test_comparison <<< "${TEST[$test_name]}"

    # Run MAGeCK test
    mageck test \
        -k A549.count.txt \
        -c "${test_comparison[0]}" \
        -t "${test_comparison[1]}" \
        --norm-method total \
        --pdf-report \
        -n "$test_name"

    # Command explanation:
    # -k A549.count.txt         : Input count table
    # -c "${test_comparison[0]}" : Control samples
    # -t "${test_comparison[1]}" : Treatment samples
    # --norm-method total       : Normalization method
    # --pdf-report             : Generate PDF report
    # -n "$test_name"          : Output prefix

    # Check if this comparison worked
    if [ ! -f "${test_name}.gene_summary.txt" ]; then
        echo "Warning: Analysis failed for $test_name"
    fi
done

#-------------------------------------------------------------------------------
# 5. Final Status Check
#-------------------------------------------------------------------------------
echo "Checking output files..."

# Create array of required output files to check
required_files=(
    "A549.count.txt"                # Raw count table
    "A549.count_normalized.txt"     # Normalized counts
    "A549.count_summary.txt"        # Summary statistics
    "A549.count.report.pdf"         # Quality control report
)

# Initialize counter for missing files
missing_files=0

# Check each required file
for file in "${required_files[@]}"; do
    if [ ! -f "$file" ]; then
        echo "Missing output file: $file"
        # Increment counter using arithmetic expansion $((...))
        missing_files=$((missing_files + 1))
    fi
done

# Print final status
# '-eq' is for numeric equality comparison
if [ $missing_files -eq 0 ]; then
    echo "Analysis completed successfully!"
    echo "Output files are ready for review."
else
    echo "Analysis completed with warnings. Please check the logs above."
fi

#===============================================================================
# Expected Output Files:
#
# 1. Count Analysis Files:
#    - A549.count.txt              : Raw count table of sgRNA reads
#    - A549.count_normalized.txt   : Normalized count data
#    - A549.count_summary.txt      : Summary statistics of the counting
#    - A549.count.report.pdf       : Quality control metrics and plots
#
# 2. Each Comparison (e.g., "D0-IV-v-D21-IV") Produces:
#    - [test_name].gene_summary.txt : Statistics at gene level
#    - [test_name].sgrna_summary.txt: Statistics at sgRNA level
#    - [test_name].test.report.pdf  : Detailed analysis plots and metrics
#===============================================================================

# Note: If you need to stop the script while it's running, press Ctrl+C
# If you need to make the script executable, use: chmod +x mageck_analysis.sh
# To run the script, use: ./mageck_analysis.sh