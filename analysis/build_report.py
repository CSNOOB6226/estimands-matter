"""Build an eight-page scientific report and two-page frozen analysis plan."""
from pathlib import Path
import csv,re,json,html
from reportlab.platypus import SimpleDocTemplate,Paragraph,Spacer,Table,TableStyle,PageBreak,Image,KeepTogether
from reportlab.lib.styles import getSampleStyleSheet,ParagraphStyle
from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import letter
from pypdf import PdfReader
ROOT=Path(__file__).resolve().parents[1]
T=ROOT/'outputs/tables';F=ROOT/'outputs/figures'
def read(n):return list(csv.DictReader((T/(n+'.csv')).open()))
def num(r,k):return float(r[k])
def pct(x):return f'{100*float(x):.2f}'
def f(x,n=2):return f'{float(x):.{n}f}'
def integer(x):return f'{int(round(float(x))):,}'
m={r['method']:r for r in read('main_results')};pate=m['PATE'];pato=m['PATO'];crude=m['Survey'];std=m['Standardized logistic'];cap=m['PATE capped']
sens=read('sensitivity_results');cox=read('cox_benchmark')[0];ph=read('ph_design_interaction')[0];audit=read('outcome_audit')[0];des=read('design_summary')[0]
wd=read('weight_diagnostics');cs=read('common_support')[0];capped=read('capped_diagnostics')[0]
def rd(r):return f"{pct(r['RD'])} ({pct(r['RD_low'])}, {pct(r['RD_high'])})"
def rr(r):return f"{f(r['RR'])} ({f(r['RR_low'])}, {f(r['RR_high'])})"
styles=getSampleStyleSheet()
styles.add(ParagraphStyle('ReportBody',fontName='Times-Roman',fontSize=10.4,leading=14.1,spaceAfter=7))
styles.add(ParagraphStyle('ReportSmall',fontName='Helvetica',fontSize=8.1,leading=10.6,spaceAfter=5))
styles.add(ParagraphStyle('ReportCaption',fontName='Helvetica',fontSize=8.8,leading=11.3,textColor=colors.HexColor('#465766'),spaceAfter=6))
styles.add(ParagraphStyle('ReportH1',fontName='Helvetica-Bold',fontSize=17,leading=21,textColor=colors.HexColor('#173A53'),spaceAfter=12))
styles.add(ParagraphStyle('ReportH2',fontName='Helvetica-Bold',fontSize=11.4,leading=15,textColor=colors.HexColor('#173A53'),spaceBefore=7,spaceAfter=5))
styles.add(ParagraphStyle('ReportTitle',fontName='Helvetica-Bold',fontSize=26,leading=29,textColor=colors.HexColor('#173A53'),spaceAfter=13))
styles.add(ParagraphStyle('ReportSub',fontName='Helvetica',fontSize=13.5,leading=18,spaceAfter=16))
W,H=letter;WIDTH=W-100
story=[];md=[]
def clean(s):
 parts=re.split(r'(<[^>]+>)',s)
 for i,p in enumerate(parts):
  if p.startswith('<'):continue
  p=re.sub(r'(?<=[a-z])(?=\d)|(?<=\d)(?=[a-z])',' ',p)
  p=re.sub(r'\b(\d+) (st|nd|rd|th)\b',r'\1\2',p)
  p=re.sub(r'(?<=[;:])(?=\d)',' ',p)
  p=re.sub(r'(?<=[a-z]),(?=\d)',', ',p)
  p=re.sub(r'(?<=[a-z]{2})\((?=\d)',' (',p)
  p=p.replace('NHANES1999','NHANES 1999').replace('R4.5','R 4.5').replace('JASA.20','JASA. 20').replace('Med.20','Med. 20').replace('Health.20','Health. 20').replace('Journal.20','Journal. 20').replace('Softw.20','Softw. 20').replace('Epidemiol.20','Epidemiol. 20')
  parts[i]=p
 return ''.join(parts)
