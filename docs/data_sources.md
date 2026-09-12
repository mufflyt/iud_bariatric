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
reversing the model's conclusion. That gap has since moved four times
more ("Two-surgeon coordination cost" widened it to $335.29, "Facility-
setting professional fee" corrected it down to $304.73, "Preop consent
visit for the combined arm" widened it to $430.13, "Postop results-
discussion cost" widened it again to $490.78), and the same logic
scales the same way against the current gap: $38.71 is a 7.9% cut at
most, leaving $452.07. This mechanism is real but
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
`iud_expulsion_probability_combined` gap described below, AND after
"Two-surgeon coordination cost," "Facility-setting professional fee,"
"Preop consent visit for the combined arm," and "Postop results-
discussion cost" below moved `base_case_gap` from
$196.39 -> $335.29 -> $304.73 -> $430.13 -> $490.78):**
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
combined arm still costs more than standalone: gap_at_low is $417.42
against the current $490.78 base case ($123 against the original
$196.39 base case, $261.90 against $335.29, $231.32 against $304.73,
$356.70 against $430.13 -- five different base-case values across this
session, and the low end of this interval has stayed positive against
every one of them) -- the model's directional conclusion has never
depended on exactly where within this range the true rate falls, across
any version of the base
case. `patient_time_
opportunity_cost_per_visit` remains excluded from the ranking for the
same reason this parameter used to be: no sourced low/high range yet.

## Probabilistic sensitivity analysis (added 2026-09-11)

`R/sensitivity_probabilistic.R` / `analysis/05_probabilistic_sensitivity_analysis.R`.
Not a new data source -- a methods note on how this project's existing
`config/model_parameters.csv` schema already carried a `distribution`
column (`triangular`, `gamma`, `fixed`) and `gamma_alpha`/`gamma_rate`
columns since the schema was first written, with no code ever
consuming them, until this analysis was built to be their first
consumer.

**Why a second sensitivity analysis, given the one-way analysis
above.** The one-way sweep answers "how much does the gap move if I
vary ONE parameter, holding every other parameter at its exact point
estimate." That is not the same question as "how uncertain is the gap
once every parameter varies AT ONCE, the way real joint uncertainty
actually behaves" -- a question a one-way sweep cannot answer by
construction, since it only ever moves one dimension at a time.

**Method.** Reuses `SENSITIVITY_PARAMETER_NAMES`
(`R/sensitivity_deterministic.R`) unchanged -- the same ten parameters
already vetted there as consumed by the cost engine with a real,
sourced low/high range; nothing new is swept that wasn't already
swept one-way. For each of the 10,000 draws, every parameter is
sampled simultaneously from its own distribution (see below),
`override_model_parameters()` applies all ten sampled values at once,
and `compute_incremental_gap()` is recomputed on that draw.

**Distribution fitting, by parameter's own `distribution` tag:**
- `triangular` (`iud_device_acquisition_cost_gpo`,
  `combined_arm_added_minutes`, `iud_expulsion_probability_standalone`,
  `standalone_office_failure_probability`): sampled directly from
  (`low_value`, `base_value`, `high_value`) via the standard
  inverse-CDF triangular formula -- no fitting required, since a
  triangular distribution's three parameters are exactly this
  project's own low/base/high columns.
- `gamma` (`iud_insertion_professional_fee`, `office_visit_em_cost`,
  `direct_room_cost_per_minute`, `anesthesia_cost_per_minute`): fit by
  the method-of-moments technique standard in health-economic PSA
  modeling (Briggs A, Claxton K, Sculpher M. "Decision Modelling for
  Health Economic Evaluation." Oxford University Press; 2006, ch. 4,
  the standard methods reference for exactly this step): `base_value`
  is treated as the target mean, `(high_value - low_value) / (2 *
  1.96)` as the standard error implied by treating low/high as a 95%
  CI's bounds, then `rate = mean / SE^2`, `shape = mean * rate`. This
  keeps the fitted gamma's mean exactly equal to `base_value` (a useful
  property: it means the PSA's average draw should land close to the
  deterministic base case purely as a consequence of correct fitting,
  which is exactly what was checked before trusting the result -- see
  below).
- `fixed` (`iud_expulsion_probability_combined`,
  `iud_perforation_risk_baseline`): held at `base_value` in every draw,
  zero variance. Both carry a real low_value/high_value range (used by
  the one-way sweep above), but their `distribution` column says
  `fixed`, not a probability-appropriate family like `beta` -- that tag
  is respected exactly as written here, not silently reinterpreted.
  Assigning either of them a beta distribution (the natural choice for
  a bounded probability, fit the same method-of-moments way) is a real,
  separate methodological decision that would need to be made
  deliberately by changing that CSV tag, not inferred from "well, it
  has a low/high value, so surely it should vary." Until that tag is
  changed, both parameters are correctly reported as NOT varied in this
  PSA, matching the CSV's own stated intent.

**NOT varied: `cancer_prevention_parameters`.** This PSA is scoped, like
the one-way analysis, to `expected_total_cost`'s
`incremental_cost_vs_standalone` -- which never consumes
`cancer_prevention_parameters` at all (only
`expected_cost_per_referred_patient` does, via
`expected_missed_cancer_prevention_cost`; see `R/strategy_costs.R`).
Extending this PSA to that second metric would require sourced
low/high ranges for `endometrial_cancer_lifetime_risk_usual_care_bmi40`,
`endometrial_cancer_death_risk_usual_care_bmi40`, and
`endometrial_cancer_treatment_cost`, none of which exist yet -- not
attempted here rather than inventing plausible-looking ranges for them.

**Sanity check performed before trusting the result:** with the gamma
fit's mean forced to equal `base_value` exactly, and the triangular
mean close to its own mode, the simulation's `mean_gap` should land
close to the deterministic `base_case_gap` purely as a property of
correct fitting -- confirmed directly (`tests/testthat/
test-sensitivity-probabilistic.R`): at 1,000 draws, `mean_gap` matched
`base_case_gap` within $0.10 relative tolerance. This does not prove
the simulation is doing anything meaningful, but it does rule out a
whole class of fitting bugs (a systematically biased distribution would
show up here as a persistent, seed-independent drift away from the
deterministic value).

**Result (10,000 draws, seed 20260911, `tables/psa_summary.csv` and
`tables/psa_draws.csv`, both git-ignored -- regenerate with `Rscript
analysis/05_probabilistic_sensitivity_analysis.R`):** against the
current $490.78 base case, the simulated gap has a mean of $477.82,
median $463.42, standard deviation $111.55, and a 95% simulation
interval of $304.49 to $736.26. **Standalone was cheaper in all 10,000
draws (100%).** The standalone-vs-combined conclusion holds across the
full joint uncertainty this project's own sourced parameter ranges
describe, not just at the single base-case point estimate.

Mutation-tested; see `docs/testing_philosophy.md`.

## Opportunity cost of a displaced case: checked, real, not quantifiable here (added 2026-09-12)

Prompted directly: if adding 10 minutes to a bariatric-surgery case for
IUD placement (or adding time to a colonoscopy for endometrial biopsy,
in the sibling `emb_colonoscopy` project) means the OR/procedure suite
can't fit in another case that day, is that lost-case cost priced
anywhere? Checked directly rather than assumed either way.

**Confirmed: not currently captured, and the source paper itself says
so explicitly.** `direct_room_cost_per_minute` ($20.90/minute, 2014
dollars) is Childers CP, Maggard-Gibbons M. "Understanding Costs of
Care in the Operating Room." *JAMA Surg.* 2018;153(4). Verified
directly via the open-access PMC full text (PMC5875376), 2026-09-12.
The paper defines "direct costs" as "costs attributable to the revenue
center, such as staff salaries or supplies" -- $20.40 of $37.37 total
per minute in the inpatient setting (54.6%), with wages/benefits
dominating direct costs (~two-thirds). It separately and explicitly
addresses the exact question asked here, under its own "opportunity
cost" discussion, and says plainly that this is NOT included in the
direct-cost figure: "If saving time allows the OR to schedule an
additional case, this potential revenue should be included as a cost.
Opportunity costs vary and are likely to be highest for short
operations (i.e., myringotomy or cataract surgery), where scheduling
additional cases is more likely. However, opportunity cost requires a
case to be profitable, which, in many circumstances, depends primarily
on payer mix." The paper's own indirect-cost analysis further notes
that reducing OR time has "little effect on the overall price of the
operation" once indirect (largely fixed) costs are considered --
consistent with, but a distinct point from, the case-displacement
opportunity cost asked about here.

