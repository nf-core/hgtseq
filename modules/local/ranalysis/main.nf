process RANALYSIS {
    tag "Ranalysis"
    label 'process_low'

    conda (params.enable_conda ? "bioconda::bioconductor-ggbio==1.42.0--r41hdfd78af_0" : null)
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'library://lescailab/hgtseq/r-ggbio-reporting:sha256.5c2f30b64e910375c9f08085faab15fca931eacc979f130f94dba6b828b611f1' :
        'ghcr.io/lescailab/r-ggbio-reporting:1.0.0' }"

    input:
    path(classified_reads_assignment)
    path(integration_sites)
    val(sampleids)


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
        rmarkdown::render('$moduleDir/analysis_report.Rmd',
        params = list(
        sampleids = \\\"$samplestring\\\"
        ),
        knit_root_dir=workdir,
        output_dir=workdir)"
    """
}