def para(s,style='ReportBody',record=True):
 s=clean(s)
 story.append(Paragraph(s,styles[style]))
 if record:
  text=re.sub(r'<link href="([^"]+)"[^>]*>(.*?)</link>',r'[\2](\1)',s)
  text=re.sub(r'<br\s*/?>','\n',text)
  text=re.sub(r'<sup>(.*?)</sup>',r'^\1',text)
  md.append(html.unescape(re.sub('<[^>]*>','',text)))
def head(s):para(s,'ReportH1');md[-1]='# '+md[-1]
def sub(s):para(s,'ReportH2');md[-1]='## '+md[-1]
def page():story.append(PageBreak());md.append('\n---\n')
def table(rows,widths=None):
 rows=[[clean(str(c)) for c in row] for row in rows]
 normalized=[[Paragraph(html.escape(str(c)).replace('\n','<br/>'),styles['ReportSmall']) for c in row] for row in rows]
 tab=Table(normalized,colWidths=widths or [WIDTH/len(rows[0])]*len(rows[0]),repeatRows=1,hAlign='LEFT')
 tab.setStyle(TableStyle([('BACKGROUND',(0,0),(-1,0),colors.HexColor('#E5EEF4')),('LINEBELOW',(0,0),(-1,0),.7,colors.HexColor('#3B647E')),('VALIGN',(0,0),(-1,-1),'TOP'),('LEFTPADDING',(0,0),(-1,-1),5),('RIGHTPADDING',(0,0),(-1,-1),5),('TOPPADDING',(0,0),(-1,-1),4),('BOTTOMPADDING',(0,0),(-1,-1),3),('ROWBACKGROUNDS',(0,1),(-1,-1),[colors.white,colors.HexColor('#F6F8FA')]),('LINEBELOW',(0,-1),(-1,-1),.5,colors.HexColor('#AAB7C1'))]))
 story.append(tab);story.append(Spacer(1,7))
 md.append('\n'.join(['| '+' | '.join(map(str,row)).replace('\n',' ')+' |' for row in rows[:1]]+['| '+' | '.join(['---']*len(rows[0]))+' |']+['| '+' | '.join(map(str,row)).replace('\n',' ')+' |' for row in rows[1:]]))
def figure(name,width,height,caption):
 story.append(Image(str(F/name),width=width,height=height,hAlign='CENTER'));para(caption,'ReportCaption');md.append(f'![{caption}](../outputs/figures/{name})')
def footer(canvas,doc):
 canvas.saveState();canvas.setStrokeColor(colors.HexColor('#C4D1DA'));canvas.line(50,43,W-50,43)
 canvas.setFont('Helvetica',8);canvas.setFillColor(colors.HexColor('#556776'))
 canvas.drawString(50,30,'Estimands Matter | Methodological reanalysis')
 canvas.drawRightString(W-50,30,str(doc.page));canvas.restoreState()

