# Per-User Account Privacy Controls

**Purpose**: This document captures the original **design spec** for per-user account privacy controls. It served as the planning and implementation tracking artifact during development.

> **WARNING — Planning document**: This file reflects the *original design spec*, not necessarily the current implementation in all details. Some patterns may have been adjusted during implementation (e.g., migration details, controller naming, scope semantics). For current architecture, see the Cursor rules in `.cursor/rules/` and the actual source code.

## Status: Complete

## Context

Currently, all accounts in a Family are fully visible to all family members — there are no per-user visibility boundaries. All 77+ account queries scope to `Current.family.accounts` without user-level filtering. Accounts have no `created_by` tracking, no "joint" concept, and no authorization layer.

**Goal**: Let family members control what they share: full access (transactions visible), balance only (just the number), or hidden entirely. Joint accounts are always fully visible. Enable personal vs household net worth views.

---

## Database Changes (4 migrations)

### Migration 1: Add ownership + joint flag to accounts
```
accounts table:
  + created_by_user_id  (uuid, FK → users, nullable initially)
  + is_joint            (boolean, default: false, not null)
  + index on (family_id, created_by_user_id)
```

### Migration 2: Create account_permissions table
```
account_permissions table:
  id              (uuid, PK)
  account_id      (uuid, FK → accounts, not null)
  user_id         (uuid, FK → users, not null)
  visibility      (string, not null, default: "full")
                  — values: "full", "balance_only", "hidden"
  timestamps

  unique index on (account_id, user_id)
  index on (user_id, visibility)
```

### Migration 3: Backfill existing accounts
- Single-user families: assign all accounts to that user
- Multi-user families: assign all accounts to the admin (or oldest user)
- No AccountPermission rows created (default = full access, backward compatible)

### Migration 4: Make created_by_user_id NOT NULL
- Runs after backfill completes successfully

---

## New Model: AccountPermission

**File**: `app/models/account_permission.rb`

- `belongs_to :account`, `belongs_to :user`
- Validates visibility in `%w[full balance_only hidden]`
- Validates uniqueness of user scoped to account
- Validates user is not the account owner (owners always have full access implicitly)
- Validates joint accounts cannot have non-full visibility
- Scopes: `for_user(user)`, `full_access`, `balance_only`, `hidden`
- `after_save`/`after_destroy` → `account.touch` (cache invalidation)

---

## New Concern: AccountAccessible (on Account)

**File**: `app/models/concerns/account_accessible.rb`

Core scopes (SQL via LEFT JOIN on account_permissions):

| Scope | Returns | Use case |
|-------|---------|----------|
| `accessible_by(user)` | Own accounts + full + balance_only (excludes hidden) | Sidebar, balance sheet, net worth |
| `full_access_for(user)` | Own accounts + explicitly "full" + default (no permission row) | Transaction lists, entry queries, holdings |
| `balance_only_for(user)` | Accounts where user has balance_only permission | Conditional UI rendering |
| `hidden_from(user)` | Accounts where user has hidden permission | Inverse check |
| `owned_by(user)` | Accounts created by user | Personal net worth |

Instance methods:
- `owned_by?(user)` — is this user the creator?
- `visibility_for(user)` → `:full` / `:balance_only` / `:hidden`
- `accessible_by?(user)`, `full_access_for?(user)`, `balance_only_for?(user)`

**Default behavior**: No `AccountPermission` row = full access (backward compatible).

**Account creation flow**: When creating an account in a multi-user family, the creation form includes a visibility section where the owner can set per-member visibility (Full / Balance Only / Hidden) at creation time. Defaults to "full" if not specified.

---

## Model Changes

### Account (`app/models/account.rb`)
- `include AccountAccessible`
- `belongs_to :created_by_user, class_name: "User"`
- `has_many :account_permissions, dependent: :destroy`
- Update `create_and_sync` to set `created_by_user_id: Current.user.id`

### User (`app/models/user.rb`)
- `has_many :owned_accounts, class_name: "Account", foreign_key: :created_by_user_id, dependent: :nullify`
- `has_many :account_permissions, dependent: :destroy`
- On deactivation: reassign owned accounts to family admin

### Family (`app/models/family.rb`)
- Add `multi_user?` method
- Add `balance_sheet_for(user, scope:)` convenience method
- `scope` parameter: `:personal` (owned_by user) or `:household` (accessible_by user)

