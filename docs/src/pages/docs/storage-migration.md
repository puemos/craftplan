---
layout: ../../layouts/DocsLayout.astro
title: Automatic MinIO migration
description: Craftplan migrates bundled MinIO storage once during normal Docker Compose upgrades
---

## Normal upgrades migrate automatically

Update your Compose file to the new release, keep your existing `.env` and project
name, and use the normal commands:

```bash
docker compose pull
docker compose up -d
```

There is **no separate migration command**. The bundled storage image detects old
MinIO data, copies and verifies it, and starts SeaweedFS. Craftplan waits for storage
to become healthy. The first upgrade takes longer and storage is unavailable during
migration. Follow progress with:

```bash
docker compose logs -f minio
```

The service is still named `minio` deliberately: Compose must replace and stop the
old container before taking a snapshot. Its new image runs **SeaweedFS 4.47** and
has the network alias `seaweedfs`. Keep that service name for this transition.

## What happens once

The old `minio_data` volume is mounted **read-only** at `/legacy`. On first startup:

1. If there is no legacy data, SeaweedFS starts without copying anything.
2. If there is legacy data, the container makes a private snapshot in the new
   volume. A temporary MinIO process reads that snapshot, leaving the original
   volume unchanged.
3. The container copies the configured bucket through S3, including original
   photos, thumbnails, object keys and metadata. It downloads both copies to
   verify every object's bytes.
4. After successful verification, it stops the temporary services and records a
   completion marker in the SeaweedFS data volume. It deletes the temporary
   snapshot and opens the normal S3 port 9000.

The temporary servers listen only on loopback ports. The old app cannot write to
them during migration. The application does not receive Docker socket access.
Existing database photo references remain unchanged.

**SeaweedFS → SeaweedFS upgrades skip migration.** The completion marker is stored
with the data, so container recreation, restarts and image updates do not trigger
another copy. New uploads stay intact and deleted objects are not restored from
old MinIO data. A SeaweedFS-only volume without legacy data is also adopted without
copying anything.

## Storage, credentials and scope

Keep `AWS_S3_BUCKET` unchanged during the transition. Existing `MINIO_ROOT_USER`
and `MINIO_ROOT_PASSWORD` settings remain supported; `AWS_ACCESS_KEY_ID` and
`AWS_SECRET_ACCESS_KEY` can select new destination credentials.

Allow free space for **both a temporary full MinIO snapshot and the migrated
objects**, in addition to your existing MinIO volume. Snapshot space is reclaimed
after success. The startup grace period defaults to 24 hours; set
`STORAGE_START_PERIOD` longer if your migration needs more time. Keep your normal
database and storage backups. The retained MinIO
volume provides recovery data but is not a substitute for an independent backup.

Automatic migration covers the bundled single-node, unversioned Craftplan photo
bucket. It does not transfer historical versions, IAM users, bucket policies,
lifecycle rules, retention settings or externally managed encryption keys.
Customized/distributed MinIO deployments need a separate migration plan.

For an HTTPS deployment, `AWS_S3_PUBLIC_URL` must be an HTTPS S3 endpoint reachable
by users' browsers, with no bucket or path, e.g. `https://files.example.com`. The
proxy must preserve the Host header. This is independent of migration.

## Failures and retry

A failed snapshot, copy or verification does not write a completion marker and
does not expose the destination on port 9000. Craftplan remains blocked. Check
`docker compose logs minio`, fix the cause (for example insufficient disk space),
and rerun `docker compose up -d`. An interrupted migration retries from the retained
source. Once completion is recorded, retries only start SeaweedFS.

Do not delete the `.craftplan-storage-v1` marker or reuse the new volume with a
different legacy source. If both volumes contain data without a completion or
in-progress marker, startup stops rather than overwriting potentially newer files.
Back up the whole SeaweedFS volume, including its marker.

## Recovery

The original MinIO volume remains unchanged. Before accepting new writes, you can
stop the new deployment and restore the previous Compose file and its cached images
using `docker compose up -d --pull never`. Keep the previous Compose file and images
until you have checked the upgrade. Do not run `down -v` or prune those volumes.

After users write to SeaweedFS, the retained MinIO store is stale. Stop writers and
reconcile changes before rolling back. Never delete the completion marker to force
a new copy from that stale source.

## Source builds and development

Source deployments use the same automatic behavior:

```bash
docker compose -f docker-compose.prod.yml up -d --build
```

For local development, restart the services with the updated configuration:

```bash
docker compose -f docker-compose.dev.yml up -d --build
```

The development service retains its `craftplan-minio` container name, reads `.minio`
without modifying it, and stores the new data in `.seaweedfs`. Pause local Phoenix
while upgrading so development requests do not encounter storage downtime.

## Real integration coverage

With Docker Compose 2.24.4+, Python 3, Elixir dependencies and ImageMagick installed:

```bash
mise run test:storage
```

The suite builds the real storage image and creates isolated MinIO and SeaweedFS
containers. It tests Waffle uploads and thumbnails, signed browser downloads,
metadata and byte integrity, special-character keys, empty and large objects,
corruption detection, authentication, persistence and deletion. It then tests a
plain Compose upgrade, failure blocking application startup, retry, an unchanged
original volume, fresh installations, and later SeaweedFS upgrades preserving new
uploads and deletions. CI runs the same suite.
