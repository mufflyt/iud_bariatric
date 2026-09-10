# Data sources

Full evidence trail for every parameter in `config/model_parameters.csv`,
including sources checked and rejected. Dates below are when each source
was checked in this session (2026-09-10) unless noted otherwise.

## Why Medicare/CMS data, the primary source for the sibling `emb_colonoscopy`
model, does not work here

- **CPT 58300 (IUD insertion) carries Medicare's "N" (non-covered) status.**
  Contraceptive devices are a statutory Medicare exclusion. Confirmed via
  web search of CMS coverage-database articles and billing guides
  (2026-09-10).
- **The CMS ASP and OPPS NDC-HCPCS crosswalk files contain zero entries**
  for the levonorgestrel-IUD HCPCS codes. Directly verified: downloaded and
  unzipped the July 2026 quarterly file
  (`https://www.cms.gov/files/zip/july-2026-ndc-hcpcs-crosswalk.zip`) and
  grepped both the ASP and OPPS crosswalk CSVs for `J7296`-`J7301` and for
  "levonorgestrel" — no matches in either file (2026-09-10).
- **NADAC (National Average Drug Acquisition Cost) does not cover this
  device either.** Downloaded the current NADAC reference file directly
  (`https://download.medicaid.gov/data/nadac-national-average-drug-acquisition-cost-09-09-2026.csv`,
  URL confirmed via the medicaid.gov metastore API) and searched for
  "levonorgestrel" + "intrauterine"/"IUD"/product names — no matches. NADAC
  only prices retail-pharmacy-dispensed drugs; a hospital-administered
  device was never going to appear there.

## Real, directly-verified numbers

**Denver Health and Hospital Authority's own CMS-mandated price-transparency
machine-readable file** (downloaded directly 2026-09-10 from
`https://sthpiprd.blob.core.windows.net/machine-readable-files/7840/841343242_denver-health-and-hospital-authority_standardcharges.csv`,
file dated 2026-04-30, discovered via the standard `https://{domain}/cms-hpt.txt`
auto-discovery convention at `https://www.denverhealth.org/cms-hpt.txt`):

| Item | Code | Gross charge | Discounted cash | Inpatient rate (min-max) |
|---|---|---|---|---|
| IUD insertion | CPT 58300 | $331.65 | $116.08 | $113.76 (flat) |
| Liletta/Kyleena 52mg 8yr | HCPCS J7297 | $2,393.32 | $837.67 | $820.91 (flat) |
| Mirena 52mg | HCPCS J7298 | $3,439.84 | $1,203.95 | $1,179.87-$5,777.42 |
| Kyleena 13.5mg 3yr | HCPCS J7301 | $2,864.24 | $1,002.49 | $982.43 (flat) |

Key observation: for an **inpatient** stay (the relevant setting, since
bariatric surgery is typically inpatient), almost every commercial payer's
negotiated rate for CPT 58300 is `NULL` in this file, meaning it is not
separately paid at all — its cost is bundled into the hospital's MS-DRG
payment for the admission. This directly supports the model's
incremental-cost framing: there is no separate facility/professional
reimbursement to net against for the combined arm.

Also directly verified in the same file, MS-DRG 619/620/621 ("O.R.
Procedures for Obesity", by complexity tier) — the host bariatric
procedure, for context only, not used in the incremental-cost calculation:
CMS/Medicare rate $41,963.80 (619, with MCC) / $28,839.33 (620, with CC) /
$27,902.21 (621, without CC/MCC); commercial payers ranged $26,000-$61,414.

## Secondary-source numbers needing re-verification

- **Non-340B GPO acquisition cost ($537-$600): verification ATTEMPTED and
  FAILED, 2026-09-10.** The only source for this range is a single MDedge
  ObGyn article
  (`https://www.mdedge.com/obgyn/article/103902/gynecology/what-does-liletta-cost-non-340b-providers`).
  Four independent methods to read it directly all failed: WebFetch
  returned truncated/no content on two separate attempts; `curl` with a
  browser user-agent returned only a cookie-consent/JS-loader shell (the
  page requires client-side rendering and appears authwall-gated, sending
  `authlevel=0`); `web.archive.org` is blocked outright for this tool; and
  the site's own beta subdomain (found via a targeted search,
  `mdedge9-beta.mdedge.com`) is not publicly routable
  (`connect ECONNREFUSED`). The Physicians' Alliance of America "Liletta
  Pricing Update" bulletin, which cites the same figures secondhand, was
  checked directly and turned out to be a members-only order bulletin
  behind a login — it only confirms that AbbVie raised Liletta's WAC as of
  January 1, 2026, not the $537/$600 numbers themselves. **This parameter
  remains unverified.** Next step for real verification: a hospital
  pharmacy buyer's own GPO contract/invoice, a paid pricing database
  (Medi-Span, RedBook), or a readable (non-authwalled) copy of the MDedge
  article.
