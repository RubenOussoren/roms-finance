# Product refinement — evidence and issue register

**Date:** 2026-10-04\
**Source baseline:** `9477538732da1acf7d52720f358ea27b66777134`\
**Tracker:** [#120](https://github.com/RubenOussoren/roms-finance/issues/120)\
**Context:** [roadmap](refinement-roadmap-2026-10.md) · [synthetic sandbox playbook](refinement-sandbox-playbook.md)

This point-in-time register contains **34 child issues: 22 bugs, 7 enhancements,
5 discovery tasks; 21 P1 and 13 P2**. All were published with existing repository
labels (`bug`, `enhancement`, `question`), evidence, user impact, bounded scope,
acceptance criteria, synthetic scenarios and dependencies. GitHub owns current
status; this document is not automatically synchronized with later issue edits.
No owner/milestone has been assigned. S/M indicate relative scope, not duration.

## Evidence classification

- **Bug:** source-confirmed behavior/contract inconsistency. Neither production
  impact nor the exact rendered browser failure has been reproduced in this run.
- **Enhancement:** proposed capability/UX improvement, not a confirmed broken flow.
- **Discovery:** observed behavior with unresolved policy or runtime consequences;
  can close as tested-adequate with evidence.
- P1/P2 are provisional priorities, not incident-severity certifications.
- Paths/line ranges below are pinned to the audit SHA, so later documentation/code
  changes do not silently change the cited evidence.

## Index

| ID | Issue | Type | Priority | Phase | Size | Title |
| --- | --- | --- | --- | --- | --- | --- |
| DISC-01 | [#121](https://github.com/RubenOussoren/roms-finance/issues/121) | discovery | P1 | 0 | M | Run synthetic end-user walkthroughs and establish a usability baseline |
| EQ-01 | [#122](https://github.com/RubenOussoren/roms-finance/issues/122) | bug | P1 | 1 | S | Clear obsolete vesting valuations when the last vested grant disappears |
| EQ-02 | [#123](https://github.com/RubenOussoren/roms-finance/issues/123) | bug | P1 | 1 | M | Align vested quantities and next-vesting dates with actual schedule boundaries |
| EQ-03 | [#124](https://github.com/RubenOussoren/roms-finance/issues/124) | bug | P1 | 1 | S | Convert stock-option market and strike prices to the same currency |
| EQ-04 | [#125](https://github.com/RubenOussoren/roms-finance/issues/125) | bug | P1 | 1 | S | Reject inferred equity sales that exceed vested available units |
| EQ-05 | [#126](https://github.com/RubenOussoren/roms-finance/issues/126) | enhancement | P2 | 2 | M | Guide grant entry with a statement-based preview and progressive disclosure |
| EQ-06 | [#127](https://github.com/RubenOussoren/roms-finance/issues/127) | enhancement | P2 | 2 | M | Offer a one-off reviewed RSU sale instead of requiring automation rules |
| EQ-07 | [#128](https://github.com/RubenOussoren/roms-finance/issues/128) | discovery | P1 | 0 | M | Characterize sale correction, transfer reconciliation and balance refresh |
| EQ-08 | [#129](https://github.com/RubenOussoren/roms-finance/issues/129) | bug | P1 | 1 | M | Expose missing equity prices and FX instead of zero or parity estimates |
| PJ-01 | [#130](https://github.com/RubenOussoren/roms-finance/issues/130) | bug | P1 | 1 | M | Use a consistent reporting-currency basis for net-worth forecasts |
| PJ-02 | [#131](https://github.com/RubenOussoren/roms-finance/issues/131) | bug | P1 | 1 | S | Record forecast actuals only after their target date using dated observations |
| PJ-03 | [#132](https://github.com/RubenOussoren/roms-finance/issues/132) | bug | P1 | 1 | S | Keep projection chart growth summaries within viewer and ownership scope |
| PJ-04 | [#133](https://github.com/RubenOussoren/roms-finance/issues/133) | enhancement | P2 | 2 | M | Connect actual net worth to the current outlook with a clear forecast origin |
| PJ-05 | [#134](https://github.com/RubenOussoren/roms-finance/issues/134) | enhancement | P1 | 1 | M | Preserve reproducible forecast vintages instead of replacing the benchmark |
| PJ-06 | [#135](https://github.com/RubenOussoren/roms-finance/issues/135) | enhancement | P2 | 3 | M | Overlay realized actuals against a selected prior forecast and its bands |
| PJ-07 | [#136](https://github.com/RubenOussoren/roms-finance/issues/136) | bug | P2 | 2 | S | Save contributions independently of guideline return and volatility defaults |
| PJ-08 | [#137](https://github.com/RubenOussoren/roms-finance/issues/137) | bug | P2 | 2 | S | Preserve projection scope and horizon after settings update or reset |
| PJ-09 | [#138](https://github.com/RubenOussoren/roms-finance/issues/138) | bug | P2 | 2 | S | Validate supported forecast horizons before allocating projection output |
| PJ-10 | [#139](https://github.com/RubenOussoren/roms-finance/issues/139) | discovery | P2 | 2 | S | Explain projection assumptions, uncertainty method and fallback provenance |
| AI-01 | [#140](https://github.com/RubenOussoren/roms-finance/issues/140) | bug | P1 | 1 | S | Apply viewer visibility to assistant debt-strategy and connectivity results |
| AI-02 | [#141](https://github.com/RubenOussoren/roms-finance/issues/141) | bug | P1 | 1 | S | Filter category spending numerically before formatting money |
| AI-03 | [#142](https://github.com/RubenOussoren/roms-finance/issues/142) | bug | P1 | 1 | M | Make assistant spending and investment aggregates currency-aware |
| AI-04 | [#143](https://github.com/RubenOussoren/roms-finance/issues/143) | bug | P1 | 1 | S | Stop labeling heuristic HELOC interest matches as established tax deductions |
| AI-05 | [#144](https://github.com/RubenOussoren/roms-finance/issues/144) | bug | P1 | 1 | S | Preserve typed parameter schemas at the RubyLLM tool boundary |
| AI-06 | [#145](https://github.com/RubenOussoren/roms-finance/issues/145) | bug | P1 | 1 | S | Make regenerate and partial-response retry target the originating user prompt |
| AI-07 | [#146](https://github.com/RubenOussoren/roms-finance/issues/146) | bug | P2 | 2 | S | Resolve one effective AI model for fallback, API defaults and attribution |
| AI-08 | [#147](https://github.com/RubenOussoren/roms-finance/issues/147) | bug | P1 | 1 | M | Make AI consent disclosures accurate and verify revocation at dispatch |
| AI-09 | [#148](https://github.com/RubenOussoren/roms-finance/issues/148) | discovery | P1 | 0 | M | Define private versus household AI memory and reviewable deletion semantics |
| AI-10 | [#149](https://github.com/RubenOussoren/roms-finance/issues/149) | enhancement | P2 | 2 | M | Attach scope, freshness and source receipts to financial assistant answers |
| AI-11 | [#150](https://github.com/RubenOussoren/roms-finance/issues/150) | enhancement | P2 | 3 | M | Evaluate three grounded assistant journeys and contextual follow-ups |
| UX-01 | [#151](https://github.com/RubenOussoren/roms-finance/issues/151) | bug | P1 | 1 | S | Restrict manual transaction account choices to writable accounts |
| UX-02 | [#152](https://github.com/RubenOussoren/roms-finance/issues/152) | bug | P2 | 2 | S | Preserve transaction nature, date and categories after validation failure |
| UX-03 | [#153](https://github.com/RubenOussoren/roms-finance/issues/153) | discovery | P1 | 0 | S | Disclose imported-account deletion and guard revert/delete by state |
| UX-04 | [#154](https://github.com/RubenOussoren/roms-finance/issues/154) | bug | P2 | 2 | S | Preserve milestone achievement history across refresh and edits |

## Detailed work items

### DISC-01 — Run synthetic end-user walkthroughs and establish a usability baseline

**Issue:** [#121](https://github.com/RubenOussoren/roms-finance/issues/121) · **discovery** · P1 · phase 0 · size M

**Observation / user impact:** Implementation and successful-response tests do not establish that users can finish a task or understand their numbers. This audit is source-based, not a browser or production reproduction.

**Pinned source evidence:**
- [`docs/FEATURE_ROADMAP.md:1–19`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/docs/FEATURE_ROADMAP.md#L1-L19)
- [`test/controllers/projections_controller_test.rb:18–60`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/test/controllers/projections_controller_test.rb#L18-L60)

**Bounded scope:** Exercise a prepared, isolated sandbox with synthetic fixtures; cover setup, connections, imports, transfers, budgets, equity, projections, milestones, debt strategy and AI. Use the scenario playbook. Start with equity/projections/AI, then inventory the remaining navigation and journeys. Do not seed/reset retained data or call live providers.

**Acceptance criteria:**
- [ ] Record tested SHA, browser/viewport, fixture version and tasks attempted.
- [ ] Capture completion, clarification requests, wrong turns, number comprehension, errors and recovery; retain sanitized screenshots.
- [ ] Include two family members with different permissions and ownership, missing data, mobile and keyboard-only use.
- [ ] Classify each new observation as reproduced bug, usability friction, adequate behavior or unresolved discovery; link a small follow-up issue.
- [ ] Record baseline measurements before setting improvement targets; no invented success rate or test count.

**Synthetic scenario — unexecuted:** Give a participant a synthetic grant statement and ask them to enter it, record a sale and explain net worth. Record what they cannot complete without coaching.

**Dependencies:** None beyond shared approval/validation gates.

### EQ-01 — Clear obsolete vesting valuations when the last vested grant disappears

**Issue:** [#122](https://github.com/RubenOussoren/roms-finance/issues/122) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** Regeneration returns for an empty grant list or no vesting dates before removing generated entries or recalculating balance. Deleting the last grant or moving all vesting into the future can retain old grant-derived values.

**Pinned source evidence:**
- [`app/models/equity_compensation.rb:139–148`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_compensation.rb#L139-L148)
- [`app/models/equity_compensation.rb:192–236`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_compensation.rb#L192-L236)
- [`app/controllers/equity_grants_controller.rb:44–48`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/equity_grants_controller.rb#L44-L48)

**Bounded scope:** Handle empty/no-vested-grant regeneration explicitly, preserving opening anchors and unrelated manual valuations. Characterize final materialized balance rather than merely checking an assigned attribute.

**Acceptance criteria:**
- [ ] Old generated vesting entries are removed when no longer justified.
- [ ] Opening anchors/manual valuations are preserved according to their existing contract.
- [ ] Account balance/history remain consistent after synchronization.
- [ ] Tests cover last-grant deletion, future-only grants and repeat regeneration.

**Synthetic scenario — unexecuted:** Delete a fully vested 100-unit grant at USD 10 with no other balances; then repeat with a legitimate USD 200 opening anchor. Grant-derived value becomes zero.

**Dependencies:** None beyond shared approval/validation gates.

### EQ-02 — Align vested quantities and next-vesting dates with actual schedule boundaries

**Issue:** [#123](https://github.com/RubenOussoren/roms-finance/issues/123) · **bug** · P1 · phase 1 · size M

**Observation / user impact:** Vested quantity counts calendar-month differences without the day, while generated dates use grant-date anniversaries. next_vest_date does not skip periods before the cliff. Values and the next event can disagree with the generated schedule.

**Pinned source evidence:**
- [`app/models/equity_grant.rb:57–67`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant.rb#L57-L67)
- [`app/models/equity_grant.rb:110–125`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant.rb#L110-L125)
- [`app/models/equity_grant.rb:153–164`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant.rb#L153-L164)
- [`app/models/equity_grant.rb:215–217`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant.rb#L215-L217)

**Bounded scope:** Establish one explicit schedule/date convention and use it consistently in quantity, generated dates and next-event reporting. Obtain financial approval for boundary-output changes; do not silently generalize arbitrary employer schedules.

**Acceptance criteria:**
- [ ] Before a scheduled vesting date, its units are not counted as vested.
- [ ] Next vesting skips pre-cliff dates.
- [ ] Month-end, leap-year, quarterly/annual and termination boundaries have independently derived expectations.
- [ ] Existing supported schedules and fractional-unit precision remain documented; unsupported schedules are identified.

**Synthetic scenario — unexecuted:** A Jan 15 monthly grant has zero first-period vesting on Feb 1 and first vest on Feb 15. A 12-month cliff must not advertise the first monthly anniversary as a vest.

**Dependencies:** None beyond shared approval/validation gates.

### EQ-03 — Convert stock-option market and strike prices to the same currency

**Issue:** [#124](https://github.com/RubenOussoren/roms-finance/issues/124) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** The form specifies strike in trading currency, but remaining/vested/unvested value subtract the raw strike from an account-currency market price. Historical regeneration also passes converted prices to remaining_value without converting strike.

**Pinned source evidence:**
- [`app/models/equity_grant.rb:45–54`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant.rb#L45-L54)
- [`app/models/equity_grant.rb:78–105`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant.rb#L78-L105)
- [`app/models/equity_compensation.rb:178–186`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_compensation.rb#L178-L186)
- [`app/models/equity_compensation.rb:210–213`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_compensation.rb#L210-L213)
- [`app/views/equity_grants/_form.html.erb:33–48`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/equity_grants/_form.html.erb#L33-L48)

**Bounded scope:** Normalize market price and strike into the same declared currency before intrinsic-value subtraction, for current/historical/projection callers. Preserve original inputs and expose missing FX separately.

**Acceptance criteria:**
- [ ] Current and historical option values use one currency for both operands.
- [ ] RSU behavior is unchanged.
- [ ] Below-strike values remain zero; missing FX is not parity.
- [ ] Tests cover both conversion directions and explicit-price callers with independently computed expected values.

**Synthetic scenario — unexecuted:** Ten vested options, USD market 100, USD strike 60, USD-to-CAD 1.35: intrinsic value is CAD 540, not CAD 750.

**Dependencies:** EQ-08 ([#129](https://github.com/RubenOussoren/roms-finance/issues/129))

### EQ-04 — Reject inferred equity sales that exceed vested available units

**Issue:** [#125](https://github.com/RubenOussoren/roms-finance/issues/125) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** Automatic rules choose the first eligible grant, fall back to a grant with no available units, and assign the entire inferred sale to it. Validation checks positivity but not availability. Backfill also does not cap its allocation.

**Pinned source evidence:**
- [`app/models/rule/action_executor/create_equity_sale.rb:32–69`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/rule/action_executor/create_equity_sale.rb#L32-L69)
- [`app/models/rule/action_executor/create_equity_sale.rb:84–89`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/rule/action_executor/create_equity_sale.rb#L84-L89)
- [`app/models/equity_grant_sale.rb:5–8`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant_sale.rb#L5-L8)
- [`app/models/equity_compensation.rb:107–132`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_compensation.rb#L107-L132)

**Bounded scope:** First fail safely for unavailable/excess quantities and leave the destination transaction unchanged. Specify same-date ordering and repeat/concurrent processing; defer multi-grant allocation until explicit requirements exist.

**Acceptance criteria:**
- [ ] No automatic sale against unvested/unavailable units.
- [ ] Excess quantity cannot mutate a receipt or create a partial transfer.
- [ ] A reviewable failure reason replaces silent invalid allocation.
- [ ] Exact availability, multi-grant insufficiency, retries and backfill are tested; characterize existing oversale fixtures before changing invariants.

**Synthetic scenario — unexecuted:** Grant A has 10 available units and B has 90 at USD 10. A USD 500 receipt must not create a 50-unit sale from A alone.

**Dependencies:** None beyond shared approval/validation gates.

### EQ-05 — Guide grant entry with a statement-based preview and progressive disclosure

**Issue:** [#126](https://github.com/RubenOussoren/roms-finance/issues/126) · **enhancement** · P2 · phase 2 · size M

**Observation / user impact:** Creating an account and entering a grant are separate steps; the grant form mixes schedule, valuation, optional tax and termination fields. Complexity is observable, but its actual completion cost still needs walkthrough evidence.

**Pinned source evidence:**
- [`app/views/equity_compensations/_form.html.erb:3–15`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/equity_compensations/_form.html.erb#L3-L15)
- [`app/views/equity_grants/_form.html.erb:11–62`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/equity_grants/_form.html.erb#L11-L62)

**Bounded scope:** Start with an RSU thin slice: explain the account/grant distinction, ask only essential statement fields, offer supported schedule presets and preview units/dates/current versus unvested value. Put tax/termination and option-specific inputs behind appropriate disclosure. Do not assume every employer uses the same schedule.

**Acceptance criteria:**
- [ ] A first-time user can add an account and first grant without understanding rules or ledger internals.
- [ ] Preview explains cliff, vesting dates, held versus unvested units, input currency and price freshness.
- [ ] Unsupported/irregular schedules are explicitly described rather than approximated silently.
- [ ] A no-market-provider/no-security state offers an honest supported next step.
- [ ] Keyboard/mobile and invalid-input recovery are included in synthetic walkthroughs.

**Synthetic scenario — unexecuted:** Enter a 1,000-unit, four-year monthly RSU grant with a one-year cliff from a synthetic statement; explain the first vesting amount before saving.

**Dependencies:** DISC-01 ([#121](https://github.com/RubenOussoren/roms-finance/issues/121)), EQ-02 ([#123](https://github.com/RubenOussoren/roms-finance/issues/123)), EQ-08 ([#129](https://github.com/RubenOussoren/roms-finance/issues/129))

### EQ-06 — Offer a one-off reviewed RSU sale instead of requiring automation rules

**Issue:** [#127](https://github.com/RubenOussoren/roms-finance/issues/127) · **enhancement** · P2 · phase 2 · size M

**Observation / user impact:** The inspected grant UI offers edit/delete while the identified sale path is rule-driven. Receipt-derived quantity treats net cash as gross proceeds, so withholding/fees can understate units sold. Vested-to-date and still-held values are not the same.

**Pinned source evidence:**
- [`app/views/equity_compensations/tabs/_grants.html.erb:58–89`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/equity_compensations/tabs/_grants.html.erb#L58-L89)
- [`app/models/rule/action_executor/create_equity_sale.rb:95–125`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/rule/action_executor/create_equity_sale.rb#L95-L125)
- [`app/views/equity_compensations/tabs/_overview.html.erb:6–19`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/equity_compensations/tabs/_overview.html.erb#L6-L19)

**Bounded scope:** Create a discoverable RSU sale review: date, grant, actual sold units, gross proceeds, withholding/fees and net destination cash, followed by a reconciliation preview and confirmation. Keep rules optional. Specify options exercise/settlement in a later slice instead of treating them as identical.

**Acceptance criteria:**
- [ ] Actual sold units override clearly labeled inference.
- [ ] Vested-to-date, sold, remaining held and net cash are distinct labels/values.
- [ ] Preview shows the authorized linked cash movement and prevents double deduction.
- [ ] Cancel leaves all records unchanged; confirmed saves are atomic/idempotent.
- [ ] Do not introduce tax calculations merely by collecting withholding.

**Synthetic scenario — unexecuted:** Sell 10 of 100 vested RSUs at USD 100, receive USD 700 after withholding: held units decrease by 10, not 7.

**Dependencies:** EQ-04 ([#125](https://github.com/RubenOussoren/roms-finance/issues/125)), EQ-07 ([#128](https://github.com/RubenOussoren/roms-finance/issues/128)), EQ-08 ([#129](https://github.com/RubenOussoren/roms-finance/issues/129)), DISC-01 ([#121](https://github.com/RubenOussoren/roms-finance/issues/121))

### EQ-07 — Characterize sale correction, transfer reconciliation and balance refresh

**Issue:** [#128](https://github.com/RubenOussoren/roms-finance/issues/128) · **discovery** · P1 · phase 0 · size M

**Observation / user impact:** The old withdrawal-subtraction proposal does not match today's sold-unit-aware balance formula. Linked sale records, transfers, generated valuations and sync need one characterized lifecycle. Stale-refresh or double-counting failures have NOT been reproduced by this audit.

**Pinned source evidence:**
- [`app/models/equity_grant_sale.rb:1–8`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant_sale.rb#L1-L8)
- [`app/models/equity_compensation.rb:205–236`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_compensation.rb#L205-L236)
- [`app/models/rule/action_executor/create_equity_sale.rb:42–79`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/rule/action_executor/create_equity_sale.rb#L42-L79)
- [`docs/plans/2026-04-11-equity-compensation-withdrawal-tracking-design.md:3–25`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/docs/plans/2026-04-11-equity-compensation-withdrawal-tracking-design.md#L3-L25)

**Bounded scope:** Trace manual/rule-created transfers and sale entry deletion/edit callbacks through balance materialization. Specify correction/undo semantics for linked versus standalone sales, price/vesting refresh triggers and opening-balance treatment. Update the domain contract before redesign.

**Acceptance criteria:**
- [ ] One economic sale affects aggregate equity plus destination cash exactly once.
- [ ] Deleting/correcting linked activity has documented sold-unit and valuation behavior.
- [ ] Advancing across a vest or changing a synthetic price gives coherent account/history/projection values or a visible stale state.
- [ ] Preserve standalone sales and unrelated manual valuations.
- [ ] Record adequate existing behavior as evidence, not a presumed bug; avoid blanket historical backfills.

**Synthetic scenario — unexecuted:** Vest 100 units at USD 10; sell/transfer 20 for USD 200; correct/undo, advance a vesting date and change price. Reconcile holdings, balance history, cash and projection each time.

**Dependencies:** None beyond shared approval/validation gates.

### EQ-08 — Expose missing equity prices and FX instead of zero or parity estimates

**Issue:** [#129](https://github.com/RubenOussoren/roms-finance/issues/129) · **bug** · P1 · phase 1 · size M

**Observation / user impact:** Missing current price returns zero, missing historical prices contribute zero, and FX conversion uses fallback_rate: 1. These produce plausible numbers without establishing value or exchange rate.

**Pinned source evidence:**
- [`app/models/equity_grant.rb:78–85`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_grant.rb#L78-L85)
- [`app/models/equity_compensation.rb:169–186`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_compensation.rb#L169-L186)
- [`app/models/equity_compensation.rb:210–213`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/equity_compensation.rb#L210-L213)
- [`app/models/rule/action_executor/create_equity_sale.rb:35–40`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/rule/action_executor/create_equity_sale.rb#L35-L40)
- [`app/models/rule/action_executor/create_equity_sale.rb:95–117`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/rule/action_executor/create_equity_sale.rb#L95-L117)

**Bounded scope:** Define complete/missing/stale/estimated valuation states and require review instead of automatic sale inference when necessary FX/price data is missing. Characterize fallback callers and seek approval before changing financial outputs.

**Acceptance criteria:**
- [ ] Missing data is distinguishable from a known zero or underwater option.
- [ ] Missing FX prevents automatic inferred-sale mutation.
- [ ] Approved nearest-price/estimate use shows source date and limitation.
- [ ] Synthetic complete/missing/stale cases cover current, historical and sale paths with no provider calls.

**Synthetic scenario — unexecuted:** USD 100 price and CAD 1,350 receipt at 1.35 imply 10 gross units; absent FX yields review-required, never 13.5 units.

**Dependencies:** None beyond shared approval/validation gates.

### PJ-01 — Use a consistent reporting-currency basis for net-worth forecasts

**Issue:** [#130](https://github.com/RubenOussoren/roms-finance/issues/130) · **bug** · P1 · phase 1 · size M

**Observation / user impact:** Family forecasts warn on foreign-currency accounts but sum projected native amounts and present results in family currency. A warning does not establish comparable arithmetic against converted historical actuals.

**Pinned source evidence:**
- [`app/calculators/family_projection_calculator.rb:75–105`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/calculators/family_projection_calculator.rb#L75-L105)
- [`app/calculators/family_projection_calculator.rb:201–229`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/calculators/family_projection_calculator.rb#L201-L229)
- [`app/views/projections/_overview.html.erb:13–19`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/projections/_overview.html.erb#L13-L19)

**Bounded scope:** Approve historical/forward FX conventions, normalize aggregation into reporting currency, or explicitly suppress/qualify incomplete aggregate results. Reuse existing money/FX boundaries, not a new financial framework.

**Acceptance criteria:**
- [ ] History, current anchor, forecast and summary identify a consistent currency convention.
- [ ] Missing FX never becomes zero or implicit parity.
- [ ] Known-rate multi-currency assets and liabilities have independent expected totals.
- [ ] Warnings/incomplete status are visible in chart and summaries, not only logs.

**Synthetic scenario — unexecuted:** CAD 100 plus USD 100 at 1.30 CAD/USD yields CAD 230, not CAD 200. Missing FX yields incomplete.

**Dependencies:** None beyond shared approval/validation gates.

### PJ-02 — Record forecast actuals only after their target date using dated observations

**Issue:** [#131](https://github.com/RubenOussoren/roms-finance/issues/131) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** The job chooses a projection anywhere in the current month and records account.balance immediately, then skips an existing actual. A month-end target can receive an early-month actual that is retained.

**Pinned source evidence:**
- [`app/jobs/projection_update_job.rb:21–32`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/jobs/projection_update_job.rb#L21-L32)
- [`test/jobs/projection_update_job_test.rb:9–38`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/test/jobs/projection_update_job_test.rb#L9-L38)

**Bounded scope:** Define target-date/observation timing and late-arrival/correction semantics. Record eligible dated balance observations for matured targets rather than latest balance; preserve unavailable status for missing data.

**Acceptance criteria:**
- [ ] Unmatured targets never receive actuals.
- [ ] Late processing can evaluate past targets using their eligible dated observations.
- [ ] Missing/stale target-date data remains explicit.
- [ ] Retries do not overwrite finalized observations; corrections have a separate contract.
- [ ] Replace the test expectation that currently permits premature recording with fixed-date regression cases.

**Synthetic scenario — unexecuted:** On Oct 4 an Oct 31 target remains unevaluated. On Nov 1 evaluate a Sep 30 target from its eligible September observation, not November balance.

**Dependencies:** None beyond shared approval/validation gates.

### PJ-03 — Keep projection chart growth summaries within viewer and ownership scope

**Issue:** [#132](https://github.com/RubenOussoren/roms-finance/issues/132) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** The controller builds viewer/personal-scoped projection data, but the chart growth calculation subtracts unscoped family.balance_sheet.net_worth. This produces inconsistent growth and can expose information about excluded accounts through the derived amount.

**Pinned source evidence:**
- [`app/controllers/projections_controller.rb:21–34`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/projections_controller.rb#L21-L34)
- [`app/views/projections/_overview.html.erb:74–80`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/projections/_overview.html.erb#L74-L80)
- [`app/components/UI/projections/net_worth_projection_chart.rb:22–32`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/components/UI/projections/net_worth_projection_chart.rb#L22-L32)
- [`app/components/UI/projections/net_worth_projection_chart.html.erb:11–17`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/components/UI/projections/net_worth_projection_chart.html.erb#L11-L17)

**Bounded scope:** Pass the authorized current anchor/balance sheet to the component; do not recompute family-wide totals inside a scoped chart. Extend the existing foundation authorization work rather than broadening access.

**Acceptance criteria:**
- [ ] Headline, growth, history, anchor and forecast share viewer/scope.
- [ ] Hidden accounts cannot influence disclosed chart growth.
- [ ] Personal ownership and household views use their correct authorized totals.
- [ ] Negative component/request cases prove exact values, not just HTTP success.

**Synthetic scenario — unexecuted:** Viewer sees a USD 100 account; a hidden account holds USD 900. A visible-account forecast of USD 200 must show USD 100 growth, not minus USD 800.

**Dependencies:** None beyond shared approval/validation gates.

### PJ-04 — Connect actual net worth to the current outlook with a clear forecast origin

**Issue:** [#133](https://github.com/RubenOussoren/roms-finance/issues/133) · **enhancement** · P2 · phase 2 · size M

**Observation / user impact:** The existing chart already draws history and future bands on one timeline; family forecast points start at month 1, and the paths remain separate. The problem is continuity/interpretability, not absence of any combined chart.

**Pinned source evidence:**
- [`app/calculators/family_projection_calculator.rb:23–34`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/calculators/family_projection_calculator.rb#L23-L34)
- [`app/calculators/family_projection_calculator.rb:88–116`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/calculators/family_projection_calculator.rb#L88-L116)
- [`app/javascript/controllers/projection_chart_controller.js:39–60`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/javascript/controllers/projection_chart_controller.js#L39-L60)
- [`app/javascript/controllers/projection_chart_controller.js:63–120`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/javascript/controllers/projection_chart_controller.js#L63-L120)

**Bounded scope:** Add a scoped current-origin point and coherent history-to-outlook interaction. Keep historical actuals visible; today's uncertainty starts at today, never retroactively. Provide useful date ticks, shared tooltips and an accessible equivalent. Validate visual behavior in sandbox before choosing styling.

**Acceptance criteria:**
- [ ] Current forecast connects to a correctly scoped/currency-normalized anchor.
- [ ] Legend and boundary distinguish observed history from current outlook.
- [ ] Tooltip identifies actual, median, interval, origin, currency and missing status as applicable.
- [ ] Sparse/no history, one-point history, negative net worth, mobile and keyboard use work.
- [ ] No historical bands are manufactured from today's inputs.

**Synthetic scenario — unexecuted:** Render 12 actual months and a five-year outlook; inspect the boundary, sparse months and shared tooltip. Use stored-vintage monitoring separately for past performance.

**Dependencies:** PJ-01 ([#130](https://github.com/RubenOussoren/roms-finance/issues/130)), PJ-03 ([#132](https://github.com/RubenOussoren/roms-finance/issues/132)), DISC-01 ([#121](https://github.com/RubenOussoren/roms-finance/issues/121))

### PJ-05 — Preserve reproducible forecast vintages instead of replacing the benchmark

**Issue:** [#134](https://github.com/RubenOussoren/roms-finance/issues/134) · **enhancement** · P1 · phase 1 · size M

**Observation / user impact:** Existing generation deletes current/future account projections before recreating them; uniqueness is account plus target date, not forecast issuance. This path writes no percentile payload. Existing storage is not an immutable archive of prior bands.

**Pinned source evidence:**
- [`app/models/account/projection.rb:5–10`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/account/projection.rb#L5-L10)
- [`app/models/account/projection.rb:64–89`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/account/projection.rb#L64-L89)
- [`db/schema.rb:45–61`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/db/schema.rb#L45-L61)

**Bounded scope:** First characterize existing persistence/consumers, then propose the smallest run/vintage contract. Preserve issuance time, targets, initial inputs, assumptions, currency/FX policy, viewer/account scope, algorithm version and applicable seed/count. Schema changes and retention/backfill require their own approved rollout.

**Acceptance criteria:**
- [ ] Changing assumptions creates a new vintage without rewriting earlier forecasts.
- [ ] An issued run can reproduce its point/band data from frozen context.
- [ ] Explicit retry versus new-run behavior and concurrent generation are tested.
- [ ] Archived runs are read through current permissions; removed/hidden account details remain protected.
- [ ] Do not backfill past bands and present them as forecasts actually issued then.

**Synthetic scenario — unexecuted:** Issue A at 4%, then B at 8%; A remains unchanged and selectable. Regeneration cannot erase A.

**Dependencies:** PJ-01 ([#130](https://github.com/RubenOussoren/roms-finance/issues/130)), PJ-02 ([#131](https://github.com/RubenOussoren/roms-finance/issues/131)), PJ-03 ([#132](https://github.com/RubenOussoren/roms-finance/issues/132))

### PJ-06 — Overlay realized actuals against a selected prior forecast and its bands

**Issue:** [#135](https://github.com/RubenOussoren/roms-finance/issues/135) · **enhancement** · P2 · phase 3 · size M

**Observation / user impact:** The requested "where did I land inside the bands?" experience needs genuine ex-ante bands. Dynamically calculated current outlooks and retrospective simulations cannot provide that evidence.

**Pinned source evidence:**
- [`app/models/account/projection.rb:19–56`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/account/projection.rb#L19-L56)
- [`app/models/account/projection_facade.rb:106–116`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/account/projection_facade.rb#L106-L116)
- [`app/models/account/projection.rb:64–89`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/account/projection.rb#L64-L89)

**Bounded scope:** Add a prior-forecast selector and realized-actual overlay using only eligible stored runs. Show forecast issuance, actual observation dates and completeness. Keep retrospective backtests a distinct mode; decide a comparable scope/currency policy for membership changes.

**Acceptance criteria:**
- [ ] Only forecasts issued before a target can count as monitoring.
- [ ] Actuals overlap the selected run's bands for matured targets.
- [ ] Dates before the earliest retained run say No prior forecast; missing actuals remain missing.
- [ ] Point error and interval coverage are separately explained; observed coverage is not a guarantee.
- [ ] Changing run selection never recalculates its historical bands from current inputs.

**Synthetic scenario — unexecuted:** A run issued Jan 1 has future p10/p50/p90 values. Overlay February/March actuals after maturity; identify inside/outside each retained interval.

**Dependencies:** PJ-05 ([#134](https://github.com/RubenOussoren/roms-finance/issues/134)), PJ-02 ([#131](https://github.com/RubenOussoren/roms-finance/issues/131)), PJ-01 ([#130](https://github.com/RubenOussoren/roms-finance/issues/130)), DISC-01 ([#121](https://github.com/RubenOussoren/roms-finance/issues/121))

### PJ-07 — Save contributions independently of guideline return and volatility defaults

**Issue:** [#136](https://github.com/RubenOussoren/roms-finance/issues/136) · **bug** · P2 · phase 2 · size S

**Observation / user impact:** The custom settings branch saves monthly_contribution; the guideline-default branch does not. Saving a contribution while enabling defaults can leave the old cash-flow input in effect.

**Pinned source evidence:**
- [`app/controllers/projection_settings_controller.rb:10–18`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/projection_settings_controller.rb#L10-L18)
- [`app/models/projection_assumption.rb:84–92`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/projection_assumption.rb#L84-L92)

**Bounded scope:** Separate user cash-flow inputs from market/default assumptions. Save submitted contributions consistently, or explicitly disable unsupported simultaneous entry with clear feedback.

**Acceptance criteria:**
- [ ] Enabling guideline defaults with contribution 500 uses 500.
- [ ] An explicit zero clears the old contribution.
- [ ] HTML and Turbo show the same saved settings and calculation inputs.
- [ ] Guideline selection does not unexpectedly overwrite unrelated user inputs.

**Synthetic scenario — unexecuted:** Set monthly contribution 100; submit 500 with guideline defaults selected; reopen settings and verify the chart uses 500.

**Dependencies:** None beyond shared approval/validation gates.

### PJ-08 — Preserve projection scope and horizon after settings update or reset

**Issue:** [#137](https://github.com/RubenOussoren/roms-finance/issues/137) · **bug** · P2 · phase 2 · size S

**Observation / user impact:** HTML redirects omit the chosen scope/horizon while normal projection navigation carries them. Turbo replaces chart/settings only; coherence of surrounding summaries needs rendered verification.

**Pinned source evidence:**
- [`app/controllers/projection_settings_controller.rb:21–35`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/projection_settings_controller.rb#L21-L35)
- [`app/controllers/projection_settings_controller.rb:40–59`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/projection_settings_controller.rb#L40-L59)
- [`app/views/projections/index.html.erb:11–46`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/projections/index.html.erb#L11-L46)

**Bounded scope:** Carry the authorized tab/scope/horizon through update/reset and refresh dependent summaries where required. Maintain account access checks.

**Acceptance criteria:**
- [ ] Personal/20-year context survives both update and reset.
- [ ] HTML/Turbo/reload/back navigation give coherent context.
- [ ] Dependent summary values are refreshed or explicitly identified as stale.
- [ ] Invalid context values use a documented safe default.

**Synthetic scenario — unexecuted:** Edit an investment from Personal/20 years, reset it and use Back. Scope must not silently become Household/10 years.

**Dependencies:** None beyond shared approval/validation gates.

### PJ-09 — Validate supported forecast horizons before allocating projection output

**Issue:** [#138](https://github.com/RubenOussoren/roms-finance/issues/138) · **bug** · P2 · phase 2 · size S

**Observation / user impact:** Request horizons are converted with unrestricted to_i; UI offers a bounded set. Zero, negative, nonnumeric or very large values reach calculations with behavior/cost not matching the UI.

**Pinned source evidence:**
- [`app/controllers/projections_controller.rb:4–6`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/projections_controller.rb#L4-L6)
- [`app/controllers/projection_settings_controller.rb:21–21`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/projection_settings_controller.rb#L21-L21)
- [`app/controllers/projection_settings_controller.rb:44–44`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/projection_settings_controller.rb#L44-L44)
- [`app/views/projections/index.html.erb:40–44`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/projections/index.html.erb#L40-L44)
- [`app/calculators/family_projection_calculator.rb:23–26`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/calculators/family_projection_calculator.rb#L23-L26)

**Bounded scope:** Define one supported horizon validation contract at request boundaries, including update/reset; reject or safely default invalid values before calculation.

**Acceptance criteria:**
- [ ] Supported 5/10/20/30-year choices behave consistently.
- [ ] Zero, negative, nonnumeric and extreme input are handled before allocation.
- [ ] Errors/defaults are understandable and retain other valid form state.
- [ ] Tests cover HTML and Turbo entry points without invoking huge computations.

**Synthetic scenario — unexecuted:** Request horizon -1, nonsense, 0 and 1000000000; verify bounded behavior and usable recovery.

**Dependencies:** None beyond shared approval/validation gates.

### PJ-10 — Explain projection assumptions, uncertainty method and fallback provenance

**Issue:** [#139](https://github.com/RubenOussoren/roms-finance/issues/139) · **discovery** · P2 · phase 2 · size S

**Observation / user impact:** Default assumptions select Jurisdiction.default rather than the family country; correlation and fallback rates are code choices. Analytical and Monte Carlo methods coexist. A confidence label alone does not explain the contract or establish calibration.

**Pinned source evidence:**
- [`app/models/projection_assumption.rb:101–113`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/projection_assumption.rb#L101-L113)
- [`app/calculators/family_projection_calculator.rb:6–11`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/calculators/family_projection_calculator.rb#L6-L11)
- [`app/calculators/family_projection_calculator.rb:122–155`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/calculators/family_projection_calculator.rb#L122-L155)
- [`app/calculators/projection_calculator.rb:115–163`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/calculators/projection_calculator.rb#L115-L163)
- [`app/components/UI/projections/net_worth_projection_chart.html.erb:35–46`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/components/UI/projections/net_worth_projection_chart.html.erb#L35-L46)

**Bounded scope:** Inventory the methods actually shown by each screen and agree plain-language disclosure of nominal/real values, contributions, volatility/correlation, source year/jurisdiction and estimates. Verify any guideline claim against a documented source before updating constants.

**Acceptance criteria:**
- [ ] Each chart identifies its method and relevant assumptions/source version.
- [ ] Custom/fallback values are distinguished from applicable published standards.
- [ ] Disclosures explain percentile intervals without guaranteed outcomes or unsupported compliance claims.
- [ ] A non-Canadian family gets an applicable explanation or explicit limitation, not silent Canadian applicability.
- [ ] Calendar/rate changes are separate approved financial changes.

**Synthetic scenario — unexecuted:** Ask a participant to explain the 10th–90th band, contribution treatment, nominal versus real value and standard year using only the displayed information.

**Dependencies:** DISC-01 ([#121](https://github.com/RubenOussoren/roms-finance/issues/121))

### AI-01 — Apply viewer visibility to assistant debt-strategy and connectivity results

**Issue:** [#140](https://github.com/RubenOussoren/roms-finance/issues/140) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** These tools query all family strategies/connections and return linked-account names/balances without the viewer account scopes already available to other tools. Family tenancy alone does not authorize account detail.

**Pinned source evidence:**
- [`app/models/assistant/function/get_debt_optimization.rb:35–64`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_debt_optimization.rb#L35-L64)
- [`app/models/assistant/function/get_connectivity_status.rb:12–32`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_connectivity_status.rb#L12-L32)
- [`app/models/assistant/function.rb:91–102`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function.rb#L91-L102)

**Bounded scope:** Apply explicit viewer-authorized relations and field allowlists to strategies, linked/unlinked provider accounts and aggregate results. Extend the existing #118 boundary inventory; do not change household sharing defaults.

**Acceptance criteria:**
- [ ] Hidden account names/balances/derived details never enter tool results or outbound provider requests.
- [ ] Balance-only output follows a reviewed field allowlist.
- [ ] Mixed-visible strategies/connections cannot reveal restricted associated-account data.
- [ ] Same-family restriction and different-family negatives cover tools, exports and outbound payloads.

**Synthetic scenario — unexecuted:** Two synthetic members share a family; one has a hidden mortgage and bank connection. The other member's assistant must not disclose its names, balances or derived results.

**Dependencies:** None beyond shared approval/validation gates.

### AI-02 — Filter category spending numerically before formatting money

**Issue:** [#141](https://github.com/RubenOussoren/roms-finance/issues/141) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** category_spending returns formatted Money; parent/subcategory filtering calls to_f on that formatted string. Currency-prefixed values parse as zero and can remove valid spending categories.

**Pinned source evidence:**
- [`app/models/assistant/function/get_categories.rb:43–70`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_categories.rb#L43-L70)

**Bounded scope:** Keep typed numeric values for filtering/sorting and format only presentation fields. Preserve missing-data semantics and authorized account scope.

**Acceptance criteria:**
- [ ] Positive categories survive currency-prefixed and thousands-separated display formats.
- [ ] Known zero behavior is explicit.
- [ ] Nested categories and actual numeric totals have independent assertions.
- [ ] No formatted display string is used as a numerical input.

**Synthetic scenario — unexecuted:** A category with USD 1,234.56 expense must appear rather than being filtered out because "$1,234.56" parses as zero.

**Dependencies:** None beyond shared approval/validation gates.

### AI-03 — Make assistant spending and investment aggregates currency-aware

**Issue:** [#142](https://github.com/RubenOussoren/roms-finance/issues/142) · **bug** · P1 · phase 1 · size M

**Observation / user impact:** These paths sum native monetary amounts and label aggregates with family currency without converting them. Investment holdings rows also omit currency; tax interest/proceeds aggregates need the same review.

**Pinned source evidence:**
- [`app/models/assistant/function/get_categories.rb:64–70`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_categories.rb#L64-L70)
- [`app/models/assistant/function/get_merchants.rb:38–52`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_merchants.rb#L38-L52)
- [`app/models/assistant/function/generate_investment_report.rb:33–66`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/generate_investment_report.rb#L33-L66)
- [`app/models/assistant/function/generate_investment_report.rb:99–104`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/generate_investment_report.rb#L99-L104)
- [`app/models/assistant/function/generate_tax_report.rb:66–72`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/generate_tax_report.rb#L66-L72)

**Bounded scope:** Inventory affected tool/report aggregations and reuse an authorized currency-aware boundary. Convert with approved dated FX or return separate currency totals and explicit incompleteness. Split implementation by tool/report if needed; keep one shared contract.

**Acceptance criteria:**
- [ ] CAD 100 and USD 100 never appear as CAD 200.
- [ ] Missing FX is incomplete, not parity or zero.
- [ ] Holdings/report rows carry their currency and comparable rankings use normalized values.
- [ ] Known-value tests check FX direction, scope and investment cost-basis completeness.
- [ ] Tax/report fixes do not introduce new deductible-interest or gain assumptions.

**Synthetic scenario — unexecuted:** Synthetic CAD 100 and USD 100 spending at 1.30 yields CAD 230; a missing rate returns incomplete, and merchant rank uses comparable values.

**Dependencies:** AI-02 ([#141](https://github.com/RubenOussoren/roms-finance/issues/141))

### AI-04 — Stop labeling heuristic HELOC interest matches as established tax deductions

**Issue:** [#143](https://github.com/RubenOussoren/roms-finance/issues/143) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** Any family strategy triggers a report section labeling interest-name matches across accessible HELOC accounts as Deductible Interest. Neither a text match nor an unrelated strategy establishes borrowing-purpose eligibility.

**Pinned source evidence:**
- [`app/models/assistant/function/generate_tax_report.rb:54–72`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/generate_tax_report.rb#L54-L72)
- [`app/models/assistant/function/generate_tax_report.rb:105–119`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/generate_tax_report.rb#L105-L119)

**Bounded scope:** Present unvalidated matches as candidate interest requiring review, with source entries and limitations. Obtain reviewed jurisdiction/purpose requirements before adding authoritative deduction classification. A disclaimer alone is not a classification fix.

**Acceptance criteria:**
- [ ] Personal-use or unrelated-account interest is not asserted to be deductible.
- [ ] CSV headings, assistant summary keys/text and tool description use consistent non-authoritative terminology.
- [ ] Report identifies evidence and uncertainty.
- [ ] Known eligibility is not invented from account type, transaction name or strategy existence.

**Synthetic scenario — unexecuted:** Family has one Smith strategy and a different personal-use HELOC with an Interest entry. That entry must not be reported as an established deduction.

**Dependencies:** None beyond shared approval/validation gates.

### AI-05 — Preserve typed parameter schemas at the RubyLLM tool boundary

**Issue:** [#144](https://github.com/RubenOussoren/roms-finance/issues/144) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** The adapter declares every property as string, discarding declared array/numeric types and schema constraints. Direct function tests cannot prove the model receives a usable filtering/scenario contract.

**Pinned source evidence:**
- [`app/models/provider/ruby_llm/function_tool_adapter.rb:30–47`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/provider/ruby_llm/function_tool_adapter.rb#L30-L47)
- [`app/models/assistant/function/get_transactions.rb:102–128`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_transactions.rb#L102-L128)
- [`app/models/assistant/function/get_loan_payoff.rb:27–29`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_loan_payoff.rb#L27-L29)

**Bounded scope:** Map supported schema types/items/enums/required constraints accurately and validate arguments before tool execution. Check the locked RubyLLM API rather than inventing adapter syntax.

**Acceptance criteria:**
- [ ] Captured provider tool definitions preserve arrays, numbers, integers and enum constraints.
- [ ] Invalid arguments return a recoverable typed error before DB/financial mutation.
- [ ] Array filters and numeric loan scenarios round-trip through the actual adapter.
- [ ] Deterministic provider stubs prove boundary behavior without live LLM calls.

**Synthetic scenario — unexecuted:** Model supplies account_ids as an array and extra payment 200 as a number; adapter accepts valid typed arguments and rejects malformed values.

**Dependencies:** None beyond shared approval/validation gates.

### AI-06 — Make regenerate and partial-response retry target the originating user prompt

**Issue:** [#145](https://github.com/RubenOussoren/roms-finance/issues/145) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** Retry only enqueues when the final conversation message is a user message. Completed or persisted failed partial assistant responses are last, so retry/regenerate can clear the error without producing an answer.

**Pinned source evidence:**
- [`app/models/chat.rb:30–38`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/chat.rb#L30-L38)
- [`app/models/assistant.rb:102–125`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant.rb#L102-L125)
- [`app/controllers/chats_controller.rb:46–48`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/chats_controller.rb#L46-L48)

**Bounded scope:** Distinguish retry failed attempt from regenerate completed answer, resolve the originating prompt and define treatment of prior partial/completed replies. Prevent duplicate/concurrent replacement attempts.

**Acceptance criteria:**
- [ ] Retry after persisted partial streaming queues one valid replacement.
- [ ] Regenerate completed answer responds to the intended user prompt.
- [ ] Old failed output stays visibly failed and is not silently reused as authoritative context.
- [ ] Duplicate clicks/job retries do not produce competing answers.
- [ ] The user retains prompt/history and sees actionable failure feedback.

**Synthetic scenario — unexecuted:** Stub a timeout after two streamed chunks, click Retry twice and verify exactly one replacement for the same prompt. Repeat after a completed response.

**Dependencies:** None beyond shared approval/validation gates.

### AI-07 — Resolve one effective AI model for fallback, API defaults and attribution

**Issue:** [#146](https://github.com/RubenOussoren/roms-finance/issues/146) · **bug** · P2 · phase 2 · size S

**Observation / user impact:** Fallback resolves a provider for the configured default but the responder still sends the original message model. Assistant attribution also starts with the original model. API omitted-model requests use a hard-coded default rather than the configured setting.

**Pinned source evidence:**
- [`app/models/assistant.rb:25–56`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant.rb#L25-L56)
- [`app/models/assistant/responder.rb:39–46`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/responder.rb#L39-L46)
- [`app/controllers/api/v1/chats_controller.rb:24–27`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/api/v1/chats_controller.rb#L24-L27)

**Bounded scope:** Resolve and pass an effective model through web/API dispatch, persisted response and usage/cost attribution; disclose fallback. Verify current registry behavior first; do not assume an external model exists because documentation lists it.

**Acceptance criteria:**
- [ ] Unsupported requested model plus supported default sends the default in captured requests.
- [ ] No available provider yields a clear configuration error, not a fictitious fallback.
- [ ] Web/API omitted-model behavior follows a consistent approved policy.
- [ ] Response attribution and cost calculation correspond to the effective/returned model.

**Synthetic scenario — unexecuted:** Stub requested model unavailable and configured default available; assert actual provider request and recorded reply use the default.

**Dependencies:** None beyond shared approval/validation gates.

### AI-08 — Make AI consent disclosures accurate and verify revocation at dispatch

**Issue:** [#147](https://github.com/RubenOussoren/roms-finance/issues/147) · **bug** · P1 · phase 1 · size M

**Observation / user impact:** Consent claims all outbound data is anonymized, while prompt/history are forwarded and tools include account/merchant labels. Chat creation and queued dispatch also need end-to-end consent/revocation verification; this audit has not reproduced a post-revocation transmission.

**Pinned source evidence:**
- [`app/views/chats/_ai_consent.html.erb:8–25`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/chats/_ai_consent.html.erb#L8-L25)
- [`app/models/provider/ruby_llm.rb:26–46`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/provider/ruby_llm.rb#L26-L46)
- [`app/models/assistant.rb:139–146`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant.rb#L139-L146)
- [`app/controllers/chats_controller.rb:20–23`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/chats_controller.rb#L20-L23)
- [`app/models/user_message.rb:4–15`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/user_message.rb#L4-L15)
- [`app/jobs/assistant_response_job.rb:4–5`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/jobs/assistant_response_job.rb#L4-L5)

**Bounded scope:** Describe actual provider transmission and retention/memory behavior. Trace web/API creation, retry, summaries, memory extraction and queued jobs, and enforce the approved consent policy before outbound calls. Do not silently change household privacy policy.

**Acceptance criteria:**
- [ ] No unqualified anonymization claim without verified implementation.
- [ ] Disclosure distinguishes local inference from external providers and names the relevant data classes.
- [ ] Direct create/retry and queued execution after disable have explicit negative tests.
- [ ] Summarization/memory paths follow the same reviewed consent boundary.
- [ ] Synthetic identifying content is traced through stubbed outbound payloads, never customer data.

**Synthetic scenario — unexecuted:** Queue a synthetic reply, disable AI, then run the job against a provider stub; verify the reviewed revocation policy and inspect exactly which data would be transmitted.

**Dependencies:** None beyond shared approval/validation gates.

### AI-09 — Define private versus household AI memory and reviewable deletion semantics

**Issue:** [#148](https://github.com/RubenOussoren/roms-finance/issues/148) · **discovery** · P1 · phase 0 · size M

**Observation / user impact:** Memories/profile are family-scoped and injected into every family member's chat instructions; conversation summaries are user-scoped. Existing sharing is code-confirmed, but the intended audience policy is not established. A private chat does not imply private saved memory.

**Pinned source evidence:**
- [`app/models/assistant/function/save_memory.rb:37–42`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/save_memory.rb#L37-L42)
- [`app/models/assistant/configurable.rb:238–259`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/configurable.rb#L238-L259)
- [`app/models/ai_memory.rb:1–17`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/ai_memory.rb#L1-L17)
- [`app/jobs/ai_memory_extraction_job.rb:4–6`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/jobs/ai_memory_extraction_job.rb#L4-L6)
- [`app/models/chat.rb:72–86`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/chat.rb#L72-L86)

**Bounded scope:** Make the policy decision first: private versus explicitly household-shared facts, author/audience, expiry, edit/delete and profile extraction provenance. Provide a reviewable memory UX and clarify whether deleting a chat removes derived memories. Summaries must not retain obsolete decisions silently.

**Acceptance criteria:**
- [ ] Policy and UI identify memory audience before implementation.
- [ ] No private fact reaches another user's outbound context under the chosen private-memory policy.
- [ ] Users can inspect/correct/forget allowed memories and see expiry/provenance.
- [ ] Chat deletion, Forget that and automatic extraction have explicit, testable effects.
- [ ] Existing household memory migration/retention requires separate approved rollout.

**Synthetic scenario — unexecuted:** User A stores a private goal; inspect user B's stubbed prompt. Then explicitly share a household goal and verify the approved audience behavior.

**Dependencies:** None beyond shared approval/validation gates.

### AI-10 — Attach scope, freshness and source receipts to financial assistant answers

**Issue:** [#149](https://github.com/RubenOussoren/roms-finance/issues/149) · **enhancement** · P2 · phase 2 · size M

**Observation / user impact:** Tool logs exist, but calculation date is not source freshness and accessible account balance is not personal ownership. Prompt rules also say not to explain limitations while later requesting transparency about insufficient data.

**Pinned source evidence:**
- [`app/models/assistant.rb:87–98`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant.rb#L87-L98)
- [`app/models/assistant/function/get_accounts.rb:13–31`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_accounts.rb#L13-L31)
- [`app/models/assistant/function/get_debt_optimization.rb:41–64`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_debt_optimization.rb#L41-L64)
- [`app/models/assistant/configurable.rb:163–167`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/configurable.rb#L163-L167)
- [`app/models/assistant/configurable.rb:225–230`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/configurable.rb#L225-L230)

**Bounded scope:** Normalize tool-result evidence metadata and render a compact answer receipt: personal/household scope, included/excluded coverage, period, reporting currency/FX, source observation/sync/run times and completeness. Link authorized supporting records. Align prompt instructions with honest uncertainty.

**Acceptance criteria:**
- [ ] My net worth uses/asks an explicit scope and respects ownership fractions.
- [ ] Calculated-at, last observation, last sync and simulation age are distinct.
- [ ] Missing/stale results qualify the answer and suggest a useful next step.
- [ ] Evidence links cannot reveal hidden/balance-only detail.
- [ ] Conflicting prompt rules are removed and every numeric claim in target journeys is traceable to a tool result.

**Synthetic scenario — unexecuted:** A 70/30 joint account and stale bank sync produce different personal/household totals with clear timestamps and coverage.

**Dependencies:** AI-01 ([#140](https://github.com/RubenOussoren/roms-finance/issues/140)), AI-03 ([#142](https://github.com/RubenOussoren/roms-finance/issues/142)), AI-05 ([#144](https://github.com/RubenOussoren/roms-finance/issues/144)), AI-08 ([#147](https://github.com/RubenOussoren/roms-finance/issues/147))

### AI-11 — Evaluate three grounded assistant journeys and contextual follow-ups

**Issue:** [#150](https://github.com/RubenOussoren/roms-finance/issues/150) · **enhancement** · P2 · phase 3 · size M

**Observation / user impact:** Specialized tools load by current-message keywords plus data flags; a follow-up such as What if I add another 200 may lose its scenario tools. A provider catalogue alone does not prove usable financial assistance.

**Pinned source evidence:**
- [`app/models/assistant/configurable.rb:12–75`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/configurable.rb#L12-L75)
- [`app/models/assistant/configurable.rb:93–108`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/configurable.rb#L93-L108)
- [`app/models/assistant.rb:131–136`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant.rb#L131-L136)
- [`app/models/assistant/function/get_loan_payoff.rb:43–65`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/assistant/function/get_loan_payoff.rb#L43-L65)

**Bounded scope:** Build offline synthetic evaluation for Why did spending rise?, What is my financial position? and What if I pay extra on this loan?. Use conversation intent for narrow tool selection, grounded calculations and authorized navigation to a reviewed next step. Document tool side effects (exports/memory/bootstrap); no autonomous payments/trades/settings changes.

**Acceptance criteria:**
- [ ] Follow-ups retain scenario context or ask when currency/intent is ambiguous.
- [ ] Numbers, period, transfer treatment, scope, missing data and limitations match independent expectations.
- [ ] Suggestions separate explain/preview/confirm and navigate only to authorized screens.
- [ ] Regression evaluation records task success, grounding, privacy, latency/cost where measurable and recovery; model comparisons require no live customer data.
- [ ] Model/provider expansion is justified by journey results, not a 2026 label.

**Synthetic scenario — unexecuted:** Ask about a mortgage, then What if I add another 200?; compare baseline/scenario from stubbed data and open review without executing a payment.

**Dependencies:** DISC-01 ([#121](https://github.com/RubenOussoren/roms-finance/issues/121)), AI-05 ([#144](https://github.com/RubenOussoren/roms-finance/issues/144)), AI-06 ([#145](https://github.com/RubenOussoren/roms-finance/issues/145)), AI-10 ([#149](https://github.com/RubenOussoren/roms-finance/issues/149)), AI-09 ([#148](https://github.com/RubenOussoren/roms-finance/issues/148))

### UX-01 — Restrict manual transaction account choices to writable accounts

**Issue:** [#151](https://github.com/RubenOussoren/roms-finance/issues/151) · **bug** · P1 · phase 1 · size S

**Observation / user impact:** The generic picker lists all manual active family accounts, while create resolves through full_access_accounts. Restricted account names can be offered even though submission will be denied.

**Pinned source evidence:**
- [`app/views/transactions/_form.html.erb:18–22`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/transactions/_form.html.erb#L18-L22)
- [`app/controllers/transactions_controller.rb:57–59`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/transactions_controller.rb#L57-L59)

**Bounded scope:** Use the same family/full-access relation for picker and submission, preserving manual/active filters. Add an actionable empty state without weakening server authorization.

**Acceptance criteria:**
- [ ] Only eligible full-access accounts appear.
- [ ] Direct hidden/balance-only/foreign-family submissions remain denied.
- [ ] No eligible accounts produces a clear setup/access next step.
- [ ] Tests inspect names/options and accepted/denied submissions.

**Synthetic scenario — unexecuted:** Full, balance-only and hidden manual accounts exist; only full appears. A restricted ID submitted directly cannot write.

**Dependencies:** None beyond shared approval/validation gates.

### UX-02 — Preserve transaction nature, date and categories after validation failure

**Issue:** [#152](https://github.com/RubenOussoren/roms-finance/issues/152) · **bug** · P2 · phase 2 · size S

**Observation / user impact:** The retry form reads top-level nature while submission supplies nested entry nature; the date field explicitly uses today. create renders new on failure without the shown new-action category setup. The exact browser failure/sign outcome remains runtime-unverified.

**Pinned source evidence:**
- [`app/views/transactions/_form.html.erb:9–29`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/transactions/_form.html.erb#L9-L29)
- [`app/controllers/transactions_controller.rb:6–9`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/transactions_controller.rb#L6-L9)
- [`app/controllers/transactions_controller.rb:57–74`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/transactions_controller.rb#L57-L74)
- [`app/controllers/transactions_controller.rb:129–140`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/transactions_controller.rb#L129-L140)

**Bounded scope:** Retain explicit form intent and rebuild required categories before failure redisplay. Default the date on first entry only; avoid re-signing a persisted/signed amount twice.

**Acceptance criteria:**
- [ ] Failed income entry retains income tab, compatible categories, amount, account and historical date.
- [ ] Correcting an unrelated invalid field creates the intended signed entry.
- [ ] Expense mode, zero/invalid amounts and repeat failures are covered.
- [ ] Errors are accessible and do not discard valid entered fields.

**Synthetic scenario — unexecuted:** Submit income 125 dated last month with a server-invalid description; repair only that field. It remains income 125 on the original date.

**Dependencies:** None beyond shared approval/validation gates.

### UX-03 — Disclose imported-account deletion and guard revert/delete by state

**Issue:** [#153](https://github.com/RubenOussoren/roms-finance/issues/153) · **discovery** · P1 · phase 0 · size S

**Observation / user impact:** Revert destroys imported accounts and entries, but its confirmation promises deletion of imported transactions only. Complete imports normally show Revert, not Delete; a direct destroy path still exists. Do NOT describe Delete as the ordinary completed-import UI action.

**Pinned source evidence:**
- [`app/models/import.rb:40–43`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/import.rb#L40-L43)
- [`app/models/import.rb:86–94`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/import.rb#L86-L94)
- [`app/controllers/imports_controller.rb:56–59`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/imports_controller.rb#L56-L59)
- [`app/views/imports/_import.html.erb:42–62`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/views/imports/_import.html.erb#L42-L62)

**Bounded scope:** Establish history-removal versus reversal semantics and affected-record disclosure. Trace callbacks/state checks and manual records added to imported accounts. Specify safe preview/cancel/confirm behavior before changing destructive semantics or running any repair.

**Acceptance criteria:**
- [ ] Preview shows affected accounts/entries, including later records on accounts that will be removed.
- [ ] Confirmation accurately distinguishes revert from removing upload/history.
- [ ] Direct requests cannot bypass agreed state/authorization guards.
- [ ] Cancel preserves records; confirm follows the approved contract and refreshes summaries.
- [ ] Characterization covers partial failure and repeat requests in isolated fixtures.

**Synthetic scenario — unexecuted:** Import a synthetic account plus two entries, add a third manually, then preview Revert. Explain whether the account and later manual entry disappear; cancel must preserve all three.

**Dependencies:** None beyond shared approval/validation gates.

### UX-04 — Preserve milestone achievement history across refresh and edits

**Issue:** [#154](https://github.com/RubenOussoren/roms-finance/issues/154) · **bug** · P2 · phase 2 · size S

**Observation / user impact:** Every achieved progress refresh sets achieved_date to today; a non-achieved refresh retains the old date. Editing can rewrite attainment history or leave ambiguous status/date combinations.

**Pinned source evidence:**
- [`app/models/milestone.rb:47–62`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/models/milestone.rb#L47-L62)
- [`app/controllers/milestones_controller.rb:72–74`](https://github.com/RubenOussoren/roms-finance/blob/9477538732da1acf7d52720f358ea27b66777134/app/controllers/milestones_controller.rb#L72-L74)

**Bounded scope:** Agree first/latest/current attainment semantics, then update dates on the corresponding status transition rather than every refresh. Specify target-edit and fall-below/regain behavior.

**Acceptance criteria:**
- [ ] Name edits/refreshes do not rewrite first-attainment date under a first-attainment contract.
- [ ] Status/date behavior on below-target and regain is explicit and tested.
- [ ] Target edits follow the chosen policy.
- [ ] Fixed-date tests cover first achievement, refresh, edit and reattainment.

**Synthetic scenario — unexecuted:** Achieve on day A, refresh/edit on B, drop below and regain on C. Date/status follow the approved history policy.

**Dependencies:** None beyond shared approval/validation gates.

## Shared issue completion contract

Use isolated synthetic fixtures/stubbed providers and add scoped numerical,
authorization and user-flow evidence. Financial conventions, privacy/consent,
schema/backfill, destructive operations and rollout require their own reviewed
decisions. A linked issue authorizes none of these automatically. Avoid framework
rewrites and preserve Rails/Hotwire patterns. Implementing PRs must include exact
fresh checks, tested revision, before/after journey evidence and remaining risks.
See the roadmap for phase exit gates and the playbook for safe validation.

## Coverage and residual uncertainty

Relevant model/calculator/controller/component/system tests already exist, including
`test/models/equity_grant_test.rb`, `test/models/equity_compensation_test.rb`,
`test/calculators/family_projection_calculator_equity_comp_test.rb`,
`test/controllers/projections_controller_test.rb`,
`test/jobs/projection_update_job_test.rb` and
`test/models/assistant/function_privacy_test.rb`. Their presence is neither a fresh
passing result nor proof that every listed boundary is covered. Examples of weak
signals include successful-response-only controller assertions and the actuals job
test that currently accepts a current-month early recording.

The audit did not execute these tests or browser flows. Sale/transfer materializer
reconciliation and callback-driven correction/refresh, full consent enforcement,
operational scheduling and broader onboarding/budget/debt journeys remain explicit
discovery/verification work. Existing golden masters are regression artifacts, not
ex-ante forecast vintages or independent statistical calibration. No financial
calibration, regulatory compliance or comprehensive privacy certification is claimed.
