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
(see `docs/data_sources.md`). Both a one-way deterministic sensitivity
analysis and a probabilistic (Monte Carlo) sensitivity analysis are now
built (see "One-way sensitivity analysis" and "Probabilistic sensitivity
analysis" below); no manuscript or figures yet.

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
marginal cost -- a 7.9% cut to the current base case's $490.78 gap (see
"Two surgeons, real coordination cost," "Facility-setting professional
fee," "Preop consent visit for the combined arm," and "Postop results-
discussion cost" below for the four corrections that moved this gap
after this section was first written), leaving $452.07 even then. Real
mechanism, too small
to matter here regardless of the exact percentage, which is why it stays
a documented, deliberately deferred refinement rather than a built one;
see `iud_perforation_management_cost`'s notes and `docs/data_sources.md`,
"Perforation cost wired into the cost engine," for the full reasoning.

## One-way sensitivity analysis

`R/sensitivity_deterministic.R` / `analysis/04_sensitivity_analysis.R`
sweeps every cost-engine parameter that has a real, sourced low/high
range across that range (one at a time, holding everything else at base
case) and measures how much it moves the headline result: the incremental
cost gap between the combined and standalone arms ($490.78 in the current
base case; this was $196.39 when this analysis was first built, moved to
$335.29 after "Two surgeons, real coordination cost" below added a real
professional fee and a scheduling-coordination cost to the combined arm,
down to $304.73 after "Facility-setting professional fee" below corrected
that same professional fee to a lower, facility-specific rate, up to
$430.13 after "Preop consent visit for the combined arm" below added a
fourth real cost, then up again to $490.78 after "Postop results-
discussion cost" below added a fifth -- see all four sections for why). This replaces guesswork about where
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
more than standalone ($417 gap, smaller than the current $491 base case
but not reversed), so the model's directional conclusion is robust to
this parameter's real uncertainty. `patient_time_opportunity_cost_per_visit`
remains an open gap of the same
kind (used by the cost engine, no sourced range yet).

## Probabilistic sensitivity analysis

The one-way analysis above answers "which single parameter matters
most, swept alone." It doesn't answer "how uncertain is the headline
gap once every parameter varies at once, together, the way real-world
uncertainty actually works." `R/sensitivity_probabilistic.R` /
`analysis/05_probabilistic_sensitivity_analysis.R` runs a 10,000-draw
Monte Carlo simulation over the exact same ten parameters swept above,
sampling each from a distribution family already present in `config/
model_parameters.csv`'s own `distribution` column (`triangular`, fit
directly from low/base/high; `gamma`, fit by the standard
health-economic-PSA method of moments from a mean and an implied 95%
CI) -- metadata that existed in the schema but had no consumer until
now. The two probability parameters tagged `fixed` rather than given a
distribution family (`iud_expulsion_probability_combined`,
`iud_perforation_risk_baseline`) are correctly held constant, not
silently randomized; see the file's own docstring for why.

**Result:** against a base case of $490.78, the simulated gap has a
mean of $477.82 and a 95% simulation interval of $304.49 to $736.26.
**Standalone was cheaper in 100% of the 10,000 draws.** The
standalone-vs-combined conclusion is not an artifact of any single
point estimate -- it holds across the full joint uncertainty this
project's own sourced parameter ranges describe. (Scope note: like the
one-way analysis, this targets `expected_total_cost`'s gap only, not
`expected_cost_per_referred_patient` -- `cancer_prevention_parameters`
is held fixed, since several of its own parameters have no sourced
low/high range to sample from yet.)

Mutation-tested; see `docs/testing_philosophy.md`.

## Does the model capture the opportunity cost of a displaced case?