- **340B price ($50, later reportedly $100): partially corroborated,
  still unresolved for 2026.** The $50 figure is directly quoted from a
  2016 AAFCPAs article citing a Medicines360 announcement ("this price
  will never increase"). A second, independently-worded source (a 340B
  Prime Vendor Program overview page, checked 2026-09-10) also states
  Liletta's "federal 340B pricing is $50," without citing a date. Two
  independent mentions of the same figure is modest reassurance, but
  neither source is dated to 2026, and neither confirms or refutes the
  separately-reported later increase to $100. **Action needed:** check
  Medicines360's current published 340B price list directly before using
  either figure as a current 2026 value.
- **Whether Denver Health (or any specific hospital this model is
  anchored to) is actually 340B-registered: checked 2026-09-11, could not
  confirm either way.** HRSA's public 340B OPAIS lookup
  (`https://340bopais.hrsa.gov/`) is a Blazor single-page app; static
  `curl` requests return only the unrendered app shell, and guessed API
  endpoint paths returned empty/404 responses. A genuine answer requires
  either using the site's own search UI interactively (`SearchCe` page) or
  downloading its published "Covered Entity Daily Report" export (Excel/
  JSON, linked from `https://340bopais.hrsa.gov/Reports`) and searching it
  directly — not yet done. Separately relevant: Disproportionate Share
  Hospitals (the 340B category Denver Health would most plausibly fall
  under) are subject to the "GPO Prohibition" — they cannot purchase
  covered outpatient drugs through group-purchasing-organization
  arrangements at all. If Denver Health is a DSH-category covered entity,
  `iud_device_acquisition_cost_gpo` would not even be an option available
  to it; its real choice would be 340B pricing or full undiscounted price,
  not GPO. This model's GPO-price scenario should be understood as
  applying to a non-DSH, non-340B hospital, not necessarily Denver Health
  itself.
- **CPT 58300 commercial professional-fee range ($75-$125):** from
  aggregator/billing-service websites (billingfreedom.com,
  obgynbillco.com), not independently confirmed against a second primary
  payer fee schedule.

## Literature gaps (searched for, not found)

- **Combined bariatric-surgery IUD placement is real, documented practice
  (see Hillman 2011 and Masten 2024 below), but no study quantifies the
  added operating-room TIME it takes, and none does a COST comparison
  between placing it standalone vs. at the time of surgery.** Multiple
  targeted searches (2026-09-10) and a 15-paper literature review
  (2026-09-11) turned up general bariatric-contraception access/counseling
  literature and two feasibility/expulsion-outcome cohorts, but no
  intraoperative timing data and no economic analysis of insertion
  setting. That remaining gap, minutes and dollars, not whether it's done,
  is what this project fills.
- **The closest analog, IUD insertion at cesarean delivery**, is well
  studied for safety/expulsion/breastfeeding outcomes but the accessible
  literature describes added time only qualitatively ("minimal"), not in
  minutes. Several relevant papers (e.g. the Fertility & Sterility
  postpartum-timing cost-effectiveness analysis) were paywalled.
