# Troubleshooting Guide

## Common Issues

### 1. Command Not Found Errors

**Error**: `bowtie2: command not found`
**Solution**: Install required tools or activate conda environment
```bash
conda activate your_environment
conda install -c bioconda bowtie2 samtools bcftools
```

### 2. Low Coverage Warnings

**Error**: `WARNING: Average coverage (X) below threshold`
**Solutions**:
```bash
# Lower coverage requirements
--min-cov 5 --min-dp 3

# Use more sensitive alignment
--sensitivity "--very-sensitive"
```

### 3. Assembly Too Short

**Error**: `WARNING: Assembly too short`
**Solutions**:
```bash
# Adjust size expectations
--expected-size-min 14000 --expected-size-max 18000

# Check reference quality
# Try different reference genome
```

### 4. High N Content

**Error**: `WARNING: High N content`
**Solutions**:
```bash
# Increase quality filters
--min-mq 40 --min-bq 25 --af 0.95

# Check input data quality with FastQC
```

### 5. Permission Denied

**Error**: `Permission denied`
**Solution**: Make scripts executable
```bash
chmod +x scripts/*.sh
```

## Getting Help

1. Check the [Usage Guide](usage.md)
2. Search [existing issues](https://github.com/alikoraykoc/mitogenome-assembly-pipeline/issues)
3. Create a [new issue](https://github.com/alikoraykoc/mitogenome-assembly-pipeline/issues/new) with:
   - Command used
   - Error message
   - System information
   - Log files (if possible)