para('Estimands Matter','ReportTitle')
para('A Survey-Weighted Reanalysis of Muscle-Strengthening Activity and 10-Year Mortality in NHANES 1999-2006','ReportSub')
para('Comparing population-average and overlap-population estimates','ReportH2')
para('Independent research report | Design frozen 23 September 2026 (Toronto time)<br/>Public NHANES data linked through 2019 | Not submitted or externally peer-reviewed','ReportCaption')
sub('Abstract')
para(f'<b>Objective.</b> To examine how a change in target population affects adjusted associations between baseline muscle-strengthening activity and ten-year mortality. <b>Methods.</b> We analyzed {integer(des["n"])} complete-case adults aged at least20 from four NHANES cycles. Exposure was at least8 versus0-7 self-reported sessions in30 days. Survey-weighted propensity scores generated population-average (PATE) and overlap-population (PATO) composite weights. Stratified delete-one-PSU jackknife inference re-estimated propensity scores in all117 replicates. <b>Results.</b> There were {integer(audit["deaths10"])} deaths by120 months. PATE mortality risks were {pct(pate["risk1"])}% versus {pct(pate["risk0"])}%, giving a risk difference of {rd(pate)} percentage points and risk ratio {rr(pate)}. PATO risks were {pct(pato["risk1"])}% versus {pct(pato["risk0"])}%, with risk difference {rd(pato)} points and risk ratio {rr(pato)}. All intervals are95% confidence intervals. <b>Conclusions.</b> Both adjusted contrasts were near the null but imprecise. Changing the target materially changed participant composition and absolute risks; it did not create compelling evidence of a different relative association. Baseline reports, complete-case selection and unmeasured confounding preclude an established sustained-training causal effect.')
sub('Why this reanalysis')
para('Strength activity and mortality in these NHANES cycles have already been studied. Booker and colleagues used the same2019 linkage but derived activity-specific resistance-training frequency and volume; Boyer and colleagues and Zhao and colleagues provide directly related precedents [1-3]. The contribution here is transparent comparison of estimands and uncertainty, rather than novelty of the medical question.')
para('A sampling weight describes how a participant contributes to a survey population. A propensity weight changes comparability and, for overlap weighting, the target population itself [4-6]. A small hazard-ratio coefficient does not establish a population risk difference, and a precisely balanced overlap population is not the entire adult population. We therefore fixed the design before inspecting study mortality outcomes and made ten-year marginal risks the primary endpoints.')
page()

head('1 | Design, target and estimation')
table([['Component','Frozen specification'],['Eligibility','Age >=20; eligible linkage; interpretable strength frequency; positive MEC weight; complete covariates. Reported inability excluded.'],['Time zero / follow-up','MEC examination to120 months. All surviving analytic participants had at least154 months of recorded follow-up through2019.'],['Exposure','PAD440/PAD460: >=8 versus0-7 sessions in30 days. A sessions-based approximation to twice-weekly guidance, not measured adherence to all guideline components.'],['Outcome / contrast','All-cause death by month120 inclusive. Marginal risk difference and risk ratio; conditional Cox HR as benchmark.'],['Interpretation','Adjusted baseline association within a restricted response domain. An ideal sustained-strategy trial cannot be emulated with one baseline report.']],[110,WIDTH-110])
sub('Covariates and missingness')
para('The outcome-blinded model included age, sex, race/ethnicity, education, income/poverty ratio, smoking, alcohol, BMI, broad aerobic activity, self-rated health, diabetes, hypertension, major cardiovascular disease, cancer and cycle. Natural splines used4 df for age and3 each for BMI and poverty ratio. Realized knots were frozen. Other variables were categorical. Alcohol distinguished lifetime <12 drinks, no past-year drinking and past-year drinking; aerobic activity distinguished neither, moderate only, vigorous only and both. These coarse measures leave residual confounding.')
para('The working DAG recognizes that baseline disease, health and BMI can affect recent exercise and mortality, while also reflecting earlier activity. Their adjustment therefore supports a baseline association, not a total effect of lifetime exercise. Complete-case analysis was selected after a missingness audit; no missing categories or univariate significance screening were used. The PATE target is explicitly the survey-weighted complete-response domain, which may differ from adults excluded for missing information.')
sub('Weights and uncertainty')
para('MEC8YR equaled WTMEC4YR/2 for1999-2002 and WTMEC2YR/4 for2003-2006. Original masked strata and nested PSUs were retained:58 strata,117 PSUs and59 design degrees of freedom. Let d be MEC8YR and e the survey-logistic propensity score. PATE composite weights were d/e for exposed and d/(1-e) for unexposed participants. PATO weights were d(1-e) and de. Separate-arm weighted means estimated risks; PATO targets a covariate distribution tilted by e(1-e). [4-7]')
para('Primary inference used stratified JKn replicates generated before domain restriction, refitting PS coefficients in each replicate with the fixed basis. Intervals used t(59), logit risks, direct risk differences and log risk ratios. Conventional survey-logistic standardization refit both its outcome model and averaging distribution in replicates. Fixed-PS Taylor estimates were a comparator. These methods propagate sampling and PS coefficient uncertainty, not model-choice, nonresponse or linkage uncertainty. [6-7]')
para('The original outcome-blinded design freeze covered the DAG, covariate dictionary, missing-data plan, diagnostics and sensitivity rules. This public edition preserves those scientific choices and records its current file hashes separately; see DESIGN_FREEZE.md. The historical freeze was not prospective public registration or external approval. Target-trial components guide the question, but the sustained-exposure gap remains. [8]','ReportCaption')
page()

