#!/usr/bin/bash

# SAM File Analysis Script
# Author: Daniel Bernad Ibáñez and José Manuel Godoy Fernandez  
# Description: Processes SAM files and generates alignment statistics

# Function to display usage information
function show_usage() {
    echo "Usage: $0 SAM1 [SAM2 SAM3...] assembly_report.txt"
    echo ""
    echo "This script processes SAM files and generates alignment statistics."
    echo ""
    echo "Parameters:"
    echo "  SAM files: One or more SAM alignment files"
    echo "  assembly_report: Assembly report file with accession and chromosome mapping"
    echo ""
    echo "Output: Creates output.txt with alignment statistics and execution time"
    exit 1
}

# Function to validate file existence and readability; provide file and extension (.sam) as arguments
function validate_file() {
    local file="$1"
    local file_type="$2"

    # Does the file exist?
    if [[ ! -f "$file" ]]; then
        echo "Error: $file_type file '$file' not found!" >&2
        exit 1
    fi

    # Is the file readable?
    if [[ ! -r "$file" ]]; then
        echo "Error: $file_type file '$file' is not readable!" >&2
        exit 1
    fi
}

# Function to validate basic SAM format
function validate_sam_format() {
    local file="$1"

    # Read up to the first 100 lines or until a non-header line is found
    local line count=0
    while IFS= read -r line && [[ $count -lt 100 ]]; do
        ((count++))
        # Skip header lines starting with '@'
        [[ $line == @* ]] && continue

        # Check that the line has at least 11 tab-separated fields
        local num_fields
        num_fields=$(awk -F $'\t' '{print NF; exit}' <<<"$line")
        if [[ $num_fields -lt 11 ]]; then
            echo "Error: File '$file' is not valid SAM format (less than 11 columns on line $count after header)." >&2
            exit 1
        fi

        # If we reach here, the first data line is valid; stop checking
        return 0
    done < "$file"

    # If only headers were found, accept the file as valid SAM
    return 0
}

