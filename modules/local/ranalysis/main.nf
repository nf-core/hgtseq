process RANALYSIS {
    tag "Ranalysis"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::bioconductor-ggbio==1.42.0--r41hdfd78af_0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'library://lescailab/hgtseq/r-ggbio-reporting:sha256.eb829b05cf12e8d827813a6afb6e38592aac6568f685a6519f5ed7dd20125cb3' :
        'ghcr.io/lescailab/r-ggbio-reporting:1.0.0' }"

    input:
    path(classified_reads_assignment)
    path(integration_sites)
    val(sampleids)
    path(markdownfile)


    output:
    path("analysis_report.html"), emit: report
    path("analysis_report.RData")

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: ''
    samplestring = sampleids.join(',')

    """
    Rscript -e "workdir<-getwd()
        rmarkdown::render('$markdownfile',
        params = list(
        sampleids = \\\"$samplestring\\\"
        ),
        knit_root_dir=workdir,
        output_dir=workdir)"
    """
}