**Searched directly for whether a real, generalizable per-minute or
per-hour opportunity-cost figure exists anywhere in the published
literature, specifically so as not to assume "no data exists" without
checking.** Two primary sources found and verified:
- Macario A, Dexter F, Traub RD. "Hospital profitability per hour of
  operating room time can vary among surgeons." *Anesth Analg.*
  2001;93(3):669-675. Directly verified via the Europe PMC abstract,
  2026-09-12. Stanford University School of Medicine, 2,848 elective
  surgical cases across 94 surgeons. Contribution margin per OR-hour
  was NEGATIVE for 26% of cases, with substantial (Cohen's f = 0.29)
  surgeon-to-surgeon variability. Conclusion: hospitals should "increase
  the hours of lucrative cases, rather than encourage surgeons to do
  more and more cases" -- i.e. the field's own classic reference on this
  exact quantity treats it as inherently case-specific and
  payer-mix-specific, not a rate that generalizes across settings.
- Saporito A, La Regina D, Perren A, Gabutti L, Anselmi L, Cafarotti S,
  Mongelli F. "Contribution margin per hour of operating room to
  reallocate unutilized operating room time: a cost-effectiveness
  analysis." *Braz J Anesthesiol.* 2023;73(3):243-249.
  doi:10.1016/j.bjane.2021.03.024. Directly verified via the Europe PMC
  abstract, 2026-09-12. A Swiss hospital, ten procedure types, 14.5
  hours of reallocated unused OR capacity: prioritizing by
  contribution-margin-per-hour raised earnings from $87,117 to $140,444
  over the study period versus random allocation. Confirms the same
  underlying variability in a newer, different-country cohort, but
  reports only portfolio-level reallocation revenue across ten
  heterogeneous procedures, not a single per-minute or per-hour rate
  usable as a model parameter, and is not U.S.-health-system data
  (inconsistent with this project's CMS-anchored, U.S.-payer-mix basis
  used everywhere else).

Neither study, nor any other found, isolates this figure for bariatric
surgery specifically, or for an endoscopy/colonoscopy suite
specifically -- both are general OR-economics studies from single
institutions, decades apart, agreeing on one thing: the quantity is too
variable (by surgeon, case type, and payer mix) and too often negative
to serve as a stable rate.

**Decision: not built into either project's cost engine.** Compressing
a quantity the field's own primary literature reports as negative over
a quarter of the time, and varying by more than an order of magnitude
by surgeon, into a single low/base/high parameter would be exactly the
kind of fabricated precision this project's parameter discipline exists
to avoid -- there is no honest single number to write into
`config/model_parameters.csv` here. Documented instead as a real,
checked, and deliberately unquantified limitation.

**A real asymmetry between the two sibling projects, worth flagging
even though neither can act on it yet.** Childers's own paper says
opportunity cost is "likely to be highest for short operations... where
scheduling additional cases is more likely" -- a description matching
colonoscopy (15-30 minute slots, high daily throughput) far better than
bariatric surgery (60-120+ minute cases, typically 1-3 per OR day,
where a 10-minute overrun is far less likely to literally displace an
entire additional case). This suggests the gap is more consequential
for `emb_colonoscopy` than for this project, even though neither has a
sourced number to close it with. Checked directly: `emb_colonoscopy`
has the identical gap (same Childers `direct_room_cost_per_minute` and
`procedure_room_cost_per_minute` figures, no opportunity-cost parameter
either) -- see that project's own `docs/data_sources.md` for the
mirrored entry.

### Follow-up: real payer-specific data was found, and a bounded estimate was built (2026-09-12)

Prompted directly: rather than stop at "no generalizable rate exists,"
try to assemble the actual payer-specific pieces (Medicare/Medicaid/
commercial reimbursement, a real cost estimate, and this hospital's
payer mix) and see how far real data can go. It went far enough to
produce an honest, checkable, if bounded, answer.

**Medicare payment for the relevant DRG, computed directly from primary
CMS sources, not a secondary paraphrase.** Downloaded and parsed
directly, 2026-09-12:
- `https://www.cms.gov/files/zip/fy2026-ipps-fr-table-5.zip` (CMS FY2026
  IPPS Final Rule Table 5): MS-DRG 621, "O.R. PROCEDURES FOR OBESITY
  WITHOUT CC/MCC" (the routine, no-complication case -- the
  most-representative DRG for an elective, uncomplicated bariatric-
  surgery patient), relative weight **1.5084**. (DRG 619, WITH MCC,
  weight 2.8874; DRG 620, WITH CC, weight 1.6003 -- both also confirmed
  directly, but not used here since this project models the routine
  case.)
- DataGen/Wisconsin Hospital Association, "Medicare IPPS Final Rule
  Payment Brief, Federal Fiscal Year 2026" (citing the August 4, 2025
  Federal Register final rule, CMS-1833-F): FFY 2026 Federal Operating
  Rate **$6,752.61**, Federal Capital Rate **$524.15**.
- Payment = (6752.61 + 524.15) x 1.5084 = **$10,976.27**. This
  independently reproduces (to the dollar) a secondary-source figure a
  prior search pass had found but could not verify ("$10,976, CY2026
  unadjusted national average") -- a strong cross-check that the
  calculation method is right, now backed by a from-scratch computation
  against the primary CMS tables rather than trusting that secondary
  claim on its own. Deliberately UNADJUSTED for hospital-specific wage
  index, IME, DSH, or outlier payments -- Denver Health's actual
  payment for this DRG would differ from this national base-rate
  figure; that adjustment was not pursued further given the bounding
  (not precision) purpose of this exercise.

**National cost, from a large, recent, methodologically standard
source.** Ng AP, Bakhtiyar SS, Verma A, et al. "Cost Variation in
Bariatric Surgery Across the United States." *Am Surg.*
2023;89(10):4061-4065. doi:10.1177/00031348231177937. PMID 37203440.
Directly verified via Europe PMC, 2026-09-12. 2016-2019 Nationwide
Readmissions Database (HCUP), 687,866 patients across 2,435 hospitals,
costs derived via HCUP's standard cost-to-charge-ratio methodology
(NOT charges). National case mix: 69.9% sleeve gastrectomy, 30.1%
gastric bypass. Median cost: sleeve $10,900 (IQR $8,600-$14,000);
bypass $13,600 (IQR $10,300-$18,000). Blended by the paper's own case
mix: 0.699*10900 + 0.301*13600 = **$11,711.70**; blended IQR bounds
(same weights applied to each procedure's own IQR bound, an
approximation, not a true joint IQR): $9,111.70 to $15,204.00.

**Resulting Medicare-payer contribution margin: -$735.43 (NEGATIVE).**
$10,976.27 (payment) - $11,711.70 (cost) = -$735.43. This is a real,
checkable finding, not an assumption -- and it is directly consistent
with the general OR-economics literature already cited above (Macario
et al. found contribution margin negative for 26% of cases generally;
Medicare specifically is well known in the broader hospital-margin
literature, e.g. MedPAC's annual reports, to run negative on average
across most inpatient service lines).

**Typical case duration, to convert the case-level margin into a
per-minute rate.** Young MT, Gebhart A, Phelan MJ, Nguyen NT. "Use and
Outcomes of Laparoscopic Sleeve Gastrectomy vs Laparoscopic Gastric
Bypass: Analysis of the American College of Surgeons NSQIP." *J Am Coll
Surg.* 2015;220(5):880-885. Directly verified via Europe PMC,
2026-09-12. n=24,117 (a different, earlier cohort than Ng et al. 2023,
with a different case mix: 20.5% sleeve/79.5% bypass here, vs. Ng's
69.9%/30.1% -- reflecting bariatric surgery's real shift toward sleeve
gastrectomy over time between the two cohorts). Mean operative time:
sleeve 101 minutes, bypass 133 minutes. Blended using Ng et al. 2023's
more current case-mix weights (a real, flagged simplification --
combining two different studies' data rather than one study measuring
both): 0.699*101 + 0.301*133 = **110.6 minutes**.

**Denver Health's actual payer mix, so the Medicare-payer calculation
above can be put in context.** An American Hospital Association case
study, citing Colorado's 2023 Hospital Expenditure Report, directly
verified 2026-09-12: 83% of Denver Health discharges are Medicare,
Medicaid, or uninsured combined; uninsured specifically = 15.9% of
total care. By subtraction, commercial/other is approximately 17%. The
underlying primary Colorado Hospital Expenditure Report itself was not
independently retrieved and cross-checked -- this is a secondary
citation of it, flagged as such.

**The calculation, and its explicit limitation.** Margin ($-735.43) /
typical case minutes (110.6) = -$6.65/minute; x
`combined_arm_added_minutes` (10) = **-$66.49**, with a range of
-$382.25 to +$168.59 across Ng et al.'s cost IQR (a wider cost range
means a wider margin range: the low-cost bound gives the highest
opportunity-cost estimate, +$168.59; the high-cost bound gives the
lowest, -$382.25). Implemented in
`R/opportunity_cost_sensitivity.R`'s `compute_bounded_displaced_case_
opportunity_cost()`, mutation-tested (see `docs/testing_philosophy.md`),
and NOT called anywhere in the base-case cost engine or either
sensitivity module -- confirmed by a dedicated regression test that
perturbing this exercise's inputs leaves `expected_total_cost`
unchanged. The linear, dollars-per-minute treatment is an explicit
SIMPLIFYING ASSUMPTION, spelled out in the function's own docstring:
the real mechanism is a discrete threshold (10 added minutes either
does or does not push a whole case off the day's schedule), not a
smooth, continuously-accruing cost. This bound should be read as an
order-of-magnitude check, not a precise dollar figure.

**Bottom line.** Even after assembling the best available real,
payer-specific data (rather than stopping at "no generic rate exists"),
the honest finding is that the opportunity cost of the combined arm's
added minutes is small and plausibly negative for roughly 83% of this
hospital's actual bariatric-surgery case volume. This reinforces,
now with real numbers rather than only a literature-based argument,
the earlier decision not to add a large opportunity-cost line item to
the base case. The remaining ~17% (commercial-payer) share of Denver
Health's case mix is NOT quantified: no verified bariatric-surgery-
specific commercial negotiated rate was found for this or any hospital,
despite direct attempts (Denver Health's own CMS machine-readable file
exists but is a large binary spreadsheet that could not be parsed in
this pass; a Colorado HCPF Medicaid base-rate file was similarly
located but not successfully downloaded). Both remain genuine, flagged
next steps, not resolved gaps papered over.

### CORRECTION: the above negative-margin finding was superseded once real hospital-specific rates were obtained (2026-09-12)

The section above stands as written (not deleted) because it documents
real reasoning and a real dead end at the time -- but its bottom line
was wrong, in a specific, findable way: it used a GENERIC NATIONAL
Medicare rate as a proxy for what Denver Health actually gets paid.
Told directly to work harder on the two flagged gaps above (Denver
Health's binary MRF, the located-but-undownloaded HCPF file), both were
obtained on a second attempt using different tooling (a direct `curl`
download of the actual current CSV machine-readable file, and a
browser-User-Agent-plus-Referer `curl` request for the HCPF Excel
files, which a plain fetch had been blocked from retrieving) -- neither
gap was actually unobtainable, just under-tried the first time.

**Denver Health's own Medicare rate, from its own current
price-transparency file.** Downloaded directly, 2026-09-12:
`https://sthpiprd.blob.core.windows.net/machine-readable-files/7840/841343242_denver-health-and-hospital-authority_standardcharges.csv`
(same file already used elsewhere in this project for
`iud_device_chargemaster_cash_price` and `iud_insertion_professional_fee`;
this download, file dated 2026-04-30, is 199 MB). Filtered to MS-DRG
621 ("O.R. PROCEDURES FOR OBESITY WITHOUT CC/MCC"), inpatient setting:
three independently-listed payer rows -- `CMS`/`Medicare`, `Aetna
Healthcare`/`Medicare Advantage`, and `Denver Health Medical Plan`/
`Medicare Advantage` -- all converge on the identical negotiated case
rate, **$27,902.21**. That convergence across three separately-reported
rows is a real internal-consistency signal that this is a genuine,
hospital-specific (wage-index, IME, and DSH-adjusted) Medicare payment
for this DRG, 2.5x the generic national-unadjusted figure computed
above -- exactly the kind of hospital-specific adjustment (Denver
Health is an urban teaching hospital with a very high DSH percentage as
a safety-net institution) that a national base-rate calculation cannot
capture.

