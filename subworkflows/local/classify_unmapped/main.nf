
include { SAMTOOLS_INDEX                              } from '../../../modules/nf-core/samtools/index/main.nf'
include { SAMTOOLS_SORT                               } from '../../../modules/nf-core/samtools/sort/main.nf'
include { SAMTOOLS_VIEW   as SAMTOOLS_VIEW_SINGLE     } from '../../../modules/nf-core/samtools/view/main.nf'
include { SAMTOOLS_VIEW   as SAMTOOLS_VIEW_BOTH       } from '../../../modules/nf-core/samtools/view/main.nf'
include { SAMTOOLS_FASTQ  as SAMTOOLS_FASTQ_SINGLE    } from '../../../modules/local/samtools/fastqlocal/main.nf'
include { SAMTOOLS_FASTQ  as SAMTOOLS_FASTQ_BOTH      } from '../../../modules/local/samtools/fastqlocal/main.nf'
include { KRAKEN2_KRAKEN2 as KRAKEN2_SINGLE           } from '../../../modules/nf-core/kraken2/kraken2/main.nf'
include { KRAKEN2_KRAKEN2 as KRAKEN2_BOTH             } from '../../../modules/nf-core/kraken2/kraken2/main.nf'
include { PARSEOUTPUTS                                } from '../../../modules/local/parseoutputs/main.nf'

workflow CLASSIFY_UNMAPPED {

    take:
    bam_bai  // channel: [ val(meta), path(bam), path(bai) ]
    db   // channel: [ path(database) ]

    main:

    ch_versions = Channel.empty()

    SAMTOOLS_VIEW_SINGLE ( bam_bai, [], [] )
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW_SINGLE.out.versions)

    SAMTOOLS_VIEW_BOTH ( bam_bai, [], [] )
    ch_versions = ch_versions.mix(SAMTOOLS_VIEW_BOTH.out.versions)

    PARSEOUTPUTS ( SAMTOOLS_VIEW_SINGLE.out.bam )
    ch_versions = ch_versions.mix(PARSEOUTPUTS.out.versions)

    SAMTOOLS_FASTQ_SINGLE ( SAMTOOLS_VIEW_SINGLE.out.bam )
    ch_versions = ch_versions.mix(SAMTOOLS_FASTQ_SINGLE.out.versions)

    SAMTOOLS_FASTQ_BOTH ( SAMTOOLS_VIEW_BOTH.out.bam )
    ch_versions = ch_versions.mix(SAMTOOLS_FASTQ_BOTH.out.versions)

    KRAKEN2_SINGLE ( SAMTOOLS_FASTQ_SINGLE.out.fastq, db, false, true )
    ch_versions = ch_versions.mix(KRAKEN2_SINGLE.out.versions)

    KRAKEN2_BOTH ( SAMTOOLS_FASTQ_BOTH.out.fastq, db, false, true )
    ch_versions = ch_versions.mix(KRAKEN2_BOTH.out.versions)

    emit:
    classified_single        = KRAKEN2_SINGLE.out.classified_reads_assignment
    classified_both          = KRAKEN2_BOTH.out.classified_reads_assignment
    candidate_integrations   = PARSEOUTPUTS.out.integration_sites
    report_single            = KRAKEN2_SINGLE.out.report
    report_both              = KRAKEN2_BOTH.out.report
    versions                 = ch_versions            // channel: [ versions.yml ]

}
