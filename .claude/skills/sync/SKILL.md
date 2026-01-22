---
name: sync
description: Create a Sidekiq sync job for background data synchronization
---

# Create Sync Job

Generate a Sidekiq background job for data synchronization following project patterns.

## Usage

```
/sync AccountSyncJob          # Account sync job
/sync PlaidSyncJob            # Plaid integration sync
/sync ExchangeRateSyncJob     # Exchange rate sync
```

## Sync Architecture

The application uses Sidekiq for background processing:
- `Sync` model tracks sync operations
- Jobs handle async data updates
- Retry and error handling built-in
- Scheduled via sidekiq-cron

## Generated Files

1. **Job:** `app/jobs/{{name}}_job.rb`
2. **Test:** `test/jobs/{{name}}_job_test.rb`

## Sync Job Template

```ruby
# frozen_string_literal: true

class AccountSyncJob < ApplicationJob
  queue_as :default

  # Retry configuration
  retry_on StandardError, wait: :polynomially_longer, attempts: 5
  discard_on ActiveRecord::RecordNotFound

  def perform(account_id)
    account = Account.find(account_id)
    sync = account.syncs.create!(status: :syncing)

    begin
      # Perform sync operation
      result = sync_account(account)

      sync.update!(
        status: :completed,
        completed_at: Time.current,
        metadata: result
      )
    rescue StandardError => e
      sync.update!(
        status: :failed,
        error_message: e.message
      )
      raise # Re-raise for retry
    end
  end

  private

  def sync_account(account)
    # Sync logic here
    # Returns metadata hash
    {
      transactions_synced: 0,
      balances_updated: true
    }
  end
end
```

## Instructions

1. Parse job name from arguments
2. Generate job class in `app/jobs/`
3. Include Sync model integration
4. Add retry and error handling
5. Generate corresponding test file

## Sync Model Integration

```ruby
# Creating a sync record
sync = syncable.syncs.create!(status: :syncing)

# Updating sync status
sync.update!(status: :completed, completed_at: Time.current)
sync.update!(status: :failed, error_message: "Error details")

# Sync statuses: pending, syncing, completed, failed
```

## Scheduled Jobs

For recurring syncs, add to sidekiq-cron:
```yaml
# config/schedule.yml
account_sync:
  cron: "0 */6 * * *"  # Every 6 hours
  class: "AccountSyncJob"
  queue: default
```

## Plaid Integration Pattern

```ruby
class PlaidSyncJob < ApplicationJob
  def perform(plaid_item_id)
    plaid_item = PlaidItem.find(plaid_item_id)

    # Fetch from Plaid API
    transactions = plaid_client.transactions(plaid_item.access_token)

    # Update local data
    transactions.each do |txn|
      plaid_item.account.transactions.find_or_create_by(
        plaid_transaction_id: txn.id
      ) do |t|
        t.assign_attributes(transaction_attributes(txn))
      end
    end
  end
end
```

## Important Notes

- Use `Current.family` when applicable for scoping
- Always create Sync record for tracking
- Implement proper retry logic
- Log errors for debugging
- Consider rate limits for external APIs
- Use VCR for testing external API calls
