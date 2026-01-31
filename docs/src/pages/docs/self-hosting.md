---
layout: ../../layouts/DocsLayout.astro
title: Self-Hosting
description: Deploy Craftplan with Docker on your own server
---

## Quick Start

Deploy Craftplan without cloning the repo — just download the Compose file and start:

```bash
# 1. Download the Compose file and env template
curl -O https://raw.githubusercontent.com/puemos/craftplan/main/docker-compose.yml
curl -O https://raw.githubusercontent.com/puemos/craftplan/main/.env.example

# 2. Create your environment file and fill in secrets (see below)
cp .env.example .env

# 3. Start everything
docker compose up -d
```

Craftplan will be available at `http://localhost:4000` (or the `PORT` you configured). Migrations run automatically on startup.

---

## Single Container (`docker run`)

If you already have a PostgreSQL database and S3-compatible storage, you can run Craftplan as a single container:

```bash
docker run -d \
  --name craftplan \
  -p 4000:4000 \
  -e SECRET_KEY_BASE="your-secret-key-base" \
  -e TOKEN_SIGNING_SECRET="your-token-signing-secret" \
  -e CLOAK_KEY="your-cloak-key" \
  -e DATABASE_URL="ecto://postgres:password@your-db-host/craftplan" \
  -e HOST="localhost" \
  -e PORT="4000" \
  -e AWS_ACCESS_KEY_ID="your-access-key" \
  -e AWS_SECRET_ACCESS_KEY="your-secret-key" \
  -e AWS_S3_BUCKET="craftplan" \
  -e AWS_S3_SCHEME="https://" \
  -e AWS_S3_HOST="s3.amazonaws.com" \
  -e AWS_REGION="us-east-1" \
  ghcr.io/puemos/craftplan:latest
```

Or with an env file:

```bash
docker run -d \
  --name craftplan \
  --env-file .env \
  -e DATABASE_URL="ecto://postgres:password@your-db-host/craftplan" \
  -p 4000:4000 \
  ghcr.io/puemos/craftplan:latest
```

---

## Deploy on Railway

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/template/craftplan)

Railway provisions a PostgreSQL database automatically. After deploying:

1. Set the required environment variables (`SECRET_KEY_BASE`, `TOKEN_SIGNING_SECRET`, `CLOAK_KEY`) in the Railway dashboard.
2. Set `HOST` to your Railway-provided domain.
3. For file storage, configure an external S3-compatible provider (e.g., AWS S3, Cloudflare R2, Tigris) using the `AWS_*` environment variables.

> **Note:** Railway does not include S3-compatible storage, so file uploads require an external provider.

---

## Generating Secrets

Your `.env` file requires three secrets. You can generate them with or without a local Elixir installation.

### SECRET_KEY_BASE and TOKEN_SIGNING_SECRET

Both are random 64-byte strings. Generate each one separately:

```bash
# With Elixir installed
mix phx.gen.secret

# Without Elixir (using Docker)
docker run --rm hexpm/elixir:1.18.3-erlang-27.2.4-debian-bookworm-20250113-slim \
  sh -c "mix local.hex --force --if-missing >/dev/null 2>&1 && mix phx.gen.secret"
```

### CLOAK_KEY

A 32-byte AES key, base64-encoded:

```bash
# With Elixir installed
elixir -e ':crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()'

# Without Elixir (using Docker)
docker run --rm hexpm/elixir:1.18.3-erlang-27.2.4-debian-bookworm-20250113-slim \
  elixir -e ':crypto.strong_rand_bytes(32) |> Base.encode64() |> IO.puts()'
```

### POSTGRES_PASSWORD

Any strong password of your choice — it's used for the bundled PostgreSQL container (not needed if you supply your own `DATABASE_URL`).

---

## Configuration Reference

All configuration is done via environment variables in your `.env` file.

### Required

| Variable | Description |
|---|---|
| `SECRET_KEY_BASE` | Phoenix secret for signing cookies and sessions |
| `TOKEN_SIGNING_SECRET` | Secret for API token signing |
| `CLOAK_KEY` | 32-byte base64-encoded AES encryption key |
| `POSTGRES_PASSWORD` | Password for the PostgreSQL database |

### Host & Networking

| Variable | Default | Description |
|---|---|---|
| `HOST` | `localhost` | Public hostname (used in generated URLs) |
| `PORT` | `4000` | HTTP port the server listens on |

### File Storage (S3 / MinIO)

The bundled MinIO container works out of the box. Override these to use an external S3-compatible provider:

| Variable | Default | Description |
|---|---|---|
| `MINIO_ROOT_USER` | `minioadmin` | MinIO access key |
| `MINIO_ROOT_PASSWORD` | `minioadmin` | MinIO secret key |
| `AWS_S3_BUCKET` | `craftplan` | S3 bucket name |
| `AWS_S3_SCHEME` | `https://` | S3 endpoint scheme (`http://` for MinIO) |
| `AWS_ACCESS_KEY_ID` | — | External S3 access key |
| `AWS_SECRET_ACCESS_KEY` | — | External S3 secret key |
| `AWS_S3_HOST` | `s3.amazonaws.com` | S3 endpoint hostname |
| `AWS_REGION` | `us-east-1` | S3 region |
| `AWS_ASSET_HOST` | — | Public URL prefix for uploaded assets |

### Email (Optional)

Email is primarily configured from the **Settings UI** inside the app. Environment variables are a fallback for automated or headless setups.

| Variable | Description |
|---|---|
| `EMAIL_PROVIDER` | One of: `sendgrid`, `postmark`, `brevo`, `mailgun`, `amazon_ses` |
| `EMAIL_API_KEY` | API key for the chosen provider |
| `EMAIL_API_DOMAIN` | Mailgun domain (Mailgun only) |
| `EMAIL_API_SECRET` | Secret key (Amazon SES only) |
| `EMAIL_API_REGION` | AWS region (Amazon SES only, default: `us-east-1`) |
| `SMTP_HOST` | SMTP relay hostname (alternative to API providers) |
| `SMTP_PORT` | SMTP port (default: `587`) |
| `SMTP_USERNAME` | SMTP username |
| `SMTP_PASSWORD` | SMTP password |

---

## File Storage

### Bundled MinIO

The default `docker-compose.yml` includes a MinIO container that provides S3-compatible object storage. It creates a `craftplan` bucket automatically and requires no additional configuration.

The MinIO console is available at `http://localhost:9001` with the credentials from your `.env`.

### External S3

To use AWS S3 or another S3-compatible provider, set the `AWS_*` variables in your `.env` and remove or comment out the `minio` service from `docker-compose.yml`.

---

## Reverse Proxy

For production deployments, place Craftplan behind a reverse proxy that handles TLS. Here's an example nginx configuration:

```nginx
upstream craftplan {
    server 127.0.0.1:4000;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate     /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://craftplan;

        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Make sure to set `HOST` to your public domain (e.g. `your-domain.com`).

> **Note:** The `Upgrade` and `Connection` headers are required for Phoenix LiveView's WebSocket connection.

---

## Updating

```bash
docker compose pull
docker compose up -d
```

Migrations run automatically on each startup via the `bin/server` entrypoint.

---

## Building from Source

If you are contributing to Craftplan or need a custom build, use the build-from-source Compose file:

```bash
git clone https://github.com/puemos/craftplan.git
cd craftplan
cp .env.example .env   # fill in secrets
docker compose -f docker-compose.prod.yml up -d
```

Or build the image manually:

```bash
docker build -t craftplan .
```

See `docker-compose.prod.yml` for the full build-from-source configuration.