# Function to validate basic assembly report format
function validate_assembly_report() {
    local file="$1"

    # Read up to the first 100 lines or until a non-comment line
    local line count=0
    while IFS= read -r line && [[ $count -lt 100 ]]; do
        ((count++))
        # Skip comment/header lines starting with '#'
        [[ $line == \#* ]] && continue

        # Split on tabs and count fields
        local num_fields
        num_fields=$(awk -F $'\t' '{print NF; exit}' <<<"$line")
        if [[ $num_fields -lt 8 ]]; then
            echo "Error: File '$file' is not a valid assembly report (found $num_fields columns on line $count after header, expected ≥8)." >&2
            exit 1
        fi

        # Check that field 5 matches accession pattern (e.g. two letters, digits, dot, digits)
        local acc
        acc=$(awk -F $'\t' '{print $5; exit}' <<<"$line")
        if [[ ! $acc =~ ^[A-Z]{2}[0-9]+\.[0-9]+$ ]]; then
            echo "Error: Field 5 ('$acc') on line $count is not a valid accession." >&2
            exit 1
        fi

        # Passed checks for first data line; stop checking
        return 0
    done < "$file"

    # If all lines were comments, accept as valid
    return 0
}

# Function to process total reads from SAM files
function count_total_reads() {
    local sam_files=("$@")
    local total_reads=0

    echo "Counting total reads..." >&2

    for sam_file in "${sam_files[@]}"; do
        # Count all non-header lines (reads) - excluding lines starting with @
        # Use grep -c for counting instead of wc -l for efficiency
        local file_reads
        file_reads=$(grep -cv "^@" "$sam_file" 2>/dev/null || echo 0)
        total_reads=$((total_reads + file_reads))
        echo "  $sam_file: $file_reads reads" >&2
    done

    echo "$total_reads"
}

# Function to count aligned reads (reads with POS > 0 and RNAME != *)
function count_aligned_reads() {
    local sam_files=("$@")
    local aligned_reads=0

    echo "Counting aligned reads..." >&2 # >&2 redirects the output of a command to the standard error stream instead of the standard output stream. Errors only appear in temrinal

    for sam_file in "${sam_files[@]}"; do
        # Count reads where:
        # - Column 3 (RNAME) is not "*" (has reference)
        # - Column 4 (POS) is greater than 0 (mapped position)
        local file_aligned
        # Start count=0
        # Count + 1 for each line not starting with '@' (header), where column 3 (RNAME) is not "*", and column 4 (POS) > 0
        file_aligned=$(awk 'BEGIN {count=0} 
                           /^[^@]/ && $3 != "*" && $4 > 0 {count++} 
                           END {print count}' "$sam_file")
        aligned_reads=$((aligned_reads + file_aligned)) # Add file's amount of reads to total
        echo "  $sam_file: $file_aligned aligned reads" >&2 # Print counts per SAM
    done

    echo "$aligned_reads" # Total aligned reads across all files
}

# Function to parse assembly report and create chromosome mapping
function create_chr_mapping() {
    local assembly_report="$1" # Local variabñe stores assembly report
    local temp_mapping="/tmp/chr_mapping_$$.txt" # Local variable with a temporary file path ($$ is the script's process ID)

    echo "Processing assembly report..." >&2
    > "$temp_mapping" # Creates temporary file or empties if it already exists

    if [[ -f "$assembly_report" ]]; then #If assembly report exists
        # set field delimiter to TAB and field separator also to tab (tab = $'\t')
        # skips (next) comment/header lines (starting with #)
        # Process lines with at least 5 columns; take accession from column 5 and chromosome name from column 1
        # If both are non-empty, prints them separated by tab, output on temp mapping file. Accesion first and chr second, easier for later join
        awk -F $'\t' 'BEGIN { OFS="\t" }
            /^#/ { next }
            NF >= 5 {
                chr = $1
                acc = $5
                if (acc != "" && chr != "")
                    print acc, chr 
            }' "$assembly_report" > "$temp_mapping"

        local mapping_count
        mapping_count=$(wc -l < "$temp_mapping") # COunts lines writteng in temp file, th enumber of chromosomes mapped
        echo "  Created mapping for $mapping_count chromosomes" >&2 
    else
        echo "  Warning: Assembly report not found" >&2
    fi

    echo "$temp_mapping" # Returns the temporary mapping filename as the function output, so other script parts can use it.
}

# Function to count reads per chromosome with improved error handling
function count_reads_per_chromosome() {
    local sam_files=("$@") # Create array containing all arguments passed to the function
    local assembly_report="${sam_files[-1]}"  # Last argument is assembly report
    unset sam_files[-1]  # Remove assembly report from SAM files array

    echo "Analyzing reads per chromosome..." >&2

    # Calls the earlier create_chr_mapping() function to generate a temporary chromosome mapping file, storing its path in chr_mapping
    local chr_mapping
    chr_mapping=$(create_chr_mapping "$assembly_report")

    # Create temporary file for chromosome counts, ith unique names using the process ID ($$)
    local temp_counts="/tmp/chr_counts_$$.txt"
    local temp_acc="/tmp/acc_$$.txt"

    # Extract all reference names from aligned reads
    for sam_file in "${sam_files[@]}"; do
        # Extract reference names or accession (column 3) from aligned reads
        # Set OFS (ouput field separator) to tab
        # From all lines not starting with @ and RNAME != *, POS > 0 (aligned reads) extract column 3 (ACC)
        awk 'BEGIN {OFS="\t"} 
             /^[^@]/ && $3 != "*" && $4 > 0 {print $3}' "$sam_file"
    done | sort > "$temp_acc" # Extracted acc are piped to sort and sorted output is written on temp_acc

    # Count occurrences of each reference
    if [[ -s "$temp_acc" ]]; then # if temp_acc is not empty
        uniq -c "$temp_acc" | awk '{print $2"\t"$1}' > "$temp_counts"  # Count all ocurrences of each acc with uniq -c, output stored on temp_counts, with acc first and counts second

        # Join with chromosome mapping if available
        if [[ -s "$chr_mapping" ]]; then # If chromosome mapping file exists and is not empty
            # Sort mapping file by accession for join
            sort -k1,1 "$chr_mapping" > "${chr_mapping}.sorted"
            sort -k1,1 "$temp_counts" > "${temp_counts}.sorted"

            # Perform join and format output
            # Joun the sorted files on the first column (acc in both) with tab as delimiter.
            join -t $'\t' -1 1 -2 1 "${chr_mapping}.sorted" "${temp_counts}.sorted" 2>/dev/null | \
            #Format change via awk to accesion<tab>chromosome<tab>count
            awk -F'\t' '{printf "%s\t%s\t%d\n", $1, $2, $3}' | \
            #%s means print a string.
            #\t means insert a tab character.
            #%d means print an integer (decimal).
            #\n means print a newline at the end.

            sort -k3 -nr  # Sort by count (descending), because the function directly prints its main output echo isn't needed.

            # Clean up temporary sorted files
            rm -f "${chr_mapping}.sorted" "${temp_counts}.sorted"
        else
            # No mapping available, show raw reference counts
            echo "# No chromosome mapping available, showing raw reference names:" >&2
            awk -F'\t' '{printf "%s\tUnknown\t%d\n", $1, $2}' "$temp_counts" | \
            sort -k3 -nr
        fi
    else
        echo "# No aligned reads found" >&2
    fi

    # Clean up temporary files
    rm -f "$chr_mapping" "$temp_counts" "$temp_acc"
}

# Main function to orchestrate the script's workflow
function main() {
    # Record start time in seconds
    local start_time
    start_time=$(date +%s)

    # Validate arguments, if fewer than 2 arguments print error and exit.
    if [[ $# -lt 2 ]]; then
        echo "Error: At least 2 arguments required (at least 1 SAM file and 1 assembly report)" >&2
        show_usage
    fi

    # Extract SAM files and assembly report
    local sam_files=("${@:1:(($#-1))}")  # All arguments except the last one
    local assembly_report="${@: -1}"      # Last argument

    echo "Starting SAM file analysis..." >&2
    echo "SAM files: ${sam_files[*]}" >&2
    echo "Assembly report: $assembly_report" >&2
    echo "" >&2

    # Validate all input files for existence and readability
    for sam_file in "${sam_files[@]}"; do
        validate_file "$sam_file" "SAM"
    done
    validate_file "$assembly_report" "Assembly report"

    # Check files provided are indeed sam files
    for sam_file in "${sam_files[@]}"; do
    validate_sam_format "$sam_file"
    done

    # Validate assembly report 
    validate_assembly_report "$assembly_report"

    # Create (or overwrite) output file with header
    local output_file="output.txt"
    {
        echo "SAM File Analysis Results"
        echo "========================"
        echo "Generated on: $(date)"
        echo ""
    } > "$output_file"

    # Count total reads
    local total_reads
    total_reads=$(count_total_reads "${sam_files[@]}")
    echo "Total number of reads processed: $total_reads" >> "$output_file"

    # Count aligned reads
    local aligned_reads
    aligned_reads=$(count_aligned_reads "${sam_files[@]}")
    echo "Number of aligned reads: $aligned_reads" >> "$output_file"

    # Calculate alignment percentage
    if [[ $total_reads -gt 0 ]]; then
        local alignment_percentage
        alignment_percentage=$(awk "BEGIN {printf \"%.2f\", ($aligned_reads/$total_reads)*100}") #%.2f means is formatted to two decimals
        echo "Alignment rate: ${alignment_percentage}%" >> "$output_file"
    fi

    # Add separator and chromosome table header
    {
        echo ""
        echo "Reads aligned per chromosome:"
        echo "ACC\tCHR\tCOUNT"
    } >> "$output_file"

    # Process chromosome alignments
    local chr_results
    chr_results=$(count_reads_per_chromosome "$@")

    # If chromosome data is available, print into the output file
    if [[ -n "$chr_results" ]]; then
        echo "$chr_results" >> "$output_file"
    else
        echo "No chromosome alignment data available" >> "$output_file"
    fi

    # Record end time and calculate execution time
    local end_time
    end_time=$(date +%s)
    local exec_time
    exec_time=$((end_time - start_time))

    # Add execution time to output
    {
        echo ""
        echo "Script execution completed in $exec_time seconds."
    } >> "$output_file"

    echo "" >&2
    echo "Analysis complete! Results saved to $output_file" >&2
    echo "Total reads: $total_reads" >&2
    echo "Aligned reads: $aligned_reads" >&2
    echo "Execution time: $exec_time seconds" >&2
}

# Set up trap for cleanup on script exit
trap 'rm -f /tmp/chr_mapping_$$.* /tmp/chr_counts_$$.* /tmp/refs_$$.*' EXIT

# Execute main function with all arguments
main "$@"
