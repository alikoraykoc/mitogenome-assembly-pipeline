#!/bin/bash
# Batch processing script for multiple mitogenome assemblies
# Processes multiple samples with consistent parameters

set -euo pipefail

# ==== Default Parameters ====
SAMPLE_LIST=""
REF_DIR=""
OUTDIR="batch_results"
THREADS=4
MIN_COV=20
MIN_BREADTH=0.98
MAX_N_PERCENT=2
EXPECTED_SIZE_MIN=15000
EXPECTED_SIZE_MAX=20000
MASK_LOWDP=false
PARALLEL_JOBS=1

# ==== Usage Function ====
usage() {
    cat << EOF
Batch Mitogenome Assembly Pipeline

Usage: $0 --sample-list SAMPLES.txt --ref-dir REFS/ [OPTIONS]

Required Arguments:
  --sample-list FILE    Tab-separated file: sample_name<TAB>R1_path<TAB>R2_path<TAB>reference_name
  --ref-dir DIR         Directory containing reference genomes

Optional Arguments:
  --outdir DIR          Output directory (default: batch_results)
  --threads INT         Threads per job (default: 4)
  --parallel-jobs INT   Number of parallel assemblies (default: 1)
  --min-cov INT         Minimum coverage (default: 20)
  --min-breadth FLOAT   Minimum breadth (default: 0.98)
  --max-n-percent INT   Maximum N% (default: 2)
  --expected-size-min INT  Min expected size (default: 15000)
  --expected-size-max INT  Max expected size (default: 20000)
  --mask-lowdp          Mask low-depth regions

Sample List Format:
sample1<TAB>data/sample1_R1.fastq.gz<TAB>data/sample1_R2.fastq.gz<TAB>reference1.fasta
sample2<TAB>data/sample2_R1.fastq.gz<TAB>data/sample2_R2.fastq.gz<TAB>reference2.fasta

Example:
$0 --sample-list samples.txt --ref-dir references/ --outdir results/ --parallel-jobs 4

EOF
    exit 1
}

# ==== Parse Arguments ====
while [[ $# -gt 0 ]]; do
    case $1 in
        --sample-list) SAMPLE_LIST="$2"; shift ;;
        --ref-dir) REF_DIR="$2"; shift ;;
        --outdir) OUTDIR="$2"; shift ;;
        --threads) THREADS="$2"; shift ;;
        --parallel-jobs) PARALLEL_JOBS="$2"; shift ;;
        --min-cov) MIN_COV="$2"; shift ;;
        --min-breadth) MIN_BREADTH="$2"; shift ;;
        --max-n-percent) MAX_N_PERCENT="$2"; shift ;;
        --expected-size-min) EXPECTED_SIZE_MIN="$2"; shift ;;
        --expected-size-max) EXPECTED_SIZE_MAX="$2"; shift ;;
        --mask-lowdp) MASK_LOWDP=true ;;
        --help|-h) usage ;;
        *) echo "Unknown option: $1"; usage ;;
    esac
    shift
done

# ==== Validation ====
if [[ -z "$SAMPLE_LIST" || -z "$REF_DIR" ]]; then
    echo "Error: --sample-list and --ref-dir are required"
    usage
fi

if [[ ! -f "$SAMPLE_LIST" ]]; then
    echo "Error: Sample list file not found: $SAMPLE_LIST"
    exit 1
fi

if [[ ! -d "$REF_DIR" ]]; then
    echo "Error: Reference directory not found: $REF_DIR"
    exit 1
fi

# Check if main script exists
SCRIPT_DIR="$(dirname "$0")"
MAIN_SCRIPT="$SCRIPT_DIR/assemble_mitogenome.sh"

if [[ ! -f "$MAIN_SCRIPT" ]]; then
    echo "Error: Main script not found: $MAIN_SCRIPT"
    exit 1
fi

# Create output directory
mkdir -p "$OUTDIR"

# ==== Main Processing ====
BATCH_LOG="$OUTDIR/batch_processing.log"
SUMMARY_FILE="$OUTDIR/batch_summary.txt"
FAILED_SAMPLES="$OUTDIR/failed_samples.txt"

echo "=======================================" | tee "$BATCH_LOG"
echo "Batch Mitogenome Assembly Pipeline" | tee -a "$BATCH_LOG"
echo "=======================================" | tee -a "$BATCH_LOG"
echo "Started: $(date)" | tee -a "$BATCH_LOG"
echo "Sample list: $SAMPLE_LIST" | tee -a "$BATCH_LOG"
echo "Reference dir: $REF_DIR" | tee -a "$BATCH_LOG"
echo "Output dir: $OUTDIR" | tee -a "$BATCH_LOG"
echo "Parallel jobs: $PARALLEL_JOBS" | tee -a "$BATCH_LOG"
echo "" | tee -a "$BATCH_LOG"

