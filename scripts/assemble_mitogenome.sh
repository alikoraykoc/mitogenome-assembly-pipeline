#!/bin/bash
set -euo pipefail

# ==== Enhanced Mitogenome Assembly with Quality Control ====
# Suitable for phylogenetic research applications

# ==== Defaults ====
SENS="--very-sensitive-local"
OUTDIR="results"
THREADS=4
HANDLE_AMB=false
MIN_MQ=30       # mpileup -q (min mapping quality)
MIN_BQ=20       # mpileup -Q (min base quality)
MIN_DP=10       # min sample depth after calling
AF_CUT=0.90     # required ALT allele fraction (haploid)
MASK_LOWDP=false # low-depth to N
MIN_COV=10      # minimum average coverage for QC
MIN_BREADTH=0.95 # minimum breadth of coverage (fraction)
MAX_N_PERCENT=5  # maximum percentage of Ns allowed
EXPECTED_SIZE_MIN=15000  # minimum expected mitogenome size (bp)
EXPECTED_SIZE_MAX=20000  # maximum expected mitogenome size (bp)

# ==== Help ====
show_usage() {
    cat << 'USAGE'
Usage: bash assemble_mitogenome.sh --r1 R1.fq.gz --r2 R2.fq.gz --ref ref.fasta --prefix NAME [OPTIONS]

Required Arguments:
  --r1 FILE               Forward reads file (FASTQ, gzipped supported)
  --r2 FILE               Reverse reads file (FASTQ, gzipped supported)
  --ref FILE              Reference mitogenome (FASTA format)
  --prefix NAME           Sample identifier

Optional Arguments:
  --outdir DIR            Output directory (default: results)
  --threads INT           Number of CPU threads (default: 4)
  --sensitivity STR       Bowtie2 sensitivity (default: --very-sensitive-local)
  --min-mq INT            Minimum mapping quality (default: 30)
  --min-bq INT            Minimum base quality (default: 20)
  --min-dp INT            Minimum depth for variant calling (default: 10)
  --af FLOAT              Minimum allele frequency (default: 0.90)
  --min-cov INT           Minimum average coverage (default: 10)
  --min-breadth FLOAT     Minimum coverage breadth (default: 0.95)
  --max-n-percent INT     Maximum N content percentage (default: 5)
  --expected-size-min INT Minimum expected size (default: 15000)
  --expected-size-max INT Maximum expected size (default: 20000)
  --handle-ambiguous      Handle heterozygous sites as ambiguous
  --mask-lowdp            Mask low-depth regions with N
  --help, -h              Show this help message

Examples:
  # Basic usage
  bash assemble_mitogenome.sh --r1 sample_R1.fq.gz --r2 sample_R2.fq.gz --ref ref.fasta --prefix my_sample
  
  # Research-quality assembly
  bash assemble_mitogenome.sh --r1 sample_R1.fq.gz --r2 sample_R2.fq.gz --ref ref.fasta --prefix my_sample --min-cov 20 --min-breadth 0.98
USAGE
}

# Check for help or no arguments
if [[ $# -eq 0 ]] || [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    show_usage
    exit 0
fi

# ==== Parse args ====
while [[ $# -gt 0 ]]; do
  case $1 in
    --r1) R1="$2"; shift ;;
    --r2) R2="$2"; shift ;;
    --ref) REF="$2"; shift ;;
    --prefix|--species) PREF="$2"; shift ;;
    --out|--outdir) OUTDIR="$2"; shift ;;
    --sensitivity) SENS="$2"; shift ;;
    --threads) THREADS="$2"; shift ;;
    --handle-ambiguous) HANDLE_AMB=true ;;
    --min-mq) MIN_MQ="$2"; shift ;;
    --min-bq) MIN_BQ="$2"; shift ;;
    --min-dp) MIN_DP="$2"; shift ;;
    --af) AF_CUT="$2"; shift ;;
    --mask-lowdp) MASK_LOWDP=true ;;
    --min-cov) MIN_COV="$2"; shift ;;
    --min-breadth) MIN_BREADTH="$2"; shift ;;
    --max-n-percent) MAX_N_PERCENT="$2"; shift ;;
    --expected-size-min) EXPECTED_SIZE_MIN="$2"; shift ;;
    --expected-size-max) EXPECTED_SIZE_MAX="$2"; shift ;;
    *) echo "Unknown arg: $1"; exit 1 ;;
  esac
  shift
