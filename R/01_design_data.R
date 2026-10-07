# This script intentionally extracts only SEQN and ELIGSTAT from mortality files.
source('R/00_common.R')
spec <- list(DEMO=c('SDDSRVYR','RIDSTATR','RIDAGEYR','RIAGENDR','RIDRETH1','DMDEDUC2','INDFMPIR','WTMEC2YR','WTMEC4YR','SDMVSTRA','SDMVPSU'),
 PAQ=c('PAD440','PAD460','PAD200','PAD320'),BMX='BMXBMI',SMQ=c('SMQ020','SMQ040'),
 ALQ=c('ALQ100','ALD100','ALQ101','ALQ110','ALQ120Q','ALQ120U','ALQ130'),HUQ='HUQ010',DIQ='DIQ010',BPQ='BPQ020',
 MCQ=c('MCQ160B','MCQ160C','MCQ160D','MCQ160E','MCQ160F','MCQ220'))
availability <- list(); dfs <- list(); checks <- list()
for(k in 1:4) {
 year <- c(1999,2001,2003,2005)[k];suffix <- c('','_B','_C','_D')[k]
 for(comp in names(spec)) {
  path <- paste0('data/raw/',comp,suffix,'.xpt');x <- read.xport(path)
  stopifnot(!anyDuplicated(x$SEQN))
  wanted <- spec[[comp]]
  for(v in wanted) availability[[length(availability)+1]] <- data.frame(cycle=paste0(year,'-',year+1),component=comp,variable=v,present=v %in% names(x),file=path)
  x <- x[,c('SEQN',intersect(wanted,names(x))),drop=FALSE]
  for(v in setdiff(wanted,names(x))) x[[v]] <- NA_real_
  if(comp=='DEMO') d <- x else {
   stopifnot(all(x$SEQN %in% d$SEQN));before <- nrow(d);d <- merge(d,x,by='SEQN',all.x=TRUE,sort=FALSE);stopifnot(nrow(d)==before)
  }
 }
 lines <- readLines(paste0('data/raw/NHANES_',year,'_',year+1,'_MORT_2019_PUBLIC.dat'))
 eligibility <- data.frame(SEQN=as.integer(substr(lines,1,6)),ELIGSTAT=as.integer(substr(lines,15,15)))
 rm(lines)
 stopifnot(!anyDuplicated(eligibility$SEQN),setequal(eligibility$SEQN,d$SEQN))
 d <- merge(d,eligibility,by='SEQN',all.x=TRUE,sort=FALSE)
 stopifnot(all(d$SDDSRVYR==k))
 d$cycle <- factor(paste0(year,'-',year+1))
 d$MEC8YR <- if(k<=2) d$WTMEC4YR/2 else d$WTMEC2YR/4
 d$ALC_LEAD <- if(k==1) d$ALQ100 else if(k==2) d$ALD100 else d$ALQ101
 dfs[[k]] <- d
 checks[[k]] <- data.frame(cycle=as.character(d$cycle[1]),n=nrow(d),adult=sum(d$RIDAGEYR>=20),mec_sum=sum(d$MEC8YR),adult_mec_sum=sum(d$MEC8YR[d$RIDAGEYR>=20]),strata_min=min(d$SDMVSTRA),strata_max=max(d$SDMVSTRA))
}
d <- do.call(rbind,dfs);stopifnot(!anyDuplicated(d$SEQN))
stopifnot(all(d$RIDAGEYR>=0 & d$RIDAGEYR<=85),all(d$MEC8YR>=0),!anyNA(d[c('SDMVSTRA','SDMVPSU','MEC8YR','ELIGSTAT')]))
outcsv(do.call(rbind,availability),'variable_availability');outcsv(do.call(rbind,checks),'cycle_weight_check')
# Preserve raw code frequencies and skip diagnostics, without any outcome data.
outcsv(as.data.frame(with(subset(d,RIDAGEYR>=20),table(cycle,PAD440,useNA='ifany'))),'exposure_codes_by_cycle')
stopifnot(!any(d$PAD440 %in% c(2,3) & !is.na(d$PAD460)))
valid_count <- !is.na(d$PAD460)&d$PAD460>=1&d$PAD460<=300
d$strength_count <- ifelse(d$PAD440==2,0,ifelse(d$PAD440==1 & valid_count,d$PAD460,NA_real_))
d$A <- ifelse(is.na(d$strength_count),NA_integer_,as.integer(d$strength_count>=8))
valid <- function(x,range) ifelse(x %in% range,x,NA_real_)
yn <- function(x) factor(ifelse(x==1,'Yes',ifelse(x==2,'No',NA)),levels=c('No','Yes'))
d$age <- d$RIDAGEYR
d$sex <- factor(valid(d$RIAGENDR,1:2),levels=1:2,labels=c('Male','Female'))
d$race <- factor(valid(d$RIDRETH1,1:5),levels=1:5,labels=c('Mexican American','Other Hispanic','Non-Hispanic White','Non-Hispanic Black','Other or multiracial'))
d$education <- factor(valid(d$DMDEDUC2,1:5),levels=1:5,labels=c('<9th grade','9th-11th grade','High school/GED','Some college/AA','College graduate'))
d$pir <- ifelse(d$INDFMPIR>=0 & d$INDFMPIR<=5,d$INDFMPIR,NA_real_)
d$bmi <- d$BMXBMI
stopifnot(all(d$bmi[!is.na(d$bmi)]>0))
d$smoking <- factor(ifelse(d$SMQ020==2,'Never',ifelse(d$SMQ020==1 & d$SMQ040==3,'Former',ifelse(d$SMQ020==1 & d$SMQ040 %in% c(1,2),'Current',NA))),levels=c('Never','Former','Current'))
# Structural alcohol skips are resolved from lifetime screening; no missing-category imputation.
never <- d$ALC_LEAD==2 & d$ALQ110==2
q <- d$ALQ120Q; validq <- !is.na(q)&q>=0&q<=366
d$alcohol <- ifelse(never,'Lifetime <12 drinks',NA_character_)
d$alcohol[which(validq & q==0)] <- 'No past-year drinking'
d$alcohol[which(validq & q>0)] <- 'Past-year drinking'
d$alcohol <- factor(d$alcohol,levels=c('Lifetime <12 drinks','No past-year drinking','Past-year drinking'))
# Broad aerobic activity is measured, not minutes or guideline adherence.
vig <- ifelse(d$PAD200==1,1,ifelse(d$PAD200 %in% c(2,3),0,NA))
mod <- ifelse(d$PAD320==1,1,ifelse(d$PAD320 %in% c(2,3),0,NA))
d$aerobic <- factor(mod+2*vig,levels=0:3,labels=c('Neither','Moderate only','Vigorous only','Both'))
d$health <- factor(valid(d$HUQ010,1:5),levels=1:5,labels=c('Excellent','Very good','Good','Fair','Poor'))
d$diabetes <- factor(valid(d$DIQ010,1:3),levels=c(2,3,1),labels=c('No','Borderline','Yes'))
d$hypertension <- yn(d$BPQ020)
cv <- d[,paste0('MCQ160',LETTERS[2:6])]
d$cvd <- factor(ifelse(rowSums(cv==1,na.rm=TRUE)>0,'Yes',ifelse(rowSums(cv==2,na.rm=TRUE)==5,'No',NA)),levels=c('No','Yes'))
d$cancer <- yn(d$MCQ220)
d$adult <- d$age>=20;d$linkage <- d$adult & d$ELIGSTAT==1
d$exposure_eligible <- d$linkage & !is.na(d$A)
d$design_eligible <- d$exposure_eligible & d$MEC8YR>0
d$complete <- d$design_eligible & complete.cases(d[,covars])
keep <- c('SEQN','ELIGSTAT','SDMVSTRA','SDMVPSU','MEC8YR','A','strength_count',covars,'PAD440','PAD460','adult','linkage','exposure_eligible','design_eligible','complete')
d <- d[,unique(keep)]
stopifnot(!any(c('MORTSTAT','PERMTH_EXM','death10') %in% names(d)))
saveRDS(d,'data/derived/design_data.rds',version=3)
flow <- data.frame(stage=c('All NHANES participants','Adults age 20+','Mortality linkage eligible','Interpretable strength exposure','Positive MEC weight','Covariate-complete analytic sample'),n=c(nrow(d),sum(d$adult),sum(d$linkage),sum(d$exposure_eligible),sum(d$design_eligible),sum(d$complete)))
flow$excluded_since_previous <- c(NA,-diff(flow$n));outcsv(flow,'participant_flow_design');print(flow)
missing <- list();b <- subset(d,design_eligible)
for(group in c('Overall',levels(b$cycle),'A=0','A=1')) {
 z <- if(group=='Overall') b else if(grepl('A=',group)) b[b$A==as.integer(substr(group,3,3)),] else b[b$cycle==group,]
 for(v in covars) missing[[length(missing)+1]] <- data.frame(group=group,variable=v,n=nrow(z),missing=sum(is.na(z[[v]])),pct=100*mean(is.na(z[[v]])))
}
outcsv(do.call(rbind,missing),'missingness')
cat('Complete cases:',sum(d$complete),'/',sum(d$design_eligible),'\n')
