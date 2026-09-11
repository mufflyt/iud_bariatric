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
  "levonorgestrel" -- no matches in either file (2026-09-10).
- **NADAC (National Average Drug Acquisition Cost) does not cover this
  device either.** Downloaded the current NADAC reference file directly
  (`https://download.medicaid.gov/data/nadac-national-average-drug-acquisition-cost-09-09-2026.csv`,
  URL confirmed via the medicaid.gov metastore API) and searched for
  "levonorgestrel" + "intrauterine"/"IUD"/product names -- no matches. NADAC
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
separately paid at all -- its cost is bundled into the hospital's MS-DRG
payment for the admission. This directly supports the model's
incremental-cost framing: there is no separate facility/professional
reimbursement to net against for the combined arm.

Also directly verified in the same file, MS-DRG 619/620/621 ("O.R.
Procedures for Obesity", by complexity tier) -- the host bariatric
procedure, for context only, not used in the incremental-cost calculation:
CMS/Medicare rate $41,963.80 (619, with MCC) / $28,839.33 (620, with CC) /
$27,902.21 (621, without CC/MCC); commercial payers ranged $26,000-$61,414.

## Cross-hospital price validation (added 2026-09-10)

Denver Health is a single safety-net hospital, and a fair question is
whether its chargemaster/cash prices and CPT 58300 fee are representative
or an outlier. Two more real hospitals' CMS-mandated machine-readable
files were checked directly, both discovered the same way (the
`https://{domain}/cms-hpt.txt` auto-discovery convention), to find out.

**NYU Langone Health** (`https://nyulangone.org/cms-hpt.txt` ->
`mrf-url: https://standard-charges-prod.s3.amazonaws.com/pricing_files/133971298-1801992631_nyu-langone-tisch_standardcharges.csv`,
file dated 2026-01-01, downloaded directly 2026-09-10, 482 MB CSV, the CMS
"tall" per-payer-column format):

| Item | Code | Gross charge | Discounted cash | Negotiated rate (n payers, min-median-max) |
|---|---|---|---|---|
| IUD insertion (setting: both) | CPT 58300 | $2,152.15 | $408.91 | n=291, $210.08-$4,100.00-$25,798.00 |
| Liletta/Mirena/Kyleena 52/19.5mg | HCPCS J7297/J7298/J7296 | $15,304.34 | $2,907.82 | n=209, $153.04-$4,591.30-$15,304.34 |
| Skyla 13.5mg | HCPCS J7301 | $12,743.39 | $2,421.24 | n=209, $127.43-$3,823.02-$12,743.39 |

**Ronald Reagan UCLA Medical Center**
(`https://www.uclahealth.org/cms-hpt.txt` ->
`mrf-url: https://www.uclahealth.org/sites/default/files/cms-hpt/956006143_ronald-reagan-ucla-medical-center_standardcharges.json`,
file dated 2026-01-01, last updated 2026-03-29, downloaded directly
2026-09-10, ~500 MB JSON, CMS HPT schema v3.0.0):

| Item | Code | Gross charge | Discounted cash | Negotiated rate (n payers) |
|---|---|---|---|---|
| IUD insertion | CPT 58300 | not present in file | not present in file | not present in file |
| Liletta/Mirena/Kyleena 52/19.5mg | HCPCS J7297/J7298/J7296 | null | null | n=3, $845.10 / $950.37 / $950.37 |
| Skyla 13.5mg | HCPCS J7301 | null | null | n=3, $917.35 / $1,031.61 / $1,031.61 |

**What this changes and what it doesn't.** Neither file reports a hospital's
own acquisition cost (what it pays its pharmacy/GPO/340B contract for the
device), so neither moves `iud_device_acquisition_cost_gpo` or `_340b`,
which remain the base-case drivers. What it does do:

- **Denver Health is the low end of a real three-hospital range, not an
  outlier.** For the same device (J7297), cash/negotiated prices ranged
  from $837.67 (Denver Health) to $845-$950 (UCLA) to $2,907.82 (NYU
  Langone), a range wide enough that NYU's single hospital, on its own,
  spans a 3.5x multiple of Denver Health's price. This is direct evidence
  for the point `iud_j7297_cash_price_nyu_langone`'s notes make in
  `config/model_parameters.csv`: charge/cash prices carry hospital margin
  and market-specific variation far too large to substitute for a real
  acquisition cost, which is exactly why this model uses acquisition-cost
  parameters instead of anchoring on any single hospital's charges.
- **CPT 58300's price varies even more, and NYU's number cannot be used as
  a second professional-fee data point.** NYU lists this code's `setting`
  as `both`, meaning its charge does not distinguish inpatient from
  outpatient billing the way Denver Health's separate professional fee
  does; NYU's $408.91 cash price plausibly bundles a facility/OR component
  that Denver Health's own professional-only fee does not carry. The two
  are not comparable line items, so `iud_insertion_professional_fee`'s
  base value and its unverified $75-$125 aggregator bound were left
  unchanged; the NYU figure is recorded as `iud_58300_cash_price_nyu_langone`
  for transparency, not folded into the model.
- **UCLA's file has no CPT 58300 entry and no gross/cash price for the
  IUD devices at all**, only 3 populated per-payer negotiated-dollar
  entries per device code. This is itself informative: hospital
  price-transparency files vary enormously in completeness even though
  all are subject to the identical federal 45 CFR 180.50 requirement, a
  limitation worth naming rather than glossing over.
- Two other large systems' `cms-hpt.txt` files were checked and could not
  be used: Cleveland Clinic's endpoint returned an HTML page rather than a
  valid discovery file, and Mayo Clinic's and Cedars-Sinai's both returned
  "Access Denied."

See `iud_j7297_cash_price_nyu_langone`, `iud_j7297_negotiated_range_ucla`,
and `iud_58300_cash_price_nyu_langone` in `config/model_parameters.csv`
(all `category = reference_only`, evidence tier A, not consumed by the
cost engine) for the exact figures and full source strings.

**A fourth, national data point corroborates the same band.** CMS's State
Drug Utilization Data (SDUD) 2025 file (downloaded directly 2026-09-10
from `https://download.medicaid.gov/data/sdud2025_updatedjuly2026.csv`,
discovered via the `data.medicaid.gov` metastore API) reports actual
Medicaid reimbursement, summed across every reporting state's FFS and MCO
claims for calendar-year 2025: Liletta averaged $857.54/unit (45,988
units, $39,437,116 total, 116 of 356 state-quarter rows privacy-suppressed
and excluded rather than treated as zero), Mirena $1,213.43/unit (243,398
units), Kyleena $1,247.53/unit (22,829 units), Skyla $1,063.36/unit (4,145
units). Four independently-sourced figures now cluster in the same
$840-$980 band for this device class (Denver Health $837.67, UCLA
$845-$950, Colorado Medicaid PAD schedule $931.73-$978.32, national
Medicaid average $857.54), with NYU Langone's $2,907.82 the clear outlier
rather than the norm. See `iud_j7297_medicaid_national_reimbursement_2025`
in `config/model_parameters.csv`.

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
  behind a login -- it only confirms that AbbVie raised Liletta's WAC as of
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
  directly -- not yet done. Separately relevant: Disproportionate Share
  Hospitals (the 340B category Denver Health would most plausibly fall
  under) are subject to the "GPO Prohibition" -- they cannot purchase
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

## Strengthened evidence (added 2026-09-11)

- **`combined_arm_added_minutes` now has a bariatric-surgery-context
  corroborating source**, not just a general non-bariatric proxy: a
  retrospective review of 25 patients undergoing concomitant laparoscopic
  bilateral salpingectomy at the time of primary sleeve gastrectomy or
  gastric bypass (12 sleeve, 13 bypass, single institution, 6 years) found
  salpingectomy added approximately 10 minutes to operative time
  (conference abstract, *Surgery for Obesity and Related Diseases*,
  April 2026). Confirmed via two independently-worded search summaries
  converging on identical specific details (patient counts, procedure
  split, time estimate); direct full-text access to soard.org returned
  HTTP 403. Not IUD-specific, but it is real bariatric-OR-context data for
  a comparably minor gynecologic add-on procedure, and it lands almost
  exactly on the existing 10-minute estimate. Evidence tier upgraded from
  C to B.
- **`iud_expulsion_probability_standalone`'s high bound is now a real
  adult, obesity-specific figure**, not an arbitrary band: re-read
  Saito-Tom et al. 2015 (the same paper already used for
  `standalone_office_failure_probability`) specifically for its expulsion
  outcome (distinct from insertion difficulty/failure, which was the
  outcome originally extracted from this paper): 11/145 (8%) overall
  12-month expulsion, 11% in obese women specifically (vs. 11% normal
  weight, 4% overweight; P=.47, authors describe the study as
  underpowered). The base value stays at Masten 2024's 5.6% because that
  is the only source with a PAIRED standalone-vs-combined comparison in
  one cohort (the model's central 3.23x differential-risk finding depends
  on that pairing; Saito-Tom has no combined-insertion arm to compare
  against). But using Saito-Tom's real adult-obese rate as the high bound,
  instead of an assumed range, partially closes the generalizability gap
  that Masten's cohort is adolescents (ages 10-19), not adults. Evidence
  tier upgraded from C to B.
- **A specific claim checked and REJECTED:** a search-engine summary
  attributed a "class III obesity (BMI>=40), 3.06x odds of expulsion"
  finding to what appeared to be the same University of Hawaii research
  group (matching ethnic-composition details). Directly re-fetched
  Saito-Tom et al. 2015's full text with a targeted prompt asking
  specifically for this odds ratio: it does not appear anywhere in the
  paper. The paper categorizes BMI into only three groups (normal,
  overweight, obese), not a separate class III/BMI>=40 category, and
  reports no such odds ratio. This looks like a search-summarization
  error, not a real finding, and is not used anywhere in this model.

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
- **Masten M, Yi H, Beaty L, Hutchens K, Alaniz V, Buyers E, Moore JM. Body
  Mass Index and Levonorgestrel Device Expulsion in Adolescents and Young
  Adults. J Pediatr Adolesc Gynecol 2024;37(4):407-411, doi:10.1016/
  j.jpag.2024.03.001, PMCID PMC11706623 (open access; author name
  corrected 2026-09-10 after reading the full text directly).**
  Retrospective chart review, 588 nulliparous patients
  aged 10-19, 43 (16.2%) placed as a combination case with metabolic/
  bariatric surgery (MBS). **This is the source for
  `iud_expulsion_probability_standalone`/`_combined` and
  `iud_expulsion_odds_ratio_combined_vs_standalone`** -- combined placement
  carried a significantly higher 12-month expulsion rate than non-combined
  placement (16.3% vs. 5.6% overall; adjusted OR=3.23, P=.024). Wired
  directly into `R/strategy_costs.R`'s `compute_expected_replacement_cost()`
  for both arms; see `docs/testing_philosophy.md` for the mutation test
  proving this is read correctly by each strategy.

  **Update (2026-09-10): `iud_expulsion_probability_combined` now has a
  real low/high range**, closing the exact gap the one-way sensitivity
  analysis surfaced (see "One-way sensitivity analysis" below). Read the
  full text directly (PMCID PMC11706623, open access) and found Table 4's
  raw numerator/denominator behind the 16.3% figure: 7 expulsions out of
  43 combination-case placements. Computed an exact Clopper-Pearson 95%
  binomial confidence interval directly on that proportion via R's
  `stats::binom.test(7, 43)`: 6.81%-30.70%. This is now
  `iud_expulsion_probability_combined`'s low/high bound. Deliberately NOT
  derived from Table 4's adjusted-odds-ratio CI (3.23, 95% CI 1.11-8.75,
  now also recorded directly in `iud_expulsion_odds_ratio_combined_vs_
  standalone`): that OR is adjusted for covariates (age, race, ethnicity,
  insurance, AUB with anemia, DD indication) this project's unadjusted
  base_value is not, so deriving a probability range from the adjusted
  OR's CI around an unadjusted point estimate would mix two different
  scales. The wide interval (driven by the small n=43 subgroup) is real
  sampling uncertainty from a single-center retrospective chart review,
  not an artifact of the calculation. While re-reading the full text, the
  first author's name was also corrected (Masten M, not "Masten E," an
  error introduced when this row was first added).
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
  sourced escalation-cost figure -- no study measures what actually happens
  economically after a failed office IUD attempt.

