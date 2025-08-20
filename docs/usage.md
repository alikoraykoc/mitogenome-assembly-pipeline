# Usage Guide

## Command Line Interface

### Basic Syntax

```bash
./scripts/assemble_mitogenome.sh [REQUIRED] [OPTIONS]
```

## Required Arguments

| Argument | Description | Example |
|----------|-------------|---------|
| `--r1` | Forward reads file | `sample_R1.fastq.gz` |
| `--r2` | Reverse reads file | `sample_R2.fastq.gz` |
| `--ref` | Reference mitogenome | `reference.fasta` |
| `--prefix` | Sample identifier | `species_sample1` |

## Optional Arguments

### Output Control
| Argument | Default | Description |
|----------|---------|-------------|
| `--outdir` | `results` | Output directory |

### Performance
| Argument | Default | Description |
|----------|---------|-------------|
| `--threads` | `4` | Number of CPU threads |
| `--sensitivity` | `--very-sensitive-local` | Bowtie2 alignment sensitivity |

### Quality Control
| Argument | Default | Description |
|----------|---------|-------------|
| `--min-cov` | `10` | Minimum average coverage |
| `--min-breadth` | `0.95` | Minimum coverage breadth (0-1) |
| `--max-n-percent` | `5` | Maximum N content (%) |
| `--expected-size-min` | `15000` | Minimum expected assembly size (bp) |
| `--expected-size-max` | `20000` | Maximum expected assembly size (bp) |

### Variant Calling
| Argument | Default | Description |
|----------|---------|-------------|
| `--min-mq` | `30` | Minimum mapping quality |
| `--min-bq` | `20` | Minimum base quality |
| `--min-dp` | `10` | Minimum depth for variant calling |
| `--af` | `0.90` | Minimum allele frequency |

### Special Options
| Argument | Default | Description |
|----------|---------|-------------|
| `--handle-ambiguous` | `false` | Handle heterozygous sites as ambiguous |
| `--mask-lowdp` | `false` | Mask low-depth regions with N |

## Usage Examples

### 1. Minimal Example
```bash
./scripts/assemble_mitogenome.sh \
  --r1 sample_R1.fastq.gz \
  --r2 sample_R2.fastq.gz \
  --ref reference.fasta \
  --prefix my_species
```

### 2. High-Quality Research Assembly
```bash
./scripts/assemble_mitogenome.sh \
  --r1 sample_R1.fastq.gz \
  --r2 sample_R2.fastq.gz \
  --ref reference.fasta \
  --prefix my_species \
  --outdir results_highqual \
  --threads 12 \
  --min-cov 25 \
  --min-breadth 0.99 \
  --max-n-percent 1 \
  --mask-lowdp
```

### 3. Orthoptera-Specific Parameters
```bash
./scripts/assemble_mitogenome.sh \
  --r1 grasshopper_R1.fastq.gz \
  --r2 grasshopper_R2.fastq.gz \
  --ref tetrix_reference.fasta \
  --prefix tetrix_bolivari \
  --expected-size-min 15000 \
  --expected-size-max 16500 \
  --min-cov 20 \
  --min-breadth 0.98
```

### 4. Low-Coverage Data
```bash
./scripts/assemble_mitogenome.sh \
  --r1 lowcov_R1.fastq.gz \
  --r2 lowcov_R2.fastq.gz \
  --ref reference.fasta \
  --prefix lowcov_sample \
  --sensitivity "--very-sensitive" \
  --min-cov 5 \
  --min-dp 3 \
  --af 0.80
```

### 5. Batch Processing
```bash
# Use the batch script
./scripts/batch_process_samples.sh \
  --sample-list samples.txt \
  --ref-dir references/ \
  --outdir batch_results/ \
  --threads 8
```

## Input File Requirements

### FASTQ Files
- **Format**: Standard FASTQ (gzipped supported)
- **Quality**: Illumina paired-end reads
- **Coverage**: Recommended >20x average coverage
- **Insert size**: Typically 300-500 bp

### Reference Genome
- **Format**: FASTA format
- **Content**: Complete or near-complete mitogenome
- **Similarity**: >80% similarity to target species
- **Size**: 15-20 kb typical for metazoans

## Output Interpretation

### QC Report (`*_QC_report.txt`)
```
=== FINAL QC SUMMARY ===
✅ ASSEMBLY COMPLETE: sample.consensus.fasta (15127 bp)

COVERAGE STATISTICS:
  Average coverage: 45.2
  Breadth of coverage: 0.984
  ✅ Coverage quality: PASS

ASSEMBLY VALIDATION:
  Assembly length: 15127 bp
  N content: 0 bp (0.00%)
  ✅ Assembly quality: PASS
```

### Assembly Statistics (`*_assembly_stats.txt`)
- Sequence length and composition
- GC/AT content
- N50 statistics (if applicable)

### Coverage File (`*_coverage.txt`)
- Per-base coverage depth
- Useful for identifying problem regions

## Quality Thresholds

### Publication Quality
- Average coverage: ≥25x
- Breadth of coverage: ≥98%
- N content: <1%
- Complete gene complement

### Phylogenetic Analysis
- Average coverage: ≥15x
- Breadth of coverage: ≥95%
- N content: <3%
- All protein-coding genes present

### Preliminary Analysis
- Average coverage: ≥10x
- Breadth of coverage: ≥90%
- N content: <5%
- Major genes present

## Common Workflows

### 1. Single Species Analysis
```bash
# Assemble mitogenome
./scripts/assemble_mitogenome.sh [params]

# Check QC report
cat results/species_QC_report.txt

# If QC passes, proceed with annotation
# Submit to MITOS2 or similar tool
```

### 2. Phylogenetic Study
```bash
# Process multiple samples
for sample in sample1 sample2 sample3; do
    ./scripts/assemble_mitogenome.sh \
        --r1 ${sample}_R1.fastq.gz \
        --r2 ${sample}_R2.fastq.gz \
        --ref reference.fasta \
        --prefix $sample \
        --min-cov 20 \
        --min-breadth 0.98
done

# Collect all consensus sequences
cat results/*/**.consensus.fasta > all_mitogenomes.fasta

# Proceed with gene extraction and alignment
```

### 3. Quality Assessment Pipeline
```bash
# Run with high stringency
./scripts/assemble_mitogenome.sh [params] --min-cov 30 --max-n-percent 1

# Check multiple quality metrics
# If fails, try with relaxed parameters
```

## Troubleshooting Common Issues

### Assembly Too Short
```bash
# Check reference quality
# Adjust size expectations
--expected-size-min 14000 --expected-size-max 18000
```

### Low Coverage
```bash
# Use more sensitive alignment
--sensitivity "--very-sensitive"
# Lower coverage thresholds
--min-cov 5 --min-dp 3
```

### High N Content
```bash
# Increase quality filters
--min-mq 40 --min-bq 25 --af 0.95
# Check input data quality
```

### Missing Genes
```bash
# Check reference completeness
# Verify gene annotation separately
# Consider different reference genome
```