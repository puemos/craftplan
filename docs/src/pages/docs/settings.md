---
layout: ../../layouts/DocsLayout.astro
title: Settings
description: General configuration, markup, allergens, nutritional facts, CSV import/export, and email
---

The Settings area at **Manage → Settings** controls global configuration for your Craftplan instance.

## General Settings

![General Settings](/craftplan/screenshots/settings.webp)

- **Hourly rate** — Default labor rate used in BOM labor step calculations. Individual steps can override this value.
- **Overhead percentage** — Applied on top of labor costs during BOM rollup calculations.
- **Default currency** — Sets the currency for all monetary values (prices, costs, invoices).

## Markup Configuration

Configure how suggested retail and wholesale prices are calculated from BOM unit costs:

- **Mode** — Choose between `percent` (percentage markup) or `fixed` (flat amount added to cost)
- **Retail markup** — Value applied for retail price suggestions
- **Wholesale markup** — Value applied for wholesale price suggestions

These feed the **Suggested Prices** card on the product details tab.

## Allergens

Manage the list of allergens available for tagging materials. These propagate through BOMs to products automatically.

## Nutritional Facts

Configure which nutritional fact fields are tracked (calories, protein, fat, carbohydrates, etc.). Values defined on materials are auto-calculated for products based on BOM component quantities.

## CSV Import & Export

Settings provides bulk data operations:

![Import Export](/craftplan/screenshots/import-export.webp)

- **Export orders** — Download order data as CSV
- **Export customers** — Download customer records as CSV
- **Export inventory movements** — Download stock movement history as CSV

These exports are useful for external reporting, accounting integration, or data backup.

## Email Configuration

Configure the sender identity for outgoing emails:

- **Sender name** — Display name shown in email clients
- **Sender address** — Reply-to email address

These settings apply to all transactional emails sent by Craftplan (order confirmations, invoices, etc.).
