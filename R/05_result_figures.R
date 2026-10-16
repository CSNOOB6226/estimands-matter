source('R/00_common.R')
r<-readRDS('data/derived/all_risk_results.rds')
m<-r$main$summary;s<-rbind(r$landmark$summary,r$no_disease$summary)
theme_set(theme_minimal(base_size=12))
forest<-rbind(m[,names(s)],s)
forest$label<-paste(forest$scenario,forest$method,sep=' | ')
p<-ggplot(forest,aes(RD*100,reorder(label,seq_along(label))))+geom_vline(xintercept=0,color='#8995A0',linetype=2)+geom_errorbar(aes(xmin=RD_low*100,xmax=RD_high*100),orientation='y',width=.15,color='#2166AC')+geom_point(size=2.4,color='#2166AC')+labs(x='Risk difference, percentage points (95% CI)',y=NULL,title='Marginal mortality associations by target population',subtitle='Contrast: >=8 minus <8 strength sessions/30 days; JKn uncertainty',caption='Landmark: risk during months24–120 among survivors to month24. Capped PATE is a robustness check.')
ggsave('outputs/figures/risk_difference_forest.png',p,width=10.5,height=6.4,dpi=180)
p<-ggplot(forest,aes(RR,reorder(label,seq_along(label))))+geom_vline(xintercept=1,color='#8995A0',linetype=2)+geom_errorbar(aes(xmin=RR_low,xmax=RR_high),orientation='y',width=.15,color='#C75B39')+geom_point(size=2.4,color='#C75B39')+scale_x_log10()+labs(x='Risk ratio (95% CI, log scale)',y=NULL,title='Relative associations across analyses',caption='JKn re-estimates the propensity model in every replicate.')
ggsave('outputs/figures/risk_ratio_forest.png',p,width=10.5,height=6.4,dpi=180)
risks<-rbind(data.frame(method=m$method,A='<8',risk=m$risk0,low=m$risk0_low,high=m$risk0_high),data.frame(method=m$method,A='>=8',risk=m$risk1,low=m$risk1_low,high=m$risk1_high))
p<-ggplot(risks,aes(method,risk*100,color=A))+geom_point(position=position_dodge(.4),size=2.5)+geom_errorbar(aes(ymin=low*100,ymax=high*100),position=position_dodge(.4),width=.15)+scale_color_manual(values=c('#2166AC','#C75B39'))+labs(x=NULL,y='10-year mortality risk (%)',color='Sessions /30 days',title='Absolute risks depend on adjustment and target')+theme(legend.position='bottom')
ggsave('outputs/figures/marginal_risks.png',p,width=9,height=5,dpi=180)
flow<-read.csv('outputs/tables/participant_flow_design.csv')
png('outputs/figures/participant_flow.png',width=1300,height=1450,res=180)
par(mar=c(0,0,2,0));plot.new();plot.window(xlim=c(0,1),ylim=c(0,1));title('Participant selection: NHANES 1999–2006',cex.main=1)
yy<-seq(.87,.12,length.out=nrow(flow))
for(i in seq_len(nrow(flow))) {
 rect(.1,yy[i]-.045,.9,yy[i]+.045,col='#EDF3F8',border='#2166AC')
 text(.5,yy[i],paste0(flow$stage[i],'\nn = ',format(flow$n[i],big.mark=',')),cex=.85)
 if(i<nrow(flow)) {arrows(.5,yy[i]-.047,.5,yy[i+1]+.047,length=.08);text(.7,(yy[i]+yy[i+1])/2,paste('Excluded:',format(flow$excluded_since_previous[i+1],big.mark=',')),cex=.7)}
}
text(.5,.02,'All complete cases had an ascertainable 120-month outcome; no additional outcome exclusions.',cex=.7);dev.off()
# A readable report plot aggregates the maximum diagnostic within each covariate;
# the full basis-level Love plot and table are retained.
z<-readRDS('data/derived/design_objects.rds');bb<-z$balance
group_term<-function(t) {
 for(v in c('age','bmi','pir')) if(t==v || grepl(paste0('ns(',v,','),t,fixed=TRUE)) return(v)
 for(v in covars) if(startsWith(t,v)) return(v)
 t
}
bb$variable<-vapply(bb$term,group_term,character(1));bb$absolute_smd<-abs(bb$smd)
bp<-aggregate(absolute_smd~method+variable,bb,max);outcsv(bp,'balance_by_variable')
p<-ggplot(bp,aes(absolute_smd,reorder(variable,absolute_smd,max),color=method))+geom_point(size=2.2)+geom_vline(xintercept=.1,linetype=2,color='#777777')+scale_color_manual(values=c(Survey='#7C8A98',PATE='#2166AC',PATO='#C75B39'))+labs(x='Maximum absolute SMD within covariate',y=NULL,color=NULL,title='Balance after targeting the population')+theme(legend.position='bottom')
ggsave('outputs/figures/love_plot_summary.png',p,width=7.8,height=4.5,dpi=200)
d<-z$data
p<-ggplot(d,aes(ps,weight=MEC8YR,color=factor(A),fill=factor(A)))+geom_density(alpha=.15,linewidth=.8,bounds=c(0,1))+scale_color_manual(values=c('#2166AC','#C75B39'),labels=c('<8','>=8'))+scale_fill_manual(values=c('#2166AC','#C75B39'),labels=c('<8','>=8'))+labs(x='Propensity score',y='Density within exposure arm',color='Sessions/30 days',fill='Sessions/30 days',title='Covariate overlap before propensity weighting')+theme(legend.position='bottom')
ggsave('outputs/figures/propensity_density.png',p,width=7.8,height=3.7,dpi=200)
lo<-max(tapply(d$ps,d$A,min));hi<-min(tapply(d$ps,d$A,max));outside<-d$ps<lo|d$ps>hi
outcsv(data.frame(common_min=lo,common_max=hi,outside_n=sum(outside),outside_weighted_pct=100*wm(as.numeric(outside),d$MEC8YR)),'common_support')
mult<-ifelse(d$A==1,1/d$ps,1/(1-d$ps));capw<-d$MEC8YR*mult
for(a in 0:1){i<-d$A==a;capw[i]<-d$MEC8YR[i]*pmin(mult[i],quantile(mult[i],.99,type=1))}
outcsv(data.frame(method='PATE capped',max_abs_smd=max(abs(balance(z$X,d$A,d$MEC8YR,capw)$smd)),ESS0=ess(capw[d$A==0]),ESS1=ess(capw[d$A==1])),'capped_diagnostics')
cat('Result figures created.\n')