done

# ==== Required ====
if [[ -z "${R1:-}" || -z "${R2:-}" || -z "${REF:-}" || -z "${PREF:-}" ]]; then
  echo "Usage: bash assemble_mitogenome.sh --r1 R1.fq.gz --r2 R2.fq.gz --ref ref.fasta --prefix NAME [OPTIONS]"
  echo "QC Options: --min-cov INT --min-breadth FLOAT --max-n-percent INT --expected-size-min INT --expected-size-max INT"
  exit 1
fi

# Check if required files exist
for file in "$R1" "$R2" "$REF"; do
    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        exit 1
    fi
done

# Check if required tools are available
REQUIRED_TOOLS=(bowtie2 samtools bcftools)
OPTIONAL_TOOLS=(bedtools seqkit blastn)

for tool in "${REQUIRED_TOOLS[@]}"; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "Error: Required tool not found: $tool" >&2
        exit 1
    fi
done

# Check optional tools
SEQKIT_AVAILABLE=false
BLAST_AVAILABLE=false
BEDTOOLS_AVAILABLE=false

if command -v seqkit >/dev/null 2>&1; then SEQKIT_AVAILABLE=true; fi
if command -v blastn >/dev/null 2>&1; then BLAST_AVAILABLE=true; fi
if command -v bedtools >/dev/null 2>&1; then BEDTOOLS_AVAILABLE=true; fi

mkdir -p "$OUTDIR"
LOG="$OUTDIR/${PREF}_log.txt"
QC_REPORT="$OUTDIR/${PREF}_QC_report.txt"
BAM="$OUTDIR/${PREF}.bam"
SORT="$OUTDIR/${PREF}.sorted.bam"
VCF="$OUTDIR/${PREF}.calls.vcf.gz"
VCF_FILT="$OUTDIR/${PREF}.calls.filtered.vcf.gz"
CONS_RAW="$OUTDIR/${PREF}.consensus.raw.fasta"
CONS="$OUTDIR/${PREF}.consensus.fasta"
COV="$OUTDIR/${PREF}_coverage.txt"
MASKBED="$OUTDIR/${PREF}.lowdp.mask.bed"
STATS="$OUTDIR/${PREF}_assembly_stats.txt"

# Initialize QC report
echo "=== MITOGENOME ASSEMBLY QUALITY CONTROL REPORT ===" > "$QC_REPORT"
echo "Sample: $PREF" >> "$QC_REPORT"
echo "Analysis Date: $(date)" >> "$QC_REPORT"
echo "Reference: $REF" >> "$QC_REPORT"
echo "" >> "$QC_REPORT"

echo -e "\n---[$(date)] START---" | tee "$LOG"
echo "[SET] REF=$REF" | tee -a "$LOG"
echo "[SET] R1=$R1 R2=$R2" | tee -a "$LOG"
echo "[SET] OUTDIR=$OUTDIR PREF=$PREF THREADS=$THREADS" | tee -a "$LOG"
echo "[SET] QC PARAMS: MIN_COV=$MIN_COV MIN_BREADTH=$MIN_BREADTH MAX_N_PERCENT=$MAX_N_PERCENT" | tee -a "$LOG"

# ==== QC FUNCTION DEFINITIONS ====

# Function to calculate assembly statistics
calculate_assembly_stats() {
    local fasta_file="$1"
    local output_file="$2"
    
    echo "=== ASSEMBLY STATISTICS ===" > "$output_file"
    
    if $SEQKIT_AVAILABLE; then
        seqkit stats "$fasta_file" >> "$output_file" 2>/dev/null
    else
        # Manual calculation
        local total_len=$(grep -v '^>' "$fasta_file" | tr -d '\n' | wc -c | xargs)
        local num_seqs=$(grep -c '^>' "$fasta_file")
        local n_count=$(grep -v '^>' "$fasta_file" | tr -d '\n' | grep -o 'N' | wc -l | xargs)
        local gc_count=$(grep -v '^>' "$fasta_file" | tr -d '\n' | grep -o '[GC]' | wc -l | xargs)
        
        echo "file: $fasta_file" >> "$output_file"
        echo "num_seqs: $num_seqs" >> "$output_file"
        echo "sum_len: $total_len" >> "$output_file"
        echo "min_len: $total_len" >> "$output_file"
        echo "max_len: $total_len" >> "$output_file"
        echo "N_count: $n_count" >> "$output_file"
        echo "GC_count: $gc_count" >> "$output_file"
        
        if [[ $total_len -gt 0 ]]; then
            echo "N_percent: $(echo "scale=2; $n_count * 100 / $total_len" | bc -l)" >> "$output_file"
            echo "GC_percent: $(echo "scale=2; $gc_count * 100 / ($total_len - $n_count)" | bc -l)" >> "$output_file"
        fi
    fi
}