head('2 | Analytic sample and selection')
flow=read('participant_flow_design')
table([['Selection step','Retained n','Excluded at step']]+[[r['stage'],integer(r['n']),'--' if not r['excluded_since_previous'] else integer(r['excluded_since_previous'])] for r in flow],[WIDTH-145,65,80])
para('Of870 exposure exclusions after linkage,851 reported inability to perform strength activity; the other19 had unavailable or uninterpretable responses. All complete cases had valid120-month outcomes, so no further outcome exclusions occurred. Excluding inability restricts the population and should not be mistaken for a nationally unrestricted contrast.','ReportCaption')
sub('Table 1. Survey-weighted baseline characteristics')
t1=read('table1_survey')
def value(pop,var,level='Mean'):
 return next(float(r['value']) for r in t1 if r['population']==pop and r['variable']==var and r['level']==level)
rows=[['Characteristic','All','<8 sessions','>=8 sessions']]
rows.append(['Unweighted n',integer(des['n']),integer(des['A0']),integer(des['A1'])])
ev=read('events_by_cycle_exposure');event0=sum(int(r['deaths10']) for r in ev if r['A']=='0');event1=sum(int(r['deaths10']) for r in ev if r['A']=='1')
rows.append(['Deaths by120 months, n',integer(audit['deaths10']),integer(event0),integer(event1)])
items=[('Age, mean years','age','Mean'),('Female, %','sex','Female'),('Non-Hispanic White, %','race','Non-Hispanic White'),('College graduate, %','education','College graduate'),('Income/poverty ratio, mean','pir','Mean'),('BMI, mean kg/m2','bmi','Mean'),('Current smoking, %','smoking','Current'),('Past-year drinking, %','alcohol','Past-year drinking'),('Both aerobic intensities, %','aerobic','Both'),('Poor self-rated health, %','health','Poor'),('Diagnosed diabetes, %','diabetes','Yes'),('Major CVD, %','cvd','Yes'),('Cancer history, %','cancer','Yes')]
for label,var,level in items:rows.append([label]+[f(value(pop,var,level),1) for pop in ['All','A=0','A=1']])
table(rows,[WIDTH-195,65,65,65])
para(f'Weighted exposure prevalence was {pct(des["weighted_prevalence"])}%. The complete-case MEC weight sum was {num(des,"weighted_population")/1e6:.1f} million, a response-domain total, not a newly calibrated estimate of all adults. Full category-level denominators appear in the supplemental CSV tables.','ReportCaption')
para('Complete cases retained82.63% of the18,264 otherwise eligible examined adults. Missingness was largest for alcohol(8.01%), poverty ratio(7.63%) and BMI(2.58%). Excluded respondents had lower observed mean poverty ratio(2.57 versus3.07), more poor health(3.75% versus2.69%) and lower exposure prevalence(18.77% versus21.37%). Original survey weights do not resolve this item-nonresponse selection.')
page()