# Initialize summary files
echo "Sample_Name	Status	Assembly_Length	AT_Content	Coverage	Completeness" > "$SUMMARY_FILE"
echo "# Failed samples:" > "$FAILED_SAMPLES"

# Read samples and create job list
TOTAL_SAMPLES=$(wc -l < "$SAMPLE_LIST")
echo "Processing $TOTAL_SAMPLES samples..." | tee -a "$BATCH_LOG"
echo ""

# Function to process a single sample
process_sample() {
    local sample_name="$1"
    local r1_path="$2"
    local r2_path="$3"
    local ref_name="$4"
    local sample_outdir="$OUTDIR/$sample_name"
    
    echo "[$(date)] Starting $sample_name" >> "$BATCH_LOG"
    
    # Check input files
    if [[ ! -f "$r1_path" ]]; then
        echo "ERROR: R1 file not found: $r1_path" >> "$BATCH_LOG"
        echo "$sample_name	FAILED	Missing_R1	-	-	-" >> "$SUMMARY_FILE"
        echo "$sample_name: Missing R1 file" >> "$FAILED_SAMPLES"
        return 1
    fi
    
    if [[ ! -f "$r2_path" ]]; then
        echo "ERROR: R2 file not found: $r2_path" >> "$BATCH_LOG"
        echo "$sample_name	FAILED	Missing_R2	-	-	-" >> "$SUMMARY_FILE"
        echo "$sample_name: Missing R2 file" >> "$FAILED_SAMPLES"
        return 1
    fi
    
    local ref_path="$REF_DIR/$ref_name"
    if [[ ! -f "$ref_path" ]]; then
        echo "ERROR: Reference not found: $ref_path" >> "$BATCH_LOG"
        echo "$sample_name	FAILED	Missing_Ref	-	-	-" >> "$SUMMARY_FILE"
        echo "$sample_name: Missing reference file" >> "$FAILED_SAMPLES"
        return 1
    fi
    
    # Create sample output directory
    mkdir -p "$sample_outdir"
    
    # Build command
    local cmd="$MAIN_SCRIPT"
    cmd="$cmd --r1 '$r1_path'"
    cmd="$cmd --r2 '$r2_path'"
    cmd="$cmd --ref '$ref_path'"
    cmd="$cmd --prefix '$sample_name'"
    cmd="$cmd --outdir '$sample_outdir'"
    cmd="$cmd --threads $THREADS"
    cmd="$cmd --min-cov $MIN_COV"
    cmd="$cmd --min-breadth $MIN_BREADTH"
    cmd="$cmd --max-n-percent $MAX_N_PERCENT"
    cmd="$cmd --expected-size-min $EXPECTED_SIZE_MIN"
    cmd="$cmd --expected-size-max $EXPECTED_SIZE_MAX"
    
    if [[ "$MASK_LOWDP" == "true" ]]; then
        cmd="$cmd --mask-lowdp"
    fi
    
    # Run assembly
    echo "Command: $cmd" >> "$BATCH_LOG"
    
    if eval "$cmd" >> "$BATCH_LOG" 2>&1; then
        # Assembly succeeded - extract statistics
        local consensus="$sample_outdir/${sample_name}.consensus.fasta"
        local qc_report="$sample_outdir/${sample_name}_QC_report.txt"
        
        if [[ -f "$consensus" ]]; then
            # Extract assembly statistics
            local length=$(grep -v '^>' "$consensus" | tr -d '\n' | wc -c | xargs)
            local at_content="Unknown"
            local coverage="Unknown"
            local completeness="Unknown"
            
            # Try to extract statistics from QC report
            if [[ -f "$qc_report" ]]; then
                at_content=$(grep "AT content:" "$qc_report" | grep -o "[0-9.]*%" | head -1 || echo "Unknown")
                coverage=$(grep "Average coverage:" "$qc_report" | grep -o "[0-9.]*" | head -1 || echo "Unknown")
                
                if grep -q "✅.*PASS" "$qc_report"; then
                    completeness="PASS"
                else
                    completeness="WARNING"
                fi
            fi
            
            echo "$sample_name	SUCCESS	$length	$at_content	$coverage	$completeness" >> "$SUMMARY_FILE"
            echo "[$(date)] Completed $sample_name: $length bp" >> "$BATCH_LOG"
        else
            echo "$sample_name	FAILED	No_Output	-	-	-" >> "$SUMMARY_FILE"
            echo "$sample_name: No consensus output" >> "$FAILED_SAMPLES"
            echo "[$(date)] Failed $sample_name: No output file" >> "$BATCH_LOG"
        fi
    else
        echo "$sample_name	FAILED	Assembly_Error	-	-	-" >> "$SUMMARY_FILE"
        echo "$sample_name: Assembly pipeline failed" >> "$FAILED_SAMPLES"
        echo "[$(date)] Failed $sample_name: Assembly error" >> "$BATCH_LOG"
    fi
}

