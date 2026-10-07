source('R/00_common.R')
stopifnot(file.exists('docs/DESIGN_FROZEN.json'),grepl('FROZEN',readLines('DESIGN_FREEZE.md')[1]))
z <- readRDS('data/derived/design_objects.rds');d <- z$data
read_num <- function(x) {x<-trimws(x);x[x %in% c('','.')] <- NA_character_;as.integer(x)}
mort <- do.call(rbind,lapply(c(1999,2001,2003,2005),function(y){
 l <- readLines(paste0('data/raw/NHANES_',y,'_',y+1,'_MORT_2019_PUBLIC.dat'))
 # Public files omit trailing blanks; the last field may end at column46/47.
 stopifnot(all(nchar(l)>=46 & nchar(l)<=48))
 data.frame(SEQN=read_num(substr(l,1,6)),ELIGSTAT_check=read_num(substr(l,15,15)),MORTSTAT=read_num(substr(l,16,16)),PERMTH_EXM=read_num(substr(l,46,48)))
}))
stopifnot(!anyDuplicated(mort$SEQN),all(d$SEQN %in% mort$SEQN))
mm <- mort[match(d$SEQN,mort$SEQN),];stopifnot(identical(d$SEQN,as.numeric(mm$SEQN)),all(mm$ELIGSTAT_check==1))
d$MORTSTAT <- mm$MORTSTAT;d$PERMTH_EXM <- mm$PERMTH_EXM
stopifnot(all(d$MORTSTAT %in% c(0,1)),!anyNA(d$PERMTH_EXM),all(d$PERMTH_EXM>=0))
d$death10 <- death_at_120(d$MORTSTAT,d$PERMTH_EXM)
stopifnot(!anyNA(d$death10),all(d$PERMTH_EXM[d$MORTSTAT==0]>=120))
d$time <- pmin(120,pmax(.5,d$PERMTH_EXM))
outcsv(data.frame(n=nrow(d),deaths10=sum(d$death10),deaths_24=sum(d$MORTSTAT==1 & d$PERMTH_EXM<=24),zero_months=sum(d$PERMTH_EXM==0),min_alive_followup=min(d$PERMTH_EXM[d$MORTSTAT==0]),missing_outcomes=sum(is.na(d$death10))),'outcome_audit')
outcsv(aggregate(cbind(n=rep(1,nrow(d)),deaths10=d$death10)~A+cycle,data=d,sum),'events_by_cycle_exposure')
saveRDS(d,'data/derived/outcome_data.rds',version=3)
cat('Outcomes validated after freeze:',nrow(d),'participants;',sum(d$death10),'deaths by120 months.\n')

