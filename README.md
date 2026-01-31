<img width="1280" alt="GitHub-Banner" src="https://github.com/user-attachments/assets/25e649e8-64a5-4c9f-b610-0f1cadccde14" />

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-AGPLv3-blue.svg" alt="License: AGPLv3"></a>
  <img src="https://img.shields.io/badge/elixir-%7E%3E%201.15-purple.svg" alt="Elixir ~> 1.15">
  <img src="https://img.shields.io/badge/phoenix-%7E%3E%201.8-orange.svg" alt="Phoenix ~> 1.8">
</p>

## Open-source ERP for small-scale artisanal manufacturers and craft businesses

Craftplan brings all essential business tools into one platform — catalog management, inventory control, order processing, production planning, purchasing, and CRM — so you can get off the ground quickly without paying for multiple separate platforms.

![Manage overview with schedule, make sheet, and completion snapshot](screenshots/plan.webp)

## Features

**Catalog & BOM**
- Product catalog with photos and labels
- Versioned Bills of Materials — edit latest, older versions read-only
- Automatic cost rollups across nested BOMs
- Labor steps with time and cost tracking

**Orders & Invoices**
- Customer order processing with calendar-based scheduling
- Invoice generation
- Order item allocation to production batches

**Production**
- Production batching with automatic material consumption
- Cost snapshots per batch
- Completion workflow with produced quantity tracking

**Inventory**
- Raw material management with lot traceability
- Stock movements (consume, receive, adjust)
- Allergen and nutritional fact tracking
- Demand forecasting and reorder planning

**Purchasing**
- Purchase orders and supplier management
- Receiving into stock with lot creation

**CRM**
- Customer and supplier database
- Order history and statistics

**Import / Export**
- CSV bulk import for products, materials, and customers
- CSV export

**Email**
- Transactional email delivery configurable from the UI
- SMTP, SendGrid, Mailgun, Postmark, Brevo, and Amazon SES
- API keys encrypted at rest

**Calendar Feed**
- iCal (.ics) subscription URL for Google Calendar, Apple Calendar, or any iCal-compatible app
- Includes order deliveries and production batch schedules
- Generate and revoke feeds from Settings

**API**
- JSON:API and GraphQL endpoints for programmatic access
- API key authentication with encrypted storage
- CORS configuration

**Access Control**
- Admin and staff roles
- Policy-based authorization on all resources

## Screenshots

<table>
  <tr>
    <td><img src="screenshots/catalog-recipe.webp" alt="BOM editor" width="400"></td>
    <td><img src="screenshots/orders.webp" alt="Order management" width="400"></td>
  </tr>
  <tr>
    <td><img src="screenshots/inventory-forecast.webp" alt="Inventory forecasting" width="400"></td>
    <td><img src="screenshots/settings.webp" alt="Settings and email configuration" width="400"></td>
  </tr>
</table>

## Tech Stack

Elixir · [Ash Framework](https://ash-hq.org/) · Phoenix LiveView · PostgreSQL · Tailwind CSS

## Getting Started

> **Prerequisites:** Docker, Elixir ~> 1.15, Erlang/OTP 27

```bash
docker-compose up -d    # Start PostgreSQL + MinIO
mix setup               # Install deps, migrate, build assets, seed
mix phx.server          # Start at localhost:4000
```

See the [setup guide](https://puemos.github.io/craftplan/docs/getting-started/) for detailed instructions.

## Why Craftplan?

- **Purpose-built for artisanal manufacturing** — not a generic ERP adapted to fit; workflows are designed around small-batch, made-to-order production
- **Allergen & nutritional tracking** — first-class support for food and beverage producers who need to track ingredients and generate nutrition labels
- **BOM versioning with cost rollups** — iterate on recipes and formulas while keeping full history and accurate costing
- **Self-hosted, no vendor lock-in** — your data stays on your infrastructure, backed by PostgreSQL

## Documentation

- [Full documentation](https://puemos.github.io/craftplan/docs/)
- [API reference (JSON:API & GraphQL)](https://puemos.github.io/craftplan/docs/api/)

## Contributing

Contributions are welcome. For major changes, please [open an issue](https://github.com/puemos/craftplan/issues) first to discuss your proposal.

```bash
mix test       # Run the test suite
mix format     # Format code (Styler, Spark, Tailwind, HEEx)
```

Commits follow the convention: `type(scope): description` (e.g., `feat(batching):`, `fix(orders):`, `ui(production):`).

## License

This project is licensed under the AGPLv3 License — see the [LICENSE](LICENSE) file for details.

## Support

- [Open an issue](https://github.com/puemos/craftplan/issues)
- [Read the docs](https://puemos.github.io/craftplan/docs/)
