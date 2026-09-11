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

## Perforation cost, now wired into the cost engine

Both arms now carry an expected perforation-management cost, applied
identically to standalone and combined: `iud_perforation_risk_baseline`
(1.4 per 1,000 LNG-IUD insertions, Heinemann et al. 2015, EURAS-IUD, a
61,448-woman prospective cohort, directly verified) times a
HCUPnet-derived retrieval-episode cost (via Dottino et al. 2016's Table
2, inflation-adjusted from 2015 dollars). Previously this risk sat in
`config/model_parameters.csv` completely unused. Since the added cost is
identical for both arms, it raises both strategies' totals by the same
amount and does not change the incremental gap between them.

This was prompted by a real question worth checking rather than assuming:
if a perforation happens during a combined (already-anesthetized,
already-open) bariatric-surgery insertion, could it be recognized and
managed in the same operative setting, avoiding a whole separate
retrieval surgery? A specific supporting statistic (only 8.4% of
perforations recognized at the time of insertion) turned out, on direct
verification, not to exist in either the primary EURAS-IUD paper or its
5-year extension study -- likely a search-synthesis error, in the same
spirit as an earlier checked-and-rejected "3.06x odds ratio" claim in
this project. What IS confirmed directly: the extension study found
"approximately one third of perforations are detected 12 months after
insertion," i.e. delayed diagnosis is common, and bariatric surgery
itself accesses the stomach, not the pelvis, so being in the OR doesn't
guarantee anyone is looking at the uterus regardless of timing.

Rather than build a differential on an unverifiable percentage, the
question can be bounded without it: the entire `expected_perforation_cost`
applied to each arm is $38.71. That's the absolute most the combined
arm's cost could drop under ANY same-setting-recognition mechanism, even
in the impossible best case of 100% immediate recognition at zero
marginal cost -- a 12.7% cut to the current base case's $304.73 gap (see
"Two surgeons, real coordination cost" and "Facility-setting professional
fee" below for the two corrections that moved this gap after this section
was first written), leaving $266.02 even then. Real mechanism, too small
to matter here regardless of the exact percentage, which is why it stays
a documented, deliberately deferred refinement rather than a built one;
see `iud_perforation_management_cost`'s notes and `docs/data_sources.md`,
"Perforation cost wired into the cost engine," for the full reasoning.

## One-way sensitivity analysis

`R/sensitivity_deterministic.R` / `analysis/04_sensitivity_analysis.R`
sweeps every cost-engine parameter that has a real, sourced low/high
range across that range (one at a time, holding everything else at base
case) and measures how much it moves the headline result: the incremental
cost gap between the combined and standalone arms ($304.73 in the current
base case; this was $196.39 when this analysis was first built, moved to
$335.29 after "Two surgeons, real coordination cost" below added a real
professional fee and a scheduling-coordination cost to the combined arm,
then back down to $304.73 after "Facility-setting professional fee"
below corrected that same professional fee to a lower, facility-specific
rate -- see both sections for why). This replaces guesswork about where
further data-hunting is worth the effort with an actual ranking.

**The result reorders priorities.** The two biggest drivers by far are
`direct_room_cost_per_minute` (swings the gap by up to $328) and
`combined_arm_added_minutes` (up to $318) -- the OR-time assumptions,
not the device cost. The still-unverified GPO device-acquisition cost
($537-$600, the subject of a whole earlier verification effort that
ultimately failed) swings the gap by only about $7, because it mostly
cancels between the two arms; the tiny residual comes from a real,
non-obvious channel this analysis surfaced -- device cost also appears
inside the expected-replacement-cost formula, which is multiplied by a
*different* expulsion probability in each arm, so it does not cancel
perfectly the way a naive read of the incremental-cost principle would
suggest. `iud_perforation_risk_baseline`, by contrast, truly does wash
out to zero: it has no such differential channel. `iud_insertion_
professional_fee`'s own swing has moved twice for two different reasons:
$45 originally (standalone-only), down to about $5 once the same fee
applied to both arms directly (mostly canceling, like device cost), then
back up to about $24 once the combined arm's own fee became a *fraction*
of this parameter (the facility ratio) rather than the same dollar
amount -- varying the office rate now moves combined's fee by less than
it moves standalone's, so it no longer cancels as cleanly. Every OTHER
swing value is unchanged by both the coordination-cost and facility-fee
corrections, since neither changes the DIFFERENCE between gap_at_high and
gap_at_low for a parameter neither of them reads from -- a mechanical
property of the `abs(gap_at_high - gap_at_low)` calculation, not a
coincidence.

**The analysis also surfaced a real gap by trying to include something
and being unable to, and that gap is now closed.** `iud_expulsion_
probability_combined` -- the single number Masten et al. 2024 identified
as most responsible for the combined arm's cost disadvantage -- had no
sourced low/high range in `config/model_parameters.csv` at all, only a
point estimate, so the first run of this analysis could not sweep it.
Rather than invent a range, the primary paper's full text (PMCID
PMC11706623, open access) was read directly for the raw numbers behind
its headline 16.3%: 7 expulsions out of 43 combination-case placements.
An exact Clopper-Pearson 95% binomial confidence interval computed
directly on that proportion (6.81%-30.70%) is now this parameter's
low/high bound, deliberately not derived from the paper's adjusted-odds-
ratio CI, which is adjusted for covariates this project's unadjusted
point estimate is not. This parameter ranks third (swing $185), just
behind the two OR-time parameters -- and, reassuringly, even at the low
end of that wide interval (6.81% expulsion), the combined arm still costs
more than standalone ($231 gap, smaller than the current $305 base case
but not reversed), so the model's directional conclusion is robust to
this parameter's real uncertainty. `patient_time_opportunity_cost_per_visit`
remains an open gap of the same
kind (used by the cost engine, no sourced range yet).

