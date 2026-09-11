# iud_bariatric

A reproducible R cost-minimization model comparing two ways to place a
levonorgestrel-releasing intrauterine device (LNG-IUD, e.g. Liletta, Mirena,
Kyleena) in a reproductive-age patient undergoing bariatric surgery:

1. **Standalone insertion** -- a separate outpatient office visit, before or
   after the surgery, with its own evaluation-and-management fee, insertion
   professional fee (CPT 58300), and device cost.
2. **Combined insertion** -- the IUD is placed in the operating room at the
   time of the already-scheduled bariatric surgery, under the anesthesia the
   patient is already receiving.

This repository follows the same conventions and evidentiary discipline as
[`emb_colonoscopy`](https://github.com/mufflyt/emb_colonoscopy), a sibling
cost-minimization model built on the identical logic. That project compares
three ways to obtain an endometrial biopsy in women with Lynch syndrome (a
hereditary condition requiring periodic endometrial-cancer surveillance):
a standalone office biopsy, an operative dilation and curettage (D&C), or
an endometrial biopsy performed *during* a surveillance colonoscopy the
patient is already having, under the sedation the colonoscopy already
requires, rather than as its own separate procedure. That third option
("EMB at the time of colonoscopy") is the same structural idea this
project applies to a different device and a different host procedure:
piggy-back a minor procedure onto anesthesia/sedation the patient is
already receiving, and ask whether that actually saves money once every
real incremental cost, not just the obvious ones, is counted. Every
parameter in `config/model_parameters.csv` carries a source citation, an
evidence tier, and a `provisional` flag, and no dollar figure enters the
model without a traceable primary source.

## Why this question, and why it's harder than the colonoscopy analog

The Lynch-syndrome model could lean almost entirely on Medicare data, because
its patient population (women old enough for Lynch-syndrome endometrial
surveillance) overlaps heavily with the Medicare population. That shortcut
does not work here:

- **Medicare does not price this at all.** CPT 58300 (IUD insertion) carries
  an "N" (non-covered) status on the Medicare Physician Fee Schedule --
  contraceptive devices are a statutory Medicare exclusion. The CMS ASP and
  OPPS NDC-HCPCS drug-pricing crosswalks (checked directly, July 2026 files)
  contain zero entries for the levonorgestrel-IUD HCPCS codes (J7296-J7301).
  Reproductive-age bariatric-surgery patients are not the Medicare
  population anyway.
- **The device is a hospital-supplied inpatient pharmacy item, not a
  separately billed drug claim.** Bariatric surgery is typically performed
  inpatient. When the IUD rides along on that same admission, its cost is
  bundled into the hospital's MS-DRG payment (confirmed directly in Denver
  Health's own published price-transparency file: for CPT 58300 and the
  device J-codes, almost every payer's inpatient negotiated rate is null --
  not separately paid at all). There is no NADAC or Medicare ASP price for
  it either, since NADAC only covers retail-pharmacy-dispensed drugs.
- **No published literature quantifies the added operating-room time** for
  IUD insertion specifically at the time of bariatric surgery. The closest
  analogs (IUD insertion at cesarean delivery, IUD placement under general
  anesthesia as its own case) are used as general-population evidence, the
  same way the Lynch model borrowed non-Lynch-specific literature for
  parameters no Lynch-specific study had measured.

The right cost lens here is the **hospital's own acquisition cost** for the
device (what it actually pays its pharmacy/GPO or 340B contract), not a
Medicare allowed amount, since there is frequently no separate reimbursement
to net against at all.

## Clinical precedent, and why combined placement isn't a free lunch

Combined bariatric-surgery IUD placement is not a hypothetical this project
invented: Hillman et al. (*J Womens Health* 2011) describe 23 of 25
adolescent bariatric-surgery patients (92%) having a levonorgestrel IUD
placed at the time of surgery, under the same anesthesia, specifically
because it's more convenient and avoids a difficult standalone insertion in
a nulliparous patient. Thornton et al. (*Contraception* 2021), studying
postoperative contraceptive choice in 460 bariatric patients, explicitly
names "coordinating combined bariatric and permanent contraception
procedures" as an unaddressed direction for future work, without studying
it themselves. That's the gap this project fills: not whether combined
placement happens (it does), but whether it's actually cheaper once every
real cost is counted.