head('3 | Balance, overlap and target population')
figure('love_plot_summary.png',WIDTH*.85,WIDTH*.85*4.5/7.8,'Figure1. Maximum absolute SMD within each covariate (including spline/dummy columns). The full basis-level diagnostic is retained separately; .10 was the prespecified descriptive threshold.')
para('The largest absolute SMD fell from0.743 under survey weights alone to0.036 under PATE weights and approximately zero under PATO weights. The latter is expected for included model columns from the weighted logistic score equations; exact mean balance is not evidence that unmeasured confounding is absent. The unweighted-PS comparator had maxima0.051 and0.052 and was not selected.')
table([['Weighting','ESS: <8','ESS: >=8','Max within-arm weight / mean'],*[ [label,integer(next(r['ESS'] for r in wd if r['method']==label and r['A']=='0')),integer(next(r['ESS'] for r in wd if r['method']==label and r['A']=='1')),f(max(float(r['max_over_mean']) for r in wd if r['method']==label),1)] for label in ['Survey','PATE','PATO']]],[128,90,90,WIDTH-308])
para(f'Observed propensity scores ranged from0.014 to0.717. The empirical common range was {f(cs["common_min"],3)}-{f(cs["common_max"],3)}; {integer(cs["outside_n"])} participants ({f(cs["outside_weighted_pct"],2)}% of survey weight) lay outside it. No hard support trimming was applied. The maximum exposed PATE multiplier was45.42. Bounded overlap multipliers avoid inverse-propensity explosions, but composite weights still inherit survey-weight variability. ESS describes dispersion, not independent sample size or guaranteed precision.','ReportCaption')
sub('Who receives more representation under PATO?')
target=read('target_populations')
def tv(pop,var,level):return next(float(r['value']) for r in target if r['population']==pop and r['variable']==var and r['level']==level)
table([['Characteristic','Original domain','PATE composite','PATO composite']]+[[label]+[f(tv(pop,var,lev),1) for pop in ['Original complete-case population','PATE composite population','PATO composite population']] for label,var,lev in [('Mean age','age','Mean'),('College graduate, %','education','College graduate'),('Both aerobic intensities, %','aerobic','Both'),('Poor health, %','health','Poor')]], [WIDTH-225,75,75,75])
para('Composite columns pool exposure arms after separate normalization. PATO represents a younger, more educated and more aerobically active population with less poor health. The additional e(1-e)-tilted population table gives a closely corresponding model-based target. Neither PATO nor the complete-case PATE is automatically representative of all US adults.','ReportCaption')
page()

head('4 | Ten-year marginal mortality risks')
table([['Analysis','Risk >=8, %','Risk <8, %','RD, points (95% CI)','RR (95% CI)']]+[[label,pct(r['risk1']),pct(r['risk0']),rd(r),rr(r)] for label,r in [('Survey only',crude),('Logistic standardization',std),('PATE',pate),('PATO',pato)]],[95,60,60,155,WIDTH-370])
para('All analyses use the same15,091 participants and1,980 events. Estimates compare >=8 with <8 sessions/30 days. Risks have corresponding95% CIs in the complete results table. Standardization is a conventional outcome-model reference, not a doubly robust estimator.','ReportCaption')
figure('marginal_risks.png',WIDTH*.84,WIDTH*.84*5/9,'Figure2. Absolute risks with jackknife confidence intervals. The capped PATE result is a prespecified stability check.')
sub('Interpretation of the contrasts')
para(f'The unadjusted survey contrast was {rd(crude)} percentage points, substantially more negative than either propensity-adjusted contrast. This attenuation is consistent with the large measured baseline differences; it does not quantify the amount of confounding removed. PATE gave {rd(pate)} points; its interval permits a modest lower or higher risk. PATO gave {rd(pato)} points, also compatible with either direction. Non-significance does not establish equivalence or absence of an effect.')
para(f'PATO arm risks were around{pct(pato["risk0"])}%, compared with roughly{pct(pate["risk0"])}% for PATE. This illustrates a change of target distribution, not a mortality reduction produced by the choice of weighting algorithm. The PATE and PATO estimates are correlated analyses of the same observations. We did not infer effect heterogeneity from their numerical difference or from comparing significance labels.')
sub('Uncertainty cross-check')
para('Direct weighted ratios and survey means agreed to numerical precision. Jackknife RD standard errors were0.773 and0.511 percentage points for PATE and PATO; fixed-PS Taylor values were0.962 and0.669. Propensity estimation can increase or decrease variance, so treating estimated weights as fixed is not uniformly conservative or anti-conservative. The primary refitting method was chosen before results, not because it produced narrower intervals.')
page()

