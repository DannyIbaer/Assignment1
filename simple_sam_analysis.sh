#!/usr/bin/bash

# Simple SAM Analysis Script - Educational Version
# This version includes detailed comments explaining each concept

echo "=== SAM File Analysis Script - Educational Version ==="
echo

# Show usage 
function show_usage() {
    echo "Usage: $0 sam_file1 [sam_file2...] assembly_report"
    echo "This script demonstrates SAM file processing concepts"
    exit 1
}

# Check if enough arguments provided
if [ $# -lt 2 ]; then
    echo "Error: Need at least 2 files (1 SAM + 1 assembly report)"
    show_usage
fi

# Record start time for execution timing
START_TIME=$(date +%s)

# Get all arguments except the last (SAM files)
SAM_FILES=("${@:1:(($#-1))}")
# Get the last argument (assembly report)
ASSEMBLY_REPORT="${@: -1}"

echo "Processing SAM files: ${SAM_FILES[*]}"
echo "Assembly report: $ASSEMBLY_REPORT"
echo

# Create output file
OUTPUT_FILE="output.txt"
> "$OUTPUT_FILE"  # REDIRECTION: Create empty file

echo "SAM File Analysis Results" >> "$OUTPUT_FILE"
echo "=========================" >> "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

# Initialize counters
TOTAL_READS=0
ALIGNED_READS=0

# LOOP: Process each SAM file
for SAM_FILE in "${SAM_FILES[@]}"; do
    echo "Processing $SAM_FILE..."

    # Check if file exists
    if [[ ! -f "$SAM_FILE" ]]; then
        echo "Warning: $SAM_FILE not found, skipping..."
        continue
    fi

    # Count total reads (non-header lines)
    # PIPE: grep output piped to wc
    FILE_READS=$(grep -v "^@" "$SAM_FILE" | wc -l)
    TOTAL_READS=$((TOTAL_READS + FILE_READS))

    # Count aligned reads (POS > 0 and RNAME != "*")
    # Using AWK for field processing
    FILE_ALIGNED=$(awk '/^[^@]/ && $3 != "*" && $4 > 0 {count++} END {print count+0}' "$SAM_FILE")
    ALIGNED_READS=$((ALIGNED_READS + FILE_ALIGNED))

    echo "  Total reads in $SAM_FILE: $FILE_READS"
    echo "  Aligned reads in $SAM_FILE: $FILE_ALIGNED"
done

echo
echo "Writing results to $OUTPUT_FILE..."

# Write results using REDIRECTION
echo "Total number of reads processed: $TOTAL_READS" >> "$OUTPUT_FILE"
echo "Number of aligned reads: $ALIGNED_READS" >> "$OUTPUT_FILE"
echo >> "$OUTPUT_FILE"

# Process chromosome alignments
echo "Reads aligned per chromosome:" >> "$OUTPUT_FILE"
echo "ACC\tCHR\tCOUNT" >> "$OUTPUT_FILE"

# Extract reference names and count them
# multiple commands connected with pipes
for SAM_FILE in "${SAM_FILES[@]}"; do
    [[ -f "$SAM_FILE" ]] && awk '/^[^@]/ && $3 != "*" && $4 > 0 {print $3}' "$SAM_FILE"
done | sort | uniq -c | sort -nr | awk '{print $2"\t""Unknown"\t"$1}' >> "$OUTPUT_FILE"

# Calculate execution time
END_TIME=$(date +%s)
EXEC_TIME=$((END_TIME - START_TIME))

echo >> "$OUTPUT_FILE"
echo "Script execution completed in $EXEC_TIME seconds." >> "$OUTPUT_FILE"

echo
echo "Analysis complete!"
echo "Results saved to: $OUTPUT_FILE"
echo "Execution time: $EXEC_TIME seconds"

# Display the results
echo
echo "=== Results Preview ==="
cat "$OUTPUT_FILE"