A direct question worth answering plainly: if the combined arm's extra
10 minutes of OR time means the surgical team can't fit in another
bariatric case (or another gynecologic procedure) that day, is that
lost-case cost priced anywhere in this model? **No.**
`direct_room_cost_per_minute` ($20.90/minute, 2014 dollars) is
literally Childers & Maggard-Gibbons's (*JAMA Surg* 2018;153(4)) own
"direct cost" figure for OR time -- staff wages, supplies, the
resources actually consumed by those 10 minutes -- and that paper is
explicit that a displaced case's lost revenue is a separate, additional
cost they deliberately excluded from that figure: "If saving time
allows the OR to schedule an additional case, this potential revenue
should be included as a cost. Opportunity costs vary and are likely to
be highest for short operations... where scheduling additional cases is
more likely. However, opportunity cost requires a case to be
profitable, which, in many circumstances, depends primarily on payer
mix."

**Checked whether a real, generalizable dollar figure for this exists
anywhere in the literature, rather than assuming it doesn't.** It
doesn't, and the literature's own reason why is itself informative.
Macario A, Dexter F, Traub RD. "Hospital profitability per hour of
operating room time can vary among surgeons." *Anesth Analg.*
2001;93(3):669-675. 2,848 elective cases across 94 surgeons at Stanford:
contribution margin per OR-hour was **negative for 26% of cases**, with
large surgeon-to-surgeon variability, concluding hospitals should
"increase the hours of lucrative cases, rather than encourage surgeons
to do more and more cases" -- i.e. this quantity is inherently
case-mix- and payer-mix-specific, not a stable rate. Saporito A, La
Regina D, Perren A, et al. "Contribution margin per hour of operating
room to reallocate unutilized operating room time: a cost-effectiveness
analysis." *Braz J Anesthesiol.* 2023;73(3):243-249. A more recent,
different-country cohort (Swiss, ten procedure types) confirms the same
underlying variability and only reports portfolio-level reallocation
revenue, not a single per-minute rate usable here. No study isolates
this figure for bariatric surgery or an endoscopy suite specifically.

**Not built in, for a real reason rather than an oversight:**
fabricating a single point estimate from a quantity the field's own
primary literature says is negative over a quarter of the time and
varies enormously by surgeon and payer mix would be exactly the kind of
false precision this project's parameter discipline exists to avoid.
One real asymmetry worth flagging: Childers's own paper says this
matters most for SHORT, high-throughput procedures where "scheduling
additional cases is more likely" -- a description that fits
colonoscopy (15-30 minute slots) far better than bariatric surgery
(60-120+ minute cases, 1-3 per OR day, where a 10-minute overrun is far
less likely to literally bump an entire additional case). Checked
directly: the sibling `emb_colonoscopy` project has the identical gap
(same Childers direct-cost figure, no opportunity-cost parameter
either), documented in its own `docs/data_sources.md`.

**Follow-up: real, payer-specific data was found and a bounded estimate
was built (2026-09-12), not wired into the base case.**
`R/opportunity_cost_sensitivity.R` computes a Medicare-payer
contribution margin directly from two primary sources: CMS's own FY2026
IPPS payment for MS-DRG 621 (routine bariatric surgery, no
complications), $10,976.27, computed from the actual downloaded CMS
Table 5 relative weight and Final Rule rates; minus Ng et al. 2023's
national blended hospitalization cost (HCUP cost-to-charge-ratio
methodology, 687,866 patients), $11,711.70. **The result is a NEGATIVE
margin, -$735.43** -- Medicare-payer bariatric cases lose money on
average nationally, consistent with the field's own literature (Macario
et al. found margin negative in 26% of cases generally). Spread across
a typical case's blended 110.6 minutes (Young et al. 2015, NSQIP,
n=24,117) as a linear-share approximation, the combined arm's 10-minute
add-on implies an opportunity cost of **-$66.49** (i.e. no real added
cost -- if anything, a small saving), with a range of -$382.25 to
+$168.59 across Ng et al.'s own cost IQR. This is representative of
roughly 83% of Denver Health's actual payer mix (Medicare, Medicaid,
and uninsured combined, per an AHA case study citing Colorado's 2023
Hospital Expenditure Report); the remaining ~17% (commercial) is not
quantified, since no verified bariatric-specific commercial rate was
found anywhere. Still not added to `expected_total_cost`: this is a
linear approximation of what is really a discrete threshold effect (see
the file's own docstring), and the honest result is that even a
best-effort, real-data attempt finds this cost is small or negative for
most of this hospital's actual case mix -- reinforcing, with real
numbers this time, why it was left out rather than guessed at. Run
`Rscript analysis/06_opportunity_cost_sensitivity.R` to reproduce.
Mutation-tested; see `docs/testing_philosophy.md`.

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
$116.08 professional-fee figure was itself corrected shortly afterward,
and a further preop-visit cost was added after that -- see "Facility-
setting professional fee" and "Preop consent visit for the combined arm"
next, and "Postop results-discussion cost" after that, for all of
them -- the current gap is $490.78.)

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