head('5 | Sensitivity analyses and Cox benchmark')
table([['Sensitivity / target','n / events','RD, points (95% CI)','RR (95% CI)']]+[[('24-month survivor / ' if r['scenario'].startswith('24') else 'No cancer/CVD / ')+r['method'],integer(r['n'])+' / '+integer(r['events']),rd(r),rr(r)] for r in sens]+[['99th-percentile cap / PATE',integer(cap['n'])+' / '+integer(cap['events']),rd(cap),rr(cap)]],[152,77,155,WIDTH-384])
para('The survivor analysis removes297 early deaths and estimates risk during months24-120 among those surviving24 months: an eight-year landmark endpoint, not the original unconditional ten-year risk. Disease exclusion changes the target again. Both PS models were refit without changing their frozen functional forms; balance remained within .10. These restrictions cannot rule out reverse causation and may introduce selection.','ReportCaption')
para(f'The sole prespecified cap was triggered by pre-outcome PATE weight diagnostics. Capping propensity multipliers at their within-arm99th percentile changed PATE RD from {pct(pate["RD"])} to {pct(cap["RD"])} points; exposed ESS increased to {integer(capped["ESS1"])}. The observed estimate was not materially dependent on this cap, but the capped estimator no longer exactly targets PATE. No alternative cutoffs were searched.')
sub('Hazard ratio and proportional hazards')
para(f'The adjusted survey Cox HR was {f(cox["HR"])} (95% CI {f(cox["lower"])}, {f(cox["upper"])}). A prespecified exposure-by-follow-up-period test gave p={f(ph["p"],3)}, with HRs {f(ph["HR_0_60"])} in months0-60 and {f(ph["HR_61_120"])} in months61-120. This did not detect that particular departure from a constant exposure HR. It cannot establish proportional hazards for the entire model.')
figure('ph_schoenfeld_exposure.png',WIDTH*.9,WIDTH*.9*.6,'Figure3. Weighted exposure Schoenfeld diagnostic. This plot is exploratory; its ordinary residual-test p-values do not fully incorporate the complex survey design.')
para('The exploratory global Schoenfeld test was p=0.00019, suggesting non-proportionality somewhere in the adjusted model. Consequently the single benchmark HR requires caution and should not be read as a constant ten-year risk ratio. The fixed-horizon marginal risk analyses remain primary. Two month0 deaths were assigned0.5 months only for Cox bookkeeping; their binary endpoints were unchanged.','ReportCaption')
page()

