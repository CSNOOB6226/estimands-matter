# Variable dictionary

Official codebooks are saved in docs/codebooks; exact per-cycle availability is outputs/tables/variable_availability.csv. File names have no suffix in 1999–2000, _B in 2001–2002, _C in 2003–2004, _D in 2005–2006. The data/download_manifest.csv records cycle, official URL, download time, bytes, SHA-256 and codebook URL. HIQ files were downloaded as candidate context but are not used in the frozen model.

| Derived variable | Source | Coding and harmonization |
|---|---|---|
| SEQN | DEMO and all components | Unique participant ID; assert one-to-one joins and distinct across cycles |
| age | DEMO RIDAGEYR | >=20; released years, top-coded at 85 |
| sex | RIAGENDR | 1 male, 2 female |
| race | RIDRETH1 | 1 Mexican American, 2 other Hispanic, 3 non-Hispanic White, 4 non-Hispanic Black, 5 other/multiracial |
| education | DMDEDUC2 | 1 <9th; 2 9th–11th; 3 high school/GED; 4 some college/AA; 5 college graduate. 7/9/missing unknown |
| pir | INDFMPIR | Ratio 0–5; released top-coding at 5; missing remains missing |
| MEC8YR | WTMEC4YR or WTMEC2YR | 0.5 times four-year weight in first two cycles; 0.25 times two-year weight thereafter; require >0 |
| strata, PSU | SDMVSTRA, SDMVPSU | Original strata 1–58; PSU nested within strata; 117 combinations |
| strength_count | PAQ PAD440/PAD460 | PAD440=2 implies zero; PAD440=1 requires PAD460 in 1–300. PAD440=3 unable is excluded, as are 7/9/missing. PAD460 special missing 77777/99999 in first two cycles, 777/999 in last two; no such value is a frequency. Observed valid maxima 300/210/300/210 |
| A | strength_count | >=8 versus 0–7 sessions/30 days; not a complete guideline measure |
| smoking | SMQ020, SMQ040 | <100 cigarettes lifetime (SMQ020=2): never; >=100 and SMQ040=3: former; >=100 and 1/2: current; unknown remains missing |
| alcohol | ALQ lead, ALQ110, ALQ120Q | Lead ALQ100 (1999), ALD100 (2001), ALQ101 (2003/2005); lead=2 and ALQ110=2 defines lifetime <12; valid ALQ120Q=0 no past-year drinking; >0 current. 777/999 unknown. Screen beverage examples change from 4 to 5 oz wine and 1 to 1.5 oz liquor; dose comparability limited |
| bmi | BMXBMI | MEC measured BMI, kg/m²; no arbitrary outlier deletion |
| aerobic | PAD200/PAD320 | Any vigorous/moderate >=10-minute bouts; 1=yes, 2/3=no reported activity; 7/9 missing. Four combinations |
| health | HUQ010 | 1 excellent, 2 very good, 3 good, 4 fair, 5 poor; 7/9 unknown |
| diabetes | DIQ010 | 1 yes, 2 no, 3 borderline; 7/9 unknown |
| hypertension | BPQ020 | 1 yes, 2 no, 7/9 unknown |
| cvd | MCQ160B/C/D/E/F | Any 1 implies CVD; no only if all five are 2; otherwise missing. Conditions: CHF, coronary heart disease, angina, heart attack, stroke |
| cancer | MCQ220 | 1 yes, 2 no; other unknown |
| cycle | SDDSRVYR | Values 1–4 checked against file source |
| ELIGSTAT | Public LMF columns 15–15 | 1 eligible; 2 under18 unavailable; 3 ineligible; only eligibility extracted before freeze |
| MORTSTAT | Public LMF column 16 | 0 assumed alive, 1 assumed deceased; not used pre-freeze |
| PERMTH_EXM | Public LMF columns 46–48 | Months from MEC examination to death or December 31, 2019; may be synthetic for selected records |
| death10 | MORTSTAT, PERMTH_EXM | 1 if deceased by month120 inclusive; 0 if time>=120 and not deceased by120; unknown/time missing stops analysis for investigation |

All harmonizations are implemented in R/01_design_data.R and post-freeze outcome code. Baseline diagnosis variables are questionnaire diagnoses, not lab-confirmed disease. Raw data are never edited.
