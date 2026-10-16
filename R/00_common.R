suppressPackageStartupMessages({library(survey);library(foreign);library(splines);library(ggplot2)})
options(survey.lonely.psu='fail', survey.adjust.domain.lonely=FALSE, warn=1)
set.seed(20260923)
outcsv <- function(x,name) write.csv(x,file.path('outputs/tables',paste0(name,'.csv')),row.names=FALSE,na='')
covars <- c('age','sex','race','education','pir','smoking','alcohol','bmi','aerobic','health','diabetes','hypertension','cvd','cancer','cycle')
ps_formula <- A ~ ns(age,df=4)+sex+race+education+ns(pir,df=3)+smoking+alcohol+ns(bmi,df=3)+aerobic+health+diabetes+hypertension+cvd+cancer+cycle
wm <- function(x,w) sum(x*w)/sum(w)
ess <- function(w) sum(w)^2/sum(w^2)
death_at_120 <- function(status,months) {
 stopifnot(length(status)==length(months))
 ifelse(status==1 & !is.na(months) & months>=0 & months<=120,1L,
        ifelse(status %in% c(0,1) & !is.na(months) & months>=120,0L,NA_integer_))
}
composite <- function(A,e,d,type) {
 stopifnot(all(e>0 & e<1),all(d>=0))
 if(type=='PATE') d*ifelse(A==1,1/e,1/(1-e)) else if(type=='PATO') d*ifelse(A==1,1-e,e) else d
}
make_design <- function(d) svydesign(ids=~SDMVPSU,strata=~SDMVSTRA,weights=~MEC8YR,data=d,nest=TRUE)
balance <- function(X,A,d,w) {
 sd0 <- sqrt(apply(X,2,function(x) (wm((x[A==1]-wm(x[A==1],d[A==1]))^2,d[A==1])+wm((x[A==0]-wm(x[A==0],d[A==0]))^2,d[A==0]))/2))
 difference <- apply(X,2,function(x) wm(x[A==1],w[A==1])-wm(x[A==0],w[A==0]))
 data.frame(term=colnames(X),smd=ifelse(sd0>0,difference/sd0,0))
}