It is not automatically cheaper. Masten et al. (*J Pediatr Adolesc Gynecol*
2024) found that combined bariatric-surgery placement carries a
significantly *higher* 12-month expulsion rate than standalone placement
(16.3% vs. 5.6%, adjusted OR=3.23, P=.024) in a cohort of 588 adolescents
and young adults. An expelled device has to be replaced, at full cost. This
model prices that risk into both arms (see `iud_expulsion_probability_standalone`/
`_combined` in `config/model_parameters.csv`), and it's a big part of why
the current base case finds combined placement *more* expensive than
standalone, the opposite of the sibling Lynch-syndrome project's finding.
See `docs/data_sources.md` for the full citation trail.

## Repository layout

- `config/model_parameters.csv` -- every cost-model input, one row per
  parameter, with `source`, `evidence_tier` (A = direct/primary, B =
  adjacent primary source, C = general-population literature, D =
  placeholder), and `provisional` columns.
- `config/cancer_prevention_parameters.csv` -- inputs for the separate
  cancer-prevention estimate (see "Cancer-prevention estimate" below),
  same column schema.
- `R/` -- parameter loading/validation, the two-strategy cost engine, the
  cancer-prevention estimate, and (as they're added) sensitivity-analysis
  and plotting helpers.
- `analysis/` -- numbered driver scripts that run the model and save tables.
- `tests/testthat/` -- unit and regression tests; run via `Rscript tests/testthat.R`.
- `docs/data_sources.md` -- the full evidence trail for every parameter,
  including dead ends (sources checked and rejected, and why).
- `tables/`, `figures/` -- generated outputs (git-ignored until real results
  exist worth version-controlling).

## Status

Scaffolding stage, but the cost engine is now reasonably complete for a
first pass: both arms carry an expected device-replacement cost for
expulsion (Masten et al. 2024), the standalone arm carries an expected
escalation cost for outright insertion failure (Saito-Tom et al. 2015),
OR/anesthesia costs are inflation-adjusted to a common reference year
(`R/inflation.R`), and both arms report a societal patient-time/travel
add-on alongside the healthcare-sector total (Ray et al. 2015, reused from
the sibling project). Every new piece of blocking logic has been
mutation-tested (see `docs/testing_philosophy.md`).

Two general-population proxies were strengthened with corroborating,
more-relevant evidence (2026-09-11): `combined_arm_added_minutes` now has
a real bariatric-surgery-context data point (a concomitant-salpingectomy
timing study, landing almost exactly on the existing 10-minute estimate),
and `iud_expulsion_probability_standalone`'s upper bound now uses a real
adult, obesity-specific expulsion rate instead of an assumed range,
partially closing the gap that its paired-comparison source (Masten 2024)
is an adolescent cohort. A separate specific claim (a "3.06x odds ratio
for class III obesity") was checked directly against its purported source
and found not to exist there; discarded rather than used.

Two real data gaps remain unresolved despite direct attempts: the GPO
device-acquisition cost ($537-$600) could not be verified from its only
found source, and whether the model's anchor hospital is actually
340B-registered could not be confirmed against HRSA's public database
(see `docs/data_sources.md`). No PSA/deterministic sensitivity analysis,
manuscript, or figures yet.

A Medicaid payer scenario (`analysis/02_scenario_analysis.R`) is now
built, using real, directly-confirmed Colorado Medicaid rates for both the
office-visit component ($77.39) and the insertion fee ($58.65, CPT 58300;
found 2026-09-10 by parsing every worksheet of Colorado's own fee-schedule
workbook, not just the one sheet its PDF export shows). Researching it
surfaced something directly relevant: Colorado Medicaid already has a
real carve-out policy that separately pays for a LARC device inserted
during an otherwise-DRG-bundled inpatient stay, exactly the structural
problem this project's own Denver Health data independently found, just
scoped to delivery admissions rather than bariatric surgery. The scenario
models what happens if that same mechanism were extended to bariatric
surgery: the combined arm's cost disadvantage gets worse, not better.

Two more real hospitals' price-transparency files (NYU Langone, UCLA)
were checked (2026-09-10) to see whether Denver Health's numbers are
representative. They are: Denver Health's cash price for the IUD device
is the low end of a real $837.67-$2,907.82 range across the three
hospitals, not an outlier, which supports the model's use of GPO/340B
acquisition cost, well below any of these charge prices, as the
conservative base-case driver rather than an understatement. See
`docs/data_sources.md` for the full breakdown, including why NYU's CPT
58300 price could not be used as a second professional-fee data point.

A fourth and fifth data point (Colorado Medicaid's own physician-
administered-drug fee schedule, and CMS's national State Drug Utilization
Data for 2025) reinforce the same conclusion from a completely different
angle, real Medicaid reimbursement rather than hospital charges: Colorado
pays $931.73-$978.32 for this device and the national 2025 Medicaid
average across 45,988 reimbursed units is $857.54, both landing in the
same $840-$980 band as Denver Health and UCLA. Reimbursement rates aren't
used to change the model's acquisition-cost parameters (a payer's
reimbursement doesn't change what a hospital pays its supplier), but as a
fourth and fifth independent source agreeing on the same band, they make
NYU's much higher charge price look like the outlier, not the norm.

## Cancer-prevention estimate

A separate module (`R/cancer_prevention.R`,
`config/cancer_prevention_parameters.csv`,
`analysis/03_cancer_prevention.R`) estimates how many endometrial cancer
cases an LNG-IUD prevents in bariatric-surgery patients. This is
deliberately NOT part of the cost-minimization model above: that model
assumes the device is equally effective once placed regardless of arm, so
it has no cancer-outcome parameter to begin with. This answers a
different question the sibling model doesn't address.

The central modeling problem: the one existing cost-effectiveness study
of this exact intervention (Dottino et al. 2016, *Obstet Gynecol*) was
built for a 50-year-old obese woman with no other treatment, not a
reproductive-age patient about to lose a large amount of weight from
bariatric surgery for reasons that have nothing to do with the IUD.
Applying Dottino's baseline risk directly would credit the IUD for
protection that surgery itself already provides. This module corrects
for that by layering two real, separately-measured effects
multiplicatively: bariatric surgery's own independent risk reduction
(Schauer et al. 2019, *Ann Surg*, a matched cohort of 22,198 actual
bariatric-surgery patients vs. 66,427 non-surgical severely-obese
controls, HR 0.50, 95% CI 0.37-0.67) and the IUD's own additional
reduction on top of that (Soini et al. 2014, *Obstet Gynecol*, a
93,843-woman Finnish national cohort, standardized incidence ratio 0.50,
95% CI 0.35-0.70, independently verified directly from the primary
source rather than taken secondhand from Dottino's table, and
corroborated by a 2021 update, Bernard et al., *Gynecol Oncol*, using the
same figure).

At base-case values: per 1,000 bariatric-surgery patients who receive an
IUD, an estimated 7.5 endometrial cancer cases are prevented (BMI 40+
baseline, number needed to treat approximately 133) or 4.75 cases (BMI
30+ baseline, NNT approximately 211). Two limitations are flagged
explicitly rather than glossed over: treating the two effects as
independent and multiplicative is a standard but unverified simplifying
assumption (no study has measured both together), and the estimate
applies the IUD's incidence ratio to a LIFETIME baseline risk rather than
a duration-corrected one, making it a likely-optimistic upper bound, not
a final answer. See `docs/data_sources.md`, "Cancer-prevention estimate,"
for the full citation trail and reasoning.