**Colorado Medicaid's rate, computed from Denver Health's own current
base rate and the matching APR-DRG weight.** Both downloaded directly,
2026-09-12, using a browser User-Agent and a `Referer` header set to
`https://hcpf.colorado.gov/inpatient-hospital-payment` (a plain
unauthenticated fetch of these same URLs returns HTTP 403; this header
combination succeeded where a plain fetch had failed):
- `https://hcpf.colorado.gov/sites/hcpf/files/Inpatient%20Base%20Rates%20effective%207.1.2026.xlsx`,
  sheet "7.1.26 IP Hospital Base Rates": Denver Health Medical Center
  (Medicare ID 060011), APR-DRG Inpatient Base Rate effective 7/1/2026
  = **$7,966.93**.
- `https://hcpf.colorado.gov/sites/hcpf/files/Oct%201%202024%20-%20All%20Patient%20Refined%20Diagnosis%20Related%20Group%20APR-DRG%20Ver%2040%20Weight%20Table%20-%20CGS%20setting%20fixed%203.11.25.xlsx`,
  sheet "V40 CO WT TBL EFF 10.1.2024": APR-DRG 403 "PROCEDURES FOR
  OBESITY", Severity of Illness (SOI) level 1 (minor -- the routine,
  no-complication case, the closest APR-DRG analog to MS-DRG 621's
  "without CC/MCC"; APR-DRG and MS-DRG are different classification
  systems, not directly interchangeable, so this is an analog choice,
  not a formal crosswalk), final scaled weight **1.472**.
- Payment = 7966.93 x 1.472 = **$11,727.32** -- coincidentally almost
  identical to Ng et al. 2023's national cost estimate ($11,711.70),
  though this is a payment figure and that is a cost figure, so the
  near-match is a numerical curiosity, not evidence of anything.

**Commercial rates, from the same current Denver Health file.** Five
real, payer-specific negotiated inpatient case rates for MS-DRG 621
(HMO/POS/PPO plans, excluding Medicare Advantage products, which were
folded into the Medicare figure above since both MA rows found matched
the traditional-Medicare rate exactly): Aetna Healthcare $26,000.00;
Anthem Blue Cross Blue Shield $32,121.00; Cigna Healthcare $32,927.04;
United Healthcare $34,230.00; Denver Health Medical Plan Elevate
$39,263.99. Mean = **$32,908.41**.

**A more granular payer-mix split**, from the same AHA case study as
before, this time combining two of its statements rather than just one:
"83% of Denver Health discharges are Medicare, Medicaid, or uninsured
combined" and, separately, "more than 65% of Denver Health's patients
are either covered by Medicaid or are uninsured," with uninsured
specifically stated as 15.9%. By subtraction: Medicaid ≈ 65% - 15.9% =
**49.1%**; Medicare ≈ 83% - 65% = **18%**; commercial/other = 100% - 83%
= **17%** (exact, since 83% itself is exact). The Medicare and Medicaid
fractions carry a real approximation caveat the uninsured and
commercial fractions do not: they are derived from "more than 65%," a
stated lower bound, not an exact value -- flagged explicitly in
`config/model_parameters.csv`'s notes for both parameters.

**The corrected calculation.** Payer-mix-weighted revenue = (27902.21 x
0.18) + (11727.32 x 0.491) + (32908.41 x 0.17) = **$16,374.94**
(uninsured's ~15.9% share is implicitly assigned $0 net revenue, a
standard conservative simplification consistent with Denver Health's
own reported $136 million 2024 uncompensated-care cost). Against Ng et
al. 2023's same national cost estimate used in the first pass
($11,711.70), the contribution margin is **+$4,663.24 -- POSITIVE**, a
sign flip from the first pass's -$735.43. Spread across the same
110.6-minute typical case as before, the combined arm's 10-minute
add-on now implies an opportunity cost of **+$421.63** (range
$105.87-$656.71 across Ng et al.'s cost IQR).

**What changed, and what didn't.** The mechanism (revenue minus cost,
per minute, times added minutes, as a linear approximation of a
discrete threshold effect) is unchanged from the first pass; only the
REVENUE inputs improved, from one generic national rate to three real,
hospital-specific, payer-specific rates properly weighted by this
hospital's own payer mix. The weakest link in the calculation is now
the COST side: `bariatric_blended_national_cost_ng2023` remains a
national proxy, since no Denver-Health-specific cost figure was found
in either research pass. `bariatric_medicare_drg621_national_payment`
(the original $10,976.27 figure) is retained in
`config/model_parameters.csv`, unconsumed by the corrected function, as
a documented before/after comparison point -- concrete evidence of how
much a generic national base rate can understate a specific safety-net
teaching hospital's actual reimbursement.

Implemented in `R/opportunity_cost_sensitivity.R`'s
`compute_payer_mix_weighted_revenue()` and the updated
`compute_bounded_displaced_case_opportunity_cost()`, mutation-tested
(see `docs/testing_philosophy.md`), still confirmed NOT called anywhere
in the base-case cost engine or either sensitivity module. `Rscript
analysis/06_opportunity_cost_sensitivity.R` reproduces the full
calculation.

## Illustrative national sweep across states: three real, stacked approximations (added 2026-09-12)

Prompted directly: "can we use the same approach and go nationally getting the same numbers for each state?" Answered honestly rather than either refusing or quietly producing a false-precision table: literally repeating the Denver Health deep-dive is not practical for 50 states (Medicaid has no single national methodology; commercial rates are hospital-specific, not state-level), so this uses real national datasets instead, each with its own real limitation, documented here so the sweep is read for what it is.

**Leg 1: Medicare, genuinely national and current.** Downloaded directly, 2026-09-12: `https://www.cms.gov/files/zip/fy2026-ipps-fr-tables-2-3-4a-4b.zip` (CMS FY2026 IPPS Final Rule Tables 2-3-4A-4B), Table 2's "FY 2026 Wage Index With Cap" column, one row per hospital (CCN), joined to state via each row's own FIPS county code. Computed a simple (unweighted) mean wage index per state across 3,253 hospitals in 52 states/territories (`data/medicare_wage_index_by_state_fy2026.csv`). Applied to the same operating/capital base-rate formula already verified for the national DRG 621 payment (`medicare_ipps_operating_base_rate_fy2026` $6,752.61, `medicare_ipps_capital_base_rate_fy2026` $524.15, `medicare_drg621_relative_weight` 1.5084, labor-related share 66% above a wage index of 1.0 or 62% at or below it, all from the same DataGen/WHA Final Rule brief already used). Capital is NOT geographically adjusted (the true capital GAF calculation is more complex and was not pursued) -- a real, flagged simplification.

**Sanity check that also demonstrates this leg's real limitation.** At wage_index = 1.0 exactly, this formula reproduces `bariatric_medicare_drg621_national_payment` ($10,976.27) almost exactly (within half a cent) -- confirming the formula is implemented correctly. But Colorado's own STATE-AVERAGE wage index (1.0563) produces an estimate of only **$11,354.74** -- just 41% of Denver Health's own real, MRF-reported rate ($27,902.21). This is not a bug; it is the whole point being demonstrated directly: a state-average, hospital-generic formula cannot capture what a specific safety-net teaching hospital's IME and DSH adjustments actually add on top of the wage index alone. Every other state's Medicare figure in this sweep carries the same kind of understatement for whichever of its hospitals resembles Denver Health.