head('6 | What the findings support')
sub('A target-population result, not a new exercise verdict')
para('The main methodological finding is that good balance and a change of target can coexist with similar relative contrasts. PATO improved the exposed group\'s weight-based ESS and described a population with lower absolute mortality risk, while the unexposed group\'s ESS decreased. There is no general rule that overlap weighting increases every group\'s ESS. The reason to use it is alignment with a scientifically defensible overlap population, not an expectation of a favorable p-value.')
para('PATE and PATO here are conventional causal-estimand labels, but the reported numbers are assumption-dependent adjusted associations. A causal interpretation would require adequate control of common causes, positivity in the relevant target, consistent and well-defined exposure versions, and valid survey/response selection assumptions. Strong balance on measured covariates alone does not meet these conditions.')
sub('Material limitations')
para('<b>Exposure and temporal order.</b> PAD460 records sessions, not necessarily different days. Training load, sets, duration and sustained adherence are unobserved. PAD440 can include push-ups or sit-ups, and the eight-session rule is only an operational approximation. Interview measurements and MEC examination are not perfectly simultaneous. We cannot identify a long-term assigned strength-training strategy from a one-time recent-activity report.')
para('<b>Confounding and reverse causation.</b> Latent frailty, disability short of reported inability, disease severity, diet, healthcare access and health consciousness may influence activity and mortality. Broad aerobic and alcohol measures leave dose confounding. Baseline BMI and disease may be consequences of earlier exercise as well as predictors of current behaviour. The chosen adjustment does not identify the total effect of exercise across the life course. Early-death and disease-exclusion analyses address only limited aspects of these problems.')
para('<b>Selection and generalizability.</b> Restriction to complete cases removed17.37% of otherwise eligible examined participants. Income and health profiles differed between retained and excluded respondents. Original MEC weights do not repair that loss. Excluding reported inability further narrows the target. PATO changes that target again. These historical1999-2006 response domains should not be presented as the present-day US population.')
para('<b>Outcome measurement and inference.</b> Public mortality files preserve final vital status but replace selected follow-up times with synthetic values. This can affect classification near120 months and survival diagnostics. Linkage eligibility and possible misclassification remain relevant. JKn uses masked strata/PSUs and a with-replacement design approximation; it conditions on selected model forms and cannot propagate unknown linkage or nonresponse mechanisms. The Cox PH evidence is mixed and partly exploratory.')
sub('Research contribution and next scientific steps')
para('The project makes its estimands, measurement compromises, population restrictions and uncertainty propagation inspectable. It offers a reproducible worked example linking survey design to propensity-based adjustment and fixed-horizon risk interpretation. Stronger causal or national-population claims would require improved longitudinal exposure measurement and a justified missing-data/selection strategy. Multiple imputation or response weighting would require a separate, justified extension of the analysis.')
para('No conclusion here constitutes individual medical or training advice. The absence of a clear adjusted association in this analysis is not evidence that strength training lacks established benefits or that every plausible mortality effect is zero.')
page()

head('7 | Sources, reproducibility and responsibility')
refs=[
('1','Booker R et al. Associations Between Resistance Training and All-Cause Mortality: NHANES1999-2006. Published online2024.','https://doi.org/10.1177/15598276241248107'),
('2','Boyer W et al. Independent and combined effects of aerobic physical activity and muscular strengthening activity on all-cause mortality. J Phys Act Health.2020;17:881-888.','https://doi.org/10.1123/jpah.2019-0581'),
('3','Zhao G et al. Leisure-time aerobic physical activity, muscle-strengthening activity and mortality risks among US adults: NHANES linked mortality study. Br J Sports Med.2014.','https://stacks.cdc.gov/view/cdc/151712'),
('4','Li F, Morgan KL, Zaslavsky AM. Balancing Covariates via Propensity Score Weighting. JASA.2018;113:390-400.','https://doi.org/10.1080/01621459.2016.1260466'),
('5','Zhou T, Tong G, Li F, Thomas LE, Li F. PSweight: An R Package for Propensity Score Weighting Analysis. R Journal.2022;14(1):282-300.','https://journal.r-project.org/articles/RJ-2022-011/'),
('6','Zeng Y, Li F, Tong G. Moving toward best practice when using propensity score weighting in survey observational studies. arXiv preprint2501.16156, revised2026.','https://arxiv.org/abs/2501.16156'),
('7','Lumley T. Analysis of Complex Survey Samples. J Stat Softw.2004;9(8); survey package4.5 and JKn documentation.','https://doi.org/10.18637/jss.v009.i08'),
('8','Hernan MA, Robins JM. Using Big Data to Emulate a Target Trial When a Randomized Trial Is Not Available. Am J Epidemiol.2016;183:758-764.','https://doi.org/10.1093/aje/kwv254'),
('9','NCHS. NHANES weighting and variance tutorials; cycle-specific official codebooks.','https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx'),
('10','NCHS.2019 Public-Use Linked Mortality Files data dictionary and linkage methodology,2022.','https://www.cdc.gov/nchs/linked-data/mortality-files/index.html'),
('11','Zubizarreta JR. Stable Weights that Balance Covariates for Estimation With Incomplete Outcome Data. JASA.2015;110:910-922. Design/balance motivation; method not implemented.','https://doi.org/10.1080/01621459.2015.1023805')]
for n,title,url in refs:para(f'{n}. {html.escape(title)} <link href="{url}" color="#2166AC">Source</link>.','ReportSmall')
sub('Reproduce and inspect')
para('Run python3 run_project.py from the project root; add --download to fetch or validate official originals. Source-file SHA-256 manifests, exact variable mappings, design history, references, code, complete tables and plots are included. R4.5.2 and survey4.5 were used. The tests independently check outcome parsing, weighted-risk arithmetic, PS-fit agreement, replicate covariance and Cox coefficients. Published result tables are checked against the reference hashes in docs/DESIGN_FROZEN.json.','ReportSmall')
para('Core artifacts: DESIGN_FREEZE.md; docs/PROTOCOL.md; MISSING_DATA_PLAN.md; VARIABLE_DICTIONARY.md; data/download_manifest.csv; outputs/tables/main_results.csv; outputs/tables/sensitivity_results.csv; outputs/tables/validation_results.csv. Supplementary diagnostics include complete-case comparisons, cycle weights, full SMDs, support and weight quantiles.','ReportSmall')
sub('Research status')
para('This methodological reanalysis uses public NHANES data and is not a submitted manuscript or externally peer-reviewed study. References identify sources for the data and methods. The analysis reports adjusted baseline associations; the limitations described above govern their interpretation.','ReportSmall')

