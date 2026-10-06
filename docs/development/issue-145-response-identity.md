# Issue #145: additive response identity plan

Status: implemented and validated locally; publication/CI evidence is recorded
separately. The maintainer approved the contract, additive schema, four-version
isolated upgrade and later ownership reconciliation. Nothing is deployed.
Historical review and safety-incident details below are preserved explicitly.

## Approved contract

Keep prompts and every assistant attempt visible. Failed attempts stay failed;
older successful versions remain distinguishable. Provider context selects the
newest successful answer per explicit originating prompt; pending/failed
regenerations do not displace success. Regeneration uses eligible preceding
turns and its original prompt, never that prompt's answers or later turns.
There is no branching, later-turn replay, or memory/consent/retention change.

Legacy assistant messages have no reliable origin identity. Leave their rows
untouched and visible; do not infer associations or backfill by adjacency or
timestamps. Exclude unlinked legacy replies from provider context, disclose the
incomplete historical context, and require an explicit new prompt instead of
regenerating an unlinked reply. Existing authorization remains unchanged.

## Expansion migrations

1. `20261006030000`: add five nullable fields without defaults to `messages`:
   `origin_user_message_id`, `replaces_message_id`, `attempt_number`,
   `execution_claimed_at`, and `conversation_turn`. Add unvalidated row-shape
   checks. Legacy rows with null identity fields satisfy these checks.
2. `20261006030001`: build four unique indexes concurrently: `(id, chat_id)`
   for in-chat reference integrity, `(origin_user_message_id, attempt_number)`
   for version identity, `replaces_message_id` as the uniqueness backstop for application-level repeated-click coalescing,
   and `(chat_id, conversation_turn)` for explicit user-turn ordering. The
   latter three are partial indexes excluding null legacy identity.
3. `20261006030002`: add unvalidated composite self-referencing foreign keys
   requiring origin/replacement links to remain in the same chat. These keys
   are initially deferred: existing transactional chat deletion can destroy all
   linked messages with callbacks in any order. At commit, dangling links are
   still rejected. No cascading deletion or new deletion endpoint is added.
4. `20261006030003`: validate the foreign keys and both row-shape checks in a
   separate transaction, after FK-installation locks have been released.

Application validation must additionally require an origin to be a UserMessage,
a replacement to be an AssistantMessage for that same origin, and an attempt
number to advance the replaced attempt. Database constraints do not by
themselves enforce these cross-row type/sequence rules.

## Implemented workflow

Serialize attempt creation and turn assignment with the existing chat row lock.
Persist an empty pending AssistantMessage before enqueueing its ID through one
path. Original generation uses attempt 1; Retry/Regenerate identifies the source
attempt explicitly. Repeated requests for that source return its existing
replacement, even if the replacement has already completed. A new regeneration
must explicitly target the newer answer.

Claim the attempt durably before provider dispatch. Concurrent/redelivered jobs
must not reclaim it. The assistant writes into that attempt rather than creating
another answer. A durable claim is not an external exactly-once guarantee: a
process crash leaves uncertain work, which needs visible recovery, not automatic
re-execution of the claimed attempt. Enqueue failures must likewise leave an
identifiable recoverable operation. These paths have focused, browser and independent review evidence.

## Execution and rollout boundaries

The four approved migrations were applied once to the existing disposable test
DB and the resulting schema captured. No production migration or rollback ran.
A first test invocation subsequently triggered an unintended implicit Rails
schema reconstruction: the direct dumper had left the old schema fingerprint.
The next resource check detected the missing ownership marker and refused work.
Validation stopped; only the capture-only operation was supervised and cleaned.
After separate maintainer permission, schema/version/constraint/index/fingerprint
and Redis identities were verified and only the original DB ownership comment
was restored. Tests now use a fail-closed maintenance guard; fingerprint mismatch
or pending migrations cannot silently invoke `db:test:prepare`. Direct schema
load/reconstruction/drop/purge/truncate routes require separate approval.
The migration helper also records the new dump fingerprint explicitly.
This incident is a failed safety approach, not approved test preparation.

