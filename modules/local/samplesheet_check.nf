process SAMPLESHEET_CHECK {
    tag "$samplesheet"

    conda (params.enable_conda ? "conda-forge::python=3.8.3" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/python:3.8.3' :
        'quay.io/biocontainers/python:3.8.3' }"

    input:
    path samplesheet

    output:
    tuple reads        , emit: reads
    path "versions.yml", emit: versions

    script: // This script is bundled with the pipeline, in nf-core/hgtseq/bin/

    // Useful functions kindly borrowed from Sarek

    // Check file extension
    def hasExtension(it, extension) {
        it.toString().toLowerCase().endsWith(extension.toLowerCase())
    }

    // Return file if it exists
    def returnFile(it) {
        if (!file(it).exists()) exit 1, "Missing file in CSV file: ${it}, see --help for more information"
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
        def input_meta = []
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
            input_meta = [ meta, [ file1, file2 ] ]
        } else {
            meta.single_end = true
            input_meta = [ meta, [ file1 ] ]
        }
        return input_meta
    }

    // split csv
    samplesheet
    .csv
    .splitCsv ( header:true, sep:',' )
    .map { create_input_channel(it) }
    .set { reads }

    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        python: \$(python --version | sed 's/Python //g')
    END_VERSIONS
    """
}
