# nf-core/hgtseq: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## v1.2.0dev - [11/11/2025]

### `Added`

- updated pipeline logo

### `Fixed`

- fixed an issue with pipeline config preventing loading on Seqera platform
- template update to nf-core version 3.3.2
- fixed null-pointer-exception triggered with Nextflow versions 25.x
- [#51](https://github.com/nf-core/hgtseq/pull/56) - Fixed json schema to latest version

## [1.1.0](https://github.com/nf-core/hgtseq/releases/tag/1.1.0) - Beary Rose

### `Added`

- [#31](https://github.com/nf-core/hgtseq/pull/31) - Fixed issue where _single_unmapped_ reads also include _both_unmapped_ reads, by creating a local module with two steps samtools flag filtering

### `Fixed`

- [#31](https://github.com/nf-core/hgtseq/pull/31) - Sync `TEMPLATE` with `tools 2.8` and all nf-core/modules updated

### `Dependencies`

| Dependency | Old version | New version |
| ---------- | ----------- | ----------- |
| `samtools` | 1.15.1      | 1.17        |
| `multiqc`  | 1.13        | 1.14        |

### `Deprecated`

## [1.0.0](https://github.com/nf-core/hgtseq/releases/tag/1.0.0) - Dalmatian Daffodil

Initial release of nf-core/hgtseq, created with the [nf-core](https://nf-co.re/) template.
