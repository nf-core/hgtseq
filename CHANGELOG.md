# nf-core/hgtseq: Changelog

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/)
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
