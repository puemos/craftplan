---
layout: ../../layouts/DocsLayout.astro
title: Self-Hosting
description: Deploy Craftplan with Docker on your own server
---

## Quick Start

Deploy Craftplan without cloning the repo. Just download the Compose file and start:

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

### First-time setup

On first launch, Craftplan shows a setup screen where you create your **admin account**. Once signed in, invite additional team members from **Settings → Members** — choose Staff or Admin role for each.

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

Your `.env` file requires several secrets. Generate them with `openssl`:

### SECRET_KEY_BASE and TOKEN_SIGNING_SECRET

Both are random 64-byte strings. Generate each one separately:

```bash
openssl rand -base64 48
```

Run the command twice -- once for `SECRET_KEY_BASE` and once for `TOKEN_SIGNING_SECRET`.

### CLOAK_KEY

A 32-byte AES key, base64-encoded:

```bash
openssl rand -base64 32
```

### POSTGRES_PASSWORD

A password for the bundled PostgreSQL container (not needed if you supply your own `DATABASE_URL`):

```bash
openssl rand -base64 16
```

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

### File Storage (S3 / SeaweedFS)

These defaults apply to the bundled Compose deployment. MinIO installations migrate automatically on the first upgrade; read the
[storage migration guide](/craftplan/docs/storage-migration/) for capacity and recovery details.

| Variable | Compose default | Description |
|---|---|---|
| `AWS_ACCESS_KEY_ID` | `MINIO_ROOT_USER` or `minioadmin` | Storage access key; change for production |
| `AWS_SECRET_ACCESS_KEY` | `MINIO_ROOT_PASSWORD` or `minioadmin` | Storage secret; change for production |
| `AWS_S3_BUCKET` | `craftplan` | Bucket created automatically |
| `AWS_S3_SCHEME` | `http://` | Internal S3 endpoint scheme |
| `AWS_S3_HOST` | `seaweedfs` | Internal S3 endpoint hostname |
| `AWS_S3_PORT` | `9000` | Internal S3 endpoint port |
| `S3_PORT` | `9000` | Published host port (does not change the internal port) |
| `AWS_S3_PUBLIC_URL` | `http://${HOST}:9000` | Browser endpoint for signed photos; no bucket or path |
| `AWS_REGION` | `us-east-1` | Signing region |
| `AWS_ASSET_HOST` | unset | URL prefix for unsigned assets only |

With standalone `docker run`, specify all storage settings explicitly. The runtime
port defaults to 443 for HTTPS and 80 for HTTP when `AWS_S3_PORT` is absent.

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

### Bundled SeaweedFS

The bundled storage image runs pinned SeaweedFS 4.47 and provides S3 storage on port 9000, creates the
configured bucket, and persists data in `seaweedfs_data`. Only the S3 port is
published; there is no MinIO console on port 9001. The service retains the name
`minio` so Compose replaces the old container during automatic migration.

Set `AWS_S3_PUBLIC_URL` to an endpoint reachable by users' browsers. For an HTTPS
Craftplan site, use an HTTPS storage hostname behind your reverse proxy, forwarding
to port 9000 and preserving the original Host header. Otherwise browsers will block
HTTP photos as mixed content. Changing `AWS_ASSET_HOST` does not affect signed URLs.

Back up the entire SeaweedFS volume while the service is stopped, alongside your
PostgreSQL backup. MinIO and SeaweedFS use different disk formats: never reuse the
old MinIO volume for the new service.

### External S3

Remove the `minio` service **and** its entry under `craftplan.depends_on`. Set
`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_S3_BUCKET`, `AWS_REGION`,
`AWS_S3_SCHEME`, `AWS_S3_HOST`, `AWS_S3_PORT`, and `AWS_S3_PUBLIC_URL` in `.env`.
For AWS S3, use your regional endpoint with HTTPS and port 443. The public URL is
the endpoint without a bucket/path, for example `https://s3.us-east-1.amazonaws.com`.

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