**Leg 2: Medicaid, real but stale and not state-specific here.** MACPAC (Medicaid and CHIP Payment and Access Commission), "Medicaid Hospital Payment: A Comparison across States and to Medicare," Issue Brief, April 2017. Downloaded and read directly, 2026-09-12 (`macpac.gov/wp-content/uploads/2017/04/`). Built from CY2010 Medicaid Analytic Extract (MAX) claims, FY2011 Medicare payment data, and CY2010-2012 CMS-64 supplemental-payment data -- **16 years old as of this writing**, and MACPAC's own more recent work (a Technical Expert Panel convened as of September 2024) confirms no updated version exists yet. The report DOES give real state-specific index values (Figure 1: a bar chart ranging from 0.49 in New Hampshire to 1.69 in DC), but only as a chart image, not a downloadable table -- extracting precise per-state numbers from bar heights would not meet this project's precision standard, so those state-specific values were NOT used. Instead, the report's single NATIONAL summary statistic was used: "after accounting for supplemental payments and provider contributions... the average Medicaid net payment was 6 percent higher than Medicare across the 18 [selected high-volume] MS-DRGs" -- `national_medicaid_to_medicare_net_ratio` = 1.06, applied uniformly to every state's own Medicare figure from Leg 1. One reassuring cross-check: Colorado's own real, directly-computed Medicaid rate (`bariatric_denver_health_medicaid_rate` / `bariatric_denver_health_medicare_rate` = 11727.32/27902.21 = 1.068) sits close to this 1.06 national ratio -- but that is one data point corroborating the ratio for one state, not proof it generalizes to the other 51.

**Leg 3: commercial, current but already known to disagree with real data.** RAND Corporation, "Prices Paid to Hospitals by Private Health Plans: Findings from Round 5.1 of an Employer-Led Transparency Initiative" (Chapin White, Christopher Whaley, et al.), 2024, 2022 claims data from >4,000 hospitals in 49 states (all except Maryland). Directly verified, 2026-09-12: "employers and private insurers paid on average 254 percent of what Medicare would have paid for the same services at the same facilities" for inpatient hospital facility services -- `national_commercial_to_medicare_ratio` = 2.54. **This is the weakest leg, and demonstrably so**: Denver Health's own real, verified commercial rate for this exact bariatric-surgery DRG (`bariatric_denver_health_commercial_mean_rate` / `bariatric_denver_health_medicare_rate` = 32908.41/27902.21 = 1.18, i.e. 118%) is well under half of RAND's national average. RAND's own report shows real state-level variation from 162% (Arkansas) to 346% (Florida), which a single national ratio cannot capture either way -- a downloadable state-by-state RAND table was searched for directly (their Round 5 project page) and not found; only the aggregate figures and named state extremes are publicly stated in the text. RAND's broad "all hospital services" basket evidently does not represent this one specific, flat-case-rate-negotiated procedure well, at least not at the one hospital where a real comparison is possible.

**Payer mix: Denver Health's own, applied uniformly.** No national or state-specific bariatric-surgery-specific payer-mix dataset was sought or found; `denver_health_payer_mix_medicare_fraction` / `_medicaid_fraction` / `_commercial_fraction` (already documented above) are applied to every state in this sweep, even though most U.S. hospitals are not safety-net institutions with Denver Health's heavy Medicare/Medicaid skew.

**Result (52 states/territories, `tables/opportunity_cost_national_by_state.csv`, git-ignored -- regenerate with `Rscript analysis/07_opportunity_cost_national.R`):** implied opportunity cost of the 10-minute add-on ranges from -$367.36 to +$401.64, with 42 of 52 positive. **This range should be read as an illustrative, order-of-magnitude sweep across Medicare's real geographic wage variation -- not as 51 independently-verified state-specific answers the way the single Denver Health figure is.** Every leg beyond Medicare's wage index carries a real, demonstrated (not merely theoretical) reason to distrust its precision for any individual state.

Implemented in `R/opportunity_cost_national.R`, mutation-tested (see `docs/testing_philosophy.md` -- this mutation-test cycle also caught a real bug in the test suite itself: an overly loose relative tolerance that let a genuine $85.50 error pass undetected on one state while only a larger error on a different state was caught, fixed before being trusted). Confirmed NOT called anywhere in the base-case cost engine or either sensitivity module.

## Better data: real rates at 9 more hospitals, replacing the borrowed national ratios (added 2026-09-12)

Prompted directly: "We need better data to nail this down." Rather than accept the illustrative sweep's borrowed national ratios as the final word, the Denver Health method itself -- pull a hospital's own CMS price-transparency file, plus that state's own Medicaid rate methodology and files -- was repeated for 9 more hospitals, one per state, chosen for a mix of wage-index extremes, RAND's own named commercial-ratio extremes (Arkansas lowest, Florida highest), and large/prominent academic medical centers. All figures below are for MS-DRG 621 ("O.R. Procedures for Obesity Without CC/MCC"), inpatient setting, downloaded and parsed directly, 2026-09-12, exactly as done for Denver Health. Full results, including every payer row found (not just the summary figures used here), are preserved in `data/bariatric_drg621_multi_hospital_rates.csv`.

**Georgia -- Emory University Hospital, Atlanta.** MRF: `emoryhealthcare.org/-/media/Project/EH/Emory/ui/pricing-transparency/csv/2026/580566256_1588640692_emory-university_standardcharges.csv`. No traditional FFS Medicare line; Medicare Advantage cluster (Aetna $15,651.04, Cigna HealthSpring $15,804.48, several others $15,344.16-$16,264.81) averages **$15,766.12**. Nine commercial payer rows (Aetna $23,774.55 to Ambetter Exchange $32,529.62) average **$25,927.51**. Medicaid: Georgia DCH's own SFY2026 provider base rate for Emory University Hospital, $7,932.13 (`dch.georgia.gov/document/document/sfy-2026-provider-base-rates-ccr/download`), times APR-DRG 403 SOI-1 relative weight 1.38 (`dch.georgia.gov/document/document/drgweightsoutlierthresholdsrebase2024/download`) = **$10,946.34**.

**Texas -- Houston Methodist Hospital, Houston.** (Parkland Health's MRF was tried first: downloaded successfully but contains zero MS-DRG 619/620/621 rows at all -- a real finding, not an extraction failure. UT Southwestern's transparency page routes through a JS portal not resolvable via `curl`.) MRF: `houstonmethodist.org/-/media/files/patient-resources/74110155_the-methodist-hospital_standardcharges.ashx`. Medicare Advantage cluster (Aetna $13,761.10, BCBS $13,557.73, UHC $13,828.88) averages **$13,715.90**. Six commercial rows (Aetna $18,089.00 to Humana $55,560.13) average **$32,233.48**. Medicaid: Texas HHSC's APR-DRG methodology, Houston Methodist's SFY2027 urban Standard Dollar Amount ($2,993.72 base + $432.10 wage-index + $338.23 IME = $3,903.26, `tmhp.com`) times APR-DRG 403 SOI-1 weight 1.392 = **$5,433.34** -- notably lower than every other state's Medicaid figure here, flagged as a real methodology difference (Standard Dollar Amount vs. provider-specific base rate), not corrected or second-guessed.

**Florida -- Tampa General Hospital, Tampa.** MRF: `tgh.org/-/media/files/patients-and-visitors/593458145_tampa-general-hospital_standardcharges.csv`. No FFS Medicare line; Medicare Advantage fee-schedule proxy modal value **$16,149.59**. Sixteen commercial rows ($11,730-$60,122) average **$32,417.00** -- one payer (BCBS PHS Traditional, $60,122, 372% of the Medicare proxy) actually EXCEEDS RAND's own 346% Florida-average claim, while others (Aetna PPO, 219%) sit well below it, confirming real bimodal variance even within one hospital. Medicaid: Florida AHCA's statewide standardized base rate for Tampa General, $3,474.74, times APR-DRG 4031 (SOI 1) relative weight 1.1737 (`ahca.myflorida.com` SFY26-27 DRG calculator files) = **$4,078.30**, cross-validated directly against real Medicaid MCO realized-average rates in the same MRF ($3,120-$5,355) -- a good independent check that this figure is real, not a methodology artifact.

**Ohio -- Ohio State University Wexner Medical Center, Columbus.** MRF: `wexnermedical.osu.edu/Files/31-1340739_OHIO-STATE-UNIVERSITY-HOSPITALS_standardcharges.csv.zip`. **Explicit traditional FFS Medicare line item: $9,479.00** -- the single most reliable Medicare figure of all 10 hospitals, since it is literally labeled Medicare rather than inferred from a Medicare Advantage cluster, and it is barely above the national-unadjusted formula estimate ($10,976.27), nothing like Denver Health's 2.5x inflation. Three clear commercial rows (Aetna $30,659.74, Anthem $33,456.31, UHC $36,602.00) average **$33,572.68** -- against this real, low Medicare figure, that is a 354% commercial-to-Medicare ratio, the highest of all 10 hospitals. Medicaid: Ohio ODM's base rate for OSU Hospital (Teaching peer group), $7,483.28 (`dam.assets.ohio.gov`, effective 1/1/2026), times APR-DRG 403 SOI-1 weight 1.1581 = **$8,666.39** (excludes capital and medical-education add-ons governed by separate rules).

