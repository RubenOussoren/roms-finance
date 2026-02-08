# Architecture Coherence Checklist

Use this checklist when evaluating Dimension 3 (Architectural Coherence) of the phase review. Check each item relevant to the phase's changes. Skip items that don't apply.

## Models & Data Layer

- [ ] New models have appropriate `belongs_to` / `has_many` associations defined
- [ ] New columns have database-level constraints (NOT NULL, defaults) matching business rules
- [ ] New indexes exist for columns used in WHERE clauses, JOINs, or ORDER BY
- [ ] Migrations are reversible (or explicitly marked `irreversible` with justification)
- [ ] No raw SQL that could be expressed as ActiveRecord scopes
- [ ] Validations exist at the model level, not only in controllers or views
- [ ] Callbacks are used sparingly — side effects (emails, cache invalidation) belong in service objects

## Services & Calculators

- [ ] New services follow existing naming conventions (e.g., `VerbNounService` or `NounCalculator`)
- [ ] Calculators are pure: they accept inputs as arguments and return results without side effects
- [ ] No `Rails.cache`, database writes, or HTTP calls inside calculator classes
- [ ] Service objects have a single public entry point (`.call`, `.run`, or `.calculate`)
- [ ] Complex financial formulas cite their source in a comment
- [ ] Shared logic is extracted to modules, not duplicated across services

## Controllers

- [ ] Controllers are thin — business logic lives in models or services, not controllers
- [ ] No N+1 queries (use `includes`, `preload`, or `eager_load` for associations)
- [ ] Strong parameters are used for all user inputs
- [ ] Error handling returns appropriate HTTP status codes
- [ ] New routes follow RESTful conventions and existing naming patterns

## Views & Frontend

- [ ] No business logic in views — calculations happen in helpers, presenters, or controllers
- [ ] Partials are used for repeated UI patterns (no copy-pasted HTML blocks)
- [ ] Hardcoded strings that should be configurable (currency symbols, units) use helpers
- [ ] New JavaScript follows existing patterns (Stimulus controllers, Turbo frames, etc.)
- [ ] Accessibility basics: labels on form fields, alt text on images, ARIA roles where needed

## Tests

- [ ] New test files follow existing directory structure (`test/models/`, `test/services/`, etc.)
- [ ] Test names describe behavior, not implementation ("calculates monthly payment" not "calls rate_helper")
- [ ] Financial tests use known-value assertions with documented expected values
- [ ] No test depends on execution order or shared mutable state
- [ ] Fixtures/factories are minimal — only set fields relevant to the test

## Cross-Cutting

- [ ] No circular dependencies between modules or classes
- [ ] New patterns are consistent with existing patterns (or the deviation is documented)
- [ ] Error messages are user-facing quality (not raw exception messages)
- [ ] Logging is present for important operations but not excessive
- [ ] No dead code: every new file is referenced, every new method is called