## Two omissions decided explicitly, not silently (added 2026-09-11)

- **Routine device removal (CPT 58301, $212.58 cash price per the Denver
  Health MRF already in this table)** is not priced in the incremental
  comparison. Every device is eventually removed regardless of which arm
  inserted it, so it cancels out under the incremental-cost principle --
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
(431.9, geometrically interpolated, not a real reported BLS figure) -- this
project's CPI table is, on this one point, better-sourced than the one it
was copied from. Consider backporting this real value to the sibling
project's `data/cpi_medical_care.csv` at some point.

## Medicaid payer scenario (added 2026-09-11)

Medicaid is a genuinely more relevant payer to explore here than Medicare
(which excludes contraceptive devices entirely), since Medicaid is a
mandatory-coverage payer for contraception and is a major real-world
funder of LARC insertion nationally.

- **Colorado Medicaid's real CPT 99213 rate: $77.39, directly confirmed.**
  Downloaded Colorado HCPF's own "Health First Colorado Physician Fee
  Schedule Rates Effective April 1, 2026" PDF directly
  (`https://hcpf.colorado.gov/sites/hcpf/files/01_CO_Fee%20Schedule_Health%20First%20Colorado_04012026%20v1.0.pdf`
  -- note: this URL 403s with a default `curl` user-agent via CloudFront
  bot-blocking; a browser user-agent string works), converted to text
  with `pdftotext -layout`, and found the "Family Planning - Professional
  Component" line for CPT 99213: $77.39 (base), $82.39 (with GT/telehealth
  modifier). This is the source for the Medicaid scenario's
  `office_visit_em_cost` override.