# Function to check coverage statistics
check_coverage_quality() {
    local cov_file="$1"
    
    if [[ ! -s "$cov_file" ]]; then
        echo "ERROR: Coverage file is empty" | tee -a "$QC_REPORT"
        return 1
    fi
    
    # Calculate coverage statistics
    local avg_cov=$(awk '{sum+=$3; count++} END {if(count>0) print sum/count; else print 0}' "$cov_file")
    local ref_len=$(wc -l < "$cov_file")
    local covered_bases=$(awk -v min_dp="$MIN_DP" '$3 >= min_dp {count++} END {print count+0}' "$cov_file")
    local breadth=$(echo "scale=4; $covered_bases / $ref_len" | bc -l)
    
    echo "COVERAGE STATISTICS:" >> "$QC_REPORT"
    echo "  Average coverage: ${avg_cov}" >> "$QC_REPORT"
    echo "  Reference length: ${ref_len} bp" >> "$QC_REPORT"
    echo "  Bases with ≥${MIN_DP}x coverage: ${covered_bases}" >> "$QC_REPORT"
    echo "  Breadth of coverage: ${breadth}" >> "$QC_REPORT"
    
    # QC checks
    local qc_pass=true
    
    if (( $(echo "$avg_cov < $MIN_COV" | bc -l) )); then
        echo "  ⚠️  WARNING: Average coverage ($avg_cov) below threshold ($MIN_COV)" >> "$QC_REPORT"
        qc_pass=false
    else
        echo "  ✅ Average coverage: PASS" >> "$QC_REPORT"
    fi
    
    if (( $(echo "$breadth < $MIN_BREADTH" | bc -l) )); then
        echo "  ⚠️  WARNING: Breadth of coverage ($breadth) below threshold ($MIN_BREADTH)" >> "$QC_REPORT"
        qc_pass=false
    else
        echo "  ✅ Breadth of coverage: PASS" >> "$QC_REPORT"
    fi
    
    echo "" >> "$QC_REPORT"
    
    if [[ "$qc_pass" == "false" ]]; then
        return 1
    fi
    return 0
}

# Function to validate assembly
validate_assembly() {
    local consensus_file="$1"
    
    echo "ASSEMBLY VALIDATION:" >> "$QC_REPORT"
    
    # Get assembly length
    local asm_len=$(grep -v '^>' "$consensus_file" | tr -d '\n' | wc -c | xargs)
    echo "  Assembly length: ${asm_len} bp" >> "$QC_REPORT"
    
    # Check assembly size
    local size_check=true
    if [[ $asm_len -lt $EXPECTED_SIZE_MIN ]]; then
        echo "  ⚠️  WARNING: Assembly too short (<${EXPECTED_SIZE_MIN} bp)" >> "$QC_REPORT"
        size_check=false
    elif [[ $asm_len -gt $EXPECTED_SIZE_MAX ]]; then
        echo "  ⚠️  WARNING: Assembly too long (>${EXPECTED_SIZE_MAX} bp)" >> "$QC_REPORT"
        size_check=false
    else
        echo "  ✅ Assembly size: PASS" >> "$QC_REPORT"
    fi
    
    # Check N content
    local n_count=$(grep -v '^>' "$consensus_file" | tr -d '\n' | grep -o 'N' | wc -l | xargs)
    local n_percent=$(echo "scale=2; $n_count * 100 / $asm_len" | bc -l)
    echo "  N content: ${n_count} bp (${n_percent}%)" >> "$QC_REPORT"
    
    local n_check=true
    if (( $(echo "$n_percent > $MAX_N_PERCENT" | bc -l) )); then
        echo "  ⚠️  WARNING: High N content (>${MAX_N_PERCENT}%)" >> "$QC_REPORT"
        n_check=false
    else
        echo "  ✅ N content: PASS" >> "$QC_REPORT"
    fi
    
    echo "" >> "$QC_REPORT"
    
    if [[ "$size_check" == "false" || "$n_check" == "false" ]]; then
        return 1
    fi
    return 0
}

