# Self-Hosting ROMS Finance with Docker

## Prerequisites

- [Docker](https://docs.docker.com/get-docker/) (v20.10+)
- [Docker Compose](https://docs.docker.com/compose/install/) (v2.0+)
- At least 1 GB of free RAM

## Quick Start

1. **Download the example Compose file:**

   ```bash
   curl -O https://raw.githubusercontent.com/RubenOussoren/roms-finance/main/compose.example.yml
   ```

2. **Generate a secret key:**

   ```bash
   openssl rand -hex 64
   ```

3. **Start the application:**

   ```bash
   SECRET_KEY_BASE=<your-generated-key> docker compose -f compose.example.yml up -d
   ```

   Or create a `.env` file alongside your compose file:

   ```env
   SECRET_KEY_BASE=<your-generated-key>
   ```

   Then run:

   ```bash
   docker compose -f compose.example.yml up -d
   ```

4. **Open the app** at [http://localhost:3000](http://localhost:3000). The first user to register becomes the admin.

## Environment Variables

### Required

| Variable | Description |
|----------|-------------|
| `SECRET_KEY_BASE` | Rails encryption key. Generate with `openssl rand -hex 64`. **Must be set** -- the app will not start without it. |

### Optional

| Variable | Default | Description |
|----------|---------|-------------|
| `POSTGRES_USER` | `roms_user` | PostgreSQL username |
| `POSTGRES_PASSWORD` | `roms_password` | PostgreSQL password |
| `POSTGRES_DB` | `roms_production` | PostgreSQL database name |
| `REDIS_URL` | `redis://redis:6379/1` | Redis URL for Sidekiq and Action Cable |
| `CACHE_REDIS_URL` | `redis://redis:6379/2` | Redis URL for Rails cache store |
| `SIDEKIQ_WEB_USERNAME` | `roms` | Username for the `/sidekiq` web dashboard |
| `SIDEKIQ_WEB_PASSWORD` | `roms` | Password for the `/sidekiq` web dashboard |
| `OPENAI_ACCESS_TOKEN` | _(none)_ | OpenAI API key for AI features (chat, rules). Costs apply. |
| `INVITE_ONLY` | `true` | When true, only admin-invited users can register |
| `APP_DOMAIN` | _(none)_ | Domain for email links (e.g. `finance.example.com`) |
| `RAILS_FORCE_SSL` | `false` | Force SSL connections |
| `RAILS_ASSUME_SSL` | `false` | Assume SSL behind a reverse proxy |

### SMTP (for email features)

| Variable | Default | Description |
|----------|---------|-------------|
| `SMTP_ADDRESS` | _(none)_ | SMTP server address |
| `SMTP_PORT` | `465` | SMTP server port |
| `SMTP_USERNAME` | _(none)_ | SMTP username |
| `SMTP_PASSWORD` | _(none)_ | SMTP password |
| `SMTP_TLS_ENABLED` | `true` | Enable TLS for SMTP |
| `EMAIL_SENDER` | _(none)_ | From address for outgoing emails |

### Market Data

| Variable | Default | Description |
|----------|---------|-------------|
| `SYNTH_API_KEY` | _(none)_ | [Synth](https://synthfinance.com/) API key for stock prices and exchange rates. Can also be set in **Settings > Self-Hosting** after login. |

### Account Connectivity

Account connectivity lets users link their real bank and brokerage accounts for automatic syncing. It is entirely optional -- the app works without any provider credentials, but users won't be able to add connected accounts. Providers auto-disable when their credentials are not configured.

#### Plaid (Banking -- US & EU)

[Plaid](https://plaid.com/) connects bank accounts (chequing, savings, credit cards, loans) in the US and EU.

1. Create an account at [dashboard.plaid.com](https://dashboard.plaid.com)
2. Obtain your **Client ID** and **Secret** from the dashboard
3. Register your redirect URI (`https://your-domain.com/accounts`) under **Developers > Redirects**
4. Uncomment the Plaid variables in your compose file and set them in your `.env`

| Variable | Default | Description |
|----------|---------|-------------|
| `PLAID_CLIENT_ID` | _(none)_ | Plaid client ID |
| `PLAID_SECRET` | _(none)_ | Plaid secret key |
| `PLAID_ENV` | `production` | `sandbox` (test data), `development` (real banks, 100-item limit), or `production` (requires Plaid approval) |
| `PLAID_REDIRECT_URI` | _(none)_ | Your public HTTPS URL + `/accounts` (e.g. `https://finance.example.com/accounts`). Must match the URI registered in your Plaid dashboard. Required for OAuth-based institutions. |

For **European institutions**, Plaid requires separate EU credentials:

| Variable | Description |
|----------|-------------|
| `PLAID_EU_CLIENT_ID` | Plaid EU client ID |
| `PLAID_EU_SECRET` | Plaid EU secret key |

#### SnapTrade (Brokerage -- Canada)

[SnapTrade](https://snaptrade.com/) connects investment and crypto brokerage accounts in Canada.

1. Sign up at [snaptrade.com](https://snaptrade.com) and obtain your credentials
2. Uncomment the SnapTrade variables in your compose file and set them in your `.env`

| Variable | Description |
|----------|-------------|
| `SNAPTRADE_CLIENT_ID` | SnapTrade client ID |
| `SNAPTRADE_CONSUMER_KEY` | SnapTrade consumer key |

## Reverse Proxy

For production deployments, place a reverse proxy (nginx, Caddy, or Traefik) in front of the app to handle HTTPS.

When running behind an SSL-terminating proxy:

1. Set `RAILS_ASSUME_SSL=true` so Rails generates HTTPS links
2. Set `APP_DOMAIN` to your public domain (e.g. `finance.example.com`) for correct link generation in emails
3. Set `PLAID_REDIRECT_URI` to your public HTTPS URL + `/accounts` if using Plaid

The compose file exposes port 3000 on the `web` service. Point your reverse proxy at `http://localhost:3000` (or the appropriate Docker network address).

## Common Operations

### View logs

```bash
docker compose -f compose.example.yml logs -f web
docker compose -f compose.example.yml logs -f worker
```

### Update to latest version

```bash
docker compose -f compose.example.yml pull
docker compose -f compose.example.yml up -d
```

Database migrations run automatically on startup.

### Backup the database

```bash
docker compose -f compose.example.yml exec db pg_dump -U roms_user roms_production > backup.sql
```

### Restore from backup

```bash
docker compose -f compose.example.yml exec -T db psql -U roms_user roms_production < backup.sql
```

### Stop the application

```bash
docker compose -f compose.example.yml down
```

To also remove volumes (deletes all data):

```bash
docker compose -f compose.example.yml down -v
```

## Troubleshooting

### "SECRET_KEY_BASE is required" error

You must set the `SECRET_KEY_BASE` environment variable. Generate one with:

```bash
openssl rand -hex 64
```

### App won't start or shows 500 errors

Check the web container logs:

```bash
docker compose -f compose.example.yml logs web
```

Common causes:
- Database not ready yet (wait a few seconds and retry)
- Missing `SECRET_KEY_BASE`
- Port 3000 already in use (change the port mapping in your compose file)

### Cannot connect to the database

Ensure the `db` service is healthy:

```bash
docker compose -f compose.example.yml ps
```

If the database container keeps restarting, check its logs:

```bash
docker compose -f compose.example.yml logs db
```

### Sidekiq dashboard credentials

The Sidekiq web dashboard is available at `/sidekiq`. Default credentials are `roms`/`roms`. Change them by setting `SIDEKIQ_WEB_USERNAME` and `SIDEKIQ_WEB_PASSWORD`.