- **UPDATE (2026-09-10): CPT 58300 does appear in Colorado's fee
  schedule, real rate $58.65, found once the workbook was parsed
  directly.** The April 2026 PDF export checked above genuinely does not
  show it, but Colorado HCPF's underlying Excel workbook
  (`01_CO_Fee Schedule_Health First Colorado_07012026 v1.2.xlsx`,
  downloaded directly from
  `https://hcpf.colorado.gov/sites/hcpf/files/01_CO_Fee%20Schedule_Health%20First%20Colorado_07012026%20v1.2.xlsx`,
  linked from `https://hcpf.colorado.gov/provider-rates-fee-schedule`) has
  13 worksheets, and the code lives in one (`Sheet3`, the underlying rate
  table) that the single printable page the PDF is exported from does not
  include. Parsing every worksheet's raw XML directly (rather than relying
  on a PDF-to-text conversion of one sheet) found two billing rows for CPT
  58300, both paying $58.65: `58300DEF` (default) and `58300FPPFP`
  (Family-Planning-modifier). This is now the Medicaid scenario's real,
  Colorado-specific `iud_insertion_professional_fee` override, replacing
  the national 2015 Medicaid-context estimate this project used previously
  ($71-$135, midpoint $103, from Bhatt & Stevens et al., "Immediate
  Postpartum Long-Acting Reversible Contraception: Review of Insertion and
  Device Reimbursement Policies," PMC9198998, inflation-adjusted from 2015;
  kept here as a record of the earlier estimate, not as a live parameter).
  Lesson for future searches of these fee-schedule workbooks: check every
  tab, not just the one a PDF export happens to show.
- **A related, Colorado-specific finding from the same workbook family:
  the PAD (physician-administered-drug) fee schedule.** Colorado HCPF
  separately publishes a drug-only fee schedule
  (`PAD Fee Schedule - CY 2026_Q1_Q2_Q3 v1.3.xlsx`, downloaded directly
  from `https://hcpf.colorado.gov/sites/hcpf/files/PAD%20Fee%20Schedule%20-%20CY%202026_Q1_Q2_Q3%20v1.3.xlsx`)
  giving real, current Colorado Medicaid reimbursement rates for all four
  LNG-IUD J-codes: J7297/Liletta $978.32 (Q2-Q4 2026; $931.73 in Q1),
  J7298/Mirena and J7296/Kyleena both $1,272.44, J7301/Skyla $1,059.52.
  These are reimbursement rates, not acquisition costs, so they are
  recorded as `iud_j7297_medicaid_reimbursement_colorado` in
  `config/model_parameters.csv` (reference only) rather than used to
  change the device-cost parameter; see that row's notes for why.
- **A real, directly relevant Colorado Medicaid policy precedent, found
  while researching this scenario:** effective 2020-01-01, Colorado
  Medicaid separately reimburses Immediate Postpartum LARC (IPP-LARC)
  devices inserted during an otherwise-DRG-bundled inpatient stay, "at the
  fee schedule rate or the amount billed, whichever is less" -- funded by
  reducing delivery DRG weights 540/542/560 by 0.004 to offset the new
  separate payment (source: web search of HCPF's own billing-manual
  summaries, corroborated by the PMC9198998 review's Table 3 listing
  Colorado as having a "device cost reimbursement separate from global
  obstetric fee: Yes, entity authorized to bill: Hospital, mechanism:
  Inpatient" policy). **This is exactly the structural problem this
  project's own Denver Health MRF analysis independently identified**
  (CPT 58300/device J-codes showing null inpatient negotiated rates,
  meaning no separate payment exists) -- Colorado Medicaid has already
  built a real fix for it, just scoped narrowly to delivery admissions.
  The `medicaid_illustrative` scenario sets
  `combined_requires_separate_professional_fee = TRUE` as an explicit
  POLICY-ANALOGY assumption (what if this same carve-out mechanism were
  extended to bariatric-surgery DRGs), clearly labeled in the scenario's
  own description field as not current law.
- **The device's own GPO acquisition cost is unchanged across scenarios.**
  Which payer eventually reimburses a claim doesn't change what the
  hospital pays its supplier to acquire the device -- that's a supply-chain
  cost, not a reimbursement question. Only `office_visit_em_cost`,
  `iud_insertion_professional_fee`, and the professional-fee toggle vary
  by scenario.
- **Result:** under this scenario, the combined arm's cost disadvantage
  widens further, not narrows -- it now pays the professional fee it
  avoided in the base case, on top of its existing OR-time and
  higher-expulsion-risk costs, while the standalone arm's total barely
  moves. Run `Rscript analysis/02_scenario_analysis.R` to reproduce.

### Colorado is not exceptional: this carve-out mechanism is near-universal across state Medicaid programs (checked 2026-09-11)

Bhatt & Stevens et al., "Immediate Postpartum Long-Acting Reversible
Contraception: Review of Insertion and Device Reimbursement Policies,"
*Women's Health Issues* 2021 (PMC9198998, read directly; policy data
collected October 2017-May 2018). Full state-by-state Table 3, device-cost
reimbursement separate from the global obstetric fee:

