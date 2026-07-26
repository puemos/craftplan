---
layout: ../../layouts/DocsLayout.astro
title: Development Setup
description: Set up a local development environment for contributing to Craftplan
---

> **Looking to run Craftplan?** See the [Self-Hosting guide](/craftplan/docs/self-hosting/). This page is for developers who want to contribute.

## Prerequisites

Before setting up Craftplan, make sure you have the following installed:

- **[mise](https://mise.jdx.dev/)** to install the pinned Elixir, Erlang/OTP, and Node.js versions
- **Docker** and **Docker Compose** for PostgreSQL, MinIO, and Mailpit

## Starting Dependencies

Start PostgreSQL, MinIO (S3-compatible object storage), and Mailpit with the project task:

```bash
mise run services:up
```

Run `mise run services:down` to stop them, or `mise run services:logs` to follow their logs.

## Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/puemos/craftplan.git
   cd craftplan
   ```

2. Install the pinned toolchain and run the full setup (installs deps, runs migrations, builds assets, seeds data):

   ```bash
   mise install
   mise run setup
   ```

   This single command handles `mix deps.get`, `mix ash.setup`, asset installation, and database seeding.

3. Start the Phoenix development server:

   ```bash
   mise run dev
   ```

4. Open [localhost:4000](http://localhost:4000) in your browser.

## Common Commands

| Command | Purpose |
|---------|---------|
| `mise run setup` | Full setup: deps, migrations, assets, seeds |
| `mise run dev` | Start the dev server |
| `mise run test` | Run the test suite |
| `mix test path/to/test.exs` | Run a single test file |
| `mix test path/to/test.exs:42` | Run a specific test at a line |
| `mise run format` | Format all code (Elixir, Tailwind, HEEx) |
| `mise run format:check` | Check formatting without modifying files |
| `mise run dialyzer` | Static type analysis |
| `mise run db:setup` | Run migrations and Ash introspection |
| `mise run db:reset` | Reset database extensions and migrations |
| `mise run ci` | Run the full CI suite locally |

## What's Next

After signing in, you land on **Manage → Overview**. Read the [Overview & Planner](/craftplan/docs/overview/) guide to learn how the main workspace is organized.