## Two surgeons, real coordination cost

Two real gaps closed after the model owner clarified this institution's
actual staffing workflow (2026-09-10): **the gynecologist places the IUD,
not the bariatric surgeon.**

First, `combined_requires_separate_professional_fee` -- previously
defaulted to FALSE as a conservative placeholder, chosen only because the
real staffing model hadn't been confirmed -- now defaults to TRUE. Two
different physicians performing distinct professional services in the
same operative session each bill their own professional component; there
was never a structural reason to assume this fee gets bundled away, only
an absence of confirmation. The combined arm now pays
`iud_insertion_professional_fee` ($116.08) directly, the same as
standalone.

Second, a genuinely new cost category: **scheduling-coordination cost.**
Combining two procedures means aligning two different surgeons' OR time,
and that coordination is real administrative labor the standalone arm
never needs (it's a single physician's own routine office visit). The
model owner's estimate -- each surgeon's own scheduler spends about 30
minutes coordinating the combined case (2 schedulers x 30 minutes = 60
minutes total) -- is the same estimate already used for the analogous
combined-visit coordination cost in the sibling `emb_colonoscopy`
project's model, confirmed by reading that project's own parameter file
directly rather than re-guessed from scratch. Priced using a real wage
rate: O*NET OnLine (the DOL/BLS-funded site that republishes BLS OEWS
data without blocking automated access, unlike bls.gov itself, which
returned HTTP 403 when checked directly this session) reports a $22.08/hour
median wage for SOC 43-6013, Medical Secretaries and Administrative
Assistants (2025 BLS data) -- the same occupational code and source
already cited in the sibling project. 60 minutes at that wage is $22.82
in reference-year dollars, added to the combined arm only.

**Combined effect at the time this was built: the base case gap nearly
doubled**, from $196.39 to $335.29. Standalone unchanged at $868.63;
combined rose from $1,065.02 to $1,203.92 ($116.08 professional fee +
$22.82 coordination cost). This was the single largest revision to the
model's headline result up to that point, and it came from confirming a
real staffing fact, not from any new literature source -- a reminder
that institutional workflow assumptions can matter as much as published
parameters. Mutation-tested; see `docs/testing_philosophy.md`. (The
$116.08 professional-fee figure was itself corrected shortly afterward --
see "Facility-setting professional fee" next -- so the CURRENT base case
gap is $304.73, not $335.29; that correction doesn't reverse anything
here, it refines the combined arm's own fee to a lower, facility-specific
rate.)

## Facility-setting professional fee

A follow-up question surfaced a second real correction the same day:
does CPT 58300 actually get billed the same regardless of where it's
performed? No. CMS's own July 2026 Relative Value File (RVU26C) gives
CPT 58300 two different total RVUs depending on place of service, even
though Medicare itself doesn't pay for the code (status N):

| Component | Non-facility (office) | Facility (OR) |
|---|---|---|
| Work RVU | 0.98 | 0.98 |
| Practice-expense RVU | 2.07 | 0.22 |
| Malpractice RVU | 0.11 | 0.11 |
| **Total RVU** | **3.16** | **1.31** |

The office rate bundles in practice-expense overhead (staff, room,
supplies) the physician's own practice bears; the facility rate strips
almost all of that out, because the facility -- here, the bariatric
surgery OR -- bills its own overhead separately, which
`direct_room_cost_per_minute` already prices. Charging the combined
arm's own insertion the SAME $116.08 the standalone arm's office visit
uses was therefore double-counting overhead. Applying the real
facility/non-facility ratio (1.31 / 3.16 = 0.4146,
`iud_insertion_professional_fee_facility_ratio`) gives the combined arm
a facility-equivalent fee of $48.13 instead -- computed as a RATIO
applied to `iud_insertion_professional_fee` at compute time, not a
separately-stored dollar figure, so a scenario that overrides the office
rate (like `medicaid_illustrative`) automatically produces a consistent
facility-equivalent value without a second override to keep in sync.

The facility rate's lower practice-expense RVU also means it excludes
disposable supplies the office rate bundles in. Checked directly: CMS's
CY2026 Direct Practice Expense Inputs file (`CMS-1832-F`) lists three
supply items for CPT 58300 (pack, pelvic exam; pack, minimum
multi-specialty visit; povidone antiseptic solution), all priced into
the office rate (`nf_quantity > 0`) but explicitly excluded from the
facility rate (`f_quantity = 0`) -- $37.39 total. Since the OR facility
itself is never separately charged under this model's incremental-cost
principle, these supplies are a genuine incremental cost for the
combined arm specifically (`iud_insertion_disposable_supply_cost`), not
a double-count.

**This exact mechanism -- and exactly this fix -- already exists in the
sibling `emb_colonoscopy` project**, for its own analogous procedure
(CPT 58100, endometrial biopsy): `emb_office_professional_cost` /
`emb_office_professional_cost_facility` and `emb_disposable_supply_cost`,
confirmed by reading that project's `config/model_parameters.csv` and
`docs/data_sources.md` directly. The one structural difference: CPT
58100 IS Medicare-covered, so that project could split its professional
fee by place of service using live CMS claims data (an actual observed
facility-vs-office payment gap, ~38%). CPT 58300 is not covered, so no
claims-volume split exists -- this project's facility fee is a RVU-ratio
proxy applied to a real anchor price (Denver Health's cash price), not
itself a directly observed facility charge. Flagged provisional for
that reason.

**Net effect: the base case gap moved from $335.29 to $304.73**
(standalone unchanged at $868.63; combined fell from $1,203.92 to
$1,173.36 -- the $67.96 professional-fee reduction outweighing the
$37.39 supply-cost addition). Mutation-tested; see
`docs/testing_philosophy.md`.

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
