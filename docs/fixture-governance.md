# Fixture Governance

AlpenLedger fixtures are part of the release evidence. They must be synthetic,
reviewable, and stable enough that import, reconciliation, tax, and UI tests can
prove behavior without using private financial data.

## Rules

- Store fixture metadata in `config/fixture-catalog.json`.
- Every file under `Fixtures/` must appear in the catalog with a stable ID,
  purpose, pack, format, SHA-256 hash, and coverage test references.
- Fixtures must be synthetic and must not contain real personal data, real bank
  identifiers, real AHV/AVS numbers, emails, phone numbers, or customer records.
- Hash changes require updating the catalog and documenting why the sample data
  changed.
- App-bundled fixtures must be explicitly marked with `appResource: true` and
  included in `project.yml`.
- Golden expected outputs should live beside their input fixture pack.

## Current Packs

- `csv-bank-statement`: synthetic CHF bank-statement CSV used by the importer,
  ledger/reconciliation tests, and sole-proprietor tax calculations.
- `customer-scale-bank-statement`: synthetic 2,500-row CHF bank-statement CSV
  used by import-throughput and customer-volume regression tests.
- `camt-bank-report`: synthetic CAMT.052 XML account-report files, including
  single-report and multi-report coverage, used by the Swiss ISO 20022 importer
  and import-pipeline regression tests.
- `camt-bank-statement`: synthetic CAMT.053 XML bank-statement files, including
  single-statement and multi-statement coverage, used by the Swiss ISO 20022
  importer and import-pipeline regression tests.
- `camt-bank-notification`: synthetic CAMT.054 XML debit/credit notifications,
  including single-notification and batched multi-notification coverage, used by
  the Swiss ISO 20022 importer and import-pipeline regression tests.
- `document-receipt`: synthetic PDF receipt used by document import, preview,
  evidence-link, and proposal review flows.
- `qr-bill`: synthetic Swiss QR-bill text payload used by document-type
  detection and structured payment field extraction tests.
- `ech-0196-tax-statement`: synthetic eCH-0196 electronic tax-statement XML
  fixture used by document import, type detection, and XML tax-year extraction
  tests.
- `ech-0248-pension-certificate`: synthetic eCH-0248 pension-contribution
  certificate XML fixture used by document import, type detection, and XML
  tax-year extraction tests.
- `ech-0275-health-insurance-certificate`: synthetic eCH-0275 health-insurance
  tax-certificate XML fixture used by document import, type detection, and XML
  tax-year extraction tests.
- `vat-period-reconciliation`: synthetic Swiss VAT quarter JSON fixture used
  by VAT code mapping and period reconciliation tests.
- `vat-export`: synthetic eCH-0217 v2.0.0 VAT declaration XML golden output
  used by VAT export tests and offline XSD validation.
- `zh-personal-tax-2026`: synthetic Zurich 2026 personal-tax certificate bundle
  plus expected tax facts for salary, health-insurance, and pillar 3a evidence.
- `personal-tax-export`: synthetic Zurich 2026 natural-person draft
  export-readiness fixture used to verify expected facts and blocker-free draft
  review shape before future eCH-0119 generation.
- `business-tax-export`: synthetic Zurich 2026 sole-proprietor draft
  export-readiness fixture used to verify self-employment facts and blocker-free
  draft review shape before future eCH-0276 generation.

## Verification

Run:

```sh
scripts/verify-fixtures.sh
```

The verifier checks catalog schema, required packs, fixture file coverage,
hashes, app-resource registration, basic CSV/CAMT.052/CAMT.053/CAMT.054/
QR-bill/PDF/text/eCH tax-certificate XML/VAT JSON and expected-tax-fact JSON
format sanity, personal/business draft export-readiness JSON shape, and a small
set of high-risk personal-data patterns for text-like fixtures. The
customer-scale bank-statement pack additionally must contain at least 2,500 data
rows, at least 80 counterparties, and CHF-only transactions.

Vendored XML schemas are tracked separately in `config/schema-catalog.json`.
Run `scripts/verify-schemas.sh` to check eCH XSD hashes and validate the
eCH-0217 VAT export fixture offline with `xmllint --nonet`.