---

## BalanceSheet + Net Worth Changes

### BalanceSheet (`app/models/balance_sheet.rb`)
- Constructor gains optional `viewer:` and `scope:` params
- Passes these through to `AccountTotals` and `NetWorthSeriesBuilder`
- When `viewer` is nil → family-wide (admin/legacy behavior)

### BalanceSheet::AccountTotals (`app/models/balance_sheet/account_totals.rb`)
- `visible_accounts` method adds `.accessible_by(viewer)` when scope is `:household`
- Adds `.owned_by(viewer)` when scope is `:personal`
- Cache key includes `viewer.id` and `scope` to avoid cross-user cache pollution

### Net Worth Views
| View | Accounts included |
|------|-------------------|
| **Personal** | Only accounts owned by (created by) current user |
| **Household** | All accounts accessible to current user (own + full + balance_only) |

Hidden accounts are excluded from BOTH views for the user they're hidden from. Household net worth only sums accounts the user can actually see (full + balance_only), not truly all family accounts.

---

## Controller Changes

### Central pattern: `scoped_accounts` helper in ApplicationController
```ruby
def scoped_accounts
  family.accounts.accessible_by(Current.user)
end

def full_access_accounts
  family.accounts.full_access_for(Current.user)
end
```

### Controllers to update (by priority):

**Phase 1 — Core access control (5 files):**
- `AccountsController#set_account` (line 71) → `scoped_accounts.find(params[:id])`
- `AccountableResource#set_account` (line 78) → `scoped_accounts.find(params[:id])`
- `AccountableResource#create` (line 37) → set `created_by_user_id`
- `AccountsController#show` → pass `visibility` to view, conditionally hide entries
- `PagesController#dashboard` → use `balance_sheet_for(Current.user, scope:)`

**Phase 2 — Transaction filtering (4 files):**
- `TransactionsController#index` → filter to `full_access_accounts` only
- `Transaction::Search` → accept `viewer:`, restrict to full-access account IDs
- `IncomeStatement` → accept `viewer:`, filter transactions to full-access accounts
- Account detail entries → hide for `balance_only` accounts

**Phase 3 — Remaining controllers (~13 files):**
- `HoldingsController`, `TradesController`, `ValuationsController` → scoped_accounts
- `ProjectionsController` → scoped_accounts for investment/debt tabs
- `BudgetsController` → filter to full-access accounts
- `TransferMatchesController`, `ImportsController` → scoped_accounts
- `DebtOptimizationStrategiesController`, `MilestonesController`
- `AccountableSparklines` → filter account IDs

**Phase 4 — API + AI (6 files):**
- `Api::V1::AccountsController` → accessible_by scope
- `Api::V1::TransactionsController` → full_access_for scope
- `Assistant::Function::GetAccounts`, `GetTransactions`, `GetBalanceSheet`, `GetIncomeStatement`

---

## New Controller: AccountPermissionsController

**Route**: `resources :accounts do resource :account_permissions, only: [:edit, :update] end`

- `before_action :ensure_account_owner` — only the account creator can set visibility
- `edit` — shows form with one row per non-owner family member, dropdown: Full / Balance Only / Hidden
- `update` — upserts AccountPermission rows
- Joint accounts: show disabled controls with explanation message
- Single-user families: controller returns 404 (no point showing privacy for 1 user)

---

## UI/View Changes

### Sidebar (`app/views/accounts/_account_sidebar_tabs.html.erb`)
- Balance sheet passed from layout with viewer scope
- Hidden accounts: not rendered at all
- Balance-only accounts: rendered with muted styling, no sparkline link, balance shown but not clickable to detail

### Dashboard
- Toggle: "Personal" / "Household" (only shown when `family.multi_user?`)
- Uses query param `?scope=personal` or `?scope=household` (default: household)
- Turbo Frame for net worth section to swap without full reload

### Account Detail (`accounts/show.html.erb`)
- For `balance_only` accounts: show name, type, balance, balance chart
- Hide activity feed, holdings tab, trades
- Show banner: "You have balance-only access to this account"
- For owner: show "Privacy Settings" link in account settings

### Account Creation/Edit
- Add "Joint account" checkbox (when `family.multi_user?`)
- Add visibility section during account creation: per-member dropdown (Full / Balance Only / Hidden), defaults to Full
- Joint accounts show badge in sidebar and account views

