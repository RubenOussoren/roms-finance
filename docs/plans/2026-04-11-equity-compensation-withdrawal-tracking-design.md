# Equity Compensation: Withdrawal Tracking

## Problem

When a user sells vested GSUs and transfers proceeds to a bank account, the equity compensation account balance doesn't decrease. `regenerate_vesting_valuations!` always sets `balance = total_vested_value` based purely on the vesting schedule, ignoring any transfers/withdrawals.

## Design

**Balance formula**: `balance = total_vested_value - total_withdrawals`

Where `total_withdrawals` is the sum of all positive-amount Transaction entries on the equity compensation account. Positive amount on an asset account = outflow (money leaving the account).

### Changes

1. **`EquityCompensation` model** — add `total_withdrawals` method that sums outgoing Transaction entries
2. **`regenerate_vesting_valuations!`** — change balance calculation from `total_vested_value` to `total_vested_value - total_withdrawals`
3. **Sync hook** — ensure balance recalculates when new transfers are added (Entry creation triggers `sync_account_later`, which calls the balance materializer)

### Constraints

- Only sum `entryable_type: "Transaction"` entries (not Valuations, which are vesting events)
- Only sum positive amounts (outflows)
- Balance cannot go negative (floor at 0)
- Unvested display unchanged
- No schema changes needed

### Example

- 275 vested units at $300/unit = $82,500 vested value
- $20,000 transferred out over time
- Balance: $82,500 - $20,000 = $62,500
