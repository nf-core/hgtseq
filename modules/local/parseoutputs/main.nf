process PARSEOUTPUTS {
    tag "$meta.id"
    label 'process_low'

    conda "bioconda::samtools=1.17"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/samtools:1.17--h00cdaf9_0' :
        'biocontainers/samtools:1.17--h00cdaf9_0' }"

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path("*_parsed_integration_sites.txt"), emit: integration_sites
    path "versions.yml"                                    , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools \\
        view \\
        $args \\
        -@ $task.cpus \\
        -T $prefix \\
        $bam | cut -f 1,3,8 > ${prefix}_parsed_integration_sites.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        local: \$(echo \$(samtools --version 2>&1) | sed 's/^.*samtools //; s/Using.*\$//' ))
    END_VERSIONS
    """
}
