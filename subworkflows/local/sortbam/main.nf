// runs SAMPLE_QC from either reads or bam files
// or both after alignment

include { SAMTOOLS_SORT     } from '../../../modules/nf-core/samtools/sort/main'
include { SAMTOOLS_INDEX    } from '../../../modules/nf-core/samtools/index/main'

workflow SORTBAM {

    take:
    bam        // channel: [mandatory] [ val(meta), path(bam) ]
    fasta      // channel: [mandatory] /path/to/reference/fasta

    main:
    ch_versions = Channel.empty()

    // samtools stats block needs the bam file to be sorted
    // and indexed

    SAMTOOLS_SORT ( bam, [[],[]] )
    ch_versions = ch_versions.mix(SAMTOOLS_SORT.out.versions.first())

    SAMTOOLS_INDEX ( SAMTOOLS_SORT.out.bam )
    ch_versions = ch_versions.mix(SAMTOOLS_INDEX.out.versions.first())

    // additionally, the modules require a single channel containing
    // both the bam file and its index
    // which is the reason for creating an additional channel that joins
    // both of them:

    // NOTE: avoid using `remainder: true` here because it triggers a NullPointerException
    // in Nextflow 25.x when the upstream channel closes before the join completes.
    SAMTOOLS_SORT.out.bam
        .join(SAMTOOLS_INDEX.out.bai, by: [0])  // join sorted BAMs with their indexes
        .set { bam_bai }

    emit:
    bam_only = SAMTOOLS_SORT.out.bam  // channel: [ val(meta), path(bam) ]
    bam_bai  = bam_bai                // channel: [ val(meta), path(bam), path(bai) ]
    versions = ch_versions            // channel: [ versions.yml ]
}
