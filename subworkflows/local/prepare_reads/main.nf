
// this subworkflow prepares the inputs from fastq reads to bam files
// and performs QC of both reads and resulting bam files


// modules to include in this subworkflow


include { BWAMEM2_INDEX                } from '../../../modules/nf-core/modules/bwamem2/index/main.nf'
include { BWAMEM2_MEM                  } from '../../../modules/nf-core/modules/bwamem2/mem/main'
include { BWA_INDEX   as BWAMEM1_INDEX } from '../../../modules/nf-core/modules/bwa/index/main.nf'
include { BWA_MEM     as BWAMEM1_MEM   } from '../../../modules/nf-core/modules/bwa/mem/main.nf'
include { TRIMGALORE                   } from '../../../modules/nf-core/modules/trimgalore/main.nf'


workflow PREPARE_READS {

    take:
    reads      // channel: [mandatory] [ val(meta), [ reads ] ]
    fasta      // channel: [mandatory] /path/to/reference/fasta
    aligner    // string:  [mandatory] "bwa-mem" or "bwa-mem2"

    main:

    ch_versions = Channel.empty()
    aligned_bam = Channel.empty()

    TRIMGALORE ( reads )
    ch_versions = ch_versions.mix(TRIMGALORE.out.versions)

    if (aligner == "bwa-mem") {
        // reference is indexed
        BWAMEM1_INDEX ( fasta )
        ch_versions = ch_versions.mix(BWAMEM1_INDEX.out.versions)

        // appropriately tagged interleaved FASTQ reads are mapped to the reference
        BWAMEM1_MEM ( TRIMGALORE.out.reads, BWAMEM1_INDEX.out.index, false )
        ch_versions = ch_versions.mix(BWAMEM1_MEM.out.versions)
        aligned_bam = BWAMEM1_MEM.out.bam
    } else {
        // reference is indexed
        BWAMEM2_INDEX ( fasta )
        ch_versions = ch_versions.mix(BWAMEM2_INDEX.out.versions)

        // appropriately tagged interleaved FASTQ reads are mapped to the reference
        BWAMEM2_MEM ( TRIMGALORE.out.reads, BWAMEM2_INDEX.out.index, false )
        ch_versions = ch_versions.mix(BWAMEM2_MEM.out.versions)
        aligned_bam = BWAMEM2_MEM.out.bam
    }



    emit:
    trimmed_reads = TRIMGALORE.out.reads  // channel: [mandatory] [ val(meta), [ reads ] ]
    bam           = aligned_bam           // channel [mandatory] [ val(meta), [ bam ] ]
    versions      = ch_versions           // channel: [ versions.yml ]


}
