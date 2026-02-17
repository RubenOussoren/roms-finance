# ROMS Finance: Personal Finance Management

## About

ROMS Finance is a personal finance app that can be [self hosted with Docker](docs/hosting/docker.md). Key features include:

- **Investment projections** with Monte Carlo confidence bands and PAG 2025 compliance
- **Canadian debt optimization** (Smith Manoeuvre simulator with CRA audit trail)
- **Multi-account tracking** for chequing, savings, investments, crypto, loans, and properties
- **Brokerage connectivity** via SnapTrade (Wealthsimple, Questrade, and other Canadian brokerages)
- **Banking connectivity** via Plaid (chequing, savings, credit cards, loans — US and EU)
- **Tax-aware calculations** with federal + provincial Canadian tax brackets

## Local Development Setup

**If you are trying to _self-host_ the ROMS Finance app, stop here. You
should [read this guide to get started](docs/hosting/docker.md).**

The instructions below are for developers to get started with contributing to the app.

### Requirements

- See `.ruby-version` file for required Ruby version
- PostgreSQL >9.3 (ideally, latest stable version)

After cloning the repo, the basic setup commands are:

```sh
cd roms-finance
cp .env.local.example .env.local
bin/setup
bin/dev
```

Edit `.env.local` to configure data providers (optional):
- **Plaid**: Set `PLAID_CLIENT_ID`, `PLAID_SECRET`, `PLAID_ENV` for banking connections
- **SnapTrade**: Set `SNAPTRADE_CLIENT_ID`, `SNAPTRADE_CONSUMER_KEY` for brokerage connections

And visit http://localhost:3000 to see the app. Seeds create a realistic
Canadian family with 20 accounts, 37 months of transactions, investment
holdings, and a pre-simulated Smith Manoeuvre strategy.

**Admin:** `admin@roms.local` / `password`
**Member:** `member@roms.local` / `password`

The member account demonstrates per-user privacy controls — each spouse
sees the other's personal accounts as balance-only.

To reload demo data from scratch: `rake demo_data:default`

For further instructions, see guides below.

### Setup Guides

- [Self-hosting with Docker](docs/hosting/docker.md)
- [Dev containers](https://code.visualstudio.com/docs/devcontainers/containers)

## Copyright & License

ROMS Finance is distributed under the [AGPLv3 license](LICENSE).

This project is based on [Maybe Finance](https://github.com/maybe-finance/maybe).
"Maybe" is a trademark of Maybe Finance, Inc. This project is not affiliated with or endorsed by Maybe Finance Inc.
