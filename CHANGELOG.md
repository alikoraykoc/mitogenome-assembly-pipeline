# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0]

### Fixed

- **Consensus sequences no longer carry reference bases at uncovered positions.**
  `bcftools consensus` applies variants on top of the reference, so any position
  not named in the VCF was emitted as the reference base regardless of read
  support. Masking was the only guard against this and it was opt-in, so default
  runs produced consensus sequences whose uncovered regions were reference
  sequence. Masking now defaults to on; use `--no-mask` to opt out.

- **Zero-coverage positions are now maskable.** `samtools depth` was called
  without `-aa`, which omits positions having no reads. The mask BED was built by
  iterating over that file, so uncovered positions produced no interval and were
  never masked. Even with `--mask-lowdp`, only sites at depth 1..min-dp-1 were
  masked.

- **Breadth of coverage is now computed against the true reference length.**
  `check_coverage_quality` used `wc -l` on the depth file as the reference
  length. That counts only positions having reads, so the denominator shrank with
  the numerator and breadth stayed near 1.0 no matter how much of the reference
  was missing. A sample missing 60% of the mitogenome reported breadth 1.0000 at
  50x; it now reports 0.40 at 20x. Reference length is taken from the `.fai`.

- **The mask is applied in the correct coordinate system.** The mask BED was in
  reference coordinates but `bedtools maskfasta` applied it to the finished
  consensus, which has already shifted by every applied indel. The mask is now
  passed to `bcftools consensus`, which resolves it in reference coordinates.
  This also removes the `bedtools` dependency and its silent `cp` fallback when
  `bedtools` was absent.

- **`--handle-ambiguous` now emits IUPAC codes.** It passed `-H 1`, which selects
  the first allele and is a no-op under `--ploidy 1`.

- **The final QC summary no longer passes on sequence length alone**, which a
  reference-guided consensus satisfies by construction.

- `samtools depth` now filters at the same MQ/BQ thresholds as `mpileup`, so
  regions covered only by low-MAPQ reads are no longer counted as deep while
  contributing nothing to variant calling.

- Batch script: fixed a parse error and a summary that reported PASS for failed
  samples.

### Impact on earlier results

Consensus sequences produced with **v1.0.0** should be treated as unreliable
wherever coverage was incomplete. On a divergent reference the effect is severe:
stringent variant filtering removes true variants, and the unmasked consensus
substitutes the reference allele at every one of them. A test run on a
congeneric reference produced a consensus that was **46% verbatim reference
sequence**, with zero ambiguous bases, full expected length, and every QC check
reporting PASS. Re-running the same reads with masking enabled reports 42.1%
ambiguous positions and 57.8% breadth of coverage, and fails QC.

If you have assemblies from v1.0.0, re-run them. To check an existing consensus
without re-running, align it to the reference used and look for long stretches of
exact identity; uncovered regions appear as verbatim reference sequence.

## [1.0.0]

Initial release.

**Affected by the defects listed under 1.1.0.** Use 1.1.0 or later.
