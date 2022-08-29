
process GAWK {
    tag 'collate kraken'
    label 'process_low'

    conda (params.enable_conda ? "gawk==5.1.0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/gawk:5.1.0':
        'quay.io/biocontainers/gawk:5.1.0' }"

    input:
    path(classified_reads)

    output:
    path "*_collated.txt"         , emit: collated_reads
    path "versions.yml"           , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    cat $classified_reads | gawk '\$1 != U && \$3 != 1 && \$3 != 0 {print \$0}' >kraken_classified_reads_collated.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        local: \$(echo \$(gawk --version 2>&1) | sed 's/^GNU Awk //; s/, API: 3.0.*//' ))
    END_VERSIONS
    """
}