**Net effect at the time this was built: the base case gap moved from
$335.29 to $304.73** (standalone unchanged at $868.63; combined fell
from $1,203.92 to $1,173.36 -- the $67.96 professional-fee reduction
outweighing the $37.39 supply-cost addition). Mutation-tested; see
`docs/testing_philosophy.md`. (A further preop-visit cost was added
after this, and a postop-discussion cost after that -- see next and
"Postop results-discussion cost" below -- so the current gap is
$490.78, not $304.73.)

## Preop consent visit for the combined arm

A survey of what else the sibling `emb_colonoscopy` project had already
solved (prompted by the user asking "what else can we borrow") turned up
a fourth real, missing cost: that project's structurally identical
combined arm (EMB during colonoscopy) charges a separate preop office
visit, on the reasoning that a patient cannot meaningfully consent to a
procedure while already under anesthesia for a different one. Our
combined arm charged **$0** for an office visit -- the gynecologist, who
places the IUD and is not the bariatric surgeon (see "Two surgeons"
above), had no visit cost at all for counseling/consenting the patient
beforehand.

New structural toggle `combined_requires_preop_office_visit` (TRUE by
default, mirroring the sibling's `combined_requires_preop_office_visit`
exactly) now adds `iud_preop_office_visit_cost` to the combined arm:
$125.40, CPT 99214 (established patient, moderate complexity -- a higher
level than the CPT 99213 standalone's own routine insertion visit uses,
reflecting that this is specifically a surgical-consent/risk-discussion
encounter). Reused directly from the sibling project's own verified
extraction (`dnc_preop_clinic_visit_cost`, real 2024 OB/GYN CMS claims
data) rather than re-pulled, since the underlying claim -- a real OB/GYN
level-4 E/M visit cost -- transfers regardless of which procedure
prompted the consent discussion. Checked directly: CPT 58300's own CMS
global-surgery period is "XXX" (the global-surgery concept doesn't apply
to this code at all), so there is no bundling rule that would fold this
visit into the procedure's own fee.

**Net effect at the time this was built: the base case gap moved from
$304.73 to $430.13** (standalone unchanged at $868.63; combined rose
from $1,173.36 to $1,298.76). Mutation-tested; see
`docs/testing_philosophy.md`. (A postop discussion cost was added the
same day -- see next -- so the current gap is $490.78, not $430.13.)

## Postop results-discussion cost