### Transaction Pages
- Account filter dropdown only shows full-access accounts
- Global search only returns transactions from full-access accounts

### Joint Account Prompt
- When viewing a joint account linked by another user, show info banner: "[User] linked this joint account. Both members have full access."

---

## Caching Strategy

Current cache key (`family.build_cache_key`):
```ruby
[id, key, data_invalidation_key, accounts.maximum(:updated_at)]
```

Updated to include viewer context:
```ruby
[id, key, viewer_id, scope, data_invalidation_key, accounts.maximum(:updated_at)]
```

- `AccountPermission` changes → `account.touch` → invalidates cache
- Per-user cache keys prevent cross-user cache leakage
- Single-user families: viewer_id is nil, no cache duplication

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| Single-user family | No privacy UI shown, all scopes return all accounts |
| User removed from family | Owned accounts reassigned to admin, permissions deleted |
| Account owner deletes account | Normal deletion, permissions cascade-deleted |
| Joint account created | Both users always have full access, cannot be restricted |
| New user joins family | All existing accounts default to full access (no permission rows) |
| Plaid-linked accounts | `PlaidAccount::Processor` sets `created_by_user_id` from PlaidItem linker |
| CSV imports | `AccountImport` sets `created_by_user_id` from `Current.user` |

---

## Implementation Phases (Incremental — ship after each phase)

### Phase 1: Foundation (database + core model) — `[x] COMPLETE`
- [x] Migration 1: Add `created_by_user_id` and `is_joint` to accounts
- [x] Migration 2: Create `account_permissions` table
- [x] Migration 3: Backfill existing accounts with `created_by_user_id`
- [x] Migration 4: Make `created_by_user_id` NOT NULL
- [x] `AccountPermission` model with validations and tests
- [x] `AccountAccessible` concern with scopes and tests
- [x] Include concern in Account, update `create_and_sync`
- [x] Update User model (associations, deactivation handling)
- [x] Update `AccountsController#set_account` and `AccountableResource#set_account`
- [x] Tests: Hidden account returns 404, owned account still accessible

### Phase 2: Balance sheet + net worth — `[x] COMPLETE`
- [x] Update `BalanceSheet`, `AccountTotals`, `NetWorthSeriesBuilder` with viewer/scope
- [x] Add `Family#balance_sheet_for` and `Family#multi_user?`
- [x] Update `PagesController#dashboard` with scope toggle
- [x] Update sidebar to use scoped balance sheet
- [x] Balance-only account visual treatment in sidebar
- [x] Update cache keys
- [x] Tests: Personal vs household net worth calculation, cache isolation

### Phase 3: Transaction + entry filtering — `[x] COMPLETE`
- [x] Update `Transaction::Search` with viewer filtering
- [x] Update `TransactionsController`, `IncomeStatement`
- [x] Account detail page: hide entries for balance_only accounts
- [x] Update `HoldingsController`, `TradesController`, `ValuationsController`
- [x] Update transaction filter dropdown to only show full-access accounts
- [x] Tests: Transactions from balance-only accounts not visible, search respects visibility

### Phase 4: Privacy settings UI — `[x] COMPLETE`
- [x] `AccountPermissionsController` (edit/update)
- [x] Privacy settings form (per-member visibility dropdown)
- [x] Joint account checkbox in account creation/edit
- [x] Joint account badge in sidebar
- [x] Only show privacy UI for multi-user families
- [x] Tests: System test for setting visibility, joint account enforcement

### Phase 5: Remaining controllers + API + AI — `[x] COMPLETE`
- [x] Update ~13 remaining controllers
- [x] Update API endpoints
- [x] Update AI assistant functions
- [x] Update PlaidItem/Import to track `created_by_user_id`
- [x] Update family exports to respect viewer
- [x] Tests: Full regression test suite, API visibility tests

---

## Verification Plan

1. **Unit tests**: AccountPermission validations, AccountAccessible scopes (SQL correctness)
2. **Integration tests**: Controller access for hidden/balance_only/full accounts
3. **System tests**: Full flow — set privacy settings, verify sidebar/dashboard/transactions
4. **Manual testing**: Log in as both demo users, set privacy on accounts, verify personal vs household net worth
5. **Run full test suite**: `bin/rails test` — ensure no regressions
6. **Brakeman**: Security analysis for new controller/model