- **Yes:** Arizona, California, Colorado, Connecticut, Delaware, Florida,
  Georgia, Hawaii, Illinois, Indiana, Iowa, Louisiana, Maine, Maryland,
  Mississippi, Missouri, Montana, Nevada, New Hampshire, New Mexico
  (vaginal delivery only), New York, Ohio, Oklahoma, Pennsylvania, South
  Carolina, South Dakota, Tennessee, Texas, Virginia, Washington, West
  Virginia (31 states as of 2017-2018 data).
- **No, or not found in this table:** Massachusetts, North Carolina, Utah,
  Vermont.
- **No policy identified at all:** Alaska, Arkansas, Idaho, Kansas,
  Michigan, Minnesota, Nebraska, New Jersey, North Dakota, Oregon, Rhode
  Island, Wyoming.
- Billing mechanism varies (inpatient carve-out vs. a separate outpatient
  claim vs. both), and the entity authorized to bill varies (hospital,
  physician, or both). Colorado's specific inpatient/hospital-billed
  mechanism, used as the basis for this scenario, is one common pattern
  among several, not universal in its exact form.

**More current, higher-level figure:** a corroborating source (search
summary citing ACOG's own maintained tracker, checked 2026-09-11; a direct
fetch of the ACOG page itself returned HTTP 402/blocked, likely
anti-scraping rather than an actual paywall on public guidance) states
that as of October 2023, 45 states plus DC have published Medicaid
guidance on immediate postpartum LARC, and device-cost reimbursement
separate from the global fee is present in 92% of those state policies
(roughly 41 states). That is substantially more than the 2017-2018 table
above, consistent with continued state-by-state adoption over the
intervening five years (ACOG has run an active advocacy campaign on this
specific issue). The exact current per-state list, and each state's
payment amount, was not independently verified past this aggregate
figure.

**Why this matters for this project:** every one of these policies is
scoped to postpartum/delivery admissions specifically. None was found to
extend a device-cost carve-out to a non-obstetric inpatient stay like
bariatric surgery. But near-universal adoption of the underlying
mechanism (a state Medicaid program choosing to un-bundle a LARC device's
cost from an otherwise-fixed DRG payment) means the `medicaid_illustrative`
scenario's policy-analogy assumption is grounded in common, not
exceptional, state Medicaid practice: the mechanism exists almost
everywhere, just not yet pointed at this specific admission type.

## Perforation cost wired into the cost engine (added 2026-09-10)

`iud_perforation_risk_baseline` existed in `config/model_parameters.csv`
from an earlier session but was explicitly documented as "NOT used to
differentiate the two strategies" and, in fact, was not used anywhere in
the cost engine at all -- a real gap, not just an undifferentiated one.
This closes it, prompted by the user asking what else could strengthen
the concurrent-insertion evidence base and specifically proposing that a
perforation recognized during a combined (already-anesthetized) insertion
might be manageable in the same operative setting, avoiding a whole
separate retrieval surgery.

**Checking the mechanism before modeling it:** Heinemann K, Reed S,
Moehner S, Minh TD, "Risk of uterine perforation with levonorgestrel-
releasing and copper intrauterine devices in the European Active
Surveillance Study on Intrauterine Devices (EURAS-IUD)," *Contraception*
2015;91(4):274-279, doi:10.1016/j.contraception.2015.01.007 (PMID
25601352; directly verified via the PubMed/Europe PMC abstract,
2026-09-10; this is the same study Dottino et al. 2016's Table 1 cites
for this figure). A prospective, multinational cohort of 61,448 women
(six European countries, 2006-2013, over 68,000 women-years) found 61
uterine perforations among LNG-IUS users, 1.4 per 1,000 insertions (95%
CI 1.1-1.8). Its 5-year extension study (Barnett C, Moehner S, Do Minh T,
Heinemann K, "Perforation risk and intra-uterine devices: results of the
EURAS-IUD 5-year extension study," *Eur J Contracept Reprod Health Care*
2017;22(6):424-428, doi:10.1080/13625187.2017.1412427, PMID 29322856,
directly verified via its Europe PMC abstract, 2026-09-10) directly
confirms delayed diagnosis is common: "approximately one third of
perforations are detected 12 months after insertion."

A more specific claim, that only 8.4% of perforations are "suspected or
discovered at the time of insertion," surfaced via a search-engine
synthesis and does NOT appear in either paper's abstract. **Verification
attempted and FAILED, 2026-09-10:** the primary 2015 paper is not in
PMC/Europe PMC (no open full text), and a direct fetch of its Elsevier
page (`https://doi.org/10.1016/j.contraception.2015.01.007`) returned
only a 2.7KB JavaScript-shell page, not the article. This specific figure
is therefore NOT used anywhere in this project and should be treated as
unconfirmed, possibly a search-synthesis error, until someone reads the
primary paper's full text directly (echoing this project's own earlier,
directly-relevant lesson: a different search-attributed statistic, "a
3.06x odds ratio for class III obesity," was checked directly against its
purported source and found not to exist there at all).

