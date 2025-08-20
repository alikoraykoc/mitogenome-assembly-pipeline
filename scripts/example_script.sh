#!/bin/bash
# Example run script for mitogenome assembly pipeline
# Demonstrates usage without actual data included

set -euo pipefail

echo "========================================"
echo "Mitogenome Assembly Pipeline - Example"
echo "========================================"
echo "This script demonstrates pipeline usage"
echo ""

# Check if we're in the examples directory
if [[ ! -f "run_example.sh" ]]; then
    echo "Error: Please run this script from the examples/ directory"
    echo "Usage: cd examples && ./run_example.sh"
    exit 1
fi

# Set up variables
SCRIPT_DIR="../scripts"
OUTPUT_DIR="example_output"
DATA_DIR="example_data"

# Check if script exists
if [[ ! -f "$SCRIPT_DIR/assemble_mitogenome.sh" ]]; then
    echo "Error: Main script not found at $SCRIPT_DIR/assemble_mitogenome.sh"
    echo "Please ensure you're running this from the correct directory"
    exit 1
fi

# Create output directory
mkdir -p "$OUTPUT_DIR"

echo "Step 1: Checking for example data..."

# Check for example data
if [[ ! -f "$DATA_DIR/sample_R1.fastq.gz" ]] || [[ ! -f "$DATA_DIR/sample_R2.fastq.gz" ]] || [[ ! -f "$DATA_DIR/reference.fasta" ]]; then
    echo ""
    echo "ℹ️  Example data not found. To run this example:"
    echo ""
    echo "1. Add your test data to $DATA_DIR/:"
    echo "   - sample_R1.fastq.gz (forward reads)"
    echo "   - sample_R2.fastq.gz (reverse reads)"
    echo "   - reference.fasta (reference mitogenome)"
    echo ""
    echo "2. Then run: ./run_example.sh"
    echo ""
    echo "📋 Example command that will be used:"
    echo ""
    
    # Show the command that would be executed
    cat << 'EOF'
../scripts/assemble_mitogenome.sh \
  --r1 example_data/sample_R1.fastq.gz \
  --r2 example_data/sample_R2.fastq.gz \
  --ref example_data/reference.fasta \
  --prefix example_sample \
  --outdir example_output \
  --threads 4 \
  --min-cov 20 \
  --min-breadth 0.98 \
  --max-n-percent 2 \
  --expected-size-min 15000 \
  --expected-size-max 17000 \
  --mask-lowdp
EOF
    echo ""
    echo "📊 Expected outputs:"
    echo "  - example_sample.consensus.fasta (final assembly)"
    echo "  - example_sample_QC_report.txt (quality control)"
    echo "  - example_sample_assembly_stats.txt (statistics)"
    echo "  - example_sample_log.txt (processing log)"
    echo ""
    echo "🧬 Pipeline validated with:"
    echo "  - Orthoptera mitogenomes (15-17 kb typical)"
    echo "  - High-quality Illumina paired-end data"
    echo "  - Publication-ready assemblies"
    exit 0
fi

echo "✅ Example data found!"
echo ""
echo "Step 2: Running mitogenome assembly..."
echo ""
echo "Command:"
echo "$SCRIPT_DIR/assemble_mitogenome.sh \\"
echo "  --r1 $DATA_DIR/sample_R1.fastq.gz \\"
echo "  --r2 $DATA_DIR/sample_R2.fastq.gz \\"
echo "  --ref $DATA_DIR/reference.fasta \\"
echo "  --prefix example_sample \\"
echo "  --outdir $OUTPUT_DIR \\"
echo "  --threads 4 \\"
echo "  --min-cov 20 \\"
echo "  --min-breadth 0.98 \\"
echo "  --max-n-percent 2 \\"
echo "  --expected-size-min 15000 \\"
echo "  --expected-size-max 17000 \\"
echo "  --mask-lowdp"
echo ""

# Run the assembly
$SCRIPT_DIR/assemble_mitogenome.sh \
  --r1 "$DATA_DIR/sample_R1.fastq.gz" \
  --r2 "$DATA_DIR/sample_R2.fastq.gz" \
  --ref "$DATA_DIR/reference.fasta" \
  --prefix example_sample \
  --outdir "$OUTPUT_DIR" \
  --threads 4 \
  --min-cov 20 \
  --min-breadth 0.98 \
  --max-n-percent 2 \
  --expected-size-min 15000 \
  --expected-size-max 17000 \
  --mask-lowdp

echo ""
echo "========================================"
echo "Example completed successfully!"
echo "========================================"

# Display results
CONSENSUS="$OUTPUT_DIR/example_sample.consensus.fasta"
QC_REPORT="$OUTPUT_DIR/example_sample_QC_report.txt"

if [[ -f "$CONSENSUS" ]]; then
    echo ""
    echo "Results:"
    echo "--------"
    
    # Get assembly length
    if command -v seqkit >/dev/null 2>&1; then
        echo "Assembly statistics:"
        seqkit stats "$CONSENSUS"
    else
        LENGTH=$(grep -v '^>' "$CONSENSUS" | tr -d '\n' | wc -c)
        echo "Assembly length: $LENGTH bp"
    fi
    
    echo ""
    echo "Output files:"
    echo "  - Final assembly: $CONSENSUS"
    echo "  - QC report: $QC_REPORT"
    echo "  - Full log: $OUTPUT_DIR/example_sample_log.txt"
    
    if [[ -f "$QC_REPORT" ]]; then
        echo ""
        echo "Quality Control Summary:"
        echo "------------------------"
        tail -20 "$QC_REPORT"
    fi
    
    echo ""
    echo "🎉 Success! Your assembly is ready for:"
    echo "  1. Gene annotation (MITOS2, MitoZ, etc.)"
    echo "  2. Phylogenetic analysis"
    echo "  3. Publication submission"
    
else
    echo "❌ Error: Assembly failed. Check the log file for details."
    if [[ -f "$OUTPUT_DIR/example_sample_log.txt" ]]; then
        echo "Last few lines of log:"
        tail -10 "$OUTPUT_DIR/example_sample_log.txt"
    fi
    exit 1
fi