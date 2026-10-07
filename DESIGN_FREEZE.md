# Design freeze — FROZEN

Historical freeze UTC: 20260924T031318Z. The original working project recorded an outcome-blinded design snapshot at this time. No individual death outcomes or study exposure–mortality estimates were accessed before that snapshot. Published literature was reviewed for design context.

The scientific specification is described in docs/PROTOCOL.md, supported by docs/DAG.md, docs/ANALYSIS_PLAN.md, MISSING_DATA_PLAN.md and VARIABLE_DICTIONARY.md. Selected PS formula and spline basis are in data/derived/design_objects.rds after the design stages run. All balance/overlap/missingness diagnostics and numerical choices were determined without study outcomes.

Primary population: 15,091 complete-case, exposure-eligible adults; PATE and PATO composite formulas, JKn PS-refitting uncertainty, Cox/PH diagnostics and three conditional/prespecified sensitivities are fixed in the protocol. Maximum PATE |SMD|=.0362; PATO approximately zero. No additional outcome-driven model selection.

The original sealed archive, design_freeze_20260924T031318Z.tar.gz, remains in the working project and is not included in this repository. The archive was created exclusively and made read-only. Its historical contents have not been replaced by the publication copy.

docs/DESIGN_FROZEN.json is the current integrity manifest for this publication copy. It verifies the distributed analysis files and documents; it is not the original sealed-archive manifest. Public-document editing and portability updates to the entry points retain the scientific parameters and results and do not establish a new outcome-blinded freeze.

The historical freeze is an internal design record rather than public preregistration, institutional review, or external scientific review. Complete-case generalizability, inability exclusions, broad behavioural measures, temporal ambiguity, unmeasured confounding, and synthetic follow-up times remain limitations documented in the protocol and missing-data plan.