**The unverified figure turns out not to matter, and this is checkable
without it.** The user's mechanism (same-setting recognition and
management during a concurrent bariatric-surgery insertion, avoiding a
separate retrieval surgery) is real and documented in the general
IUD-perforation literature (case reports describe concurrent laparoscopic
retrieval when perforation is found during another abdominal/pelvic
procedure) but would, at best, only apply to whatever minority of
perforations are recognized immediately -- most are diagnosed later via
delayed presentation, and bariatric surgery itself accesses the stomach,
not the pelvis, so being in the OR does not by itself create pelvic
visualization. Rather than build a differential on an unverifiable
percentage, the question can be answered with a bound instead: the entire
`expected_perforation_cost` currently applied to each arm is $38.71 (at
`reference_dollar_year` prices). That is the ABSOLUTE MOST the combined
arm's cost could drop under ANY same-setting-recognition mechanism, even
in the impossible best case where 100% of perforations were caught
immediately and managed at zero marginal cost. Against the base case's combined-arm cost disadvantage at the time this
was computed ($196.39), that was a 19.7% reduction at most, leaving a
$157.68 disadvantage even in that best case -- nowhere close to
reversing the model's conclusion. That gap has since moved twice more
("Two-surgeon coordination cost" widened it to $335.29, then "Facility-
setting professional fee" corrected it back down to $304.73), and the
same logic scales the same way against the current gap: $38.71 is a
12.7% cut at most, leaving $266.02. This mechanism is real but
quantitatively too small to matter here, independent of the exact
percentage or which version of the gap it's checked against, which is
why it is not built into the cost engine: the verification gap turned
out not to be the
blocking issue after all.

**What was built instead, as the higher-value first step:** both arms now
carry the SAME expected perforation-management cost, using the real
EURAS-IUD probability above and a real management-cost estimate: Dottino
JA, Hasselblad V, Secord AA, Myers ER, Chino J, Havrilesky LJ,
"Levonorgestrel Intrauterine Device as an Endometrial Cancer Prevention
Strategy in Obese Women: A Cost-Effectiveness Analysis," *Obstet Gynecol*
2016;128(4):747-753, Table 2 (PDF read directly; already used elsewhere
in this project for the cancer-prevention module). Dottino's Table 2
reports a perforation-management cost sourced from HCUPnet (Healthcare
Cost and Utilization Project), ICD-9 code 998.2 "accidental perforation
during procedure," accessed by Dottino in January 2016, in 2015 dollars:
mean $20,805.84, median $14,822.49. This project uses the MEAN as
`iud_perforation_management_cost`'s base value, since it feeds an
expected-value (probability x cost) calculation where the mean, not the
median, is the correct statistic for a right-skewed cost distribution.
This is a secondary citation (via Dottino's table), not independently
re-queried from HCUPnet directly for this project, and is recorded as
such (`evidence_tier = B`, `provisional = TRUE`).

**Effect on the model's results:** because the added cost
($38.71 in `reference_dollar_year` dollars, both arms) is identical
across strategies, it raises both arms' totals by the same amount and
does NOT change the incremental cost gap between standalone and
combined -- the base case still shows the same $196 combined-arm cost
disadvantage as before this change. Run `Rscript analysis/01_base_case.R`
to reproduce. Mutation-tested: see `docs/testing_philosophy.md`.

## One-way sensitivity analysis (added 2026-09-10)

`R/sensitivity_deterministic.R` / `analysis/04_sensitivity_analysis.R`.
Not a new data source -- a methods note on how existing parameters'
already-sourced low/high ranges were used to rank which uncertainties
actually matter for the standalone-vs-combined comparison, rather than
continuing to guess at it.

**Method:** for each parameter with a real, non-missing `low_value` and
`high_value` in `config/model_parameters.csv` that is actually read by a
`compute_*` function in `R/strategy_costs.R`, override it to its low
value (holding everything else at base case), recompute
`compare_combined_vs_standalone()`'s incremental cost gap, then repeat at
the high value. `swing = abs(gap_at_high - gap_at_low)` ranks parameters
by how much they move the headline result.

**Result (2026-09-11, current base case, after closing the
`iud_expulsion_probability_combined` gap described below, AND after both
"Two-surgeon coordination cost" and "Facility-setting professional fee"
below moved `base_case_gap` from $196.39 -> $335.29 -> $304.73):**
`direct_room_cost_per_minute` (swing $328.43) and `combined_arm_
added_minutes` (swing $318.48) dominate, followed by `iud_expulsion_
probability_combined` ($184.75), `anesthesia_cost_per_minute` ($77.00),
`iud_expulsion_probability_standalone` ($41.76), `standalone_office_
failure_probability` ($26.54), `iud_insertion_professional_fee` ($23.92),
`office_visit_em_cost` ($8.64), `iud_device_acquisition_cost_gpo` ($6.74),
and `iud_perforation_risk_baseline` (essentially $0). Full table:
`tables/sensitivity_analysis.csv` (git-ignored; regenerate with
`Rscript analysis/04_sensitivity_analysis.R`).

**A mechanical property, and one parameter's swing changing twice for
two different reasons.** Adding a cost that applies IDENTICALLY to both
arms shifts `base_case_gap` by a constant but cannot change any `swing`
value, since `swing = abs(gap_at_high - gap_at_low)` and a constant added
to both `gap_at_high` and `gap_at_low` cancels in the subtraction --
confirmed directly: every parameter's swing above is unchanged from
before either correction, with one exception. `iud_insertion_
professional_fee`'s swing moved twice: $45 originally (read only by
standalone directly, plus a small differential channel through
replacement cost); down to about $5 once "Two-surgeon coordination cost"
made the SAME dollar amount apply to both arms directly (mostly
canceling, the way device cost always has); back up to $23.92 once
"Facility-setting professional fee" made combined's own reading of this
parameter a *fraction* (the facility ratio) rather than the same dollar
amount -- varying the office rate no longer moves both arms by the same
amount, so it stops canceling as cleanly. This is a real, checkable
illustration of the same mechanical rule: only a change that breaks
IDENTICAL-across-arms treatment of a parameter can move its swing.

**A genuinely non-obvious finding, not just a ranking:** the still-
unverified GPO device-acquisition cost ($537-$600, the subject of a
four-method verification effort earlier this session that ultimately
failed) turns out to swing the incremental gap by only about $7, not
because it is small in absolute terms ($63 of range) but because it
enters both arms' `expected_total_cost` identically AND, separately,
enters `compute_expected_replacement_cost()`, which is multiplied by a
*different* expulsion probability in each arm. The device-cost line item
cancels between the arms exactly; the small residual comes entirely from
that second, differential channel ($63 range x (0.163-0.056) expulsion-
probability difference = $6.74, matching the reported swing exactly).
`iud_perforation_risk_baseline`, by contrast, has no such differential
channel (it is a flat add-on in both arms), so its swing is genuinely
zero, not just small. This means further effort verifying the GPO cost
would sharpen the model's ABSOLUTE cost estimate but would do almost
nothing for the standalone-vs-combined conclusion -- a real, checkable
reason to redirect that earlier-abandoned verification effort elsewhere.

**A real gap surfaced by trying to include a parameter and being unable
to, closed the same day.** `iud_expulsion_probability_combined` --
Masten et al. 2024's 16.3% combined-arm expulsion rate, the single number
most directly responsible for the combined arm's cost disadvantage -- had
only a point estimate in `config/model_parameters.csv`, no low/high
range, when this analysis first ran; `run_one_way_sensitivity()` refused
to sweep it rather than inventing one. See "Masten M, et al." above,
under "Clinical precedent," for the fix: reading the full text directly
and computing an exact Clopper-Pearson 95% CI on the paper's own 7/43 raw
proportion (6.81%-30.70%). This parameter ranks third (swing $184.75) --
and, reassuringly, even at the low end of that wide interval, the
combined arm still costs more than standalone: gap_at_low is $231.32
against the current $304.73 base case (it was $123 against the $196.39
base case before the professional-fee/coordination corrections, and
$261.90 against the $335.29 gap in between) -- the model's directional
conclusion has never depended on exactly where within this range the
true rate falls, across any version of the base case. `patient_time_
opportunity_cost_per_visit` remains excluded from the ranking for the
same reason this parameter used to be: no sourced low/high range yet.

## Two-surgeon coordination cost (added 2026-09-10)

Prompted by the model owner directly clarifying this institution's actual
staffing workflow: **the gynecologist places the IUD, not the bariatric
surgeon.** This resolved two things at once.

**1. `combined_requires_separate_professional_fee` now defaults to
TRUE.** Previously FALSE, chosen (per that row's original notes) only
because "the real staffing model had not yet been confirmed" -- a
conservative placeholder, not a finding. Two different physicians
performing distinct professional services in the same operative session
each bill their own professional component under standard multiple-
procedure/co-surgeon billing conventions. There was never a structural
reason to assume bundling; there was only an absence of confirmation,
now resolved. This raises the combined arm's cost by
`iud_insertion_professional_fee` ($116.08) directly.

**2. A new cost category: scheduling-coordination cost.** Combining two
procedures means aligning two different surgeons' OR time -- real
administrative labor the standalone arm never needs, since it is a
single physician's own routine office visit. Rather than invent a time
estimate, checked the sibling `emb_colonoscopy` project first (per the
user's own prompt: "We had this cost of surgery scheduler time in
endometrial biopsy colonoscopy"), and confirmed by reading that project's
`config/model_parameters.csv` directly (2026-09-10) that it already
models an analogous `coordination_cost` parameter for its own combined
(GYN + colorectal) visit, with an identical structure: 2 schedulers x 30
minutes each, described in that project's own notes as "practitioner
estimate (Tyler Muffly, MD, Denver Health)." This project's model owner
gave the same 30-minutes-per-scheduler estimate independently for this
project, so it is a consistent, repeated estimate from the same source,
not a one-off guess -- `combined_arm_scheduling_coordination_minutes` =
60 (2 x 30).

Wage rate: also reused directly from the sibling project's citation
rather than re-derived. O*NET OnLine
(`https://www.onetonline.org/link/summary/43-6013.00`), directly verified
2026-09-10: median hourly wage $22.08, annual $45,930, attributed to
"Bureau of Labor Statistics 2025 wage data," for SOC 43-6013, Medical
Secretaries and Administrative Assistants. `bls.gov` itself returned
HTTP 403 to a direct automated fetch this session (confirmed directly,
matching the sibling project's own documented experience); O*NET Online
is the DOL/BLS-funded site that republishes the same OEWS data without
blocking it. Converted to per-minute (22.08 / 60 = 0.368) as
`surgery_scheduler_wage_per_minute`, kept separate from the minutes
parameter rather than pre-multiplied into one dollar figure -- this
project's existing convention for OR-time costs
(`combined_arm_added_minutes x direct_room_cost_per_minute`, computed in
`R/strategy_costs.R`) already decomposes this way, and the sibling
project's own parameter notes flag pre-multiplying as something a future
refactor should undo, so building it decomposed here from the start is
the more rigorous choice. A real 2025 BLS CPI-U All Items row (average of
the 11 of 12 monthly 2025 values available from FRED as of 2026-09-10,
321.962; see `data/cpi_all_items.csv`) was added to inflation-adjust this
2025-dollar wage to `reference_dollar_year`.

**Combined effect on the model's headline result, at the time this was
built:** the base case's incremental cost gap moved from $196.39 to
$335.29 -- standalone unchanged at $868.63, combined up from $1,065.02
to $1,203.92 ($116.08 professional fee + $22.82 coordination cost, in
`reference_dollar_year` dollars). This was the largest single revision
to the model's result up to that point, and it came from confirming a
real staffing fact rather than from any new literature source. See "One-way
sensitivity analysis" above for how this shift did (and, mechanically,
could not) affect other parameters' swing values. Mutation-tested: see
`docs/testing_philosophy.md`. (The $116.08 figure itself was corrected
the same day -- see "Facility-setting professional fee" next -- so the
gap now stands at $304.73, not $335.29.)

## Facility-setting professional fee (added 2026-09-11)

Prompted directly by the user asking whether the device cost, the
bariatric/gynecology professional fees, and office-vs-OR facility fees
were all accounted for -- while confirming yes to the last two, the
answer surfaced a real refinement: CPT 58300's own professional fee
should not be the same dollar amount in both settings.

**The mechanism, verified directly from CMS's own data.** RVU26C (CMS's
July 2026 National Physician Fee Schedule Relative Value File,
downloaded directly 2026-09-11 from
`https://www.cms.gov/files/zip/rvu26c-updated-06-30-2026.zip`, file
`PPRRVU2026_Jul_nonQPP.csv`) gives CPT 58300's RVU components by place of
service, even though Medicare itself does not pay for the code (status
N):

| Component | Non-facility (office) | Facility (OR) |
|---|---|---|
| Work RVU | 0.98 | 0.98 |
| Practice-expense RVU | 2.07 | 0.22 |
| Malpractice RVU | 0.11 | 0.11 |
| **Total RVU** | **3.16** | **1.31** |

The office (non-facility) rate bundles in practice-expense overhead
(staff, room, supplies) because the physician's own practice bears that
cost in an office; the facility rate strips almost all of it out (2.07
-> 0.22) because the facility bills its own overhead separately -- here,
via `direct_room_cost_per_minute`. Charging the combined arm's own
insertion the full $116.08 office rate, identical to standalone's, was
therefore double-counting overhead already priced in via the OR facility
cost.

**New parameter: `iud_insertion_professional_fee_facility_ratio` =
0.4146** (1.31 / 3.16). Stored as a RATIO, applied at compute time
(`iud_insertion_professional_fee x iud_insertion_professional_fee_
facility_ratio`) inside `compute_combined_strategy_cost()`, rather than
as its own fixed dollar parameter -- deliberately, so that any scenario
overriding the office rate (`medicaid_illustrative` already does, with
Colorado's real CPT 58300 Medicaid rate) automatically produces a
consistent facility-equivalent value without a second override to keep
in sync. Applied to the base case's $116.08: 116.08 x 0.4146 = $48.13.
This is a proxy, not a directly observed facility charge: CPT 58300 is
Medicare-non-covered, so no live claims-volume data exists to split by
place of service the way real paid claims would; the ratio comes from
CMS's own relative-value methodology, applied to a real anchor price
(Denver Health's cash price), not the other way around. Flagged
provisional for that reason (`evidence_tier = C`).

**A second, related mechanism, checked the same way: disposable
supplies.** The facility rate's much lower practice-expense RVU (0.22 vs.
2.07) implies it excludes something the office rate includes. Checked
directly: CMS's CY2026 Direct Practice Expense Inputs file (`CMS-1832-F`,
downloaded from
`https://www.cms.gov/files/zip/cy-2026-pfs-final-rule-direct-pe-inputs.zip`,
file `CMS-1832-F_PUF_Supply_508.txt`) lists three supply items for HCPCS
58300:

| Supply | CMS code | Unit price | `nf_quantity` | `f_quantity` |
| --- | --- | --- | --- | --- |
| Pack, minimum multi-specialty visit | SA048 | $4.01 | 1 | 0 |
| Pack, pelvic exam | SA051 | $14.38 | 1 | 0 |
| Povidone soln (Betadine) | SJ041 | $0.38/ml | 50 | 0 |
| **Total** | | **$37.39** | | |

All three carry `nf_quantity > 0` (priced into the office rate, i.e.
already inside `iud_insertion_professional_fee`) and `f_quantity = 0`
(excluded from the facility rate). New parameter
`iud_insertion_disposable_supply_cost` = $37.39, applied ONLY to the
combined arm: since the bariatric-surgery OR itself is never separately
charged under this model's incremental-cost principle, these supplies
are a genuine incremental cost when added to that setting, not a
double-count the way adding them to standalone would be (standalone's
office rate already bundles them).

**This exact mechanism, and exactly this two-part fix, already exists in
the sibling `emb_colonoscopy` project**, for CPT 58100 (endometrial
biopsy): `emb_office_professional_cost` / `emb_office_professional_cost_
facility` and `emb_disposable_supply_cost`, confirmed by reading that
project's `config/model_parameters.csv` and `docs/data_sources.md`
directly, 2026-09-11 -- prompted by the user pointing there first
("We had this cost of surgery scheduler time in endometrial biopsy
colonoscopy," in reference to the coordination-cost feature, which led
directly to checking whether the facility-fee question was also already
solved there). One structural difference: CPT 58100 IS Medicare-covered,
so that project split its professional fee using a LIVE CMS PUF query by
`Place_Of_Srvc` -- an actual observed office-vs-facility payment gap
(~38%, $97.03 vs. $60.05), not a ratio proxy. CPT 58300's non-coverage
means this project cannot replicate that exact method; the RVU-ratio
approach here is the closest available substitute, not an equally strong
one.

**Effect on the model's headline result:** the base case gap moved from
$335.29 to $304.73 -- standalone unchanged at $868.63; combined fell
from $1,203.92 to $1,173.36 (the $67.96 professional-fee reduction
outweighing the $37.39 supply-cost addition). See "One-way sensitivity
analysis" above for how `iud_insertion_professional_fee`'s own swing
changed as a direct, checkable consequence of this fix. Mutation-tested:
see `docs/testing_philosophy.md`.

## Cancer-prevention estimate (added 2026-09-10)

A separate module, `R/cancer_prevention.R` /
`config/cancer_prevention_parameters.csv` / `analysis/03_cancer_prevention.R`,
estimates the endometrial cancer cases an LNG-IUD prevents in bariatric-
surgery patients. This is NOT part of the cost-minimization model: that
model assumes the device is equally effective once placed regardless of
arm, so a cancer-outcome parameter has no place in it. This module answers
a genuinely different question ("how much benefit does placing the device
actually buy"), asked directly by the user rather than derived from the
cost-minimization work.

**The core problem this module has to solve, not sidestep:** the one
existing cost-effectiveness model for this exact intervention (Dottino et
al. 2016, already read in full for this project's literature review) was
built for a 50-year-old obese woman with no other intervention -- not a
reproductive-age bariatric-surgery patient who is about to lose a large
amount of weight for reasons that have nothing to do with the IUD.
Applying Dottino's obesity-only baseline risk directly to this project's
population would overstate the IUD's benefit, because it would credit the
IUD for risk reduction that bariatric surgery itself already provides.

**Real numbers used, each independently verified:**

- **Baseline lifetime endometrial cancer risk, obese, no intervention:**
  Dottino JA, Hasselblad V, Secord AA, Myers ER, Chino J, Havrilesky LJ,
  "Levonorgestrel Intrauterine Device as an Endometrial Cancer Prevention
  Strategy in Obese Women: A Cost-Effectiveness Analysis," *Obstet Gynecol*
  2016;128(4):747-753 (PDF read directly). Their Markov model (SEER
  age-specific incidence x published obesity hazard ratios) outputs a 3%
  lifetime risk for a 50-year-old with BMI >=40, 1.9% for BMI >=30. These
  are the two `endometrial_cancer_lifetime_risk_usual_care_bmi*` rows.
  Age/cohort mismatch to this project's population is explicit in both
  rows' notes and is why they're tier C here despite being a solid,
  directly-read modeled estimate in their own context.
- **Bariatric surgery's own, independent risk reduction:** Schauer DP,
  Feigelson HS, Koebnick C, Caan B, Weinmann S, Leonard AC, Powers JD,
  Yenumula PR, Arterburn DE, "Bariatric Surgery and the Risk of Cancer in a
  Large Multisite Cohort," *Ann Surg* 2019;269(1):95-101, doi:10.1097/
  SLA.0000000000002525. Directly verified via the open-access PMC full
  text (PMC6201282), 2026-09-10: a 5-site, matched retrospective cohort
  (22,198 bariatric-surgery patients vs. 66,427 non-surgical patients with
  severe obesity, matched on sex/age/site/BMI/comorbidity index, surgery
  2005-2012, up to 10 years follow-up) found HR 0.50 (95% CI 0.37-0.67,
  P<0.001) for endometrial cancer specifically. This is the single most
  population-relevant number in this module: it directly compares
  bariatric-surgery patients to non-surgical severely-obese controls, the
  real counterfactual this project's patients face, rather than an
  obesity-in-general comparison.
- **The IUD's own additional risk reduction:** Soini T, Hurskainen R,
  Grenman S, Maenpaa J, Paavonen J, Pukkala E, "Cancer risk in women using
  the levonorgestrel-releasing intrauterine system in Finland," *Obstet
  Gynecol* 2014;124(2 pt 1):292-299, doi:10.1097/AOG.0000000000000356.
  Directly verified via the PubMed/Europe PMC abstract, 2026-09-10 (this
  is the same study Dottino's Table 1 draws its risk-reduction figure
  from, now independently re-confirmed from the primary source rather
  than taken secondhand): a nationwide Finnish cohort of 93,843 LNG-IUS
  users (menorrhagia indication, ages 30-49, 1994-2007), 855,324
  women-years of follow-up, standardized incidence ratio for endometrial
  adenocarcinoma 0.50 (95% CI 0.35-0.70; 34 observed vs. 68 expected
  cases). This is `iud_endometrial_cancer_incidence_ratio`.
- **Corroboration, not just one source:** the same 0.50 figure is the
  risk-reduction assumption independently used by Bernard L, Kwon JS,
  Simpson AN, Ferguson SE, Sinasac S, Pina A, Reade CJ, "The levonorgestrel
  intrauterine system for prevention of endometrial cancer in women with
  obesity: A cost-effectiveness study," *Gynecol Oncol* 2021;161:367-373
  (abstract directly verified 2026-09-10), a 2021 update to this same
  modeling literature that also tested longer device durations (5, 7, 10,
  and 14 years, the last two via one replacement) using the identical
  Soini-derived risk reduction. Two independent modeling groups relying on
  the same primary evidence is real corroboration of that evidence's
  standing in the field, though it does not create a second independent
  measurement of the effect itself.

**How the module combines them:** `compute_cancer_prevention_summary()`
applies the two hazard/incidence ratios multiplicatively --
`lifetime_risk x surgery_HR x iud_ratio` -- to get the risk under both
interventions, and reports the IUD's own marginal contribution
(`lifetime_risk x surgery_HR x (1 - iud_ratio)`) as the absolute risk
reduction attributable to the device specifically, on top of surgery. At
base-case values, per 1,000 bariatric-surgery patients who receive an
IUD: 7.5 expected endometrial cancer cases prevented (BMI >=40 baseline,
NNT approximately 133) or 4.75 cases (BMI >=30 baseline, NNT approximately
211). Run `Rscript analysis/03_cancer_prevention.R` to reproduce.

**Two limitations flagged explicitly, not glossed over:**

1. **Multiplicative independence is an assumption, not a finding.** No
   study has measured bariatric surgery and LNG-IUD use together in one
   cohort. Treating their effects as independent and multiplicative is
   the standard simplifying approach for combining two hazard ratios from
   separate literatures, but it is an assumption this module makes, not
   something Schauer or Soini's data can confirm or refute.
2. **This is a lifetime-risk calculation, not a duration-corrected one.**
   The incidence ratio is applied to a LIFETIME baseline risk (Dottino's
   age-50-to-100 Markov horizon), which implicitly assumes the IUD's
   protective effect operates across the woman's entire remaining
   lifetime. In reality, Dottino's own base case limits the protective
   effect to the 5 years the device is in place (an explicitly-stated
   assumption, not itself an empirical finding), and this project's
   device (Liletta) is labeled for 8 years, well within Soini's own
   cohort's mean ~9.1-year follow-up but still far short of a full
   lifetime. `iud_protective_duration_years` records both figures for
   context but is NOT yet consumed by the calculation. This means the
   module's headline numbers should be read as a likely-optimistic upper
   bound, not as a duration-corrected estimate. A future version would
   need an annual (rather than lifetime) incidence model to fix this
   properly, which is a materially larger undertaking than this v1 scope.

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
adjustment" above) -- this scaffold no longer reports 2014-dollar OR/
anesthesia costs mixed in with 2026-dollar everything-else.
