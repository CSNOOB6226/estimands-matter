source('R/00_common.R')
# Hand calculations: e=.2/.8, d=10/20, A=1/0 gives IPTW=50/100; OW=8/16.
stopifnot(isTRUE(all.equal(composite(c(1,0),c(.2,.8),c(10,20),'PATE'),c(50,100))))
stopifnot(isTRUE(all.equal(composite(c(1,0),c(.2,.8),c(10,20),'PATO'),c(8,16))))
stopifnot(all.equal(c(200,400)/2,c(100,200)),all.equal(c(200,400)/4,c(50,100)))
stopifnot(identical(death_at_120(c(1,1,1,0,0,1),c(0,120,121,120,119,NA)),c(1L,1L,0L,0L,NA_integer_,NA_integer_)))
z <- readRDS('data/derived/design_objects.rds');d <- z$data
stopifnot(!anyDuplicated(d$SEQN),all(d$A %in% 0:1),all(d$ELIGSTAT==1),all(d$age>=20),!anyNA(d[,covars]),all(d$MEC8YR>0))
stopifnot(!any(grepl('mort|death|permth',names(d),ignore.case=TRUE)))
stopifnot(max(abs(subset(z$balance,method=='PATE')$smd))<.1,max(abs(subset(z$balance,method=='PATO')$smd))<1e-7)
# Weighted logistic score identity independently verifies exact mean balance.
X <- model.matrix(z$ps)
stopifnot(max(abs(colSums(X*(d$MEC8YR*(d$A-d$ps)))/sum(d$MEC8YR)))<1e-7)
stopifnot(sum(d$A==0)+sum(d$A==1)==nrow(d))
cat('Design checks PASS: hand weights, boundaries, unique joins, eligibility, no outcomes, balance and logistic score equations.\n')
