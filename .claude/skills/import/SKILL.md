---
name: import
description: Create a CSV import handler with field mapping
---

# Create Import Handler

Generate an import handler following the project's Import pattern.

## Usage

```
/import TransactionImport       # Transaction import handler
/import BalanceImport           # Balance import handler
/import CustomDataImport        # Custom data import
```

## Import Architecture

The application uses a structured import system based on the `Import` base class:
- **Status enum:** `pending`, `complete`, `importing`, `reverting`, `revert_failed`, `failed` (string enum)
- **Types:** `TransactionImport`, `TradeImport`, `AccountImport`, `MintImport`
- Subclasses implement: `import!`, `column_keys`, `required_column_keys`, `mapping_steps`
- Errors stored in `.error` string column (not an association)
- CSV rows stored in `Import::Row` records, mappings in `Import::Mapping` records

## Generated Files

1. **Import handler:** `app/models/{{name}}_import.rb`
2. **Test:** `test/models/{{name}}_import_test.rb`

## Import Handler Template

```ruby
# frozen_string_literal: true

class ExampleImport < Import
  def import!
    transaction do
      mappings.each(&:create_mappable!)

      records = rows.map do |row|
        mapped_account = if account
          account
        else
          mappings.accounts.mappable_for(row.account)
        end

        # Build your domain object from the mapped row
        # Example from TransactionImport:
        # Transaction.new(
        #   entry: Entry.new(
        #     account: mapped_account,
        #     date: row.date_iso,
        #     amount: row.signed_amount,
        #     name: row.name,
        #     currency: row.currency,
        #     import: self
        #   )
        # )
      end
    end
  end

  def required_column_keys
    %i[date amount]
  end

  def column_keys
    base = %i[date amount name currency category tags notes]
    base.unshift(:account) if account.nil?
    base
  end

  def mapping_steps
    base = [Import::CategoryMapping, Import::TagMapping]
    base << Import::AccountMapping if account.nil?
    base
  end
end
```

## Instructions

1. Parse import name from arguments
2. Generate import class inheriting from `Import` at `app/models/`
3. Implement `import!` — the core import logic, wrapped in a transaction
4. Implement `required_column_keys` — symbols for required CSV columns
5. Implement `column_keys` — all supported CSV columns
6. Implement `mapping_steps` — array of `Import::*Mapping` classes
7. Generate corresponding test file

## Import Workflow

```
1. User uploads CSV file
2. System parses CSV and creates Import::Row records
3. User maps columns via Import::Mapping UI
4. import.publish_later enqueues ImportJob
5. ImportJob calls import.publish → import!
6. On success: status → complete. On failure: status → failed, error message in .error
7. Revert via import.revert_later if needed
```

## Important Notes

- Use `Current.family` for scoping all created records
- The `import!` method is called within `publish` which handles status transitions
- Do NOT set status manually — `publish` and `revert` manage the state machine
- Errors go to the `.error` string column, not an association
- Row data is accessed through `Import::Row` records (e.g., `row.date_iso`, `row.signed_amount`)
- Mappings use `Import::CategoryMapping`, `Import::TagMapping`, `Import::AccountMapping`
