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

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN MAIN WORKFLOW
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// Info required for completion email and summary
def multiqc_report = []

workflow HGTSEQ {

    ch_input = Channel.empty()
    csv_input = returnFile(params.input)
    // split csv
    ch_input = Channel.from(csv_input)
        .splitCsv ( header:true, sep:',' )
        .map { create_input_channel(it) }

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
            ch_input
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
            PREPARE_READS.out.bam
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
    if (!params.enable_conda) {
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


    MULTIQC (
        ch_multiqc_files.collect(),
        [],
        [],
        []
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

// Function to get list of [ meta, [ fastq_1, fastq_2 ] ]
def create_input_channel(LinkedHashMap row) {
    // named rows in CSV file expected to be:
    // sample,group,input1 [optional: input2]
    // input1 can be either .fastq.gz or .fastq or .bam
    // input2 can only be .fastq.gz or .fastq
    // create meta map
    def meta = [:]
    // check if mandatory sample column exists
    if (row.sample){
        meta.id         = row.sample
    } else {
        exit 1, "ERROR: Please check input samplesheet -> a column named sample with sample ID is mandatory!\n"
    }

    def input_meta = []

    // check if mandatory input1 column exists
    if (row.input1){
        def file1 = returnFile(row.input1)
        if (!file1.exists()) {
            exit 1, "ERROR: Please check input samplesheet -> file indicated in input1 column does not exist!\n${row.input1}"
        }
        // check whether input1 is a fastq or bam
        if (!hasExtension(file1, "fastq.gz") && !hasExtension(file1, "fastq") && !hasExtension(file1, "bam") && !hasExtension(file1, "cram")){
            exit 1, "ERROR: input file in input1 column must be either a fastq or a bam/cram file!\n${row.input1}"
        }
    } else {
        exit 1, "ERROR: Please check input samplesheet -> a column named input1 with either fastq or bam/cram input is mandatory!\n"
    }
    // single or paired end is set based on presence or absence of input2 column
    if (row.input2){
        def file1 = returnFile(row.input1)
        def file2 = returnFile(row.input2)
        if (!file2.exists()) {
            exit 1, "ERROR: Please check input samplesheet -> file indicated in input2 column does not exist!\n${row.input2}"
        }
        if (getExtensionFromStringPath(row.input1) == ".bam" | getExtensionFromStringPath(row.input1) == ".cram"){
            exit 1, "ERROR: when providing BAM or CRAM input in column input1, column input2 should not exist"
        }
        if (!(getExtensionFromStringPath(row.input1) == getExtensionFromStringPath(row.input2))){
            exit 1, "ERROR: when providing paired end fastq files, both input should have the same extension\n${row.input1}\n${row.input2}"
        }
        meta.single_end = false
        input_meta = [ meta, [ file1, file2 ] ]
    } else {
        meta.single_end = true
        def file1 = returnFile(row.input1)
        input_meta = [ meta, [ file1 ] ]
    }
    return input_meta
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
