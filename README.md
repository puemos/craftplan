<img width="1280" alt="GitHub-Banner" src="https://github.com/user-attachments/assets/25e649e8-64a5-4c9f-b610-0f1cadccde14" />

## Overview

Craftplan is an open-source ERP system designed for small-scale artisanal manufacturers and craft businesses. It brings all essential business tools into one platform — catalog management, inventory control, order processing, production planning, purchasing, and CRM — so you can get off the ground quickly without paying for multiple separate platforms.

![Manage overview with schedule, make sheet, and completion snapshot](screenshots/plan.webp)

## Features

Craftplan covers the full production lifecycle: manage products with versioned Bills of Materials and cost rollups, track raw materials with lot traceability and demand forecasting, process customer orders with calendar-based scheduling, plan and batch production runs with automatic material consumption and cost snapshots, handle purchasing from suppliers with receiving into stock, and maintain a customer database with order history and statistics. Transactional email delivery supports SMTP, SendGrid, Mailgun, Postmark, Brevo, and Amazon SES — configurable from the UI with API keys encrypted at rest.

**[Read the full documentation →](https://puemos.github.io/craftplan/docs/)**

## Tech Stack

Elixir · Ash Framework · Phoenix LiveView · PostgreSQL · Tailwind CSS

## Getting Started

```bash
docker-compose up -d    # Start PostgreSQL + MinIO
mix setup               # Install deps, migrate, build assets, seed
mix phx.server          # Start at localhost:4000
```

See the [setup guide](https://puemos.github.io/craftplan/docs/getting-started/) for prerequisites and detailed instructions.

## Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the AGPLv3 License — see the [LICENSE](LICENSE) file for details.

## Support

If you need help with setup or have questions:

- [Open an issue](https://github.com/puemos/craftplan/issues)
- [Read the docs](https://puemos.github.io/craftplan/docs/)
