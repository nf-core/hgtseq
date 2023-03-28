// runs SAMPLE_QC from either reads or bam files
// or both after alignment

include { BAMTOOLS_STATS    } from '../../../modules/nf-core/bamtools/stats/main'
include { SAMTOOLS_SORT     } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX    } from '../../../modules/nf-core/samtools/index/main'
include { SAMTOOLS_STATS    } from '../../../modules/nf-core/samtools/stats/main'
include { SAMTOOLS_IDXSTATS } from '../../../modules/nf-core/samtools/idxstats/main'
include { SAMTOOLS_FLAGSTAT } from '../../../modules/nf-core/samtools/flagstat/main'
include { QUALIMAP_BAMQC    } from '../../../modules/nf-core/qualimap/bamqc/main'

workflow BAM_QC {

    take:
    bam        // channel: [mandatory] [ val(meta), path(bam) ]
    bam_bai    // channel: [mandatory] [ val(meta), path(bam), path(bai) ]
    fasta      // channel: [mandatory] path(fasta)
    gff        // channel: [optional] path(gff)

    main:
    ch_versions = Channel.empty()

    SAMTOOLS_STATS ( bam_bai, fasta )
    ch_versions = ch_versions.mix(SAMTOOLS_STATS.out.versions.first())

    SAMTOOLS_FLAGSTAT ( bam_bai )
    ch_versions = ch_versions.mix(SAMTOOLS_FLAGSTAT.out.versions.first())

    SAMTOOLS_IDXSTATS ( bam_bai )
    ch_versions = ch_versions.mix(SAMTOOLS_IDXSTATS.out.versions.first())

    // qualimap requires the original bam file
    // but also a GFF file with the regions to run the QC on
    QUALIMAP_BAMQC ( bam, gff )
    ch_versions = ch_versions.mix(QUALIMAP_BAMQC.out.versions.first())

    BAMTOOLS_STATS ( bam )
    ch_versions = ch_versions.mix(BAMTOOLS_STATS.out.versions.first())

    emit:
    stats    = SAMTOOLS_STATS.out.stats       // channel: [ val(meta), [ stats ] ]
    flagstat = SAMTOOLS_FLAGSTAT.out.flagstat // channel: [ val(meta), [ flagstat ] ]
    idxstats = SAMTOOLS_IDXSTATS.out.idxstats // channel: [ val(meta), [ idxstats ] ]
    qualimap = QUALIMAP_BAMQC.out.results     // channel: [ val(meta), [ results ] ]
    bamstats = BAMTOOLS_STATS.out.stats       // channel: [ val(meta), [ bamstats ] ]

    versions = ch_versions                    // channel: [ versions.yml ]
}
