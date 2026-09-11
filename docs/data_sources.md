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
- **Masten E, et al. Body Mass Index and Levonorgestrel Device Expulsion in
  Adolescents and Young Adults. J Pediatr Adolesc Gynecol
  2024;37:407-411.** Retrospective chart review, 588 nulliparous patients
  aged 10-19, 43 (16.2%) placed as a combination case with metabolic/
  bariatric surgery (MBS). **This is the source for
  `iud_expulsion_probability_standalone`/`_combined` and
  `iud_expulsion_odds_ratio_combined_vs_standalone`** -- combined placement
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
- **CPT 58300 (IUD insertion) does NOT appear anywhere in that same fee
  schedule PDF**, despite the document covering a broad range of
  procedure codes (confirmed by checking that other 5xxxx-range codes,
  e.g. urology codes in the 50000s, do appear normally). It likely lives
  in a different Colorado Medicaid billing manual (HCPF publishes
  separate "Family Planning Benefit Expansion," "Reproductive Health
  Care," and "Obstetrical Care" billing manuals) not yet located. Given
  this, the Medicaid scenario's `iud_insertion_professional_fee` override
  uses a national (not Colorado-specific) 2015 Medicaid-context estimate
  instead: $71-$135 (midpoint $103), from Bhatt & Stevens et al.,
  "Immediate Postpartum Long-Acting Reversible Contraception: Review of
  Insertion and Device Reimbursement Policies," a 2022 systematic review
  of state Medicaid postpartum-LARC reimbursement policies (PMC9198998,
  read directly), inflation-adjusted from 2015 to `reference_dollar_year`
  using a newly-added real 2015 CPI-Medical row in
  `data/cpi_medical_care.csv` (446.752, same FRED-download methodology as
  the 2014 row).
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