**Washington -- University of Washington Medical Center, Seattle.** (Harborview's MRF has zero MS-DRG 619/620/621 entries -- it doesn't bill elective bariatric surgery under these codes. UW Medicine's live site returned Akamai 403s to every direct `curl` attempt; the real MRF URLs were recovered from a Wayback Machine snapshot of the price-transparency page, then fetched via the `r.jina.ai` proxy.) MRF: `uwmedicine.org/sites/stevie/files/cms-mrf/916001537_university-of-washington-medical-center_standardcharges.json`. **No usable Medicare figure**: no FFS line, and every payer except one uses the CMS MRF's own sentinel value (999999999.00) meaning "algorithm-priced, no disclosed dollar amount" -- including all the Medicare Advantage and Medicaid MCO rows. The ONE real dollar figure in the entire record is a state-employee commercial plan (WA PEBB via Regence Blue Shield): $28,195.20. Medicaid: WA HCA's APR-DRG conversion factor for this hospital, $8,863.05 (`hca.wa.gov`), times APR-DRG 403 SOI-1 weight 1.18254 = **$10,480.91**. Too data-poor for a reliable ratio; kept in the dataset for completeness, excluded from both empirical ratio calculations below.

**Pennsylvania -- UPMC Presbyterian, Pittsburgh.** MRF: `dam.upmc.com/-/media/upmc/locations/hospitals/documents/cdm-json-files/250965480_upmc-presbyterian-shadyside_standardcharges.csv` (a 309MB file filed jointly for UPMC Presbyterian/Montefiore/Shadyside under one license). Rows labeled "Medicare" (AmeriHealth Caritas, PA Health & Wellness, Highmark Wholecare, UHC, mostly clustering at $15,664.07, one Aetna row at $15,954.15) are Medicare Advantage products, not traditional FFS -- median **$15,664.07**. Five commercial rows, excluding one $55,937.58 "UPMC Emergent" outlier plan, average **$24,659.08**. Medicaid: PA DHS does use APR-DRG (403, SOI-1 relative weight 1.2128, confirmed from the official state weight table), but **no public, current, hospital-specific base-rate dollar table could be found** after real, direct search (the only located document, the Medicaid State Plan Attachment 4.19-A, is a decades-old narrative formula with figures only through ~2008) -- reported as a genuine gap, not computed from a guess.

**Mississippi -- University of Mississippi Medical Center (UMMC), Jackson.** MRF: `umc.edu/Healthcare/Patients-and-Visitors/Bill%20Pay/Pricing%20Files/646008520-1154317527_university-of-mississippi-medical-center_standardcharges.csv`. **Explicit traditional FFS Medicare line item: $14,881.54** -- despite Mississippi having the LOWEST average Medicare wage index of any state in this project's own wage-index table (0.79), UMMC's real rate is well above the national-unadjusted formula estimate, plausibly reflecting real IME/GME add-ons for an academic medical center that a wage-index-only formula cannot capture (a smaller version of the same phenomenon documented at Denver Health). Six commercial rows (Aetna $11,804.19 to Ambetter $23,569.59, excluding one 80%-of-billed-charges outlier) average **$17,372.18** -- the LOWEST commercial mean of all 10 hospitals, barely above its own Medicare rate (117%). Medicaid: Mississippi's own SFY2027 APR-DRG pricing calculator (`medicaid.ms.gov`), statewide DRG base price $5,608 times APR-DRG 403 SOI-1 weight 1.23593 = **$6,931.10** (the calculator itself states this exact figure).

**Arkansas -- University of Arkansas for Medical Sciences (UAMS), Little Rock.** MRF: retrieved via `apim.services.craneware.com` (a third-party hosting API UAMS's price-transparency page links to), a 950MB CSV. Medicare Advantage plan explicitly priced "100% of Medicare": **$14,550.41** (high-confidence proxy for the true FFS rate). Nine real commercial dollar rates (QualChoice $28,082.29 at 193% of Medicare, down to BCBS Metallic Plan $14,518.35 at ~100%) average **$22,017**, a commercial-to-Medicare ratio of ~151% -- close to, though below, RAND's own 162% Arkansas-average claim, the closest match to RAND's state-level figure found among all 10 hospitals. Medicaid: **Arkansas Medicaid FFS inpatient hospital reimbursement is NOT DRG-based at all** -- confirmed directly from the Arkansas Medicaid Hospital Provider Manual (Section II, retrieved via WebFetch after `curl` returned 403 on every attempt): hospital-specific interim per diem rates with year-end cost settlement, subject to TEFRA rate-of-increase limits and an aggregate daily cap ($850/day for days 1-24, $400/day beyond). UAMS itself is paid this same per-diem way, with no publicly downloadable hospital-specific rate table (unlike Colorado's APR-DRG files) -- a genuine structural finding about how much U.S. state Medicaid methodology varies, reported as a real gap rather than forced into a number.

**New York -- NYU Langone Hospitals (Tisch), Manhattan.** MRF: `standard-charges-prod.s3.amazonaws.com/pricing_files/133971298-1801992631_nyu-langone-tisch_standardcharges.csv` (482MB). No FFS Medicare; Medicare Advantage cluster, ~50 converging plans, flat **$15,373.70**. Ten major commercial rows (Aetna $29,092 to Empire BCBS Indemnity $68,665.38) average **$51,245.57** -- the HIGHEST commercial mean of all 10 hospitals, a 333% ratio. Medicaid: two real data points found -- (a) the SAME MRF's APR-DRG 403 SOI-1 row shows ~20 Medicaid managed-care plans (Fidelis, Healthfirst, MetroPlus, etc.) at a flat, real, contracted **$15,062.50** (used here, since most NY Medicaid enrollees are in managed care, making this arguably more representative than FFS); (b) a separately computed NY DOH FFS estimate (base rate $10,242.44 from `health.ny.gov`'s own SFY2025 file, times a 2018-vintage-but-still-current APR-DRG 403 SOI-1 weight of 1.14) of roughly $11,676-$15,000 before DME/capital add-ons whose exact combination formula was not independently verified -- the managed-care figure was used as the more reliable of the two.

**Empirical ratios, replacing the borrowed national ones.** Across the 9 hospitals with a usable Medicare figure (all except WA): commercial-to-Medicare ratio, ascending -- MS 1.167, CO 1.179, AR 1.513, PA 1.574, GA 1.645, FL 2.007, TX 2.350, NY 3.333, OH 3.542. Mean **2.035**, median 1.645 -- `empirical_commercial_to_medicare_ratio` (base 2.035, low 1.167, high 3.542), replacing `national_commercial_to_medicare_ratio` (RAND, 2.54) as the primary figure. Across the 7 hospitals with both a Medicare and a Medicaid figure (CO, GA, TX, FL, OH, MS, NY): Medicaid-to-Medicare ratio, ascending -- FL 0.2525, TX 0.3961, CO 0.4203, MS 0.4658, GA 0.6943, OH 0.9143, NY 0.9798. Mean **0.589**, median 0.4658 -- `empirical_medicaid_to_medicare_ratio` (base 0.589, low 0.2525, high 0.9798), replacing `national_medicaid_to_medicare_net_ratio` (MACPAC, 1.06, 2010 data) as the primary figure. Both original borrowed-ratio parameters are retained, unconsumed, as documented before/after comparison points. **This is still a small, non-random convenience sample (n=9/7, one hospital per state, not a probability sample of U.S. hospitals)** -- real, genuine data, not a formal national estimate; the low/high range should be read as illustrative of real variation, not a confidence interval.

**What this changes.** Re-running the 52-state illustrative sweep (`R/opportunity_cost_national.R`, unchanged state-average Medicare formula) with these empirical ratios instead of the borrowed national ones shifts its result from 42-of-52-positive to **0 of 52 positive** (range -$561.05 to -$7.42) -- a real, honest reversal driven mainly by the much lower empirical Medicaid ratio (0.589 vs. 1.06). This is not a sign the new ratios are wrong; it is a sign the sweep's true weak link was always the state-average Medicare estimate underneath the ratios (already demonstrated: Colorado's formula estimate is 41% of Denver Health's real rate, and Ohio State's real rate is actually LOWER than its own formula estimate) -- multiplying a systematically-biased base by better ratios does not fix the base.

**The real, strongest artifact from this whole exercise is the direct multi-hospital comparison, not the sweep.** `compute_multi_hospital_opportunity_cost()` (new function, `R/opportunity_cost_national.R`) applies each hospital's own three real rates directly, with Denver Health's payer-mix weights as the only remaining approximation (still no hospital-specific payer-mix data exists). Result, 7 hospitals with complete data (`tables/opportunity_cost_multi_hospital.csv`, git-ignored -- regenerate with `Rscript analysis/07_opportunity_cost_national.R`): NY +$647.65, CO +$421.63, GA +$82.15, OH -$3.88, TX -$99.04, FL -$116.77, MS -$242.01. **Genuinely mixed sign across real hospitals** -- not a uniform finding either way, and a materially different and more trustworthy picture than either the single-hospital Denver Health estimate or the borrowed-ratio sweep. WA, PA, and AR are reported as `NA`, not fabricated or dropped, since a real per-hospital Medicare or Medicaid rate could not be found for each.

