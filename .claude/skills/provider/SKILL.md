---
name: provider
description: Create a data provider for third-party services
---

# Create Data Provider

Generate a data provider following the Provider pattern for third-party integrations.

## Usage

```
/provider ExchangeRateProvider    # Exchange rate data
/provider SecurityPriceProvider   # Security/stock prices
/provider PlaidProvider           # Plaid banking data
```

## Provider Architecture

The application uses a provider pattern for third-party data:

### Provider Registry
- Providers configured at runtime via `Provider::Registry`
- Settings stored in database for API keys, etc.
- Supports "managed" and "self_hosted" modes

### Two Types of Provider Data

1. **Concept Data** - Generic with swappable providers
   - Each concept has interface in `app/models/provider/concepts/`
   - Example: `ExchangeRate` concept uses different providers

2. **One-off Data** - Provider-specific methods
   - Called directly without abstractions
   - Example: `Provider::Registry.get_provider(:synth)&.usage`

## Generated Files

1. **Provider:** `app/models/provider/{{name}}.rb`
2. **Test:** `test/models/provider/{{name}}_test.rb`

## Provider Template

```ruby
# frozen_string_literal: true

class Provider::ExchangeRateProvider < Provider
  # Implement concept interface
  include Provider::Concepts::ExchangeRate

  def fetch_rate(from:, to:, date: Date.current)
    with_provider_response do
      response = client.get_exchange_rate(
        from_currency: from,
        to_currency: to,
        date: date.to_s
      )

      unless response.success?
        raise ProviderError, "Failed to fetch rate: #{response.error}"
      end

      {
        rate: response.data["rate"].to_d,
        from_currency: from,
        to_currency: to,
        date: date
      }
    end
  end

  def sync_rates(currencies:, start_date:, end_date:)
    with_provider_response do
      # Batch fetch rates
      rates = []

      currencies.each do |currency|
        (start_date..end_date).each do |date|
          rate = fetch_rate(from: "USD", to: currency, date: date)
          rates << rate
        end
      end

      { rates: rates, count: rates.size }
    end
  end

  private

  def client
    @client ||= ExternalApi::Client.new(
      api_key: settings.api_key,
      base_url: settings.base_url
    )
  end
end
```

## Instructions

1. Parse provider name from arguments
2. Generate provider class inheriting from `Provider`
3. Implement concept interface if applicable
4. Use `with_provider_response` wrapper
5. Handle errors with `ProviderError`
6. Generate corresponding test file

## Provider Response Pattern

```ruby
def with_provider_response(&block)
  Provider::ProviderResponse.new(
    success: true,
    data: yield
  )
rescue ProviderError => e
  Provider::ProviderResponse.new(
    success: false,
    error: e.message
  )
rescue StandardError => e
  Provider::ProviderResponse.new(
    success: false,
    error: "Unexpected error: #{e.message}"
  )
end
```

## Provided Concerns

Domain models use `Provided` concerns:
```ruby
# In ExchangeRate model
include ExchangeRate::Provided

# Provides:
# - find_or_fetch_rate
# - sync_provider_rates
```

## Registry Usage

```ruby
# Get specific provider
provider = Provider::Registry.get_provider(:synth)

# Get provider for concept
provider = Provider::Registry.provider_for(:exchange_rate)

# Direct usage
result = provider.fetch_rate(from: "USD", to: "CAD")
```

## Important Notes

- Inherit from `Provider` base class
- Always use `with_provider_response` wrapper
- Raise `ProviderError` for invalid data
- Register provider with `Provider::Registry`
- Use VCR for testing external API calls
- Handle rate limits appropriately
