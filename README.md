# SAM File Analysis Scripts

This package contains two versions of the SAM file analysis script:

## Files
1. **enhanced_sam_analysis.sh** - Enhanced version with better error handling
2. **simple_sam_analysis.sh** - Educational simplified step by step version without the more complicated functions

## Script Elements 

### Functions
- `show_usage()` - Display usage information
- `validate_file()` - Check file existence
- `validate_sam_format()` - Check if files provided as .sam follow the common sam format
- `validate_assembly_report()` - Check if files provided as assembly report follow assembly rep format
- `count_total_reads()` - Count all reads in SAM files
- `count_aligned_reads()` - Count mapped reads
- `create_chr_mapping()` - Creates mapping from accession to chromosome using assembly report
- `count_reads_per_chromosome()` - Generate chromosome statistics

### Conditionals
- Argument validation (`if [ $# -lt 2 ]`)
- File existence checks (`if [[ ! -f "$file" ]]`)
- Error handling throughout the script

### Loops
- `for` loops to process multiple SAM files
- `for` loops to validate each input file
- `while` loops to validate SAM and assembly report format
- Loop through array of SAM files

### Redirections
- `> "$output_file"` - Create/overwrite output file
- `>> "$output_file"` - Append to output file
- `>&2` - Redirect to stderr for status messages

### Pipes
- `grep -v "^@" | wc -l` - Count non-header lines
- `sort | uniq -c | sort -nr` - Process chromosome counts
- `awk ... | sort | join ...` - Complex data processing pipelines

## SAM Format Understanding

The script processes SAM files with these key fields:
- Column 3 (RNAME): Reference sequence name
- Column 4 (POS): Mapping position (0 = unmapped)
- Lines starting with @ are headers

## Usage

```bash
chmod +x enhanced_sam_analysis.sh
./enhanced_sam_analysis.sh sample1.sam sample2.sam assembly_report.txt
```

## Output

Creates `output.txt` with:
- Total reads processed
- Number of aligned reads
- Alignment rate percentage
- Table of reads per chromosome
- Script execution time

## Assembly Report Format

The script was made for the canonical NCBI assembly report format. Where field 1 is sequence name and field 5 is GenBank Accession.

- Lines beginning with “#” are comments or header metadata.
- It is tab-delimited with at least 10 columns per record.
- Each data line describes one assembled molecule (chromosome or scaffold) with fields such as:
    · Sequence Name (e.g., X, 2L, 2R, 3L, 3R, 4)
    · Sequence Role (e.g., assembled-molecule)
    · Assigned Molecule (e.g., X, 2L, etc.)
    · Type (e.g., Chromosome)
    · GenBank Accession (e.g., CP122180.1)
    · RefSeq Accession (often “<>” if not provided)
    · Relationship (e.g., na)
    · Assembly Unit (e.g., Primary Assembly)
    · Sequence Length (e.g., 23542271)
    · UCSC Name (e.g., na)

## Example Output

```
Total number of reads processed: 275952
Number of aligned reads: 271972
Alignment rate: 98.56%

Reads aligned per chromosome:
ACC         CHR    COUNT
CP122175.1  2L     114951
CP122176.1  2R     123480
CP122177.1  3L     144389
...

Script execution completed in 15 seconds.
```
