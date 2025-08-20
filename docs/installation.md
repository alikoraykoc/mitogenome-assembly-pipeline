# Installation Guide

## System Requirements

- Linux or macOS
- Bash shell (≥4.0)
- At least 4GB RAM (8GB+ recommended)
- 10GB+ free disk space

## Required Software

### Core Tools (Required)
```bash
# Using conda (recommended)
conda install -c bioconda bowtie2 samtools bcftools bc

# Or install individually:
# - Bowtie2 ≥2.4.0
# - SAMtools ≥1.10  
# - BCFtools ≥1.10
# - bc (calculator)
```

### Optional Tools (Recommended)
```bash
conda install -c bioconda seqkit bedtools blast
```

## Installation

### Method 1: Git Clone
```bash
git clone https://github.com/alikoraykoc/mitogenome-assembly-pipeline.git
cd mitogenome-assembly-pipeline
chmod +x scripts/*.sh
```

### Method 2: Download Release
1. Go to [Releases](https://github.com/alikoraykoc/mitogenome-assembly-pipeline/releases)
2. Download latest version
3. Extract and make executable:
```bash
tar -xzf mitogenome-assembly-pipeline-v1.0.0.tar.gz
cd mitogenome-assembly-pipeline
chmod +x scripts/*.sh
```

## Verification

Test the installation:
```bash
./scripts/assemble_mitogenome.sh --help
```

If you see the help message, installation was successful!
