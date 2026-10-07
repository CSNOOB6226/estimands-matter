source('R/00_common.R')
all <- readRDS('data/derived/design_data.rds')
full <- make_design(subset(all,MEC8YR>0));des <- subset(full,complete);d <- des$variables
stopifnot(nrow(d)==sum(all$complete),length(unique(d$SDMVSTRA))==58)
ps <- svyglm(ps_formula,design=des,family=quasibinomial(),control=glm.control(epsilon=1e-10,maxit=100))
stopifnot(ps$converged,!anyNA(coef(ps)))
d$ps <- as.numeric(predict(ps,type='response'))
cross <- glm(ps_formula,data=d,weights=MEC8YR/mean(MEC8YR),family=quasibinomial(),control=glm.control(epsilon=1e-10,maxit=100))
stopifnot(max(abs(d$ps-predict(cross,type='response')))<1e-8)
X <- model.matrix(ps)[,-1,drop=FALSE]
# Include raw continuous covariates as well as every spline basis/factor model column.
X <- cbind(age=d$age,bmi=d$bmi,pir=d$pir,X)
weights <- list(Survey=d$MEC8YR,PATE=composite(d$A,d$ps,d$MEC8YR,'PATE'),PATO=composite(d$A,d$ps,d$MEC8YR,'PATO'))
bals <- do.call(rbind,lapply(names(weights),function(n) transform(balance(X,d$A,d$MEC8YR,weights[[n]]),method=n)))
outcsv(bals,'balance');print(aggregate(abs(smd)~method,bals,max))
# Outcome-blinded comparison of weighted versus unweighted PS with the same formula.
unw <- glm(ps_formula,data=d,family=binomial());pe <- predict(unw,type='response')
comp <- do.call(rbind,lapply(c('Survey PS','Unweighted PS'),function(spec) {
 e <- if(spec=='Survey PS') d$ps else pe
 do.call(rbind,lapply(c('PATE','PATO'),function(t) {
 w <- composite(d$A,e,d$MEC8YR,t)
 data.frame(specification=spec,estimand=t,max_abs_smd=max(abs(balance(X,d$A,d$MEC8YR,w)$smd)),ESS0=ess(w[d$A==0]),ESS1=ess(w[d$A==1]))
 }))
}));outcsv(comp,'ps_specification_comparison');print(comp)
quantiles <- list()
for(n in names(weights)) for(a in 0:1) {
 w <- weights[[n]][d$A==a];pw <- w/d$MEC8YR[d$A==a]
 quantiles[[length(quantiles)+1]] <- data.frame(method=n,A=a,n=length(w),ESS=ess(w),min=min(w),median=median(w),p95=quantile(w,.95),p99=quantile(w,.99),max=max(w),max_over_mean=max(w)/mean(w),ps_multiplier_p99=quantile(pw,.99),ps_multiplier_max=max(pw))
}
outcsv(do.call(rbind,quantiles),'weight_diagnostics')
outcsv(do.call(rbind,lapply(0:1,function(a) data.frame(A=a,t(quantile(d$ps[d$A==a],c(0,.01,.05,.25,.5,.75,.95,.99,1)))))),'ps_quantiles')
d$w_ate <- weights$PATE;d$w_ato <- weights$PATO
# Descriptive summaries retain variable-specific denominators, including incomplete-case comparisons.
describe <- function(z,w,label) {
 rows <- list(data.frame(population=label,variable='N',level='',value=nrow(z),available_n=nrow(z),available_weight=sum(w)))
 for(v in c('A',covars)) {
  ok <- !is.na(z[[v]]);x <- z[[v]][ok];ww <- w[ok]
  if(is.factor(x)) {
   for(l in levels(x)) rows[[length(rows)+1]] <- data.frame(population=label,variable=v,level=l,value=100*wm(as.numeric(x==l),ww),available_n=sum(ok),available_weight=sum(ww))
  } else rows[[length(rows)+1]] <- data.frame(population=label,variable=v,level=if(v=='A')'Prevalence (%)' else 'Mean',value=wm(x,ww)*ifelse(v=='A',100,1),available_n=sum(ok),available_weight=sum(ww))
 }
 do.call(rbind,rows)
}
tab1 <- do.call(rbind,lapply(c('All','A=0','A=1'),function(l){z <- if(l=='All')d else d[d$A==as.integer(substr(l,3,3)),];describe(z,z$MEC8YR,l)}));outcsv(tab1,'table1_survey')
b <- subset(all,design_eligible)
incl <- do.call(rbind,lapply(c(TRUE,FALSE),function(i){z<-b[b$complete==i,];describe(z,z$MEC8YR,if(i)'Included' else 'Excluded')}));outcsv(incl,'included_excluded')
# Equal-arm pooling makes composite pseudo-population comparisons interpretable.
pool_weights <- function(w,A) w/ave(w,A,FUN=sum)/2
targets <- rbind(describe(d,d$MEC8YR,'Original complete-case population'),describe(d,pool_weights(d$w_ate,d$A),'PATE composite population'),describe(d,pool_weights(d$w_ato,d$A),'PATO composite population'),describe(d,d$MEC8YR*d$ps*(1-d$ps),'PATO tilting target'))
outcsv(targets,'target_populations')
outcsv(data.frame(n=nrow(d),A0=sum(d$A==0),A1=sum(d$A==1),weighted_prevalence=wm(d$A,d$MEC8YR),weighted_population=sum(d$MEC8YR),strata=length(unique(d$SDMVSTRA)),PSUs=nrow(unique(d[c('SDMVSTRA','SDMVPSU')])),df=degf(des),complete_fraction=nrow(d)/nrow(b)),'design_summary')
theme_set(theme_minimal(base_size=12))
cols <- c(Survey='#7C8A98',PATE='#2166AC',PATO='#C75B39')
p <- ggplot(bals,aes(abs(smd),reorder(term,abs(smd),max),color=method))+geom_point(size=1.8)+geom_vline(xintercept=.1,linetype=2)+scale_color_manual(values=cols)+labs(x='Absolute standardized mean difference',y=NULL,color=NULL,title='Balance in the survey-weighted target population',subtitle='Fixed denominator: pooled within-group SD under MEC weights')+theme(legend.position='bottom')
ggsave('outputs/figures/love_plot.png',p,width=9,height=9,dpi=180)
p <- ggplot(d,aes(ps,weight=MEC8YR/sum(MEC8YR),fill=factor(A)))+geom_histogram(position='identity',alpha=.5,bins=35)+scale_fill_manual(values=c('#2166AC','#C75B39'),labels=c('<8 / 30 days','>=8 / 30 days'))+labs(x='Survey-weighted propensity score',y='Weighted fraction of complete-case population',fill='Strength activity',title='Observed propensity-score overlap')+theme(legend.position='bottom')
ggsave('outputs/figures/propensity_overlap.png',p,width=8,height=4.7,dpi=180)
long <- do.call(rbind,lapply(names(weights),function(n) data.frame(method=n,A=factor(d$A),weight=weights[[n]]/mean(weights[[n]]))))
p <- ggplot(long,aes(A,weight,fill=method))+geom_boxplot(outlier.size=.3)+scale_y_log10()+facet_wrap(~method)+scale_fill_manual(values=cols)+labs(x='Exposure (1 = >=8 sessions/30 days)',y='Composite weight / mean (log scale)',title='Weight dispersion')+theme(legend.position='none')
ggsave('outputs/figures/weight_distribution.png',p,width=8,height=4.7,dpi=180)
saveRDS(list(data=d,ps=ps,X=X,formula=ps_formula,comparison=comp,balance=bals),'data/derived/design_objects.rds',version=3)
capture.output(sessionInfo(),file='logs/sessionInfo_design.txt')
cat('Design diagnostics completed. No outcomes accessed.\n')