(ROOT/'report').mkdir(exist_ok=True)
report=ROOT/'report/Estimands_Matter_Report.pdf'
doc=SimpleDocTemplate(str(report),pagesize=letter,rightMargin=50,leftMargin=50,topMargin=42,bottomMargin=55,title='Estimands Matter',author='')
doc.build(story,onFirstPage=footer,onLaterPages=footer)
(ROOT/'report/Estimands_Matter_Report.md').write_text('\n\n'.join(md))
pages=len(PdfReader(report).pages)
assert pages==8,f'Report has {pages} pages, expected8; inspect layout.'

# Two-page plan, preserving the frozen scientific content in a compact artifact.
plan=(ROOT/'docs/ANALYSIS_PLAN.md').read_text();sections=re.split(r'(?m)^## ',plan)
ps=[]
for i,sec in enumerate(sections):
 if i==3:ps.append(PageBreak())
 if i==0:
  ps.append(Paragraph('Estimands Matter | Analysis plan',styles['ReportH1']))
  ps.append(Paragraph('Scientific design dated 23 September 2026. Public edition; see DESIGN_FREEZE.md for the design history.',styles['ReportCaption']))
  continue
 lines=sec.splitlines();ps.append(Paragraph(html.escape(lines[0]),styles['ReportH2']))
 for block in '\n'.join(lines[1:]).strip().split('\n\n'):
  block=re.sub(r'\*\*([^*]+)\*\*',r'\1',block)
  ps.append(Paragraph(clean(html.escape(block)),ParagraphStyle('PlanBody',parent=styles['ReportBody'],fontSize=9.8,leading=12.7,spaceAfter=6)))
planpdf=ROOT/'docs/analysis_plan.pdf'
SimpleDocTemplate(str(planpdf),pagesize=letter,rightMargin=48,leftMargin=48,topMargin=40,bottomMargin=52,title='Frozen Analysis Plan').build(ps,onFirstPage=footer,onLaterPages=footer)
assert len(PdfReader(planpdf).pages)==2,'Plan must render to two pages'
(ROOT/'logs/pdf_page_check.json').write_text(json.dumps({'report_pages':pages,'plan_pages':2,'text_characters':[len(p.extract_text()) for p in PdfReader(report).pages]},indent=2))
print('Created eight-page report and two-page analysis plan.')
