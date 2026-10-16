# Run from the project root. Raw downloads are handled by run_project.py.
stopifnot(file.exists('docs/PROTOCOL.md'),file.exists('docs/DESIGN_FROZEN.json'))
for (path in c('data/derived', 'outputs/tables', 'outputs/figures', 'logs')) {
 dir.create(path, recursive=TRUE, showWarnings=FALSE)
}
stages<-c('R/01_design_data.R','R/02_design_diagnostics.R','tests/test_design.R','R/03_outcomes.R','R/04_cox.R','R/05_result_figures.R','tests/test_results.R')
for(s in stages) {
 cat('Running',s,'\n')
 log<-file.path('logs',paste0('rerun_',sub('\\.R$','',basename(s)),'.log'))
 status<-system2(file.path(R.home('bin'),'Rscript'),s,stdout=log,stderr=log)
 if(status!=0)stop('Stage failed: ',s,'; inspect ',log)
}
cat('All statistical stages passed.\n')
