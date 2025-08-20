# Mitogenome Assembly Pipeline

A robust pipeline for assembling mitochondrial genomes from Illumina paired-end sequencing data using reference-guided mapping. Designed specifically for phylogenetic research with comprehensive quality control and validation.

## 🎯 Features

- **Reference-guided assembly** using Bowtie2, SAMtools, and BCFtools
- **Comprehensive quality control** with publication-ready metrics
- **Automated validation** of assembly completeness and quality
- **Phylogenetic research ready** with detailed reporting
- **Publication-quality output** suitable for peer review
- **Batch processing** support for multiple samples
- **Detailed logging** and error handling

## Installation

### Prerequisites

The pipeline requires the following tools to be installed and available in your PATH:

**Required:**
- [Bowtie2](https://github.com/BenLangmead/bowtie2) (≥2.4.0)
- [SAMtools](https://github.com/samtools/samtools) (≥1.10)
- [BCFtools](https://samtools.github.io/bcftools/) (≥1.10)
- [bc](https://en.wikipedia.org/wiki/Bc_(programming_language)) (for calculations)

**Optional (recommended):**
- [SeqKit](https://bioinf.shenwei.me/seqkit/) (for enhanced statistics)
- [bedtools](https://bedtools.readthedocs.io/) (for masking low-depth regions)
- [BLAST+](https://blast.ncbi.nlm.nih.gov/Blast.cgi?PAGE_TYPE=BlastDocs&DOC_TYPE=Download) (for contamination screening)

### Quick Install

```bash
# Clone the repository
git clone https://github.com/alikoraykoc/mitogenome-assembly-pipeline.git
cd mitogenome-assembly-pipeline

# Make scripts executable
chmod +x scripts/*.sh

# Test installation
./scripts/assemble_mitogenome.sh --help
```

### Using Conda (Recommended)

```bash
# Create conda environment
conda create -n mitogenome-pipeline -c bioconda bowtie2 samtools bcftools seqkit bedtools blast bc
conda activate mitogenome-pipeline

# Clone and setup
git clone https://github.com/alikoraykoc/mitogenome-assembly-pipeline.git
cd mitogenome-assembly-pipeline
chmod +x scripts/*.sh
```

## 🚀 Quick Start

### Basic Usage

```bash
./scripts/assemble_mitogenome.sh \
  --r1 sample_R1.fastq.gz \
  --r2 sample_R2.fastq.gz \
  --ref reference_mitogenome.fasta \
  --prefix sample_species_name
```

### Research-Quality Assembly

```bash
./scripts/assemble_mitogenome.sh \
  --r1 sample_R1.fastq.gz \
  --r2 sample_R2.fastq.gz \
  --ref reference_mitogenome.fasta \
  --prefix sample_species_name \
  --outdir results_sample \
  --threads 8 \
  --min-cov 20 \
  --min-breadth 0.98 \
  --max-n-percent 2 \
  --mask-lowdp
```

### Usage

```bash
# Run the included example (requires your own test data)
cd examples/
./run_example.sh

# The script will show you exactly what command to use
# and what outputs to expect
```

## 📊 Output Files

| File | Description |
|------|-------------|
| `{PREFIX}.consensus.fasta` | **Final mitogenome assembly** |
| `{PREFIX}_QC_report.txt` | **Quality control summary** ⭐ |
| `{PREFIX}_assembly_stats.txt` | **Assembly statistics** ⭐ |
| `{PREFIX}_coverage.txt` | Per-base coverage data |
| `{PREFIX}.calls.filtered.vcf.gz` | High-quality variants |
| `{PREFIX}_log.txt` | Complete analysis log |

⭐ = Essential files for publication

## 📋 Parameters

### Required Parameters
- `--r1`: Forward reads (FASTQ, gzipped supported)
- `--r2`: Reverse reads (FASTQ, gzipped supported)
- `--ref`: Reference mitogenome (FASTA)
- `--prefix`: Sample identifier

### Quality Control Parameters
- `--min-cov`: Minimum average coverage (default: 10)
- `--min-breadth`: Minimum breadth of coverage (default: 0.95)
- `--max-n-percent`: Maximum N content percentage (default: 5)
- `--expected-size-min`: Minimum expected size in bp (default: 15000)
- `--expected-size-max`: Maximum expected size in bp (default: 20000)

### Performance Options
- `--threads`: CPU threads (default: 4)
- `--sensitivity`: Bowtie2 sensitivity (default: "--very-sensitive-local")
- `--outdir`: Output directory (default: "results")

See [full parameter documentation](docs/usage.md) for all options.

### Citing This Work

If you use this pipeline in your research, please cite:

```
Ali Koray Koç (2025). Mitogenome Assembly Pipeline: A robust tool for 
phylogenetic research. GitHub repository: 
https://github.com/alikoraykoc/mitogenome-assembly-pipeline
```

## 📈 Validation

This pipeline has been validated with:
- **Orthoptera species** producing assemblies of 15-17 kb
- **Complete gene complements** (37 mitochondrial genes)
- **Publication-quality assemblies** with minimal ambiguous bases
- **High AT content** appropriate for arthropod mitogenomes

## 🧪 Testing

```bash
# Run test suite
cd tests/
./run_tests.sh

# Expected: All tests pass with sample data
```

## 🐛 Troubleshooting

### Common Issues

**Low coverage warnings:**
```bash
# Use more sensitive alignment
--sensitivity "--very-sensitive" --min-cov 5
```

**Assembly too short:**
```bash
# Check reference quality and adjust size expectations
--expected-size-min 14000 --expected-size-max 18000
```

**High error rates:**
```bash
# Increase quality thresholds
--min-mq 40 --min-bq 25 --af 0.95
```

See [troubleshooting guide](docs/troubleshooting.md) for detailed solutions.

## 🤝 Contributing

Contributions are welcome! Please read our [contributing guidelines](CONTRIBUTING.md) and submit pull requests for any improvements.

### Development Setup

```bash
git clone https://github.com/alikoraykoc/mitogenome-assembly-pipeline.git
cd mitogenome-assembly-pipeline
# Make your changes
# Test thoroughly
# Submit PR
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 📞 Support

- 🐛 [Report bugs](https://github.com/alikoraykoc/mitogenome-assembly-pipeline/issues)

- 📧 Contact: [kocalikoray@gmail.com]