- **`combined_arm_added_minutes` (5-15 minutes) is therefore a
  general-population proxy**, from a patient-facing clinical protocol page
  (Children's Hospital Colorado / CU Anschutz adolescent gynecology, "IUD
  Placement Under Anesthesia"), not a bariatric-specific or even a
  peer-reviewed timed study. Revisit if one is ever published.

## Clinical precedent and expulsion risk (added 2026-09-11, from a 15-paper literature review)

A systematic review of 15 candidate papers (see the project's own review
notes, session of 2026-09-11) found that combined bariatric-surgery IUD
placement is not hypothetical, it is documented, already-practiced clinical
care, and it carries a real safety tradeoff this model did not originally
capture:

- **Hillman JB, Miller RJ, Inge TH. Menstrual concerns and intrauterine
  contraception among adolescent bariatric surgery patients. J Womens
  Health 2011;20(4):533-538.** Retrospective cohort, 25 adolescent
  bariatric-surgery patients; 23/25 (92%) had a levonorgestrel IUD placed
  *at the time of* bariatric surgery under the same anesthesia. States the
  clinical rationale directly: combined placement "is desirable in that it
  is convenient for the patients and ensures no unplanned pregnancies,"
  citing insertion difficulty in nulliparous adolescents as a further
  reason to use existing anesthesia. No cost or OR-time data. Establishes
  clinical precedent and patient acceptance, not economics.
- **Masten E, et al. Body Mass Index and Levonorgestrel Device Expulsion in
  Adolescents and Young Adults. J Pediatr Adolesc Gynecol
  2024;37:407-411.** Retrospective chart review, 588 nulliparous patients
  aged 10-19, 43 (16.2%) placed as a combination case with metabolic/
  bariatric surgery (MBS). **This is the source for
  `iud_expulsion_probability_standalone`/`_combined` and
  `iud_expulsion_odds_ratio_combined_vs_standalone`** — combined placement
  carried a significantly higher 12-month expulsion rate than non-combined
  placement (16.3% vs. 5.6% overall; adjusted OR=3.23, P=.024). Wired
  directly into `R/strategy_costs.R`'s `compute_expected_replacement_cost()`
  for both arms; see `docs/testing_philosophy.md` for the mutation test
  proving this is read correctly by each strategy.
- **Thornton KA, et al. Counseling, contraception, and conception rates in
  patients undergoing bariatric surgery: a retrospective review.
  Contraception 2021.** Retrospective cohort, 460 bariatric-surgery
  patients; describes postoperative contraceptive choice (LNG-IUD most
  common LARC) and conception rates, and explicitly names
  *"coordinating combined bariatric and permanent contraception
  procedures"* as an unaddressed future direction, without studying it.
  Cited in the README as the stated literature gap this project fills.

None of these three papers does a cost-minimization comparison of
insertion setting/timing, that gap is what this project fills, but Masten
2024 in particular changes the model's conclusion: it is the reason the
combined arm is not simply "device cost + OR minutes," it also carries a
higher expected replacement cost than the standalone arm.

## An independent commercial-claims cost benchmark

**Nguyen ABT, et al. Descriptive study of the real-world, long-term cost
estimates and duration of use for hormonal and nonhormonal intrauterine
devices using US commercial insurance claims. J Manag Care Spec Pharm
2023;29(12):1303-1311.** IBM MarketScan commercial claims, 63,386 IUD
insertions in 2014, 5-year follow-up. Reports a 52mg levonorgestrel IUD's
combined device + physician-insertion claim cost as $1,107 (+/-$4) in 2014
dollars, and $1,514 cumulative over 5 years (driven mostly by AUB/
ovarian-cyst workup and removal/reinsertion, not modeled here). This is a
third independent cost channel (`iud_commercial_claims_cost_benchmark`),
alongside the Denver Health chargemaster cash price ($837.67) and the
unverified GPO estimate ($537-$600): what a commercial payer actually paid
nationally, sitting conceptually between chargemaster and true acquisition
cost. Not directly comparable to either other figure without adjustment
(different year, and "paid claim" is not "hospital's acquisition cost"),
so it is reference-only, not used in the base-case cost engine, but useful
triangulation confirming the order of magnitude.

## Standalone office-insertion failure/escalation risk (added 2026-09-11)

- **Saito-Tom LY, Soon RA, Harris SC, Salcedo J, Kaneshiro BE. Levonorgestrel
  Intrauterine Device Use in Overweight and Obese Women. Hawaii J Med
  Public Health 2015.** Directly read via WebFetch. Retrospective cohort,
  149 women (55 normal weight, 45 overweight, 49 obese). Obese group: 4%
  (2/49) failed insertion, 8% (4/49) "difficult" insertion; no
  statistically significant difference by BMI group (P=.47). **This is
  the source for `standalone_office_failure_probability`.**
- A second candidate source was checked and rejected: Harrison, "Failed
  IUD insertions in community practice," *Contraception* 2012 (19.6%
  failure in nulliparous women choosing emergency contraception, inserted
  by nurse practitioners without adjuvant measures, at family-planning
  clinics). Rejected because that population (nulliparous,
  emergency-contraception-seeking, nurse-practitioner-inserted, no
  adjuvant measures) is a much weaker match to this project's target
  population than Saito-Tom's obese-BMI-specific cohort, even though
  Saito-Tom's sample is smaller (n=49 obese women, only 2 failures).
