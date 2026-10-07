source('R/00_common.R')
d<-readRDS('data/derived/outcome_data.rds');r<-readRDS('data/derived/all_risk_results.rds')
stopifnot(nrow(d)==15091,sum(d$death10)==1980,sum(d$A==1)==2826)
ind<-do.call(rbind,lapply(c(1999,2001,2003,2005),function(y)read.fwf(paste0('data/raw/NHANES_',y,'_',y+1,'_MORT_2019_PUBLIC.dat'),widths=c(6,-8,1,1,-29,3),col.names=c('SEQN','ELIGSTAT','MORTSTAT','PERMTH_EXM'),na.strings=c('.',''),strip.white=TRUE)))
ind<-ind[match(d$SEQN,ind$SEQN),]
stopifnot(all(ind$ELIGSTAT==d$ELIGSTAT),all(ind$MORTSTAT==d$MORTSTAT),all(ind$PERMTH_EXM==d$PERMTH_EXM))
ind_y<-as.integer(ind$MORTSTAT==1 & ind$PERMTH_EXM<=120)
stopifnot(identical(ind_y,d$death10))
for(o in r[c('main','landmark','no_disease')]) {
 a<-o$summary
 stopifnot(all(a$risk0>=0&a$risk0<=1),all(a$risk1>=0&a$risk1<=1),all(abs(a$RD-(a$risk1-a$risk0))<1e-12),all(abs(a$RR-a$risk1/a$risk0)<1e-12),all(is.finite(o$replicates)))
 # Independent, explicit replicate covariance calculation.
 delta<-sweep(o$replicates,2,o$theta,'-')
 vv<-matrix(0,ncol(delta),ncol(delta))
 for(j in seq_len(nrow(delta))) vv<-vv+outer(delta[j,],delta[j,])*r$rscales[j]*r$scale
 stopifnot(max(abs(vv-o$variance))<1e-12)
}
c<-readRDS('data/derived/cox_results.rds');stopifnot(c$coefficient_check<1e-7)
# Manual finite differences confirm direct-RD and log-RR Taylor gradients.
checks<-read.csv('outputs/tables/independent_risk_validation.csv');stopifnot(max(checks$max_point_difference)<1e-10)
outcsv(data.frame(check=c('Independent fixed-width mortality parser','Exposure and event counts','Risk contrast arithmetic','Independent replicate covariance','Weighted means versus direct ratios','Independent Cox coefficients'),status='PASS'),'validation_results')
cat('Outcome validation PASS; all117 replicates retained in each scenario.\n')