# Replicates are generated before domain restriction, preserving all masked PSUs.
all <- readRDS('data/derived/design_data.rds');full <- make_design(subset(all,MEC8YR>0))
repf <- as.svrepdesign(full,type='JKn',mse=TRUE);repd <- subset(repf,complete)
stopifnot(identical(repd$variables$SEQN,d$SEQN))
rw <- as.matrix(weights(repd,type='analysis'));basew <- d$MEC8YR
X <- model.matrix(z$ps)
stopifnot(nrow(X)==nrow(d))
fit_ps <- function(x,a,w) {
 fit <- glm.fit(x=x,y=a,weights=w/mean(w),family=quasibinomial(),control=glm.control(epsilon=1e-10,maxit=100))
 stopifnot(fit$converged)
 b <- fit$coefficients;b[is.na(b)] <- 0
 e <- plogis(drop(x%*%b));stopifnot(all(e>0 & e<1));e
}
vector_risks <- function(r0,r1) c(risk0=r0,risk1=r1,RD=r1-r0,logRR=log(r1/r0),logit0=qlogis(r0),logit1=qlogis(r1))
weighted_quantile <- function(x,w,p=.99) {o<-order(x);x[o][which(cumsum(w[o])/sum(w)>=p)[1]]}
estimate <- function(sw,dd,xx,methods,originalw) {
 a<-dd$A;y<-dd$death10;e<-fit_ps(xx,a,sw)
 ans<-list()
 for(m in methods) {
  if(m=='Standardized logistic') {
   ox<-cbind(xx,A=a);fit<-glm.fit(ox,y,weights=sw/mean(sw),family=quasibinomial(),control=glm.control(epsilon=1e-10,maxit=100));stopifnot(fit$converged)
   b<-fit$coefficients;b[is.na(b)]<-0
   r<-sapply(0:1,function(g){px<-ox;px[,'A']<-g;wm(plogis(drop(px%*%b)),sw)})
  } else {
   w<-composite(a,e,sw,if(m=='PATE capped') 'PATE' else m)
   if(m=='PATE capped') {
    mult<-ifelse(a==1,1/e,1/(1-e));rf<-sw/originalw
    for(g in 0:1) {idx<-a==g;cap<-weighted_quantile(mult[idx],rf[idx]);w[idx]<-sw[idx]*pmin(mult[idx],cap)}
   }
   r<-sapply(0:1,function(g)wm(y[a==g],w[a==g]))
  }
  ans[[m]]<-vector_risks(r[1],r[2])
 }
 unlist(ans)
}
summarize_est <- function(theta,V,methods,scenario,df,n,events) {
 critical<-qt(.975,df);rows<-list()
 for(m in methods) {
  nm<-paste0(m,'.',c('risk0','risk1','RD','logRR','logit0','logit1'));b<-theta[nm];se<-sqrt(pmax(0,diag(V)[nm]))
  ci0<-plogis(b[5]+c(-1,1)*critical*se[5]);ci1<-plogis(b[6]+c(-1,1)*critical*se[6]);cird<-b[3]+c(-1,1)*critical*se[3];cirr<-exp(b[4]+c(-1,1)*critical*se[4])
  rows[[m]]<-data.frame(scenario=scenario,method=m,n=n,events=events,df=df,risk0=b[1],risk0_low=ci0[1],risk0_high=ci0[2],risk1=b[2],risk1_low=ci1[1],risk1_high=ci1[2],RD=b[3],RD_low=cird[1],RD_high=cird[2],RR=exp(b[4]),RR_low=cirr[1],RR_high=cirr[2],SE_RD=se[3],SE_logRR=se[4],row.names=NULL)
 }
 do.call(rbind,rows)
}
run_scenario <- function(idx,methods,label) {
 dd<-d[idx,];xx<-X[idx,,drop=FALSE];w<-basew[idx];wr<-rw[idx,,drop=FALSE]
 theta<-estimate(w,dd,xx,methods,w)
 rr<-matrix(NA_real_,ncol(wr),length(theta),dimnames=list(NULL,names(theta)))
 for(j in seq_len(ncol(wr))) {
  rr[j,]<-estimate(wr[,j],dd,xx,methods,w)
  if(j%%30==0) cat(label,':',j,'/',ncol(wr),'replicates\n')
 }
 stopifnot(all(is.finite(rr)))
 V<-survey::svrVar(rr,scale=repd$scale,rscales=repd$rscales,mse=TRUE,coef=theta)
 dimnames(V)<-list(names(theta),names(theta))
 df<-degf(subset(repd,idx))
 list(theta=theta,variance=V,replicates=rr,summary=summarize_est(theta,V,methods,label,df,nrow(dd),sum(dd$death10)))
}
main<-run_scenario(rep(TRUE,nrow(d)),c('Survey','Standardized logistic','PATE','PATO','PATE capped'),'Primary')
saveRDS(main,'data/derived/main_results.rds',version=3);outcsv(main$summary,'main_results');print(main$summary)
sens1<-run_scenario(!(d$MORTSTAT==1 & d$PERMTH_EXM<=24),c('PATE','PATO'),'24-month survivor landmark')
sens2<-run_scenario(d$cancer=='No' & d$cvd=='No',c('PATE','PATO'),'Exclude baseline cancer/CVD')
outcsv(rbind(sens1$summary,sens2$summary),'sensitivity_results')
saveRDS(list(main=main,landmark=sens1,no_disease=sens2,scale=repd$scale,rscales=repd$rscales,replicate_count=ncol(rw)),'data/derived/all_risk_results.rds',version=3)

# Independent point calculation plus fixed-PS design-based Taylor uncertainty.
checks<-list()
for(m in c('Survey','PATE','PATO')) {
 dd<-d;dd$MEC8YR<-composite(dd$A,dd$ps,dd$MEC8YR,m)
 ds<-make_design(dd)
 means<-svyby(~death10,~A,ds,svymean,covmat=TRUE)
 r<-coef(means);V<-vcov(means);gradient<-c(-1/r[1],1/r[2])
 manual<-sapply(0:1,function(a)with(dd[dd$A==a,],sum(MEC8YR*death10)/sum(MEC8YR)))
 stopifnot(max(abs(r-manual))<1e-10,max(abs(manual-main$theta[paste0(m,c('.risk0','.risk1'))]))<1e-9)
 checks[[m]]<-data.frame(method=m,risk0=r[1],risk1=r[2],SE_RD_fixedPS=sqrt(drop(c(-1,1)%*%V%*%c(-1,1))),SE_logRR_fixedPS=sqrt(drop(gradient%*%V%*%gradient)),max_point_difference=max(abs(r-manual)),row.names=NULL)
}
outcsv(do.call(rbind,checks),'independent_risk_validation')
# Refit-PS sensitivity design diagnostics (not used to choose a new model).
diagnostics<-list()
for(l in c('Primary','Landmark','No cancer/CVD')) {
 idx<-if(l=='Primary')rep(TRUE,nrow(d)) else if(l=='Landmark')!(d$MORTSTAT==1 & d$PERMTH_EXM<=24) else d$cancer=='No' & d$cvd=='No'
 dd<-d[idx,];ee<-fit_ps(X[idx,,drop=FALSE],dd$A,dd$MEC8YR)
 for(m in c('PATE','PATO')) {
  w<-composite(dd$A,ee,dd$MEC8YR,m)
  diagnostics[[length(diagnostics)+1]]<-data.frame(scenario=l,method=m,max_abs_smd=max(abs(balance(z$X[idx,,drop=FALSE],dd$A,dd$MEC8YR,w)$smd)),ESS0=ess(w[dd$A==0]),ESS1=ess(w[dd$A==1]))
 }
}
outcsv(do.call(rbind,diagnostics),'sensitivity_design_diagnostics')
capture.output(sessionInfo(),file='logs/sessionInfo_outcomes.txt')
cat('All risk analyses and independent point checks complete.\n')