# Function to check for potential contamination (basic)
check_contamination() {
    local consensus_file="$1"
    
    echo "CONTAMINATION SCREENING:" >> "$QC_REPORT"
    
    if $BLAST_AVAILABLE; then
        echo "  Running BLAST contamination check..." >> "$QC_REPORT"
        # This would require a contamination database - placeholder for now
        echo "  ℹ️  BLAST available but contamination DB not configured" >> "$QC_REPORT"
    else
        echo "  ℹ️  BLAST not available - skipping contamination check" >> "$QC_REPORT"
    fi
    
    echo "" >> "$QC_REPORT"
}

# ==== MAIN ASSEMBLY PIPELINE ====

# 1) Input validation and read statistics
echo "[QC] Input validation" | tee -a "$LOG"
echo "INPUT FILES:" >> "$QC_REPORT"

for file in "$R1" "$R2"; do
    if $SEQKIT_AVAILABLE; then
        echo "  $file:" >> "$QC_REPORT"
        seqkit stats "$file" | tail -n +2 >> "$QC_REPORT"
    else
        echo "  $file: exists" >> "$QC_REPORT"
    fi
done
echo "" >> "$QC_REPORT"

# 2) Bowtie2 index
if [[ ! -f "${REF}.1.bt2" && ! -f "${REF}.1.bt2l" ]]; then
  echo "[1] bowtie2-build" | tee -a "$LOG"
  bowtie2-build "$REF" "$REF" >> "$LOG" 2>&1
else
  echo "[1] index exists" | tee -a "$LOG"
fi

# 3) Align with alignment statistics
echo "[2] bowtie2 align" | tee -a "$LOG"
bowtie2 $SENS -x "$REF" -1 "$R1" -2 "$R2" -p "$THREADS" --no-unal \
  2>>"$LOG" | samtools view -bS - > "$BAM"

# Extract alignment statistics from bowtie2 log
echo "ALIGNMENT STATISTICS:" >> "$QC_REPORT"
grep -E "(reads; of these:|aligned concordantly|aligned discordantly|aligned exactly)" "$LOG" | tail -5 >> "$QC_REPORT" || true
echo "" >> "$QC_REPORT"

# 4) Sort + index
echo "[3] sort/index" | tee -a "$LOG"
samtools sort -@ "$THREADS" -o "$SORT" "$BAM" 2>>"$LOG"
samtools index "$SORT" 2>>"$LOG"

# 5) Coverage analysis with QC
echo "[4] coverage analysis" | tee -a "$LOG"
samtools depth "$SORT" > "$COV" 2>>"$LOG"

# QC: Check coverage quality
echo "[QC] Coverage quality check" | tee -a "$LOG"
if ! check_coverage_quality "$COV"; then
    echo "WARNING: Coverage QC failed - check $QC_REPORT" | tee -a "$LOG"
fi

# 6) Variant calling
echo "[5] mpileup+call (ploidy=1)" | tee -a "$LOG"
bcftools mpileup -Ou -f "$REF" -q "$MIN_MQ" -Q "$MIN_BQ" \
  -a "AD,ADF,ADR,DP" "$SORT" 2>>"$LOG" \
| bcftools call -m --ploidy 1 -Oz -o "$VCF" 2>>"$LOG"
bcftools index -f "$VCF" 2>>"$LOG"

# 7) Filter variants with statistics
AF_EXPR='FORMAT/AD[0:1] >= ('"$AF_CUT"' * (FORMAT/AD[0:0] + FORMAT/AD[0:1]))'
SB_EXPR='(FORMAT/ADF[0:1] > 0 && FORMAT/ADR[0:1] > 0)'
DP_EXPR='FORMAT/DP[0] >= '"$MIN_DP"
QUAL_EXPR='QUAL >= 30'
FILTER_EXPR="$QUAL_EXPR && $DP_EXPR && $AF_EXPR && $SB_EXPR"

