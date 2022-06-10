//
// Check input samplesheet and get read channels
//

include { SAMPLESHEET_CHECK } from '../../modules/local/samplesheet_check'

workflow INPUT_CHECK {
    take:
    samplesheet // file: /path/to/samplesheet.csv

    main:
    SAMPLESHEET_CHECK ( samplesheet )
        .csv
        .splitCsv ( header:true, sep:',' )
        .map { create_fastq_channel(it) }
        .set { reads }

    emit:
    reads                                     // channel: [ val(meta), [ reads ] ]
    versions = SAMPLESHEET_CHECK.out.versions // channel: [ versions.yml ]
}

// Useful functions kindly borrowed from Sarek

// Check file extension
def hasExtension(it, extension) {
    it.toString().toLowerCase().endsWith(extension.toLowerCase())
}

// Return file if it exists
def returnFile(it) {
    if (!file(it).exists()) exit 1, "Missing file in TSV file: ${it}, see --help for more information"
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
    meta.id         = row.sample

    // add path(s) of the fastq file(s) to the meta map
    def fastq_meta = []
    def file1      = returnFile(row.input1)
    if (!file1.exists()) {
        exit 1, "ERROR: Please check input samplesheet -> file indicated in input1 column does not exist!\n${row.input1}"
    }
    if (row.input2){
        def file2 = returnFile(row.input2)
        if (!file2.exists()) {
            exit 1, "ERROR: Please check input samplesheet -> file indicated in input2 column does not exist!\n${row.input2}"
        }
        meta.single_end = false
        meta.isbam = false
        fastq_meta = [ meta, [ file1, file2 ] ]
    } else {
        fastq_meta = [ meta, [ file1 ] ]
        if (hasExtension(file1, ".bam")) {
            meta.isbam = true
            meta.single_end = false
        } else {
            meta.isbam = false
            meta.single_end = true
        }
    }
    return fastq_meta
}
