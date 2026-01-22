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

The application uses a structured import system:
- `Import` model manages import sessions
- Supports transaction and balance imports
- Custom field mapping with transformation rules
- Validation and error reporting

## Generated Files

1. **Import handler:** `app/models/import/{{name}}_import.rb`
2. **Test:** `test/models/import/{{name}}_import_test.rb`

## Import Handler Template

```ruby
# frozen_string_literal: true

class TransactionImport < Import
  # Define required and optional columns
  REQUIRED_COLUMNS = %w[date amount].freeze
  OPTIONAL_COLUMNS = %w[description category merchant].freeze

  # Field mappings
  def column_mappings
    {
      "date" => :transaction_date,
      "amount" => :amount,
      "description" => :description,
      "category" => :category_name,
      "merchant" => :merchant_name
    }
  end

  # Transform raw row into importable attributes
  def transform_row(row)
    {
      date: parse_date(row[:transaction_date]),
      amount: parse_amount(row[:amount]),
      description: row[:description],
      category: find_or_create_category(row[:category_name]),
      merchant: row[:merchant_name]
    }
  end

  # Validate a single row
  def validate_row(row)
    errors = []
    errors << "Date is required" if row[:date].blank?
    errors << "Amount is required" if row[:amount].blank?
    errors << "Invalid date format" unless valid_date?(row[:date])
    errors
  end

  # Process the import
  def process!
    transaction do
      rows.each_with_index do |row, index|
        transformed = transform_row(row)
        errors = validate_row(transformed)

        if errors.any?
          record_error(index, errors)
          next
        end

        create_transaction(transformed)
      end

      update!(status: errors.any? ? :completed_with_errors : :completed)
    end
  end

  private

  def parse_date(value)
    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def parse_amount(value)
    BigDecimal(value.to_s.gsub(/[^0-9.-]/, ""))
  rescue ArgumentError
    nil
  end

  def valid_date?(value)
    parse_date(value).present?
  end

  def find_or_create_category(name)
    return nil if name.blank?
    Current.family.categories.find_or_create_by(name: name)
  end

  def create_transaction(attributes)
    Current.family.transactions.create!(attributes)
  end

  def record_error(row_index, errors)
    import_errors.create!(
      row_number: row_index + 1,
      messages: errors
    )
  end
end
```

## Instructions

1. Parse import name from arguments
2. Generate import class inheriting from `Import`
3. Define required and optional columns
4. Implement column mappings
5. Implement row transformation
6. Implement validation
7. Generate corresponding test file

## Import Workflow

```
1. User uploads CSV file
2. System parses headers and shows mapping UI
3. User maps CSV columns to system fields
4. Import.process! runs in background job
5. Results shown with success/error counts
```

## Important Notes

- Use `Current.family` for scoping all created records
- Wrap processing in transaction for atomicity
- Record row-level errors for user feedback
- Support both required and optional columns
- Handle various date and number formats
- Validate before creating records
