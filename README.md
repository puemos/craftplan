<img width="1280" alt="GitHub-Banner" src="https://github.com/user-attachments/assets/25e649e8-64a5-4c9f-b610-0f1cadccde14" />

## Overview

Craftplan is an open-source ERP system designed specifically for small-scale artisanal manufacturers and craft businesses. It brings all essential business tools into one platform, helping you get off the ground quickly while minimizing costs—no need to pay for multiple separate platforms. From raw materials to finished products, Craftplan provides everything you need to manage your entire production process and make data-driven decisions as you grow.

After signing in you now land on **Manage → Overview** (`/manage/overview`), which combines the Overview, Schedule, Make Sheet, and Materials tabs into one LiveView-driven planner. It also shows completion snapshots with batch codes and BOM cost rollups as soon as you mark production done.

![Manage overview with schedule, make sheet, and completion snapshot](screenshots/plan.png)

## User Guides

For detailed instructions on using Craftplan, check out our user guides:

- [Overview](guides/OVERVIEW.md) - Manage → Overview tabs, cost snapshots, and consumption recaps
- [Catalog Management](guides/CATALOG.md) - BOM editor, simple versioning, labor scaling, pricing guidance
- [Inventory Control](guides/INVENTORY.md) - Tracking raw materials and stock
- [Order Management](guides/ORDERS.md) - Processing customer orders
- [Customer Management](guides/CUSTOMERS.md) - Managing your customer database
- [Business Intelligence](guides/REPORTS.md) - Reports and analytics
- [Settings](guides/SETTINGS.md) - Configuring your Craftplan installation

## Features

### 📋 Catalog Management

- [x] Product lifecycle management (draft/active/discontinued)
- [x] Cost and margin analysis (materials cost, gross profit, markup)
- [x] Allergen tracking (auto-aggregated from BOM components)
- [x] Nutritional facts (auto-calculated from BOM components)
- [x] Recipe/Bill of Materials management
  - Simple versioning UX: edit only the latest version; older versions are read‑only with a “Go to latest” banner and a history modal (View / Make Active).
- [x] Pricing helper card with markup-based retail & wholesale suggestions sourced from settings
- [ ] Variant management
- [x] Default currency setting and money formatting

### 📦 Inventory Control

- [x] Raw material stock tracking
- [x] Minimum/maximum stock levels
- [x] Stock movement history (adjustments, consumption, receiving)
- [x] Allergen support
- [x] Nutritional facts per material
- [x] Inventory forecasting by upcoming orders (materials requirements)
- [ ] Unit conversion (display formatting only)

### 🧾 Purchasing

- [x] Suppliers
- [x] Purchase orders
- [x] Receive POs into stock

### 🛍️ Sales & Order Management

- [x] Order processing workflow with statuses
- [x] Order status tracking and calendar view
- [x] Delivery date per order
- [ ] Discounts and promotions
- [ ] Customer-specific pricing
- [ ] Invoicing and payments
- [ ] WhatsApp Business integration
- [ ] E-commerce integrations (Shopify, WooCommerce, etc.)

### 👥 Customer Relationship Management

- [x] Customer database
- [x] Order history per customer
- [x] Shipping & billing addresses
- [ ] Loyalty programs
- [ ] Customer segmentation

### 📊 Business Intelligence

- [x] Product cost and margin visibility
- [ ] Inventory turnover
- [ ] Sales trends
- [ ] Production efficiency metrics

### 🗓️ Production Planning

- [x] Manage → Overview landing page (`/manage/overview`) with Overview/Schedule/Make Sheet/Materials tabs
- [x] Weekly production planner (by product/day) with print-ready make sheets
- [x] Materials consumption on completion backed by BOM rollups plus completion snapshots (batch code, material/labor/overhead/unit cost)
- [ ] Quality control tracking
- [ ] Notifications

### 🛒 Storefront

- [x] Public login/overview landing page
- [x] Responsive UI
- [ ] Blog
- [ ] Billing/payments

## Technology Stack

- **Backend**: Elixir + Ash Framework + Phoenix Framework
- **Database**: PostgreSQL
- **Frontend**: Phoenix LiveView + TailwindCSS

## Getting Started

### Prerequisites

- Elixir 1.18+
- Erlang OTP 25+
- PostgreSQL 16+
- Node.js 18+ (for asset building)

### Installation

1. Clone the repository

   ```bash
   git clone https://github.com/puemos/craftplan.git
   cd craftplan
   ```

2. Install dependencies

   ```bash
   mix setup
   ```

3. Create and migrate database

   ```bash
   mix ash.setup
   ```

4. Start the Phoenix server
   ```bash
   mix phx.server
   ```

Now you can visit [`localhost:4000`](http://localhost:4000) from your browser.

## Contributing

We welcome contributions! Please feel free to submit a Pull Request. For major changes, please open an issue first to discuss what you would like to change.

## License

This project is licensed under the AGPLv3 License - see the [LICENSE](LICENSE) file for details.

## Support

If you need help with setup or have questions:

- Open an issue
- Check out our [documentation](guides/OVERVIEW.md)
