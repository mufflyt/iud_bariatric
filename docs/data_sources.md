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

- **Non-340B GPO acquisition cost ($537-$600):** from a Physicians'
  Alliance of America pricing bulletin summarizing manufacturer pricing. A
  direct fetch of the underlying MDedge article
  (`https://www.mdedge.com/obgyn/article/103902/gynecology/what-does-liletta-cost-non-340b-providers`)
  was attempted but the response was truncated and did not independently
  confirm the figures. **Action needed:** re-fetch that article in full, or
  find a primary GPO contract/invoice, before treating $537-$600 as settled.
- **340B price ($50, later reportedly $100):** the $50 figure is directly
  quoted from a 2016 AAFCPAs article citing a Medicines360 announcement
  ("this price will never increase"). A separate, unverified secondary
  source claims it was later raised to $100. **Action needed:** check
  Medicines360's current published 340B price list directly before using
  either figure as a current 2026 value.
- **CPT 58300 commercial professional-fee range ($75-$125):** from
  aggregator/billing-service websites (billingfreedom.com,
  obgynbillco.com), not independently confirmed against a second primary
  payer fee schedule.

## Literature gaps (searched for, not found)

- **No study quantifies added operating-room time for IUD insertion
  specifically at the time of bariatric surgery.** Multiple targeted
  searches (2026-09-10) turned up only general bariatric-contraception
  access/counseling literature (e.g. "Optimizing contraceptive access for
  women undergoing bariatric surgery," PubMed 33004300), not intraoperative
  timing data.
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

## Reused from the sibling `emb_colonoscopy` project

`office_visit_em_cost`, `direct_room_cost_per_minute`, and
`anesthesia_cost_per_minute` are copied directly from that project's
already-verified extractions (CMS Physician & Other Practitioners by
Provider and Service PUF for the E/M visit; Childers & Maggard-Gibbons,
*JAMA Surg*, for the OR/anesthesia per-minute costs) rather than re-pulled
fresh, because the underlying claim transfers directly. See that project's
`docs/data_sources.md` and `config/model_parameters.csv` for the full
citation trail.

**Not yet done:** `direct_room_cost_per_minute` and
`anesthesia_cost_per_minute` are still in their original 2014 dollars; this
scaffold has not wired up an inflation-adjustment step (`R/inflation.R`,
`data/cpi_medical_care.csv`) yet. Do this before reporting any dollar total
from this model.
