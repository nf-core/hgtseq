/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT MODULES / SUBWORKFLOWS / FUNCTIONS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config          = Channel.fromPath("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config   = params.multiqc_config ? Channel.fromPath( params.multiqc_config, checkIfExists: true ) : Channel.empty()
ch_multiqc_logo            = params.multiqc_logo   ? Channel.fromPath( params.multiqc_logo, checkIfExists: true ) : Channel.empty()
ch_multiqc_custom_methods_description = params.multiqc_methods_description ? file(params.multiqc_methods_description, checkIfExists: true) : file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core
//
include { BAM_QC                      } from '../subworkflows/local/bam_qc/main'
include { CLASSIFY_UNMAPPED           } from '../subworkflows/local/classify_unmapped/main'
include { PREPARE_READS               } from '../subworkflows/local/prepare_reads/main'
include { READS_QC                    } from '../subworkflows/local/reads_qc/main'
include { REPORTING                   } from '../subworkflows/local/reporting/main'
include { SORTBAM                     } from '../subworkflows/local/sortbam/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core
//
include { MULTIQC                                     } from '../modules/nf-core/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS                 } from '../modules/nf-core/custom/dumpsoftwareversions/main'
include { UNTAR                       as UNTAR_KRAKEN } from '../modules/nf-core/untar/main'
include { UNTAR                       as UNTAR_KRONA  } from '../modules/nf-core/untar/main'
include { FASTQC                                      } from '../modules/nf-core/fastqc/main'
include { paramsSummaryMap                            } from 'plugin/nf-schema'
include { paramsSummaryMultiqc                        } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { softwareVersionsToYAML                      } from '../subworkflows/nf-core/utils_nfcore_pipeline'
include { methodsDescriptionText                      } from '../subworkflows/local/utils_nfcore_hgtseq_pipeline'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow HGTSEQ {

    take:
    ch_input

    main:
    ch_versions = Channel.empty()
    ch_multiqc_files = Channel.empty()

    // check if databases are local or compressed archives
    krakendb = returnFile(params.krakendb)
    kronadb  = returnFile(params.kronadb)

    // parsing kraken2 database
    if (hasExtension(krakendb, "tar.gz")) {
        krakendb_input = [ [], krakendb ]
        UNTAR_KRAKEN(krakendb_input)
        ch_krakendb = UNTAR_KRAKEN.out.untar.map{ it[1] }
    } else {
        ch_krakendb = Channel.value(krakendb)
    }

    // parsing krona database
    if (hasExtension(kronadb, "tar.gz")) {
        kronadb_input = [ [], kronadb ]
        UNTAR_KRONA(kronadb_input)
        ch_kronadb = UNTAR_KRONA.out.untar.map{ it[1] }
    } else {
        ch_kronadb = Channel.value(kronadb)
    }


    // execute prepare reads and reads qc if input is fastq
    if (!params.isbam) {
        PREPARE_READS (
            ch_input,
            params.fasta,
            params.aligner
        )
        ch_versions = ch_versions.mix(PREPARE_READS.out.versions)

        READS_QC (
            ch_input,
            PREPARE_READS.out.trimmed_reads
        )
        ch_versions = ch_versions.mix(READS_QC.out.versions)
    }

    if (params.isbam) {
        // executes SORTBAM on input files from CSV
        SORTBAM (
            ch_input,
            params.fasta
        )

        BAM_QC (
            SORTBAM.out.bam_only,
            SORTBAM.out.bam_bai,
            params.fasta,
            params.gff
        )
        ch_versions = ch_versions.mix(BAM_QC.out.versions)

        // executes classification on sorted bam including bai in tuple
        CLASSIFY_UNMAPPED (
            SORTBAM.out.bam_bai,
            ch_krakendb
        )
        ch_versions = ch_versions.mix(CLASSIFY_UNMAPPED.out.versions)
    } else {
        // executes SORTBAM on aligned trimmed reads
        // executes SORTBAM on input files from CSV
        SORTBAM (
            PREPARE_READS.out.bam,
            params.fasta
        )
        // then executes BAM QC on the sorted files
        BAM_QC (
            SORTBAM.out.bam_only,
            SORTBAM.out.bam_bai,
            params.fasta,
            params.gff
        )
        ch_versions = ch_versions.mix(BAM_QC.out.versions)

        // executes classification on aligned trimmed reads sorted and in tuple with bai
        CLASSIFY_UNMAPPED (
            SORTBAM.out.bam_bai,
            ch_krakendb
        )
        ch_versions = ch_versions.mix(CLASSIFY_UNMAPPED.out.versions)
    }

    // execute reporting only if genome is Human
    if (!workflow.profile.contains('conda')) {
            REPORTING (
                CLASSIFY_UNMAPPED.out.classified_single.collect{ it[1] },
                CLASSIFY_UNMAPPED.out.classified_both.collect{ it[1] },
                CLASSIFY_UNMAPPED.out.candidate_integrations.collect{ it[1] },
                ch_kronadb,
                CLASSIFY_UNMAPPED.out.classified_single.collect{ it[0].id }
            )
            ch_versions = ch_versions.mix(REPORTING.out.versions)
    }

    //
    // Collate and save software versions
    //
    softwareVersionsToYAML(ch_versions)
        .collectFile(
            storeDir: "${params.outdir}/pipeline_info",
            name: 'nf_core_'  +  'hgtseq_software_'  + 'mqc_'  + 'versions.yml',
            sort: true,
            newLine: true
        ).set { ch_collated_versions }


    //
    // MODULE: MultiQC
    //
    ch_multiqc_config        = Channel.fromPath(
        "$projectDir/assets/multiqc_config.yml", checkIfExists: true)
    ch_multiqc_custom_config = params.multiqc_config ?
        Channel.fromPath(params.multiqc_config, checkIfExists: true) :
        Channel.empty()
    ch_multiqc_logo          = params.multiqc_logo ?
        Channel.fromPath(params.multiqc_logo, checkIfExists: true) :
        Channel.empty()

    summary_params      = paramsSummaryMap(
        workflow, parameters_schema: "nextflow_schema.json")
    ch_workflow_summary = Channel.value(paramsSummaryMultiqc(summary_params))
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_custom_methods_description = params.multiqc_methods_description ?
        file(params.multiqc_methods_description, checkIfExists: true) :
        file("$projectDir/assets/methods_description_template.yml", checkIfExists: true)
    ch_methods_description                = Channel.value(
        methodsDescriptionText(ch_multiqc_custom_methods_description))

    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(ch_methods_description.collectFile(name: 'methods_description_mqc.yaml'))
    // adding reads QC for both trimmed and untrimmed
    if (!params.isbam) {
        ch_multiqc_files = ch_multiqc_files.mix(READS_QC.out.fastqc_untrimmed.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(READS_QC.out.fastqc_trimmed.collect{it[1]}.ifEmpty([]))
    }
    // adding BAM qc
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.stats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.flagstat.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.idxstats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.qualimap.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.bamstats.collect{it[1]}.ifEmpty([]))
    // adding kraken report if running full analysis
    // when running small test, small krakendb won't classify enough reads to generate a report
    if (params.multiqc_runkraken) {
        ch_multiqc_files = ch_multiqc_files.mix(CLASSIFY_UNMAPPED.out.report_single.collect{it[1]}.ifEmpty([]))
        ch_multiqc_files = ch_multiqc_files.mix(CLASSIFY_UNMAPPED.out.report_both.collect{it[1]}.ifEmpty([]))
    }

    ch_multiqc_files = ch_multiqc_files.mix(ch_collated_versions)
    ch_multiqc_files = ch_multiqc_files.mix(
        ch_methods_description.collectFile(
            name: 'methods_description_mqc.yaml',
            sort: true
        )
    )

    MULTIQC (
        ch_multiqc_files.collect(),
        ch_multiqc_config.toList(),
        ch_multiqc_custom_config.toList(),
        ch_multiqc_logo.toList(),
        [],
        []
    )

    emit:multiqc_report = MULTIQC.out.report.toList() // channel: /path/to/multiqc_report.html
    versions       = ch_versions                 // channel: [ path(versions.yml) ]

}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    UTILITIES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Useful functions kindly borrowed from Sarek

// Check file extension
def hasExtension(it, extension) {
    it.toString().toLowerCase().endsWith(extension.toLowerCase())
}

// from string indicating path
// returns extension WITH dot
def getExtensionFromStringPath(it) {
    return it.drop(it.lastIndexOf('.'))
}

// Return file if it exists
def returnFile(it) {
    if (!file(it).exists()) exit 1, "Input file does not exist: ${it}, see --help for more information"
    return file(it)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
