source('R/00_common.R')
stopifnot(file.exists('docs/DESIGN_FROZEN.json'))
d<-readRDS('data/derived/outcome_data.rds');z<-readRDS('data/derived/design_objects.rds')
X<-model.matrix(z$ps)[,-1,drop=FALSE]
mapping<-data.frame(cox_column=sprintf('C%02d',seq_len(ncol(X))),original_term=colnames(X));colnames(X)<-mapping$cox_column
cd<-cbind(d,as.data.frame(X));des<-make_design(cd)
# All 117 PSUs remain in this domain, so PSU linearized totals are unchanged by
# dropping zero-contribution out-of-domain records in this benchmark.
stopifnot(nrow(unique(cd[c('SDMVSTRA','SDMVPSU')]))==117,degf(des)==59)
form<-reformulate(c('A',colnames(X)),response='Surv(time,death10)')
cox<-svycoxph(form,design=des,ties='breslow',x=TRUE,y=TRUE)
df<-degf(des);b<-coef(cox)['A'];se<-sqrt(vcov(cox)['A','A']);ci<-exp(b+c(-1,1)*qt(.975,df)*se)
result<-data.frame(n=nrow(d),events=sum(d$death10),HR=exp(b),lower=ci[1],upper=ci[2],SE_logHR=se,df=df,zero_months_shifted=sum(d$PERMTH_EXM==0),row.names=NULL)
outcsv(result,'cox_benchmark');outcsv(mapping,'cox_basis_dictionary')
# Independent coefficient check; variance here is not used for NHANES inference.
cc<-coxph(form,data=cd,weights=MEC8YR/mean(MEC8YR),ties='breslow')
stopifnot(max(abs(coef(cc)-coef(cox)))<1e-7)
ph<-cox.zph(cox,transform='km')
ph_table<-data.frame(term=rownames(ph$table),ph$table,row.names=NULL)
ph_table$inference_note<-'Exploratory only: cox.zph test does not incorporate full survey design'
outcsv(ph_table,'ph_schoenfeld_exploratory')
png('outputs/figures/ph_schoenfeld_exposure.png',width=1500,height=900,res=180)
plot(ph,var='A',resid=TRUE,se=TRUE,main='Exposure PH diagnostic (weighted Schoenfeld residuals)',xlab='Follow-up time (months)',ylab='Estimated log hazard ratio');abline(h=coef(cox)['A'],lty=2,col='#C75B39');dev.off()

# Prespecified design-based exposure time interaction at60 months.
sp<-survSplit(Surv(time,death10)~.,data=cd,cut=60,episode='period')
sp$A_late<-sp$A*as.numeric(sp$period==2)
spdes<-make_design(sp)
phform<-reformulate(c('A','A_late',colnames(X)),response='Surv(tstart,time,death10)')
phfit<-svycoxph(phform,design=spdes,ties='breslow',x=TRUE,y=TRUE)
bp<-coef(phfit);Vp<-vcov(phfit)
seint<-sqrt(Vp['A_late','A_late']);tval<-bp['A_late']/seint
early<-bp['A'];late<-bp['A']+bp['A_late'];selate<-sqrt(Vp['A','A']+Vp['A_late','A_late']+2*Vp['A','A_late'])
phtable<-data.frame(split_month=60,logHR_change=bp['A_late'],SE_change=seint,t=tval,df=df,p=2*pt(-abs(tval),df),HR_0_60=exp(early),HR_61_120=exp(late),HR_0_60_low=exp(early-qt(.975,df)*sqrt(Vp['A','A'])),HR_0_60_high=exp(early+qt(.975,df)*sqrt(Vp['A','A'])),HR_61_120_low=exp(late-qt(.975,df)*selate),HR_61_120_high=exp(late+qt(.975,df)*selate),row.names=NULL)
outcsv(phtable,'ph_design_interaction');print(result);print(phtable)
saveRDS(list(cox=cox,ph=ph,phfit=phfit,result=result,ph_interaction=phtable,coefficient_check=max(abs(coef(cc)-coef(cox)))),'data/derived/cox_results.rds',version=3)
cat('Cox and PH diagnostics complete.\n')