Mutation-tested (the NA-propagation logic specifically, since silently treating a missing rate as zero revenue would misrepresent WA/PA/AR's real data gaps as answers); see `docs/testing_philosophy.md`. Confirmed NOT called anywhere in the base-case cost engine or either sensitivity module.

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
the same day, and a preop-visit cost plus a postop-discussion cost were
added the day after -- see "Facility-setting professional fee," "Preop
consent visit for the combined arm," and "Postop results-discussion
cost" next -- so the gap now stands at $490.78, not $335.29.)

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

**Effect on the model's headline result, at the time this was built:**
the base case gap moved from $335.29 to $304.73 -- standalone unchanged
at $868.63; combined fell from $1,203.92 to $1,173.36 (the $67.96
professional-fee reduction outweighing the $37.39 supply-cost addition).
See "One-way sensitivity analysis" above for how `iud_insertion_
professional_fee`'s own swing changed as a direct, checkable consequence
of this fix. Mutation-tested: see `docs/testing_philosophy.md`. (A preop
consent-visit cost and a postop-discussion cost were added the
following day -- see "Preop consent visit for the combined arm" and
"Postop results-discussion cost" next -- so the gap now stands at
$490.78, not $304.73.)

## Preop consent visit for the combined arm (added 2026-09-11)

Prompted by the user asking to survey what else could be borrowed from
the sibling `emb_colonoscopy` project (following the coordination-cost
and facility-fee borrows above). Confirmed by reading that project's
`config/model_parameters.csv` directly: its structurally identical
combined arm (endometrial biopsy performed during colonoscopy) charges a
separate preop office visit, via a toggle named -- identically --
`combined_requires_preop_office_visit` (TRUE by default), on the
reasoning that a patient cannot meaningfully consent to a procedure while
already under anesthesia for a different one, so the consenting
physician needs their own encounter on an earlier date. This project's
combined arm charged $0 for an office visit before this fix -- a real
gap, not a deliberate exclusion, once "Two surgeons, real coordination
cost" above established that the gynecologist (not the bariatric
surgeon) is the one who needs to counsel and consent the patient.

**New parameters**, mirroring the sibling's exactly (same toggle name;
cost parameter renamed to this project's `iud_` prefix convention):
`combined_requires_preop_office_visit` (TRUE, structural,
`evidence_tier = D`) and `iud_preop_office_visit_cost` ($125.40, CPT
99214, `evidence_tier = B`). The cost figure is reused directly from the
sibling project's own verified extraction
(`dnc_preop_clinic_visit_cost`), not re-pulled: CMS Physician & Other
Practitioners by Provider and Service, 2024, CPT 99214, filtered to
`Rndrng_Prvdr_Type = 'Obstetrics & Gynecology'` (live API query,
7,642 provider-service rows, 515,741 observed services). Level 4 (99214,
moderate complexity), not the 99213 `office_visit_em_cost` uses for
standalone's own routine insertion visit, reflecting that this is
specifically a surgical-consent/risk-discussion encounter. Checked
directly, 2026-09-11: CPT 58300's own CMS global-surgery period is "XXX"
(RVU26C, GLOB DAYS field) -- the global-surgery concept does not apply
to this code at all, so no bundling rule folds an earlier-date preop
visit into the procedure's own fee (the sibling project separately
confirmed the analogous non-bundling result for CPT 58120's 010-day
period).

**Effect on the model's headline result, at the time this was built:**
the base case gap moved from $304.73 to $430.13 -- standalone unchanged
at $868.63; combined rose from $1,173.36 to $1,298.76. Because this cost
applies identically regardless of any other parameter's value, it does
not change any parameter's `swing` in "One-way sensitivity analysis"
above (confirmed directly: every swing value is unchanged from before
this addition), only `base_case_gap` itself. Mutation-tested: see
`docs/testing_philosophy.md`. (A postop-discussion cost was added the
same day -- see next -- so the gap now stands at $490.78, not $430.13.)

## Postop results-discussion cost (added 2026-09-11)

