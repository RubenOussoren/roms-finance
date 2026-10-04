---
name: pag-check
description: Audit projection assumptions and financial guideline claims against their sources
---

# Projection guideline audit

Read [shared guidance](../references/operating-guidance.md), particularly
`docs/architecture/financial-contracts.md`. This is a source-backed audit, not legal
certification or an instruction to upgrade assumptions automatically.

1. Establish the requested files/scenarios, jurisdiction, projection date, and selected
   guideline edition. Read actual assumption records/configuration, `ProjectionStandard`,
   projection callers, and relevant concerns. Report missing or stale sources.
2. Trace returns, inflation, fees, volatility, tax rules, and any safety adjustment from
   their source through calculation to displayed output. Check effective dates, overrides,
   and provenance. Do not copy rates, thresholds, or guideline years from this skill.
3. Verify nominal/real returns, gross/net assumptions, compounding/payment frequency,
   cash-flow timing, and percentage units. Apply mortgage/credit conventions only where
   supported by the product contract; reuse existing helpers.
4. Check jurisdiction and provincial/federal handling against implemented rules and
   source data. Check that safety adjustments, if required by the selected contract,
   are applied once. Concern inclusion or a badge is not evidence of compliance.
5. Inspect known-value tests and labels: custom assumptions must not be represented as
   guideline-compliant. Use `/test` for isolated validation; never call live providers.
6. Report scope, edition/source, evidence (`file:line`), impact, and suggested correction.
   Separate verified deviations from unverified external claims; do not change seed
   data, guideline versions, or financial outputs without an agreed scope.
