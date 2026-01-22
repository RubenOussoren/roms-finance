---
name: api-endpoint
description: Create a new API endpoint with controller, views, and tests
---

# Create API Endpoint

Generate a new API v1 endpoint following project conventions.

## Usage

```
/api-endpoint accounts              # CRUD for accounts
/api-endpoint transactions index    # Single action
/api-endpoint projections show      # Specific resource action
```

## Generated Files

1. **Controller:** `app/controllers/api/v1/{{name}}_controller.rb`
2. **Jbuilder views:** `app/views/api/v1/{{name}}/{{action}}.json.jbuilder`
3. **Routes:** Added to `config/routes.rb`
4. **Request spec:** `test/controllers/api/v1/{{name}}_controller_test.rb`

## Controller Template

```ruby
# frozen_string_literal: true

module Api
  module V1
    class AccountsController < Api::V1::BaseController
      before_action :set_account, only: [:show, :update, :destroy]

      def index
        @accounts = Current.family.accounts
      end

      def show
      end

      def create
        @account = Current.family.accounts.build(account_params)

        if @account.save
          render :show, status: :created
        else
          render json: { errors: @account.errors }, status: :unprocessable_entity
        end
      end

      def update
        if @account.update(account_params)
          render :show
        else
          render json: { errors: @account.errors }, status: :unprocessable_entity
        end
      end

      def destroy
        @account.destroy
        head :no_content
      end

      private

      def set_account
        @account = Current.family.accounts.find(params[:id])
      end

      def account_params
        params.require(:account).permit(:name, :balance, :currency)
      end
    end
  end
end
```

## Jbuilder View Template

```ruby
# app/views/api/v1/accounts/show.json.jbuilder
json.account do
  json.id @account.id
  json.name @account.name
  json.balance @account.balance
  json.currency @account.currency
  json.created_at @account.created_at
  json.updated_at @account.updated_at
end
```

## Routes Template

```ruby
# In config/routes.rb, under namespace :api, namespace :v1
resources :accounts, only: [:index, :show, :create, :update, :destroy]
```

## Instructions

1. Parse resource name and actions from arguments
2. Generate controller in `app/controllers/api/v1/`
3. Generate Jbuilder templates for each action
4. Add routes to `config/routes.rb`
5. Generate request test file
6. Report created files

## Authentication

API endpoints use:
- OAuth2 (Doorkeeper) for third-party apps
- API keys with JWT tokens for direct access
- `Current.user` and `Current.family` for auth context

## Rate Limiting

Rate limiting is handled by Rack Attack:
- Configurable limits per API key
- Standard rate headers in responses

## Important Notes

- Use `Current.user` not `current_user`
- Use `Current.family` not `current_family`
- Scope all queries to `Current.family` for multi-tenancy
- Use Jbuilder for JSON rendering (not `render json:` directly)
- Include pagination for list endpoints
- Follow REST conventions
