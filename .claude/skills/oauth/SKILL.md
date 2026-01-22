---
name: oauth
description: Configure OAuth scopes and applications for API access
---

# OAuth Configuration

Configure Doorkeeper OAuth for API authentication.

## Usage

```
/oauth scopes                # List available scopes
/oauth app "App Name"        # Create new OAuth application
/oauth token                 # Generate test token
```

## OAuth Architecture

The application uses Doorkeeper for OAuth2:
- Authorization Code flow for third-party apps
- Client Credentials for server-to-server
- API keys with JWT tokens for direct access

## Available Scopes

```ruby
# config/initializers/doorkeeper.rb
default_scopes :read
optional_scopes :write, :admin

# Scope descriptions:
# read   - Read-only access to user data
# write  - Create and modify user data
# admin  - Administrative operations
```

## Creating OAuth Application

```ruby
# Via Rails console
app = Doorkeeper::Application.create!(
  name: "My Application",
  redirect_uri: "https://myapp.com/callback",
  scopes: "read write"
)

puts "Client ID: #{app.uid}"
puts "Client Secret: #{app.secret}"
```

## Generating Access Token

```ruby
# For testing
token = Doorkeeper::AccessToken.create!(
  application: app,
  resource_owner_id: user.id,
  scopes: "read write",
  expires_in: 7200
)

puts "Access Token: #{token.token}"
```

## API Authentication Flow

### Authorization Code Flow
```
1. Redirect user to:
   GET /oauth/authorize?client_id=UID&redirect_uri=CALLBACK&response_type=code&scope=read+write

2. User authorizes, redirected to:
   CALLBACK?code=AUTHORIZATION_CODE

3. Exchange code for token:
   POST /oauth/token
   {
     grant_type: "authorization_code",
     code: "AUTHORIZATION_CODE",
     client_id: "UID",
     client_secret: "SECRET",
     redirect_uri: "CALLBACK"
   }

4. Use token in requests:
   Authorization: Bearer ACCESS_TOKEN
```

### API Key Authentication
```
1. Generate API key for user
2. Create JWT token from API key
3. Include in requests:
   Authorization: Bearer JWT_TOKEN
```

## Instructions

### scopes - List Scopes
1. Read Doorkeeper configuration
2. List default and optional scopes
3. Describe what each scope permits

### app - Create Application
1. Prompt for application name and redirect URI
2. Create Doorkeeper::Application
3. Return client ID and secret

### token - Generate Test Token
1. Find or create test application
2. Generate access token for current user
3. Return token for testing

## Security Notes

- Never expose client secrets in client-side code
- Use HTTPS for all OAuth flows
- Tokens should have reasonable expiration
- Revoke tokens when no longer needed
- Audit token usage regularly

## Important Notes

- OAuth applications are created via seed data
- Test tokens should only be used in development
- Production tokens require proper OAuth flow
- Rate limiting applies to all API requests