The same question that produced the preop visit above surfaced a second
gap: IUD placements do not get a formal postop office visit (see "IUD
string checks" below for the direct confirmation), so nothing in this
model priced the time it actually takes the gynecologist to discuss the
procedure's results with the patient afterward. Checked with the user
directly rather than assumed: for the combined arm, this conversation
cannot happen at the time of placement (the patient is under
anesthesia), so it happens as a separate phone call -- not an in-person
visit, since the patient is otherwise occupied recovering from a much
larger surgery and no physical examination is needed for the IUD side
of things.

**New parameters**, mirroring the wage-times-minutes pattern already
established for scheduling coordination: `combined_arm_postop_
discussion_minutes` = 25 (user-provided operational estimate, 2026-09-11)
and `gynecologist_wage_per_minute` = $2.347 (O*NET OnLine,
`https://www.onetonline.org/link/summary/29-1218.00`, median hourly wage
$140.82, attributed to BLS 2025 wage data, directly verified 2026-09-11,
SOC 29-1218 Obstetricians and Gynecologists; same discovery method as
`surgery_scheduler_wage_per_minute` -- `bls.gov` itself returns HTTP 403
to automated retrieval, O*NET republishes the same OEWS data without
blocking it). Deliberately priced as raw physician time via a wage rate,
not a procedure fee: a phone call with no physical exam is not codeable
as a standard E/M visit, so no real CPT/RVU analog applies the way it
does for the insertion itself. Applies ONLY to the combined arm --
standalone's single office visit already includes this discussion live,
in the same encounter as the insertion, so pricing it there too would be
a double-count.

**Checked directly, not assumed: is this already bundled into a global
surgical fee?** No, for two independent reasons. First, CPT 58300's own
CMS global-surgery period is "XXX" (RVU26C, GLOB DAYS field, the same
lookup used for the preop visit above) -- CMS's own documentation
defines "XXX" as "global concept does not apply to the code," meaning
there is no global surgical package for this code at all, pre- or
post-op, for the gynecologist billing it. Second, and separately, even
under the general Medicare rule that a same-day E/M service related to
a minor procedure is not separately payable, this call happens on a
LATER calendar day: the patient is asleep in the OR, then recovering
from the much larger bariatric procedure, on the day of insertion
itself, so a same-day bundling rule would not apply regardless. A
further point worth naming explicitly: even if the BARIATRIC surgeon's
own procedure code carries a real global period (major bariatric
procedures typically do), that is a different physician's global
package for a different procedure code -- it would not, and could not,
bundle the gynecologist's own separate, IUD-specific communication.

**Effect on the model's headline result:** the base case gap moved from
$430.13 to $490.78 -- standalone unchanged at $868.63; combined rose
from $1,298.76 to $1,359.41. Like the coordination cost, this is a flat
addition and changes no parameter's `swing`, only `base_case_gap`
itself. Mutation-tested: see `docs/testing_philosophy.md`.

## IUD string checks (added 2026-09-11)

Checked directly in response to the user's question, "What does the
data say about IUD string checks in the office?" Current CDC guidance
(Curtis KM, Nguyen AT, Tepper NK, Zapata LB, Snyder EM, Hatfield-Timajchy
K, Kortsmit K, Cohen MA, Whiteman MK. "U.S. Selected Practice
Recommendations for Contraceptive Use, 2024." *MMWR Recomm Rep*
2024;73(3):1-77, published August 8, 2024; directly verified via
`https://www.cdc.gov/contraception/hcp/usspr/intrauterine-contraception.html`,
2026-09-11) states plainly: **"No routine follow-up visit is
required"** after IUD placement. The same source rates the underlying
evidence "very limited and of poor quality" (level of evidence II-2)
for any specific follow-up-visit schedule improving continuation, and
recommends only that clinicians "consider performing an examination to
check for the presence of the IUD strings" opportunistically at other
routine visits the patient already has, not via a dedicated scheduled
visit.

**No cost is added to either arm for a routine string-check visit.**
This is a deliberate, evidence-based exclusion, recorded as
`iud_string_check_followup_not_recommended` in
`config/model_parameters.csv` (a `reference_only` row with no cost
consequence, kept specifically so this decision is documented rather
than silently absent), not an oversight -- directly consistent with the
user's own observation that IUD inserts typically do not get a postop
visit at all. A patient-initiated, symptom-driven visit (cannot feel
strings, pain, suspected expulsion) would be a different, separately-
justified cost; that is not what this CDC guidance addresses, and is not
modeled here either.

## Standalone loss to follow-up (added 2026-09-11)

Prompted by a request to build the loss-to-follow-up parameter for
standalone visits, following up on an item flagged much earlier in this
session's own review of what data would strengthen this model.

**The distinction from what's already modeled.** This project already
has `standalone_office_failure_probability`: the probability that a
patient who SHOWS UP for the standalone visit has an insertion attempt
that fails outright, requiring escalation. Loss to follow-up is a
different, upstream phenomenon: the probability a scheduled patient
never shows up for the visit AT ALL. No prior parameter in this model
captured that.

**Source, directly verified.** Baldwin MK, Edelman AB, Lim JY, Nichols
MD, Bednarek PH, Jensen JT, "Comparison of intrauterine device insertion
at 3 weeks versus 6 weeks postpartum: a randomized trial," *Contraception*
2016;93(4):356-363, doi:10.1016/j.contraception.2015.12.006, PMID
26686914. Directly verified via the Europe PMC abstract, 2026-09-11.
Prospective RCT, 201 postpartum women intending interval IUD placement,
randomized to a 3-week (n=101) vs. standard 6-week (n=100) scheduled
return visit: "Most participants returned for IUD placement as
scheduled; 70.1% (53/75) in the early group, 74.3% (58/78) in the
standard group." `standalone_loss_to_follow_up_probability` base/low
value is the standard (6-week) group's complement (1 - 0.743 = 0.257);
high value is the early (3-week) group's complement (1 - 0.701 = 0.299).

**Population mismatch, flagged explicitly, same as other borrowed
parameters in this project.** This is a postpartum cohort returning for
a scheduled visit after childbirth, not a bariatric-surgery population.
No published loss-to-follow-up data specific to scheduling an IUD visit
around bariatric surgery was found. Used as the best available
real-world analog because the underlying logistics phenomenon --
returning for a deliberately scheduled interval procedure after a
different major medical event -- is structurally similar, the same
reasoning already applied to Saito-Tom et al. 2015 (a general
obesity-not-bariatric-surgery cohort) and Masten et al. 2024 (an
adolescent, not adult, cohort) elsewhere in this model.

**Why this is reported separately rather than priced into
`expected_total_cost`.** This project's cost-minimization framing
assumes equal effectiveness across arms by design -- that's what
distinguishes cost-minimization from cost-effectiveness analysis. Loss
to follow-up is a genuine violation of that assumption (the two arms do
NOT achieve equal device-placement rates), so folding it into the
existing dollar figure would either misleadingly discount standalone's
cost (since a missed visit costs nothing directly: no device purchased,
no professional fee billed) or require fabricating a downstream cost
pathway (what happens to a patient who doesn't get the IUD -- alternative
contraception, an unintended pregnancy, nothing at all) that no data in
this project supports. Instead, `compute_probability_device_placed()`
reports the completion-probability gap directly (standalone 0.743,
combined 1.0) and `expected_cost_per_referred_patient` reports what that
implies for cost-per-patient-referred, alongside, not instead of, the
existing per-completed-visit cost.

**The result was genuinely counterintuitive at the time this was built,
and worth stating plainly:** per referred patient, standalone's
advantage WIDENED, from $868.63-vs-$1,359.41 (per completed visit) to
$645.39-vs-$1,359.41 (per referred patient) -- because in this model, a
missed visit costs nothing directly. That was not a point in
standalone's favor; it was the mechanism by which an unpriced
effectiveness gap can look like a cost advantage if the two numbers are
not read together. `analysis/01_base_case.R` printed both explicitly for
this reason. See "Chaining loss to follow-up to a real downstream
outcome" below for how this was later revised once a real downstream
cost was found and built: the gap narrows to $735.01-vs-$1,359.41, still
counterintuitively favoring standalone on paper but less starkly.

## Chaining loss to follow-up to a real downstream outcome (added 2026-09-11)

Prompted by a direct request to look at how other literature addresses
this exact structural problem -- a strategy that guarantees placement
during an existing admission (immediate postpartum LARC; here, combined
bariatric-surgery placement) vs. one requiring a separate,
loss-to-follow-up-prone visit (interval LARC; here, standalone) --
before building anything further.

**What the literature actually does, verified directly, not assumed.**
Washington CI, Jamshidi R, Thung SF, Nayeri UA, Caughey AB, Werner EF,
"Timing of postpartum intrauterine device placement: a cost-effectiveness
analysis," *Fertil Steril* 2015;103(1):131-137, doi:10.1016/
j.fertnstert.2014.09.032, PMID 25439838 (already indirectly connected to
this project: Dottino et al. 2016 cites this same paper for its own IUD
cost inputs). Directly verified via the Europe PMC abstract, 2026-09-11:
a decision-analysis model finding immediate postpartum IUD placement
prevented 88 unintended pregnancies per 1,000 women over a 2-year
horizon and was the dominant strategy (cost savings of $282,540 and 10
QALYs gained per 1,000 women). Critically: "The model is most sensitive
to the cost of an undesired pregnancy" -- the downstream outcome, not
the procedural costs, drove the result. Gariepy AM, Duffy JY, Xu X,
"Cost-Effectiveness of Immediate Compared With Delayed Postpartum
Etonogestrel Implant Insertion," *Obstet Gynecol* 2015;126(1):47-55,
directly verified via the PMC full text (PMC4526123), builds the
identical structure for the implant: 35% loss to follow-up at the
postpartum visit, 27% of attendees then decline the device anyway, a
weighted-average contraceptive-failure rate across whatever method
non-completers end up using, and a pregnancy-cost breakdown ($8,907
expected cost: $11,871-$24,045 live birth depending on insurance, $973
miscarriage, $4,906 ectopic, $788 abortion). Neither paper treats loss
to follow-up as a side metric; both chain it to a real, priced adverse
outcome.

**This project's population has a different real stake, so a different
outcome is chained here.** This device also protects against
endometrial cancer (see "Cancer-prevention estimate" below); a
bariatric-surgery patient is not specifically trying to avoid pregnancy
in the way a postpartum patient is, so unintended pregnancy is not the
relevant downstream consequence for this population the way it is for
the postpartum-LARC literature. Endometrial cancer is.

**Built directly on `R/cancer_prevention.R`'s own machinery, not
re-derived.** `compute_expected_missed_cancer_prevention_cost()` reuses
`compute_post_surgery_baseline_risk()` and
`compute_iud_absolute_risk_reduction()` from that module, so the two
modules cannot silently drift apart. New parameters:

- `endometrial_cancer_death_risk_usual_care_bmi40` = 0.014 (and, for
  symmetry, `_bmi30` = 0.007), added to
  `config/cancer_prevention_parameters.csv`. Source: the same Dottino et
  al. 2016 results text already used for
  `endometrial_cancer_lifetime_risk_usual_care_bmi40`: "there is a 3%
  lifetime probability of developing and a 1.4% probability of dying
  from endometrial cancer." Used to derive a conditional mortality-given-
  diagnosis ratio (0.014 / 0.03 = 0.4667), deliberately NOT adjusted by
  `bariatric_surgery_endometrial_cancer_hazard_ratio` (Schauer et al.
  2019): that hazard ratio is specifically an incidence hazard ratio,
  with no evidence it also applies to prognosis once diagnosed.
- `endometrial_cancer_treatment_cost` = $34,982.33 (2015 dollars), added
  to `config/model_parameters.csv`. Derived from Dottino et al. 2016's
  Table 2 (PDF read directly), itself sourced from Yabroff KR, Lamont EB,
  Mariotto A, Warren JL, Topor M, Meekins A, et al., "Cost of care for
  elderly cancer patients in the United States," *J Natl Cancer Inst*
  2008;100:630-641: first 12 months from diagnosis $20,491.74, ongoing
  annual cost $1,153.83, last 12 months of life $31,051.26. This
  parameter = first-year cost + (mortality-given-diagnosis ratio x
  last-year-of-life cost) = 20491.74 + (0.4667 x 31051.26) = $34,982.33.
  DELIBERATELY EXCLUDES the ongoing-annual-care component: Dottino's own
  Markov model handles this via annual-cycle simulation to age 100,
  which this project's closed-form expected-value calculation cannot
  replicate without inventing a specific number of survivorship years,
  so it is omitted rather than guessed -- a flagged, conservative
  (understated) simplification, not a hidden one.

**The formula:** `expected_missed_cancer_prevention_cost` =
`standalone_loss_to_follow_up_probability` x
`compute_iud_absolute_risk_reduction(post_surgery_no_iud_risk,
iud_endometrial_cancer_incidence_ratio)` x
`endometrial_cancer_treatment_cost` (inflation-adjusted). Added to
`expected_cost_per_referred_patient` for standalone only; always 0 for
combined, since `probability_device_placed = 1` there means no
lost-to-follow-up population exists to apply this cost to.

**Effect on the model's numbers:** `expected_missed_cancer_prevention_cost`
= $89.62 per referred standalone patient. `expected_cost_per_referred_
patient` moves from $645.39 to $735.01 for standalone (combined
unchanged at $1,359.41, and `base_case_gap` -- $490.78 -- is untouched,
since this only affects the per-referred-patient metric, not
`expected_total_cost`). Even after this real cost, standalone's
per-referred-patient number ($735.01) remains below its per-completed-
visit number ($868.63): the avoided-visit savings (`expected_total_cost
x (1 - probability_device_placed)` = $223.24) still outweighs the added
cancer-risk cost ($89.62). This is an honest, checkable result, not a
predetermined one -- the numbers say standalone's apparent extra
savings come partly, not entirely, from missed placements, and the
model reports that ratio directly rather than asserting a conclusion
either way. Mutation-tested: see `docs/testing_philosophy.md`.

## Mortality-specific hazard ratio: a checked, excluded sensitivity parameter (added 2026-09-11)

Prompted by a direct follow-up question: "Add it as a sensitivity-analysis-only parameter with the wide CI flagged," after first asking whether bariatric surgery's endometrial-cancer effect should be adjusted "by a bariatric surgery incidence hazard ratio" and then, once the distinction was raised, specifically "look for a different hazard ratio, one that's specifically about survival/mortality after an endometrial cancer diagnosis in bariatric-surgery patients (vs. non-surgery patients)."

**The distinction that prompted this search.** `bariatric_surgery_endometrial_cancer_hazard_ratio` (Schauer et al. 2019, already used throughout this module) is an INCIDENCE hazard ratio: it measures whether bariatric surgery changes the risk of DEVELOPING endometrial cancer, in a cohort of bariatric-surgery patients matched against non-surgical patients with severe obesity, none of whom had the disease at baseline. It says nothing about what happens to a woman's SURVIVAL once she already has an endometrial cancer diagnosis. `endometrial_cancer_treatment_cost`'s mortality-given-diagnosis ratio (0.014/0.03 = 0.4667, see the "Chaining loss to follow-up" section above) is exactly this second, different question, and had deliberately not been adjusted by the incidence HR for exactly this reason. This section documents the search for whether a real, mortality-specific hazard ratio exists instead.

**Search performed, verified directly against primary sources, 2026-09-11.** Search terms covered: "bariatric surgery endometrial cancer survival," "bariatric surgery endometrial cancer mortality hazard ratio," "weight loss surgery endometrial cancer prognosis," "bariatric surgery gynecologic cancer outcomes survival," "bariatric surgery cancer-specific mortality women," plus targeted checks of Utah bariatric-surgery-mortality cohorts (Adams et al.) and SEER/NCDB-linked studies.

**Result found:** Lee E, Kawaguchi ES, Zhang J, et al. "Bariatric surgery in patients with breast and endometrial cancer in California: population-based prevalence and survival." *Surg Obes Relat Dis.* 2022;18(1):42-52 (published online 2021 Sep 30). doi:10.1016/j.soard.2021.09.017. PMID 34740554. Directly verified via the open-access PMC full text (PMC9078098). California Cancer Registry-linked cohort, endometrial cancer patients diagnosed 2011-2014, BMI>=30, comparing POST-DIAGNOSIS weight-loss surgery (n=46) against no surgery (n=3,343), followed through 2017-12-31. Covariate-adjusted (stage, age, Charlson comorbidity index, race/ethnicity, socioeconomic status) all-cause-mortality hazard ratio within the endometrial cancer cohort: 0.23 (95% CI 0.033-1.70, p=0.15). NOT statistically significant. Fewer than 15 deaths occurred in the surgery group; the California Cancer Registry's small-cell suppression rule prevented reporting the exact count. A pooled breast-plus-endometrial analysis in the same paper (HR 0.37, 95% CI 0.14-0.99, p=0.049) does reach significance, but is dominated by the much larger breast-cancer sample size and would misattribute that effect to endometrial cancer specifically if used here.

**Candidate ruled out:** Argenta PA, Mattson J, Denzel J, Boente M, Miller D, Teoh D. "Bariatric surgery as a means to decrease mortality in women with type I endometrial cancer: An intriguing option in a population at risk for dying of complications of metabolic syndrome." *Gynecol Oncol.* 2015;138(3):597-602. PMID 26232518. This is a Markov decision-analytic simulation model (routine care 8.10 QALYs vs. weight-loss surgery 9.30 QALYs over a 15-year horizon), not an observed cohort. Its survival benefit is an imported modeling *assumption* drawn from the general bariatric-surgery all-cause-mortality literature, not a primary empirical finding about endometrial cancer patients' prognosis. Not usable as a real mortality hazard ratio for this population.

**Decision: excluded from the base case, kept as a sensitivity-only parameter.** A CI of 0.033-1.70 spans everything from "surgery nearly eliminates mortality risk" to "surgery increases it by 70%," built on fewer than 15 events in the exposed group -- not distinguishable from no effect. Applying the 0.23 point estimate as if it were a settled adjustment would inject substantial real uncertainty while presenting it as a precise correction, which this project's parameter discipline treats as fabricated precision to be avoided, not embraced.

`bariatric_surgery_endometrial_cancer_mortality_hazard_ratio` was added to `config/cancer_prevention_parameters.csv` with `base_value` fixed at 1 (no adjustment -- this is what every number in "Chaining loss to follow-up" above already reflects, unchanged), `low_value` 0.033, `high_value` 1.70, evidence tier D, provisional TRUE. Two supporting parameters were added to `config/model_parameters.csv`: `endometrial_cancer_cost_first_year` ($20,491.74, 2015 dollars) and `endometrial_cancer_cost_last_year_of_life` ($31,051.26, 2015 dollars) -- the same two Dottino et al. 2016 Table 2 / Yabroff et al. 2008 figures that were already collapsed into the single `endometrial_cancer_treatment_cost` value, now decomposed so a mortality-specific hazard ratio can be applied to just the last-year-of-life component (the one only incurred by patients who actually die of the disease), without touching the base-case parameter or any of its consumers.

A new, separate function, `compute_expected_missed_cancer_prevention_cost_at_mortality_hr()` in `R/strategy_costs.R`, recomputes `expected_missed_cancer_prevention_cost` from the two decomposed components with the mortality hazard ratio applied. It is NOT called from `compute_standalone_strategy_cost()`, `compute_combined_strategy_cost()`, `compute_strategy_costs()`, `run_scenario_analysis()`, or `run_one_way_sensitivity()` -- every base-case and existing-sensitivity number in this project is completely unaffected by this addition. At its default argument (the parameter's own `base_value` of 1), it exactly reproduces `compute_expected_missed_cancer_prevention_cost()`'s $89.62, confirming the decomposition was done correctly (`tests/testthat/test-strategy-costs.R`, verified with a floating-point tolerance since the base-case parameter is stored pre-rounded to the cent).

**What sweeping the full CI actually shows:** at HR=0.033 (the most-protective end of the CI), `expected_missed_cancer_prevention_cost` = $53.72; at the point estimate (HR=0.23), $61.04; at HR=1 (no adjustment, the base case), $89.62; at HR=1.70 (the least-protective end), $115.61. The whole range ($53.72-$115.61) stays well below what would be needed to change which strategy is cheaper -- so even if this uncertain, non-significant effect turned out to be real, it would not overturn the standalone-vs-combined conclusion. Mutation-tested; see `docs/testing_philosophy.md`.

## Two literature leads investigated: neither changes the base case (added 2026-09-11)

Prompted by a general request to "research more about how we can improve this analysis with publicly available data and literature." A broad search surfaced two genuine candidates for strengthening two of this project's own flagged, real-population-mismatch parameters. Both were checked directly against primary sources before deciding, and both turned out to be real, verified findings that nonetheless should NOT change the base case -- documented here so that judgment call is visible, not silently made.

**Lead 1: a bariatric-surgery-specific alternative to Baldwin et al. 2016 for `standalone_loss_to_follow_up_probability`.** That parameter's existing population-mismatch caveat (a postpartum RCT standing in for a bariatric-surgery population) suggested a real bariatric-specific rate would be a straightforward upgrade. Two real candidates were found and verified directly:
- Paolino L, Couteau N, Vignot M, Batahei S, Lazzati A. "Where Are My Patients? Lost and Found in Bariatric Surgery." *Obes Surg.* 2021;31(5):1979-1985. doi:10.1007/s11695-020-05186-9. PMID 33428161. French single-center retrospective cohort, surgeries 2014-2017: 29.7% lost to follow-up overall.
- Krietenstein L, Koschker AC, Miras AD, Kollmann L, Gruber M, Dischinger U, Haubitz I, Fassnacht M, Warrings B, Seyfried F. "Characteristics of Patients Lost to Follow-up after Bariatric Surgery." *Nutrients.* 2024;16(16):2710. doi:10.3390/nu16162710. PMID 39203846. German single-center prospective cohort, 573 patients, surgeries 2008-2017: lost-to-follow-up defined as no visit within the previous 18 months; only 90.32% still attending by 1 year, 44.6% by 2 years.

Reading both directly (not just their headline percentages) surfaced why neither is a clean substitute: both define "lost to follow-up" as non-adherence to a bariatric center's ONGOING, MULTI-YEAR monitoring program -- a chronic-adherence measure -- not whether a patient returns for ONE deliberately scheduled early visit shortly after the surgery, which is the specific behavior `standalone_loss_to_follow_up_probability` needs and the specific behavior Baldwin et al. 2016's postpartum-IUD trial directly measures (in the wrong population). Swapping in either bariatric rate would trade a population mismatch for a behavior mismatch, not fix one -- not a defensible improvement, just a different kind of imprecision. **Decision: keep Baldwin et al. 2016 as this parameter's source, unchanged.** Both new citations were added to the parameter's `notes` field in `config/model_parameters.csv` as a documented, sourced, directional caveat: real bariatric-population follow-up rates (29.7%-50%+, depending on definition/timepoint) run considerably higher than this parameter's current 25.7%-29.9% range, a real reason to suspect the true rate for even a short-interval visit could be higher, not lower, than currently modeled -- surfaced rather than acted on, since acting on it would require fabricating a number from a source measuring a different thing.

**Lead 2: Yi et al. 2024, a larger, more recent, but less-protective endometrial-cancer HR than Soini et al. 2014.** Yi H, Zhang N, Huang J, et al. "Association of levonorgestrel-releasing intrauterine device with gynecologic and breast cancers: a national cohort study in Sweden." *Am J Obstet Gynecol.* 2024;231:450.e1-12. doi:10.1016/j.ajog.2024.05.011. PMID 38759709. Directly verified via the Europe PMC abstract, 2026-09-11: 514,719 LNG-IUD users (contraceptive indication, not menorrhagia) vs. 1,544,157 propensity-matched non-users, ages 18-50, Sweden, 2005-2018. Adjusted hazard ratio for endometrial cancer: 0.67 (95% CI 0.56-0.80).

This is a real, large, well-conducted, more recent study (~15x Soini et al. 2014's sample size, a decade newer) finding a materially SMALLER protective effect (0.67 vs. Soini's 0.50), with confidence intervals that barely overlap (Soini 0.35-0.70; Yi 0.56-0.80; overlap region only 0.56-0.70) -- a genuine scientific disagreement between two large studies, not a case where one is simply more correct than the other on its face. Presented to the model owner directly rather than resolved unilaterally, given how far this ripples (every cancer-prevention number in this project derives from `iud_endometrial_cancer_incidence_ratio`). **Decision: keep Soini et al. 2014 (0.50) as the base-case parameter, unchanged; document Yi et al. 2024 as a flagged, unresolved disagreement in the parameter's `notes` field** in `config/cancer_prevention_parameters.csv`, rather than either silently ignoring it or silently switching to it. Rationale for keeping Soini specifically: neither Dottino et al. 2016 nor Bernard et al. 2021 -- the two obesity-specific LNG-IUD cost-effectiveness models this project's own methodology follows most closely -- could have used a 2024 finding (both predate it), so adopting Yi's figure now would be a new methodological choice this project is introducing, not a correction of an error those models already made.

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