One more real gap, surfaced by the same question that produced the
preop visit above: IUD placements do not get a formal postop office
visit (confirmed directly against current CDC guidance -- see "IUD
string checks" below), so nothing in the model priced the time it
actually takes the gynecologist to discuss the procedure's results with
the patient afterward. For the combined arm specifically, this can't
happen at the time of placement (the patient is under anesthesia), and
it happens as a separate phone call, not an in-person visit, since the
patient is otherwise occupied recovering from a much larger surgery and
no physical exam is needed for the IUD side of things.

New parameters: `combined_arm_postop_discussion_minutes` = 25 (model-
owner operational estimate) and `gynecologist_wage_per_minute` = $2.347
(O*NET/BLS 2025 median wage for SOC 29-1218, Obstetricians and
Gynecologists, $140.82/hour -- same discovery method as the scheduler
wage: bls.gov blocks automated retrieval, O*NET republishes the same
OEWS data). Priced as raw physician time, not a procedure fee, since a
phone call with no physical exam isn't a billable E/M encounter.
Applies only to the combined arm; standalone's single office visit
already includes this discussion live, in the same encounter as the
insertion itself.

Checked directly rather than assumed: is this already covered by a
global surgical fee? No -- CPT 58300's own CMS global-surgery period is
"XXX" (no global package exists for this code at all, the same lookup
used for the preop visit above), and separately, this call happens on a
later calendar day than the insertion itself (the patient is in the OR,
then recovering from the bariatric procedure, that day), so even the
general same-day-minor-procedure bundling rule wouldn't apply. The
bariatric surgeon's own global period, if any, covers a different
physician's different procedure code, not the gynecologist's separate
communication.

**Net effect: the base case gap moved from $430.13 to $490.78**
(standalone unchanged at $868.63; combined rose from $1,298.76 to
$1,359.41). Mutation-tested; see `docs/testing_philosophy.md`.

## IUD string checks

Checked directly, in response to the question of whether a routine
in-office string-check visit belongs in either arm's cost. It doesn't.
Current CDC guidance states it plainly: **"No routine follow-up visit
is required"** after IUD placement (Curtis KM, Nguyen AT, Tepper NK,
Zapata LB, Snyder EM, Hatfield-Timajchy K, Kortsmit K, Cohen MA,
Whiteman MK. "U.S. Selected Practice Recommendations for Contraceptive
Use, 2024." *MMWR Recomm Rep* 2024;73(3):1-77), based on evidence rated
"very limited and of poor quality" for any specific follow-up-visit
schedule improving continuation. Clinicians are instead advised to check
for the strings opportunistically at other routine visits, not via a
dedicated scheduled one. This is a deliberate, evidence-based exclusion,
not an oversight: no cost is added to either arm for a routine
string-check visit, consistent with the observation that IUD inserts
don't get a postop visit at all. See
`iud_string_check_followup_not_recommended` in
`config/model_parameters.csv`.

## Standalone loss to follow-up: a real, unpriced effectiveness gap

Every cost figure above is a cost GIVEN the device gets placed. It
doesn't answer a different, real question: does it actually get placed?
Combined placement happens in the OR while the patient is already
anesthetized for bariatric surgery -- there's no analog to a patient
"not showing up," so it's treated as guaranteed
(`probability_device_placed = 1`). Standalone requires the patient to
return for a separate, later visit, and a real fraction of patients
scheduled for exactly this kind of interval visit never do.

`standalone_loss_to_follow_up_probability` = 25.7% (base/low) to 29.9%
(high), from a real primary source: Baldwin MK, Edelman AB, Lim JY,
Nichols MD, Bednarek PH, Jensen JT, "Comparison of intrauterine device
insertion at 3 weeks versus 6 weeks postpartum: a randomized trial,"
*Contraception* 2016;93(4):356-363 -- a 201-patient RCT of postpartum
women intending interval IUD placement, where 74.3% (58/78, standard
6-week group) to 70.1% (53/75, early 3-week group) returned for their
scheduled visit as planned. This is a POSTPARTUM population, not a
bariatric-surgery one -- no published data on IUD scheduling
specifically around bariatric surgery was found -- but the underlying
logistics phenomenon (returning for a deliberately scheduled interval
procedure after a different major medical event) is structurally
similar, and no better-matched source exists. Flagged provisional for
that population mismatch.

This is a genuine effectiveness gap a cost-minimization model (which
assumes equal effectiveness by design) does not belong folding into a
single dollar figure, so it's reported as its own number instead:
`probability_device_placed` (standalone 0.743, combined 1.0) and
`expected_cost_per_referred_patient` (cost per patient REFERRED to a
strategy, not per patient who completes it). At base case (before the
missed-cancer-prevention cost below was added), this WIDENED the
standalone advantage on paper -- $645.39 vs. combined's $1,359.41, wider
than the $868.63-vs-$1,359.41 per-completed-visit gap above -- because a
missed visit costs nothing directly in this model.

Mutation-tested; see `docs/testing_philosophy.md`.

## Chaining loss to follow-up to a real downstream outcome

Asked to look at how other literature handles exactly this structural
problem (a strategy that guarantees placement during an existing
admission vs. one requiring a separate, loss-to-follow-up-prone visit).
The immediate-vs-interval-postpartum-LARC literature has studied this
directly, and doesn't treat loss to follow-up as a side metric the way
the section above did: Washington et al. 2015 (*Fertil Steril*
103(1):131-137) and Gariepy et al. 2015 (*Obstet Gynecol* 126(1):47-55)
both build a full decision tree chaining a missed visit through to
contraceptive failure and unintended pregnancy, with Washington's own
finding that results are "most sensitive to the cost of an undesired
pregnancy" -- the downstream outcome, not the procedural costs, drives
their result.

This population's actual stake is different: this device also protects
against endometrial cancer (see "Cancer-prevention estimate" below), so
that's the outcome chained here instead of pregnancy.
`endometrial_cancer_treatment_cost` ($34,982.33, 2015 dollars, derived
from Dottino et al. 2016's Table 2 cost-of-care figures via a
conditional mortality-given-diagnosis ratio: first-year cost + [death
risk / lifetime risk] x last-year-of-life cost, deliberately excluding
ongoing survivorship-care costs as a conservative simplification) is
multiplied by `standalone_loss_to_follow_up_probability` and the IUD's
own absolute risk reduction (reused directly from
`R/cancer_prevention.R`'s own functions, not re-derived) to get
`expected_missed_cancer_prevention_cost`: $89.62 per referred standalone
patient.

**Even counting this real cost, standalone's per-referred-patient
number is still below its per-completed-visit number** -- $735.01 vs.
$868.63 -- because the avoided-visit savings ($223.24, from `expected_
total_cost x (1 - probability_device_placed)`) outweighs the added
cancer-risk cost. Standalone's apparent extra savings come PARTLY, not
entirely, from some patients never getting an IUD at all. `Rscript
analysis/01_base_case.R` prints all of this together for exactly this
reason.

Mutation-tested; see `docs/testing_philosophy.md`.

## Does bariatric surgery also improve survival after an endometrial cancer diagnosis?

A direct follow-up question: the cancer-prevention chain above already
applies `bariatric_surgery_endometrial_cancer_hazard_ratio` (Schauer et
al. 2019) to endometrial cancer INCIDENCE -- the risk of developing it
in the first place. Does bariatric surgery also change SURVIVAL once a
woman already has an endometrial cancer diagnosis? That would be a
different hazard ratio, measured in a different population (diagnosed
patients, not the general obese population), and it was not assumed to
be the same without checking.

The only real, cohort-derived estimate found: Lee et al. 2021 (*Surg
Obes Relat Dis* 18(1):42-52), a California Cancer Registry cohort of
endometrial cancer patients with (n=46) vs. without (n=3,343)
post-diagnosis weight-loss surgery, reports an adjusted all-cause
mortality hazard ratio of 0.23 (95% CI 0.033-1.70, p=0.15) -- not
statistically significant, and based on fewer than 15 deaths in the
surgery group. A decision-analytic paper that sounds relevant, Argenta
et al. 2015 (*Gynecol Oncol* 138(3):597-602), turned out not to be
usable either: it's a Markov simulation whose survival assumption is
imported from general bariatric-surgery mortality literature, not
measured in endometrial cancer patients specifically.

Given a CI that wide (crossing 1.0 by a wide margin) on that few
events, this is deliberately **excluded from the base case** --
`bariatric_surgery_endometrial_cancer_mortality_hazard_ratio`'s
`base_value` is fixed at 1 (no adjustment) in
`config/cancer_prevention_parameters.csv`. It's kept as a documented,
sourced, sensitivity-only parameter, consumed only by
`compute_expected_missed_cancer_prevention_cost_at_mortality_hr()` in
`R/strategy_costs.R` -- a separate function the base-case tibbles never
call. Sweeping the full CI moves `expected_missed_cancer_prevention_cost`
from $53.72 (at HR=0.033, the most-protective end) to $115.61 (at
HR=1.70, the least-protective end), against a base case of $89.62 (at
HR=1, no adjustment) -- a real range, but one that doesn't change which
strategy is cheaper either way.

Mutation-tested; see `docs/testing_philosophy.md`.

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
