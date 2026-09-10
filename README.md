# iud_bariatric

A reproducible R cost-minimization model comparing two ways to place a
levonorgestrel-releasing intrauterine device (LNG-IUD, e.g. Liletta, Mirena,
Kyleena) in a reproductive-age patient undergoing bariatric surgery:

1. **Standalone insertion** — a separate outpatient office visit, before or
   after the surgery, with its own evaluation-and-management fee, insertion
   professional fee (CPT 58300), and device cost.
2. **Combined insertion** — the IUD is placed in the operating room at the
   time of the already-scheduled bariatric surgery, under the anesthesia the
   patient is already receiving.

This repository follows the same conventions and evidentiary discipline as
[`emb_colonoscopy`](https://github.com/mufflyt/emb_colonoscopy) (a sibling
cost-minimization model for Lynch-syndrome endometrial-biopsy strategies):
every parameter in `config/model_parameters.csv` carries a source citation,
an evidence tier, and a `provisional` flag, and no dollar figure enters the
model without a traceable primary source.

## Why this question, and why it's harder than the colonoscopy analog

The Lynch-syndrome model could lean almost entirely on Medicare data, because
its patient population (women old enough for Lynch-syndrome endometrial
surveillance) overlaps heavily with the Medicare population. That shortcut
does not work here:

- **Medicare does not price this at all.** CPT 58300 (IUD insertion) carries
  an "N" (non-covered) status on the Medicare Physician Fee Schedule —
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
  device J-codes, almost every payer's inpatient negotiated rate is null —
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

## Repository layout

- `config/model_parameters.csv` — every model input, one row per parameter,
  with `source`, `evidence_tier` (A = direct/primary, B = adjacent primary
  source, C = general-population literature, D = placeholder), and
  `provisional` columns.
- `R/` — parameter loading/validation, the two-strategy cost engine, and
  (as they're added) sensitivity-analysis and plotting helpers.
- `analysis/` — numbered driver scripts that run the model and save tables.
- `tests/testthat/` — unit and regression tests; run via `Rscript tests/testthat.R`.
- `docs/data_sources.md` — the full evidence trail for every parameter,
  including dead ends (sources checked and rejected, and why).
- `tables/`, `figures/` — generated outputs (git-ignored until real results
  exist worth version-controlling).

## Status

Scaffolding stage: the parameter table, cost engine, and one base-case driver
script exist with real (if provisional) starting values. No sensitivity
analysis, manuscript, or figures yet.