# Export function for parallel processing
export -f process_sample
export MAIN_SCRIPT OUTDIR THREADS MIN_COV MIN_BREADTH MAX_N_PERCENT
export EXPECTED_SIZE_MIN EXPECTED_SIZE_MAX MASK_LOWDP BATCH_LOG SUMMARY_FILE FAILED_SAMPLES

# Process samples in parallel
if command -v parallel >/dev/null 2>&1; then
    echo "Using GNU parallel for processing..." | tee -a "$BATCH_LOG"
    cat "$SAMPLE_LIST" | parallel -j "$PARALLEL_JOBS" --colsep '\t' process_sample {1} {2} {3} {4}
else
    echo "GNU parallel not available, processing sequentially..." | tee -a "$BATCH_LOG"
    
    # Sequential processing
    while IFS=\t' read -r sample_name r1_path r2_path ref_name; do
        # Skip empty lines and comments
        [[ -z "$sample_name" || "$sample_name" =~ ^# ]] && continue
        
        process_sample "$sample_name" "$r1_path" "$r2_path" "$ref_name"
        
    done < "$SAMPLE_LIST"
fi

# ==== Final Summary ====
echo "" | tee -a "$BATCH_LOG"
echo "=======================================" | tee -a "$BATCH_LOG"
echo "Batch Processing Complete!" | tee -a "$BATCH_LOG"
echo "=======================================" | tee -a "$BATCH_LOG"
echo "Finished: $(date)" | tee -a "$BATCH_LOG"

# Count results
TOTAL_PROCESSED=$(tail -n +2 "$SUMMARY_FILE" | wc -l)
SUCCESSFUL=$(tail -n +2 "$SUMMARY_FILE" | grep -c "SUCCESS" || true)
FAILED=$(tail -n +2 "$SUMMARY_FILE" | grep -c "FAILED" || true)

echo "" | tee -a "$BATCH_LOG"
echo "Results Summary:" | tee -a "$BATCH_LOG"
echo "  Total samples: $TOTAL_PROCESSED" | tee -a "$BATCH_LOG"
echo "  Successful: $SUCCESSFUL" | tee -a "$BATCH_LOG"
echo "  Failed: $FAILED" | tee -a "$BATCH_LOG"
echo "" | tee -a "$BATCH_LOG"

if [[ $SUCCESSFUL -gt 0 ]]; then
    echo "✅ Successful assemblies:" | tee -a "$BATCH_LOG"
    tail -n +2 "$SUMMARY_FILE" | grep "SUCCESS" | cut -f1,3 | while read -r name length; do
        echo "  $name: $length bp" | tee -a "$BATCH_LOG"
    done
    echo "" | tee -a "$BATCH_LOG"
fi

if [[ $FAILED -gt 0 ]]; then
    echo "❌ Failed assemblies:" | tee -a "$BATCH_LOG"
    tail -n +2 "$SUMMARY_FILE" | grep "FAILED" | cut -f1,2 | while read -r name reason; do
        echo "  $name: $reason" | tee -a "$BATCH_LOG"
    done
    echo "" | tee -a "$BATCH_LOG"
fi

echo "Output files:" | tee -a "$BATCH_LOG"
echo "  Summary: $SUMMARY_FILE" | tee -a "$BATCH_LOG"
echo "  Log: $BATCH_LOG" | tee -a "$BATCH_LOG"
echo "  Failed samples: $FAILED_SAMPLES" | tee -a "$BATCH_LOG"
echo "  Individual results: $OUTDIR/[sample_name]/" | tee -a "$BATCH_LOG"

# Create collective FASTA file
COLLECTIVE_FASTA="$OUTDIR/all_mitogenomes.fasta"
echo "Creating collective FASTA file: $COLLECTIVE_FASTA" | tee -a "$BATCH_LOG"

> "$COLLECTIVE_FASTA"
for sample_dir in "$OUTDIR"/*/; do
    if [[ -d "$sample_dir" ]]; then
        sample_name=$(basename "$sample_dir")
        consensus="$sample_dir/${sample_name}.consensus.fasta"
        if [[ -f "$consensus" ]]; then
            cat "$consensus" >> "$COLLECTIVE_FASTA"
        fi
    fi
done

if [[ -s "$COLLECTIVE_FASTA" ]]; then
    num_seqs=$(grep -c '^>' "$COLLECTIVE_FASTA")
    echo "  Collective FASTA: $num_seqs sequences" | tee -a "$BATCH_LOG"
else
    echo "  No sequences to combine" | tee -a "$BATCH_LOG"
fi

echo ""
echo "🎉 Batch processing complete!"
echo "📊 Check $SUMMARY_FILE for detailed results"
echo "📋 Check $BATCH_LOG for full processing log"

if [[ $FAILED -gt 0 ]]; then
    echo "⚠️  Some samples failed - check $FAILED_SAMPLES for details"
    exit 1
else
    echo "✅ All samples processed successfully!"
    exit 0
fi