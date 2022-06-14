/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    VALIDATE INPUTS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

def summary_params = NfcoreSchema.paramsSummaryMap(workflow, params)

// Validate input parameters
WorkflowHgtseq.initialise(params, log)

def checkPathParamList = [ params.input, params.multiqc_config, params.fasta, params.krakendb, params.kronadb ]
for (param in checkPathParamList) { if (param) { file(param, checkIfExists: true) } }

// Check mandatory parameters
if (params.input) { ch_input = file(params.input) } else { exit 1, 'Input samplesheet not specified!' }

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    CONFIG FILES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

ch_multiqc_config        = file("$projectDir/assets/multiqc_config.yml", checkIfExists: true)
ch_multiqc_custom_config = params.multiqc_config ? Channel.fromPath(params.multiqc_config) : Channel.empty()

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT LOCAL MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// SUBWORKFLOW: Consisting of a mix of local and nf-core/modules
//
include { BAM_QC                      } from '../subworkflows/local/bam_qc/main'
include { CLASSIFY_UNMAPPED           } from '../subworkflows/local/classify_unmapped/main'
include { INPUT_CHECK                 } from '../subworkflows/local/input_check'
include { PREPARE_READS               } from '../subworkflows/local/prepare_reads/main'
include { READS_QC                    } from '../subworkflows/local/reads_qc/main'
include { REPORTING                   } from '../subworkflows/local/reporting/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    IMPORT NF-CORE MODULES/SUBWORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// MODULE: Installed directly from nf-core/modules
//
include { MULTIQC                                     } from '../modules/nf-core/modules/multiqc/main'
include { CUSTOM_DUMPSOFTWAREVERSIONS                 } from '../modules/nf-core/modules/custom/dumpsoftwareversions/main'
include { UNTAR                       as UNTAR_KRAKEN } from '../modules/nf-core/modules/untar/main'
include { UNTAR                       as UNTAR_KRONA  } from '../modules/nf-core/modules/untar/main'

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow HGTSEQ {

    ch_versions = Channel.empty()

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

    //
    // SUBWORKFLOW: Read in samplesheet, validate and stage input files
    //
    INPUT_CHECK (
        ch_input
    )
    ch_versions = ch_versions.mix(INPUT_CHECK.out.versions)

    test = INPUT_CHECK.out.reads.dump()

    // execute prepare reads and reads qc if input is fastq
    if (!params.isbam) {
        PREPARE_READS (
            INPUT_CHECK.out.reads,
            params.fasta,
            params.aligner
        )
        ch_versions = ch_versions.mix(PREPARE_READS.out.versions)

        READS_QC (
            INPUT_CHECK.out.reads,
            PREPARE_READS.out.trimmed_reads
        )
        ch_versions = ch_versions.mix(READS_QC.out.versions)
    }

    if (params.isbam) {
        // executes BAM QC on input files from CSV
        BAM_QC (
            INPUT_CHECK.out.reads,
            params.fasta,
            params.gff
        )
        ch_versions = ch_versions.mix(BAM_QC.out.versions)

        // executes classification on input files from CSV
        CLASSIFY_UNMAPPED (
            INPUT_CHECK.out.reads,
            ch_krakendb
        )
        ch_versions = ch_versions.mix(CLASSIFY_UNMAPPED.out.versions)
    } else {
        // executes BAM QC on aligned trimmed reads
        BAM_QC (
            PREPARE_READS.out.bam,
            params.fasta,
            params.gff
        )
        ch_versions = ch_versions.mix(BAM_QC.out.versions)

        // executes classification on aligned trimmed reads
        CLASSIFY_UNMAPPED (
            PREPARE_READS.out.bam,
            ch_krakendb
        )
        ch_versions = ch_versions.mix(CLASSIFY_UNMAPPED.out.versions)
    }

    // execute reporting only if genome is Human
    if (params.is_human) {
        REPORTING (
            CLASSIFY_UNMAPPED.out.classified_single.collect{ it[1] },
            CLASSIFY_UNMAPPED.out.classified_both.collect{ it[1] },
            CLASSIFY_UNMAPPED.out.candidate_integrations.collect{ it[1] },
            ch_kronadb,
            CLASSIFY_UNMAPPED.out.classified_single.collect{ it[0].id }
        )
        ch_versions = ch_versions.mix(REPORTING.out.versions)
    }

    CUSTOM_DUMPSOFTWAREVERSIONS (
        ch_versions.unique().collectFile(name: 'collated_versions.yml')
    )

    //
    // MODULE: MultiQC
    //
    workflow_summary    = WorkflowHgtseq.paramsSummaryMultiqc(workflow, summary_params)
    ch_workflow_summary = Channel.value(workflow_summary)

    ch_multiqc_files = Channel.empty()
    ch_multiqc_files = ch_multiqc_files.mix(Channel.from(ch_multiqc_config))
    ch_multiqc_files = ch_multiqc_files.mix(ch_multiqc_custom_config.collect().ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(ch_workflow_summary.collectFile(name: 'workflow_summary_mqc.yaml'))
    ch_multiqc_files = ch_multiqc_files.mix(CUSTOM_DUMPSOFTWAREVERSIONS.out.mqc_yml.collect())
    // adding reads QC for both trimmed and untrimmed
    ch_multiqc_files = ch_multiqc_files.mix(READS_QC.out.fastqc_untrimmed.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(READS_QC.out.fastqc_trimmed.collect{it[1]}.ifEmpty([]))
    // adding BAM qc
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.stats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.flagstat.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.idxstats.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(BAM_QC.out.qualimap.collect{it[1]}.ifEmpty([]))
    // adding kraken report
    ch_multiqc_files = ch_multiqc_files.mix(CLASSIFY_UNMAPPED.out.report_single.collect{it[1]}.ifEmpty([]))
    ch_multiqc_files = ch_multiqc_files.mix(CLASSIFY_UNMAPPED.out.report_both.collect{it[1]}.ifEmpty([]))

    MULTIQC (
        ch_multiqc_files.collect(),
        [[],[]]
    )
    multiqc_report = MULTIQC.out.report.toList()
    ch_versions    = ch_versions.mix(MULTIQC.out.versions)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    COMPLETION EMAIL AND SUMMARY
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

workflow.onComplete {
    if (params.email || params.email_on_fail) {
        NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
    }
    NfcoreTemplate.summary(workflow, params, log)
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