echo "[6] filter variants" | tee -a "$LOG"
bcftools filter -i "$FILTER_EXPR" "$VCF" -Oz -o "$VCF_FILT" 2>>"$LOG"
bcftools index -f "$VCF_FILT" 2>>"$LOG"

# Variant statistics
echo "VARIANT STATISTICS:" >> "$QC_REPORT"
echo "  Total variants: $(bcftools view -H "$VCF" | wc -l)" >> "$QC_REPORT"
echo "  Filtered variants: $(bcftools view -H "$VCF_FILT" | wc -l)" >> "$QC_REPORT"
echo "" >> "$QC_REPORT"

# 8) Consensus generation
echo "[7] consensus generation" | tee -a "$LOG"
if $HANDLE_AMB; then
  bcftools consensus -H 1 -f "$REF" "$VCF_FILT" > "$CONS_RAW" 2>>"$LOG"
else
  bcftools consensus -f "$REF" "$VCF_FILT" > "$CONS_RAW" 2>>"$LOG"
fi

# 9) Optional masking
if $MASK_LOWDP; then
  echo "[8] mask low-depth regions" | tee -a "$LOG"
  awk -v m="$MIN_DP" '($3<m){printf "%s\t%d\t%d\n",$1,$2-1,$2}' "$COV" > "$MASKBED"
  if [[ -s "$MASKBED" && "$BEDTOOLS_AVAILABLE" == "true" ]]; then
    bedtools maskfasta -fi "$CONS_RAW" -bed "$MASKBED" -fo "$CONS" 2>>"$LOG"
    echo "  Masked $(wc -l < "$MASKBED") low-depth regions" >> "$QC_REPORT"
  else
    cp "$CONS_RAW" "$CONS"
  fi
else
  cp "$CONS_RAW" "$CONS"
fi

# 10) Fix FASTA header
if [[ "$(uname)" == "Darwin" ]]; then
    sed -i '' "1s/.*/>${PREF}/" "$CONS"
else
    sed -i "1s/.*/>${PREF}/" "$CONS"
fi

# 11) QUALITY CONTROL CHECKS
echo "[QC] Final assembly validation" | tee -a "$LOG"

# Calculate assembly statistics
calculate_assembly_stats "$CONS" "$STATS"
cat "$STATS" >> "$QC_REPORT"
echo "" >> "$QC_REPORT"

# Validate assembly
if ! validate_assembly "$CONS"; then
    echo "WARNING: Assembly validation failed - check $QC_REPORT" | tee -a "$LOG"
fi

# Basic contamination check
check_contamination "$CONS"

# 12) Final QC summary
echo "=== FINAL QC SUMMARY ===" >> "$QC_REPORT"
LEN=$(grep -v '^>' "$CONS" | tr -d '\n' | wc -c | xargs)

if [[ $LEN -ge $EXPECTED_SIZE_MIN && $LEN -le $EXPECTED_SIZE_MAX ]]; then
    echo "✅ ASSEMBLY COMPLETE: $CONS (${LEN} bp)" >> "$QC_REPORT"
    echo "[SUCCESS] Assembly completed: $CONS (${LEN} bp)" | tee -a "$LOG"
else
    echo "⚠️  ASSEMBLY COMPLETED WITH WARNINGS: $CONS (${LEN} bp)" >> "$QC_REPORT"
    echo "[WARNING] Assembly completed with issues: $CONS (${LEN} bp)" | tee -a "$LOG"
fi

echo "" >> "$QC_REPORT"
echo "Files generated:" >> "$QC_REPORT"
echo "  - Consensus: $CONS" >> "$QC_REPORT"
echo "  - Coverage: $COV" >> "$QC_REPORT"
echo "  - Variants: $VCF_FILT" >> "$QC_REPORT"
echo "  - Log: $LOG" >> "$QC_REPORT"
echo "  - QC Report: $QC_REPORT" >> "$QC_REPORT"
echo "  - Assembly Stats: $STATS" >> "$QC_REPORT"

echo "---[$(date)] END---" | tee -a "$LOG"
echo ""
echo "📊 Quality Control Report: $QC_REPORT"
echo "📈 Assembly Statistics: $STATS"
echo "🧬 Final Assembly: $CONS (${LEN} bp)"

# Clean up intermediate files
rm -f "$BAM" "$CONS_RAW"