- On failure, the model assumes escalation to a sedated re-attempt at the
  same per-minute cost as the combined arm's OR/anesthesia minutes
  (`compute_added_or_cost()`), with no duplicate device or professional
  fee charged. This is a simplifying modeling assumption, not itself a
  sourced escalation-cost figure — no study measures what actually happens
  economically after a failed office IUD attempt.

## Two omissions decided explicitly, not silently (added 2026-09-11)

- **Routine device removal (CPT 58301, $212.58 cash price per the Denver
  Health MRF already in this table)** is not priced in the incremental
  comparison. Every device is eventually removed regardless of which arm
  inserted it, so it cancels out under the incremental-cost principle —
  recorded as `iud_routine_removal_professional_fee` (reference-only) so
  the omission is documented.
- **Differential uterine-perforation risk by insertion setting** is not
  applied. Baseline perforation risk (0.3-2.6 per 1,000 insertions,
  general LNG/copper-IUD literature) is recorded as
  `iud_perforation_risk_baseline` (reference-only), but the literature on
  whether anesthesia/sedation changes that risk is genuinely mixed: one
  source suggests general anesthesia may modestly increase risk (excess
  force at the internal os without patient feedback), while a separately
  cited large study found no association between anesthesia use and
  perforation. No confident directional evidence exists to differentiate
  the two arms, so neither arm gets an adjustment. Revisit if a study
  specifically comparing office vs. sedated/OR insertion settings is
  found.

## Inflation adjustment (added 2026-09-11)

`R/inflation.R`, `data/cpi_medical_care.csv`, and `data/cpi_all_items.csv`
are now wired up (adapted directly from the sibling `emb_colonoscopy`
project's `R/inflation.R`). `direct_room_cost_per_minute` and
`anesthesia_cost_per_minute` (2014 dollars) are now inflation-adjusted to
`reference_dollar_year` (2026) before being used in
`compute_added_or_cost()`. This project's `data/cpi_medical_care.csv` 2014
row is a REAL value (435.293, the average of the January and July FRED
series CUUS0000SAM data points for 2014, downloaded directly
2026-09-10/11 from
`https://fred.stlouisfed.org/graph/fredgraph.csv?id=CUUS0000SAM`) rather
than the sibling project's own flagged-placeholder 2014 value
(431.9, geometrically interpolated, not a real reported BLS figure) — this
project's CPI table is, on this one point, better-sourced than the one it
was copied from. Consider backporting this real value to the sibling
project's `data/cpi_medical_care.csv` at some point.

## Reused from the sibling `emb_colonoscopy` project

`office_visit_em_cost`, `direct_room_cost_per_minute`,
`anesthesia_cost_per_minute`, and `patient_time_opportunity_cost_per_visit`
are copied directly from that project's already-verified extractions (CMS
Physician & Other Practitioners by Provider and Service PUF for the E/M
visit; Childers & Maggard-Gibbons, *JAMA Surg*, for the OR/anesthesia
per-minute costs; Ray et al. 2015 for the patient-time/travel opportunity
cost) rather than re-pulled fresh, because the underlying claim transfers
directly. See that project's `docs/data_sources.md` and
`config/model_parameters.csv` for the full citation trail.

**Done as of 2026-09-11:** `direct_room_cost_per_minute` and
`anesthesia_cost_per_minute` are now inflation-adjusted to
`reference_dollar_year` via `R/inflation.R` before use (see "Inflation
adjustment" above) — this scaffold no longer reports 2014-dollar OR/
anesthesia costs mixed in with 2026-dollar everything-else.
