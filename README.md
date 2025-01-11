<div align="center">
  <img src="priv/static/images/favicon.svg" width="100" />
  <h1>Microcraft</h1>
  <p>
    Modern tool — built for managing artisanal micro-scale craft businesses.
  </p>
</div>
<br>
<br>
<br>


## Overview

Microcraft is an open-source ERP system designed specifically for small-scale artisanal manufacturers and craft businesses. It provides tools for managing your entire production process from raw materials to finished products, while helping you make data-driven decisions to scale efficiently.

## Features

### 📋 Catalog Management
- Product lifecycle management (from idea to production)
- Recipe/Bill of Materials management
- Cost and margin analysis
- Allergen tracking
- Variant management

### 📦 Inventory Control
- Raw material stock tracking
- Minimum/maximum stock levels
- Movement history
- Unit conversion
- Cost tracking

### 🛍️ Sales & Order Management
- Order processing workflow
- Customer-specific pricing
- Delivery scheduling
- Order status tracking
- Basic invoicing

### 👥 Customer Relationship Management
- Customer database
- Order history
- Shipping & billing address management
- Customer segmentation
- Communication history

### 📊 Business Intelligence
- Cost analysis
- Margin calculations
- Sales trends
- Inventory turnover
- Production efficiency metrics

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
   git clone https://github.com/puemos/microcraft.git
   cd microcraft
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
- Join our community [Discord/Slack]
- Check out our [documentation]

## Roadmap

- [ ] Multi-currency support
- [ ] Advanced inventory forecasting
- [ ] Production scheduling
- [ ] Quality control tracking
- [ ] Integration with e-commerce platforms
- [ ] Mobile application
- [ ] API for third-party integrations