The reviewed `AUTONOMY_MIGRATE_APPROVED=issue-145 bin/autonomy-check
db:issue145:migrate` path applies only these four versions in verified
`roms_autonomy_test`, rejects unknown versions/partial upgrades/unexpected pending
migrations and requires the baseline. Do not rerun it after this upgrade.
It uses the same frozen-source/offline guards, 5s lock and 120s statement timeouts,
and retains pending evidence on migration failure. Schema publication is restricted
to the captured `db/schema.rb`, refuses unrelated edits, and assumes the common
phase lock's exclusive schema-edit window. No bootstrap schema-load flag is used.

The first, third and fourth migrations use transactions. Adding nullable columns has no
backfill/table rewrite, but acquires table locks. Constraint validation scans
`messages`; foreign-key creation/validation also takes locks. FK installation
holds a stronger write-conflicting lock until the third migration commits;
validation is deliberately separate to avoid retaining that lock during scans. Concurrent index
creation reduces write blocking but consumes I/O/storage and is nontransactional.
No production-scale lock duration, table size, backup readiness, or operational
window has been measured or approved. No production execution is authorized.

If an index build fails, inspect its exact validity and migration outcome under
supervision; do not blindly retry, drop indexes, or use `if_not_exists` to conceal
an invalid index. Stop on unexpected state. The migrations are reversible DDL,
but rollback would remove newly captured origin/attempt metadata; after new
writers run, reversal needs its own decision and must not be automatic.

New application code must not run before the expansion is complete. Old code
can write null identity fields during an expansion window; those rows stay legacy
and are not silently mapped. Retire/drain old queued message jobs through an
explicitly reviewed compatibility path, not by inferring their intent.

Local validation includes baseline upgrade and schema inspection,
constraint negatives (including commit-time cross-chat/dangling-link failures),
linked-chat/user deletion with callbacks inside transactions, focused
model/controller/job coverage, deterministic
stream failure/retry/regeneration browser flows, the full unit/integration suite,
applicable static gates and independent implementation review. A fresh-install schema load or rollback test
would need separate approval; existing resources do not grant it.

## Schema review follow-up

Independent read-only schema review found no NULL-check or uniqueness defect,
but identified FK-lock lifetime and existing dependent-destroy compatibility.
Installation and validation are now separate migrations; initially deferred
foreign keys preserve whole-chat transactional deletion without adding cascade
semantics. The approved isolated upgrade and deferred-FK/dependent-destroy tests passed.
The schema does not implement request coalescing, identity immutability, context
selection, claim acquisition, new-writer identity requirements or cycle prevention;
those remain application implementation and regression-review obligations.

## Interrupted-attempt recovery and output fencing

Claims are never reset. After five minutes without a persisted update, the user
can explicitly select Stop and retry (API: `recover_interrupted: true`). Under
the chat and attempt locks, the source becomes failed while retaining content
and claim, and one replacement is reserved. Normal retry/redelivery never takes
over pending work. Persisted stream writes, token/tool logs, completion and
failure callbacks recheck the source status under its row lock. Late writes from
an abandoned execution cannot restore it to complete or contaminate context.
This does not cancel upstream network work or prove an idle process dead; nor
can it undo tool effects already executed. No new tool or consent policy is added.

The singleton chat-error container is updated, not appended repeatedly. Its
banner directs users to the failing attempt's own action rather than guessing
from the latest prompt. The original failed attempt remains visible even if a
later operation clears the current banner.

Real PostgreSQL concurrency tests verify distinct backend connections, observed
row-lock contention, single replacement enqueue and one provider invocation on
concurrent redelivery. They also exercise unique/check/deferred-FK failures and
whole-chat/user dependent destruction with callbacks. Synthetic browser tests
exercise actual queued attempt arguments and deterministic provider output.
