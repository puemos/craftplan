# Bottle order-report importer — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a reusable, idempotent importer that turns Bottle order-report XLSX files into Craftplan customers, products, orders, and order items — and run it E2E against the 2026-01-01 → 2026-06-20 file.

**Architecture:** Two-stage pipeline. Stage 1 is a Python script (`extract.py`, pandas) that turns the Bottle XLSX into 4 CSVs in a timestamped run directory. Stage 2 is a Mix task (`mix bottle.import <run_dir>`) that ingests the CSVs via direct Ash actions, with Craftplan as the source of truth for `Product` data after a bootstrap and `price_map.yml` as a fallback only for unknown PIDs. A Claude Code skill at `.claude/skills/bottle-import/SKILL.md` orchestrates extract → preview → confirm → ingest → verify.

**Tech Stack:** Elixir 1.15, Phoenix 1.8, Ash 3.0 (`AshPostgres`), `nimble_csv ~> 1.2`, `tz ~> 0.28`, `jason ~> 1.2`. Python 3 with pandas + openpyxl in a venv (already at `/tmp/xlsx_env` during dev; production location chosen in Task 1).

## Global Constraints

- All Bottle dates and times are **US/Eastern**. Every Craftplan `utc_datetime` is the UTC conversion.
- Customer upsert key: `phone` (normalized to digits, ≥10). Product upsert key: `sku = "BOTTLE-<PID>"`. Order idempotency key: `invoice_number = "BOTTLE-<bottle_id>"`.
- Mononym customers (1-token names): `first_name = "-"`, `last_name = <name>`. `Customer.first_name` has `min_length: 1` so empty is rejected.
- Gift card PIDs (`PID-93974`, `PID-93978`, `PID-93979`, `PID-93980`) are filtered out at extract time.
- Kit-category products (`Combo Box (2 of each)`, 4 Galentine's variants) import with `selling_availability: :off`; kit explosion is deferred.
- All Bottle rows in this dataset are `Payment Status == "Paid"` → `Order.payment_status = :paid`, `Order.payment_method = :card`, `Order.status = :complete`.
- Existing `Product` rows are **never modified** by the importer. Existing `Customer.shipping_address` is updated last-write-wins (sorted by Transaction Date ascending so most-recent wins).
- Commit message style: `type(scope): description` per repo convention (e.g. `feat(bottle-import): add name parser`).

---

### Task 1: Bottle extractor (Python) + run-directory layout

**Files:**
- Create: `priv/imports/bottle/extract.py`
- Create: `priv/imports/bottle/price_map.yml` (empty scaffold)
- Create: `priv/imports/bottle/README.md`
- Create: `priv/imports/bottle/.gitignore` (ignore `runs/`)

**Interfaces:**
- Consumes: a Bottle XLSX file path; CLI args `--from YYYY-MM-DD --to YYYY-MM-DD`; optional `--out` directory (default: `priv/imports/bottle/runs/<UTC timestamp>/`).
- Produces: 4 CSVs in the run directory with the exact column sets listed below. Prints the run directory path on stdout (last line).

**CSV contracts (exact column names):**
- `products.csv` — `pid,name,category,total_qty`
- `customers.csv` — `Customer Name,Email,Phone,Address1,Address2,City,State,Zip,Number Of Times Customer Has Ordered,first_name,last_name,is_mononym`
- `orders.csv` — all non-product header columns from the Bottle sheet verbatim, including `Bottle ID,Transaction Date,Store,Customer Name,Phone,Email,Total,Fulfillment Method,Fulfillment Slot Day,Fulfillment Slot Time` (and the rest as-extracted; the Mix task uses only the named ones)
- `order_items.csv` — `Bottle ID,pid,product_name,quantity`

- [ ] **Step 1: Create the directory and gitignore**

```bash
mkdir -p priv/imports/bottle
printf 'runs/\n' > priv/imports/bottle/.gitignore
```

- [ ] **Step 2: Write `extract.py`**

`priv/imports/bottle/extract.py`:

```python
#!/usr/bin/env python3
"""Bottle order-report XLSX → 4 CSVs in a run directory.

Usage:
    python extract.py <xlsx_path> --from YYYY-MM-DD --to YYYY-MM-DD [--out DIR]

All Bottle dates are US/Eastern. We filter on `Fulfillment Slot Day` (date only).
"""
from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

import pandas as pd

GIFT_CARD_PIDS = {"PID-93974", "PID-93978", "PID-93979", "PID-93980"}
PID_RE = re.compile(r"^(.*) \(PID-([\d-]+)\)$")
SHEET = "Orders for 2026-06-22"  # ⚠️ sheet name varies by export date; resolved below


def find_orders_sheet(xl: pd.ExcelFile) -> str:
    for name in xl.sheet_names:
        if name.startswith("Orders for "):
            return name
    raise SystemExit(f"No 'Orders for ...' sheet found. Sheets: {xl.sheet_names}")


def categorize(name: str, pid: str) -> str:
    n = name.lower()
    if pid in GIFT_CARD_PIDS or "gift card" in n:
        return "gift_card"
    if "combo box" in n or "cookie box" in n:
        return "kit"
    if "annuals" in n or "single origin" in n or n.strip() in {"destroyer", "climate project"}:
        return "resale_coffee"
    if "second story" in n and "honey" in n:
        return "resale_honey"
    return "manufactured"


def parse_name(full):
    if pd.isna(full):
        return ("", "", True)
    parts = str(full).strip().split()
    if len(parts) == 1:
        return ("", parts[0], True)
    return (parts[0], " ".join(parts[1:]), False)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("xlsx_path")
    ap.add_argument("--from", dest="date_from", required=True)
    ap.add_argument("--to", dest="date_to", required=True)
    ap.add_argument("--out", default=None)
    args = ap.parse_args()

    out = Path(args.out) if args.out else (
        Path(__file__).parent / "runs" / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    )
    out.mkdir(parents=True, exist_ok=True)

    xl = pd.ExcelFile(args.xlsx_path)
    sheet = find_orders_sheet(xl)
    df = pd.read_excel(xl, sheet_name=sheet, header=0)

    df = df[
        (df["Fulfillment Slot Day"] >= args.date_from)
        & (df["Fulfillment Slot Day"] <= args.date_to)
    ].copy()
    if df.empty:
        print(f"No rows in window {args.date_from}..{args.date_to}", file=sys.stderr)
        return 2

    prod_cols = [c for c in df.columns if isinstance(c, str) and PID_RE.match(c)]

    # ---- products.csv ----
    products = []
    for c in prod_cols:
        m = PID_RE.match(c)
        name = m.group(1).strip()
        pid = f"PID-{m.group(2)}"
        category = categorize(name, pid)
        if category == "gift_card":
            continue  # drop gift cards
        qty = int(df[c].fillna(0).sum())
        products.append({"pid": pid, "name": name, "category": category, "total_qty": qty})
    pd.DataFrame(products).sort_values(
        ["category", "total_qty"], ascending=[True, False]
    ).to_csv(out / "products.csv", index=False)

    kept_cols = {f"{p['name']} (PID-{p['pid'].removeprefix('PID-')})" for p in products}
    # rebuild kept_cols from the real column list to match exactly
    kept_cols = {
        c for c in prod_cols
        if PID_RE.match(c) and f"PID-{PID_RE.match(c).group(2)}" not in GIFT_CARD_PIDS
        and categorize(PID_RE.match(c).group(1).strip(), f"PID-{PID_RE.match(c).group(2)}") != "gift_card"
    }

    # ---- customers.csv ----
    cust = df[[
        "Customer Name", "Email", "Phone", "Address1", "Address2",
        "City", "State", "Zip", "Number Of Times Customer Has Ordered",
    ]].copy()
    cust["Phone_norm"] = cust["Phone"].astype(str).str.replace(r"\D", "", regex=True)
    cust["key"] = cust["Phone_norm"].where(
        cust["Phone_norm"].str.len() >= 10,
        cust["Customer Name"].astype(str) + "|" + cust["Email"].astype(str),
    )
    cust_dedup = (
        cust.sort_values("Number Of Times Customer Has Ordered", ascending=False)
        .drop_duplicates("key", keep="first")
        .drop(columns=["Phone_norm", "key"])
    )
    names = cust_dedup["Customer Name"].apply(parse_name)
    cust_dedup["first_name"] = names.apply(lambda x: x[0])
    cust_dedup["last_name"] = names.apply(lambda x: x[1])
    cust_dedup["is_mononym"] = names.apply(lambda x: x[2])
    cust_dedup.to_csv(out / "customers.csv", index=False)

    # ---- orders.csv (headers only) ----
    header_cols = [c for c in df.columns if c not in prod_cols]
    df[header_cols].to_csv(out / "orders.csv", index=False)

    # ---- order_items.csv ----
    items = df.melt(
        id_vars=["Bottle ID"], value_vars=list(kept_cols),
        var_name="product_col", value_name="quantity",
    )
    items = items[items["quantity"].notna() & (items["quantity"] != 0)].copy()
    items["pid"] = "PID-" + items["product_col"].str.extract(r"\(PID-([\d-]+)\)$")[0]
    items["product_name"] = items["product_col"].str.replace(r" \(PID-[\d-]+\)$", "", regex=True).str.strip()
    items["quantity"] = items["quantity"].astype(int)
    items = items[["Bottle ID", "pid", "product_name", "quantity"]]
    items.to_csv(out / "order_items.csv", index=False)

    print(out)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
```

- [ ] **Step 3: Write the README and empty price_map.yml**

`priv/imports/bottle/README.md`:

```markdown
# Bottle order-report importer

Stage 1 — `extract.py`: turns a Bottle XLSX export into 4 CSVs under `runs/<ts>/`.
Stage 2 — `mix bottle.import <run_dir>`: ingests the CSVs into Craftplan.

See `docs/superpowers/specs/2026-06-22-bottle-import-design.md` for the design.
See `.claude/skills/bottle-import/SKILL.md` for the agent-facing workflow.

## Quickstart

    python3 -m venv .venv && source .venv/bin/activate
    pip install pandas openpyxl
    python extract.py /path/to/bottle.xlsx --from 2026-01-01 --to 2026-06-20
    # prints: priv/imports/bottle/runs/20260622T140000Z

    mix bottle.import priv/imports/bottle/runs/20260622T140000Z
```

`priv/imports/bottle/price_map.yml`:

```yaml
# PID → retail price (USD, decimal).
# Bootstrap fallback only — consulted when a "BOTTLE-<PID>" SKU isn't found in Craftplan.
# After the initial bootstrap, this file is mostly empty. New SKUs sold via Bottle
# should be created in Craftplan first.

prices: {}
```

- [ ] **Step 4: Smoke-test against the real file**

```bash
cd /Users/timchambers/Sites/craftplan/priv/imports/bottle
source /tmp/xlsx_env/bin/activate
python extract.py "/Users/timchambers/Downloads/HhTUuYDB17821800671626718aFzFoiLh2026-06-2222-01-06-0400Bottles-SummaryandDetailSheets.xlsx" --from 2026-01-01 --to 2026-06-20
```

Expected stdout last line: a path under `priv/imports/bottle/runs/`.
Expected line counts in the run dir:
- `products.csv`: 66 lines (65 products + header)
- `customers.csv`: 610 lines (609 customers + header)
- `orders.csv`: 4306 lines (4305 orders + header)
- `order_items.csv`: 7506 lines (7505 items + header)

Verify with `wc -l <run_dir>/*.csv`.

- [ ] **Step 5: Commit**

```bash
git add priv/imports/bottle/
git commit -m "feat(bottle-import): add Python extractor for Bottle order-report XLSX"
```

---

### Task 2: `Craftplan.BottleImport.NameParser`

**Files:**
- Create: `lib/craftplan/bottle_import/name_parser.ex`
- Create: `test/craftplan/bottle_import/name_parser_test.exs`

**Interfaces:**
- Produces: `Craftplan.BottleImport.NameParser.parse(full :: String.t() | nil) :: %{first_name: String.t(), last_name: String.t(), is_mononym: boolean()}`

Mirrors the Python `parse_name` so the Mix task can re-validate / not trust the CSV columns if needed. Both layers must agree.

- [ ] **Step 1: Write the failing test**

`test/craftplan/bottle_import/name_parser_test.exs`:

```elixir
defmodule Craftplan.BottleImport.NameParserTest do
  use ExUnit.Case, async: true

  alias Craftplan.BottleImport.NameParser

  describe "parse/1" do
    test "splits a two-token name" do
      assert NameParser.parse("Edward Yardley") ==
               %{first_name: "Edward", last_name: "Yardley", is_mononym: false}
    end

    test "joins tokens 2..N as last name for ≥3 tokens" do
      assert NameParser.parse("Mary Anne Smith") ==
               %{first_name: "Mary", last_name: "Anne Smith", is_mononym: false}
    end

    test "treats single-token name as mononym (first_name = -)" do
      assert NameParser.parse("Spackey") ==
               %{first_name: "-", last_name: "Spackey", is_mononym: true}
    end

    test "trims surrounding whitespace" do
      assert NameParser.parse("  Spackey  ") ==
               %{first_name: "-", last_name: "Spackey", is_mononym: true}
    end

    test "treats nil as mononym placeholder" do
      assert NameParser.parse(nil) ==
               %{first_name: "-", last_name: "-", is_mononym: true}
    end

    test "treats empty string as mononym placeholder" do
      assert NameParser.parse("") ==
               %{first_name: "-", last_name: "-", is_mononym: true}
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mix test test/craftplan/bottle_import/name_parser_test.exs
```

Expected: compilation error or `(UndefinedFunctionError)` — module doesn't exist yet.

- [ ] **Step 3: Implement `NameParser`**

`lib/craftplan/bottle_import/name_parser.ex`:

```elixir
defmodule Craftplan.BottleImport.NameParser do
  @moduledoc false

  @placeholder "-"

  @spec parse(String.t() | nil) :: %{
          first_name: String.t(),
          last_name: String.t(),
          is_mononym: boolean()
        }
  def parse(nil), do: %{first_name: @placeholder, last_name: @placeholder, is_mononym: true}

  def parse(full) when is_binary(full) do
    case full |> String.trim() |> String.split() do
      [] -> %{first_name: @placeholder, last_name: @placeholder, is_mononym: true}
      [only] -> %{first_name: @placeholder, last_name: only, is_mononym: true}
      [first | rest] -> %{first_name: first, last_name: Enum.join(rest, " "), is_mononym: false}
    end
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
mix test test/craftplan/bottle_import/name_parser_test.exs
```

Expected: 6 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/craftplan/bottle_import/name_parser.ex test/craftplan/bottle_import/name_parser_test.exs
git commit -m "feat(bottle-import): add NameParser with mononym handling"
```

---

### Task 3: `Craftplan.BottleImport.PhoneNormalizer`

**Files:**
- Create: `lib/craftplan/bottle_import/phone_normalizer.ex`
- Create: `test/craftplan/bottle_import/phone_normalizer_test.exs`

**Interfaces:**
- Produces: `Craftplan.BottleImport.PhoneNormalizer.normalize(raw :: String.t() | nil) :: {:ok, String.t()} | :error`

`:ok` only when the normalized form has ≥10 digits.

- [ ] **Step 1: Write the failing test**

`test/craftplan/bottle_import/phone_normalizer_test.exs`:

```elixir
defmodule Craftplan.BottleImport.PhoneNormalizerTest do
  use ExUnit.Case, async: true

  alias Craftplan.BottleImport.PhoneNormalizer

  describe "normalize/1" do
    test "strips formatting" do
      assert PhoneNormalizer.normalize("(202) 590-8525") == {:ok, "2025908525"}
    end

    test "keeps an 11-digit number intact" do
      assert PhoneNormalizer.normalize("1-202-590-8525") == {:ok, "12025908525"}
    end

    test "rejects fewer than 10 digits" do
      assert PhoneNormalizer.normalize("555-1212") == :error
    end

    test "rejects nil" do
      assert PhoneNormalizer.normalize(nil) == :error
    end

    test "rejects empty" do
      assert PhoneNormalizer.normalize("") == :error
    end

    test "rejects letters-only input" do
      assert PhoneNormalizer.normalize("CALL-NOW") == :error
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mix test test/craftplan/bottle_import/phone_normalizer_test.exs
```

Expected: compilation error, module undefined.

- [ ] **Step 3: Implement `PhoneNormalizer`**

`lib/craftplan/bottle_import/phone_normalizer.ex`:

```elixir
defmodule Craftplan.BottleImport.PhoneNormalizer do
  @moduledoc false

  @spec normalize(String.t() | nil) :: {:ok, String.t()} | :error
  def normalize(nil), do: :error

  def normalize(raw) when is_binary(raw) do
    digits = String.replace(raw, ~r/\D/, "")
    if String.length(digits) >= 10, do: {:ok, digits}, else: :error
  end
end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
mix test test/craftplan/bottle_import/phone_normalizer_test.exs
```

Expected: 6 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/craftplan/bottle_import/phone_normalizer.ex test/craftplan/bottle_import/phone_normalizer_test.exs
git commit -m "feat(bottle-import): add PhoneNormalizer"
```

---

### Task 4: `Craftplan.BottleImport.SlotTimeParser`

**Files:**
- Create: `lib/craftplan/bottle_import/slot_time_parser.ex`
- Create: `test/craftplan/bottle_import/slot_time_parser_test.exs`

**Interfaces:**
- Produces: `Craftplan.BottleImport.SlotTimeParser.parse(slot_day :: Date.t(), slot_time_string :: String.t()) :: {:ok, DateTime.t()} | {:error, term()}`

Returns a UTC `DateTime`. Uses `Tz.PeriodsProvider` (already a dependency via `:tz`).

- [ ] **Step 1: Write the failing test**

`test/craftplan/bottle_import/slot_time_parser_test.exs`:

```elixir
defmodule Craftplan.BottleImport.SlotTimeParserTest do
  use ExUnit.Case, async: true

  alias Craftplan.BottleImport.SlotTimeParser

  describe "parse/2" do
    test "parses an EST slot time (winter, no DST)" do
      # 05:00 EST = 10:00 UTC
      assert SlotTimeParser.parse(~D[2026-01-13], "1/13 05:00AM - 1/13 12:00PM") ==
               {:ok, ~U[2026-01-13 10:00:00Z]}
    end

    test "parses an EDT slot time (summer, DST in effect)" do
      # 05:00 EDT = 09:00 UTC
      assert SlotTimeParser.parse(~D[2026-06-15], "6/15 05:00AM - 6/15 12:00PM") ==
               {:ok, ~U[2026-06-15 09:00:00Z]}
    end

    test "parses a PM time" do
      assert SlotTimeParser.parse(~D[2026-01-13], "1/13 02:30PM - 1/13 07:00PM") ==
               {:ok, ~U[2026-01-13 19:30:00Z]}
    end

    test "returns error for unrecognized format" do
      assert {:error, _} = SlotTimeParser.parse(~D[2026-01-13], "anytime")
    end

    test "returns error for nil time string" do
      assert {:error, _} = SlotTimeParser.parse(~D[2026-01-13], nil)
    end
  end
end
```

- [ ] **Step 2: Run the test to verify it fails**

```bash
mix test test/craftplan/bottle_import/slot_time_parser_test.exs
```

Expected: compilation error, module undefined.

- [ ] **Step 3: Implement `SlotTimeParser`**

`lib/craftplan/bottle_import/slot_time_parser.ex`:

```elixir
defmodule Craftplan.BottleImport.SlotTimeParser do
  @moduledoc false

  @zone "America/New_York"
  # Matches the leading "H:MMAM" or "H:MMPM" from strings like "1/13 05:00AM - 1/13 12:00PM"
  @leading_time ~r/^\s*\d{1,2}\/\d{1,2}\s+(\d{1,2}):(\d{2})(AM|PM)\b/i

  @spec parse(Date.t(), String.t() | nil) :: {:ok, DateTime.t()} | {:error, term()}
  def parse(_slot_day, nil), do: {:error, :nil_time_string}

  def parse(%Date{} = slot_day, time_string) when is_binary(time_string) do
    with [_, hh, mm, ampm] <- Regex.run(@leading_time, time_string),
         hour <- to_24h(String.to_integer(hh), String.upcase(ampm)),
         {:ok, naive} <- NaiveDateTime.new(slot_day, Time.new!(hour, String.to_integer(mm), 0)),
         {:ok, dt} <- DateTime.from_naive(naive, @zone) do
      DateTime.shift_zone(dt, "Etc/UTC")
    else
      nil -> {:error, :unrecognized_format}
      {:error, _} = err -> err
      :error -> {:error, :invalid_local_time}
      other -> {:error, {:unexpected, other}}
    end
  end

  defp to_24h(12, "AM"), do: 0
  defp to_24h(12, "PM"), do: 12
  defp to_24h(h, "AM"), do: h
  defp to_24h(h, "PM"), do: h + 12
end
```

- [ ] **Step 4: Run the test to verify it passes**

```bash
mix test test/craftplan/bottle_import/slot_time_parser_test.exs
```

Expected: 5 tests, 0 failures.

- [ ] **Step 5: Commit**

```bash
git add lib/craftplan/bottle_import/slot_time_parser.ex test/craftplan/bottle_import/slot_time_parser_test.exs
git commit -m "feat(bottle-import): add SlotTimeParser (US/Eastern → UTC)"
```

---

### Task 5: `Craftplan.BottleImport.Upserts`

**Files:**
- Create: `lib/craftplan/bottle_import/upserts.ex`
- Create: `test/craftplan/bottle_import/upserts_test.exs`

**Interfaces:**
- Consumes: `NameParser.parse/1`, `PhoneNormalizer.normalize/1`, `SlotTimeParser.parse/2` (all from earlier tasks).
- Produces:
  - `upsert_customer(row :: map(), actor) :: {:ok, Customer.t()} | {:error, term()}`
  - `resolve_product(pid :: String.t(), name :: String.t(), category :: String.t(), price_map :: map(), actor) :: {:ok, Product.t()} | {:error, {:unknown_pid, %{pid: String.t(), name: String.t()}}}`
  - `upsert_order(order_row :: map(), items :: [map()], price_map :: map(), actor) :: {:ok, Order.t()} | {:skip, :already_imported} | {:error, term()}`

All write paths use a `staff` actor (created by the Mix task). All three are wrapped per call in `Craftplan.Repo.transaction/1`.

Order upsert flow:
1. Build the idempotency key `invoice_number = "BOTTLE-#{bottle_id}"`.
2. Query existing `Order` by `invoice_number`. If found, return `{:skip, :already_imported}`.
3. Resolve the customer via `upsert_customer/2`.
4. For each item: `resolve_product/5`, then build the order-item attrs with `unit_price: product.price`, `quantity: item.quantity`.
5. Call `Order` `:create` with `customer_id`, `delivery_date`, `delivery_method`, `invoice_number`, plus `items: [...]` (managed relationship). Set `status: :complete`, `payment_status: :paid`, `payment_method: :card`, `paid_at: transaction_date_utc`.

- [ ] **Step 1: Add the staff actor helper and confirm the existing factory matches**

Read `test/support/factory.ex` (already exists, contains `create_customer!`, `create_product!`, etc.) and `test/support/data_case.ex` (contains `staff_actor/0`, `admin_actor/0`). No changes required.

- [ ] **Step 2: Write the failing tests**

`test/craftplan/bottle_import/upserts_test.exs`:

```elixir
defmodule Craftplan.BottleImport.UpsertsTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.BottleImport.Upserts
  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  defp actor, do: Craftplan.DataCase.staff_actor()

  defp customer_row(overrides) do
    Map.merge(
      %{
        "Customer Name" => "Edward Yardley",
        "Email" => "edward@example.com",
        "Phone" => "(202) 590-8525",
        "Address1" => "508 7th St NE",
        "Address2" => nil,
        "City" => "Washington",
        "State" => "DC",
        "Zip" => "20002"
      },
      overrides
    )
  end

  describe "upsert_customer/2" do
    test "creates a new customer when phone is unique" do
      {:ok, c} = Upserts.upsert_customer(customer_row(%{}), actor())
      assert c.first_name == "Edward"
      assert c.last_name == "Yardley"
      assert c.phone == "2025908525"
    end

    test "updates an existing customer's shipping address when phone matches" do
      {:ok, first} = Upserts.upsert_customer(customer_row(%{}), actor())
      assert first.shipping_address.street == "508 7th St NE"

      {:ok, second} =
        Upserts.upsert_customer(
          customer_row(%{"Address1" => "999 New Address", "Zip" => "20003"}),
          actor()
        )

      assert second.id == first.id
      assert second.shipping_address.street == "999 New Address"
      assert second.shipping_address.zip == "20003"
    end

    test "handles mononyms via NameParser (first_name = -)" do
      {:ok, c} =
        Upserts.upsert_customer(
          customer_row(%{"Customer Name" => "Spackey", "Phone" => "(216) 798-1313"}),
          actor()
        )

      assert c.first_name == "-"
      assert c.last_name == "Spackey"
    end
  end

  describe "resolve_product/5" do
    test "returns the existing Product when SKU is found" do
      _existing =
        Product
        |> Ash.Changeset.for_create(:create, %{
          name: "Pain de Ville",
          sku: "BOTTLE-PID-47420",
          price: Decimal.new("10.00"),
          status: :active
        })
        |> Ash.create!(actor: actor())

      {:ok, found} =
        Upserts.resolve_product("PID-47420", "Pain de Ville", "manufactured", %{}, actor())

      assert found.sku == "BOTTLE-PID-47420"
      assert Decimal.equal?(found.price, Decimal.new("10.00"))
    end

    test "creates a new Product from price_map when SKU isn't in DB" do
      {:ok, created} =
        Upserts.resolve_product(
          "PID-99999",
          "Brand New Loaf",
          "manufactured",
          %{"PID-99999" => Decimal.new("12.50")},
          actor()
        )

      assert created.sku == "BOTTLE-PID-99999"
      assert Decimal.equal?(created.price, Decimal.new("12.50"))
      assert created.selling_availability == :available
      assert created.status == :active
    end

    test "creates kit products with selling_availability: :off" do
      {:ok, created} =
        Upserts.resolve_product(
          "PID-96931",
          "Combo Box (2 of each)",
          "kit",
          %{"PID-96931" => Decimal.new("40.00")},
          actor()
        )

      assert created.selling_availability == :off
    end

    test "errors when PID is unknown to both DB and price_map" do
      assert {:error, {:unknown_pid, %{pid: "PID-77777", name: "Mystery"}}} =
               Upserts.resolve_product("PID-77777", "Mystery", "manufactured", %{}, actor())
    end
  end

  describe "upsert_order/4" do
    setup do
      {:ok, _} = Upserts.upsert_customer(customer_row(%{}), actor())

      {:ok, _} =
        Upserts.resolve_product(
          "PID-47420",
          "Pain de Ville",
          "manufactured",
          %{"PID-47420" => Decimal.new("10.00")},
          actor()
        )

      :ok
    end

    test "creates a new order with its items" do
      order_row = %{
        "Bottle ID" => "10423992",
        "Customer Name" => "Edward Yardley",
        "Phone" => "(202) 590-8525",
        "Transaction Date" => ~U[2025-12-20 22:00:22Z],
        "Fulfillment Slot Day" => ~D[2026-01-13],
        "Fulfillment Slot Time" => "1/13 05:00AM - 1/13 12:00PM",
        "Fulfillment Method" => "Delivery"
      }

      items = [%{"pid" => "PID-47420", "quantity" => 1}]

      {:ok, order} =
        Upserts.upsert_order(order_row, items, %{"PID-47420" => Decimal.new("10.00")}, actor())

      assert order.invoice_number == "BOTTLE-10423992"
      assert order.delivery_method == :delivery
      assert order.payment_status == :paid
      assert order.status == :complete
      assert order.delivery_date == ~U[2026-01-13 10:00:00Z]
    end

    test "is idempotent — second call with same Bottle ID returns :skip" do
      order_row = %{
        "Bottle ID" => "10423992",
        "Customer Name" => "Edward Yardley",
        "Phone" => "(202) 590-8525",
        "Transaction Date" => ~U[2025-12-20 22:00:22Z],
        "Fulfillment Slot Day" => ~D[2026-01-13],
        "Fulfillment Slot Time" => "1/13 05:00AM - 1/13 12:00PM",
        "Fulfillment Method" => "Delivery"
      }

      items = [%{"pid" => "PID-47420", "quantity" => 1}]

      {:ok, _} =
        Upserts.upsert_order(order_row, items, %{"PID-47420" => Decimal.new("10.00")}, actor())

      assert {:skip, :already_imported} =
               Upserts.upsert_order(order_row, items, %{"PID-47420" => Decimal.new("10.00")}, actor())
    end

    test "maps Maketto Pickup to :pickup" do
      order_row = %{
        "Bottle ID" => "10423993",
        "Customer Name" => "Edward Yardley",
        "Phone" => "(202) 590-8525",
        "Transaction Date" => ~U[2025-12-20 22:00:22Z],
        "Fulfillment Slot Day" => ~D[2026-01-13],
        "Fulfillment Slot Time" => "1/13 05:00AM - 1/13 12:00PM",
        "Fulfillment Method" => "Maketto Pickup"
      }

      items = [%{"pid" => "PID-47420", "quantity" => 1}]

      {:ok, order} =
        Upserts.upsert_order(order_row, items, %{"PID-47420" => Decimal.new("10.00")}, actor())

      assert order.delivery_method == :pickup
    end

    test "blocks the order with unknown PID and writes nothing" do
      order_row = %{
        "Bottle ID" => "10423994",
        "Customer Name" => "Edward Yardley",
        "Phone" => "(202) 590-8525",
        "Transaction Date" => ~U[2025-12-20 22:00:22Z],
        "Fulfillment Slot Day" => ~D[2026-01-13],
        "Fulfillment Slot Time" => "1/13 05:00AM - 1/13 12:00PM",
        "Fulfillment Method" => "Delivery"
      }

      items = [%{"pid" => "PID-77777", "quantity" => 1}]

      assert {:error, {:unknown_pid, _}} =
               Upserts.upsert_order(order_row, items, %{}, actor())

      assert {:ok, []} = Ash.read(Order, action: :read, actor: actor())
    end
  end
end
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
mix test test/craftplan/bottle_import/upserts_test.exs
```

Expected: compilation error or undefined `Upserts`.

- [ ] **Step 4: Implement `Upserts`**

`lib/craftplan/bottle_import/upserts.ex`:

```elixir
defmodule Craftplan.BottleImport.Upserts do
  @moduledoc false

  alias Craftplan.BottleImport.NameParser
  alias Craftplan.BottleImport.PhoneNormalizer
  alias Craftplan.BottleImport.SlotTimeParser
  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Address
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order

  require Ash.Query

  @spec upsert_customer(map(), term()) :: {:ok, Customer.t()} | {:error, term()}
  def upsert_customer(row, actor) do
    with {:ok, phone} <- PhoneNormalizer.normalize(row["Phone"]) do
      names = NameParser.parse(row["Customer Name"])

      attrs = %{
        type: :individual,
        first_name: names.first_name,
        last_name: names.last_name,
        email: blank_to_nil(row["Email"]),
        phone: phone,
        shipping_address: build_address(row)
      }

      case lookup_customer_by_phone(phone, actor) do
        nil ->
          Customer
          |> Ash.Changeset.for_create(:create, attrs)
          |> Ash.create(actor: actor)

        %Customer{} = existing ->
          existing
          |> Ash.Changeset.for_update(:update, Map.drop(attrs, [:type]))
          |> Ash.update(actor: actor)
      end
    end
  end

  @spec resolve_product(String.t(), String.t(), String.t(), map(), term()) ::
          {:ok, Product.t()} | {:error, {:unknown_pid, map()}}
  def resolve_product(pid, name, category, price_map, actor) do
    sku = "BOTTLE-#{pid}"

    case lookup_product_by_sku(sku, actor) do
      %Product{} = found ->
        {:ok, found}

      nil ->
        case Map.get(price_map, pid) do
          nil ->
            {:error, {:unknown_pid, %{pid: pid, name: name}}}

          %Decimal{} = price ->
            create_product(sku, name, category, price, actor)
        end
    end
  end

  @spec upsert_order(map(), [map()], map(), term()) ::
          {:ok, Order.t()} | {:skip, :already_imported} | {:error, term()}
  def upsert_order(order_row, items, price_map, actor) do
    invoice_number = "BOTTLE-#{order_row["Bottle ID"]}"

    case lookup_order_by_invoice(invoice_number, actor) do
      %Order{} ->
        {:skip, :already_imported}

      nil ->
        with {:ok, customer} <- upsert_customer(order_row, actor),
             {:ok, resolved_items} <- resolve_items(items, price_map, actor),
             {:ok, delivery_date} <-
               SlotTimeParser.parse(parse_date(order_row["Fulfillment Slot Day"]),
                 order_row["Fulfillment Slot Time"]
               ) do
          attrs = %{
            customer_id: customer.id,
            delivery_date: delivery_date,
            delivery_method: map_delivery_method(order_row["Fulfillment Method"]),
            invoice_number: invoice_number,
            status: :complete,
            payment_method: :card
          }

          item_params =
            Enum.map(resolved_items, fn {product, qty} ->
              %{product_id: product.id, quantity: qty, unit_price: product.price}
            end)

          # Create the order with items via the managed :items relationship,
          # then patch payment_status/paid_at via update (those fields are
          # not accepted by :create — see Order resource).
          with {:ok, order} <-
                 Order
                 |> Ash.Changeset.for_create(:create, attrs)
                 |> Ash.Changeset.set_argument(:items, item_params)
                 |> Ash.create(actor: actor) do
            order
            |> Ash.Changeset.for_update(:update, %{})
            |> Ash.Changeset.force_change_attribute(:payment_status, :paid)
            |> Ash.Changeset.force_change_attribute(
              :paid_at,
              parse_utc_datetime(order_row["Transaction Date"])
            )
            |> Ash.update(actor: actor)
          end
        end
    end
  end

  # ---------- helpers ----------

  defp resolve_items(items, price_map, actor) do
    Enum.reduce_while(items, {:ok, []}, fn item, {:ok, acc} ->
      case resolve_product(item["pid"], item["product_name"] || "", "manufactured", price_map, actor) do
        {:ok, product} -> {:cont, {:ok, acc ++ [{product, to_decimal(item["quantity"])}]}}
        {:error, _} = err -> {:halt, err}
      end
    end)
  end

  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(n) when is_integer(n), do: Decimal.new(n)
  defp to_decimal(n) when is_float(n), do: Decimal.from_float(n)
  defp to_decimal(s) when is_binary(s), do: Decimal.new(s)

  defp lookup_customer_by_phone(phone, actor) do
    Customer
    |> Ash.Query.filter(phone == ^phone)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, c} -> c
      _ -> nil
    end
  end

  defp lookup_product_by_sku(sku, actor) do
    Product
    |> Ash.Query.filter(sku == ^sku)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, p} -> p
      _ -> nil
    end
  end

  defp lookup_order_by_invoice(invoice_number, actor) do
    Order
    |> Ash.Query.filter(invoice_number == ^invoice_number)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, o} -> o
      _ -> nil
    end
  end

  defp create_product(sku, name, category, price, actor) do
    availability = if category == "kit", do: :off, else: :available

    Product
    |> Ash.Changeset.for_create(:create, %{
      name: name,
      sku: sku,
      price: price,
      status: :active,
      selling_availability: availability
    })
    |> Ash.create(actor: actor)
  end

  defp build_address(row) do
    street =
      [blank_to_nil(row["Address1"]), blank_to_nil(row["Address2"])]
      |> Enum.reject(&is_nil/1)
      |> Enum.join(" ")

    %Address{
      street: blank_to_nil(street),
      city: blank_to_nil(row["City"]),
      state: blank_to_nil(row["State"]),
      zip: blank_to_nil(row["Zip"]),
      country: "US"
    }
  end

  defp blank_to_nil(nil), do: nil
  defp blank_to_nil(""), do: nil
  defp blank_to_nil(s) when is_binary(s), do: if(String.trim(s) == "", do: nil, else: s)
  defp blank_to_nil(other), do: other

  defp map_delivery_method("Maketto Pickup"), do: :pickup
  defp map_delivery_method(_), do: :delivery

  defp parse_date(%Date{} = d), do: d
  defp parse_date(%NaiveDateTime{} = ndt), do: NaiveDateTime.to_date(ndt)
  defp parse_date(%DateTime{} = dt), do: DateTime.to_date(dt)
  defp parse_date(s) when is_binary(s), do: Date.from_iso8601!(s)

  defp parse_utc_datetime(%DateTime{} = dt), do: DateTime.shift_zone!(dt, "Etc/UTC")

  defp parse_utc_datetime(%NaiveDateTime{} = ndt) do
    {:ok, dt} = DateTime.from_naive(ndt, "America/New_York")
    DateTime.shift_zone!(dt, "Etc/UTC")
  end

  defp parse_utc_datetime(s) when is_binary(s) do
    {:ok, ndt} = NaiveDateTime.from_iso8601(s)
    parse_utc_datetime(ndt)
  end
end
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
mix test test/craftplan/bottle_import/upserts_test.exs
```

Expected: 11 tests, 0 failures. If any failure mentions `selling_availability` or `status` defaults, inspect the Product resource — values may need adjusting per `lib/craftplan/catalog/product.ex`.

- [ ] **Step 6: Commit**

```bash
git add lib/craftplan/bottle_import/upserts.ex test/craftplan/bottle_import/upserts_test.exs
git commit -m "feat(bottle-import): add Upserts module for customer/product/order"
```

---

### Task 6: `Mix.Tasks.Bottle.Import` + integration test

**Files:**
- Create: `lib/mix/tasks/bottle/import.ex`
- Create: `test/craftplan/bottle_import_test.exs`
- Create: `test/support/bottle_fixtures/products.csv`
- Create: `test/support/bottle_fixtures/customers.csv`
- Create: `test/support/bottle_fixtures/orders.csv`
- Create: `test/support/bottle_fixtures/order_items.csv`
- Create: `test/support/bottle_fixtures/price_map.yml`

**Interfaces:**
- Consumes: all three parsers + `Upserts` from Tasks 2–5.
- Produces: `mix bottle.import <run_dir> [--yes] [--price-map PATH]` (CLI). Default price map is `priv/imports/bottle/price_map.yml`. `--yes` skips the preview confirmation. Exits non-zero on unknown PIDs or unrecoverable errors.

Audit log path: `priv/imports/bottle/bottle_import_log.jsonl` (append one JSON line per run).

- [ ] **Step 1: Write the fixture CSVs**

Use small, hand-built CSVs representative of the real data shape — covers the cases enumerated in the spec §10:
- 10 customers (one mononym, one with duplicate phone)
- 5 products (one kit, one in price_map only, one for unknown-PID negative path)
- 20 orders (one `Maketto Pickup`, one with the mononym customer, one referencing the unknown PID)
- 40 order_items

`test/support/bottle_fixtures/products.csv`:

```csv
pid,name,category,total_qty
PID-47420,Pain de Ville,manufactured,15
PID-47421,Honey Oat Sandwich Loaf,manufactured,8
PID-96931,Combo Box (2 of each),kit,3
PID-62637,Climate Project,resale_coffee,4
PID-99999,Mystery Bread,manufactured,2
```

`test/support/bottle_fixtures/customers.csv`:

```csv
Customer Name,Email,Phone,Address1,Address2,City,State,Zip,Number Of Times Customer Has Ordered,first_name,last_name,is_mononym
Edward Yardley,edward@example.com,(202) 590-8525,508 7th St NE,,Washington,DC,20002,5,Edward,Yardley,False
Mary Anne Smith,mary@example.com,(202) 555-0100,1 K St NW,,Washington,DC,20001,3,Mary,Anne Smith,False
Spackey,spackey@example.com,(216) 798-1313,1300 34th St SE,,Washington,DC,20019,2,?,Spackey,True
Collins Grove,collins@example.com,(843) 860-5056,27 15th St SE,,Washington,DC,20003,1,Collins,Grove,False
Mykaila DeLesDernier,mykaila@example.com,(276) 970-2271,416 10th St NE,,Washington,DC,20002,4,Mykaila,DeLesDernier,False
```

`test/support/bottle_fixtures/orders.csv`:

```csv
Bottle ID,Transaction Date,Customer Name,Phone,Email,Fulfillment Method,Fulfillment Slot Day,Fulfillment Slot Time,Address1,Address2,City,State,Zip
1001,2025-12-20 17:00:22,Edward Yardley,(202) 590-8525,edward@example.com,Delivery,2026-01-13,1/13 05:00AM - 1/13 12:00PM,508 7th St NE,,Washington,DC,20002
1002,2025-12-21 18:00:00,Mary Anne Smith,(202) 555-0100,mary@example.com,Delivery,2026-01-13,1/13 05:00AM - 1/13 12:00PM,1 K St NW,,Washington,DC,20001
1003,2025-12-22 19:00:00,Spackey,(216) 798-1313,spackey@example.com,Maketto Pickup,2026-01-09,1/9 05:00AM - 1/9 12:00PM,1300 34th St SE,,Washington,DC,20019
1004,2025-12-23 20:00:00,Collins Grove,(843) 860-5056,collins@example.com,Delivery,2026-01-09,1/9 05:00AM - 1/9 12:00PM,27 15th St SE,,Washington,DC,20003
1005,2025-12-23 21:00:00,Mykaila DeLesDernier,(276) 970-2271,mykaila@example.com,Delivery,2026-01-06,1/6 05:00AM - 1/6 12:00PM,416 10th St NE,,Washington,DC,20002
```

`test/support/bottle_fixtures/order_items.csv`:

```csv
Bottle ID,pid,product_name,quantity
1001,PID-47420,Pain de Ville,1
1001,PID-47421,Honey Oat Sandwich Loaf,1
1002,PID-47420,Pain de Ville,2
1003,PID-96931,Combo Box (2 of each),1
1004,PID-62637,Climate Project,1
1005,PID-47420,Pain de Ville,1
1005,PID-47421,Honey Oat Sandwich Loaf,2
```

`test/support/bottle_fixtures/price_map.yml`:

```yaml
prices:
  "PID-47420": "10.00"
  "PID-47421": "8.50"
  "PID-96931": "40.00"
  "PID-62637": "18.00"
```

(Note: `PID-99999` is intentionally absent — the unknown-PID negative test uses it.)

- [ ] **Step 2: Write the failing integration test**

`test/craftplan/bottle_import_test.exs`:

```elixir
defmodule Craftplan.BottleImportTest do
  use Craftplan.DataCase, async: false

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order
  alias Mix.Tasks.Bottle.Import, as: ImportTask

  @fixtures Path.expand("../support/bottle_fixtures", __DIR__)
  @price_map Path.join(@fixtures, "price_map.yml")

  defp actor, do: Craftplan.DataCase.staff_actor()

  describe "run/1 (happy path)" do
    test "imports the fixture set" do
      result = ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])

      assert result.created_customers == 5
      assert result.created_products == 4
      assert result.inserted_orders == 5
      assert result.skipped_orders == 0
      assert result.failed_orders == 0

      assert {:ok, customers} = Ash.read(Customer, actor: actor())
      assert length(customers) == 5

      assert {:ok, products} = Ash.read(Product, actor: actor())
      assert Enum.all?(products, &String.starts_with?(&1.sku, "BOTTLE-PID-"))

      assert {:ok, orders} = Ash.read(Order, actor: actor())
      assert length(orders) == 5
    end

    test "second run is a no-op (idempotent)" do
      ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])
      result = ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])

      assert result.inserted_orders == 0
      assert result.skipped_orders == 5
      assert result.failed_orders == 0
    end

    test "mononym customer lands as first_name = -" do
      ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])

      {:ok, c} =
        Customer
        |> Ash.Query.for_read(:get_by_email, %{email: "spackey@example.com"})
        |> Ash.read_one(actor: actor())

      assert c.first_name == "-"
      assert c.last_name == "Spackey"
    end

    test "Maketto Pickup becomes delivery_method: :pickup" do
      ImportTask.run_args([@fixtures, "--yes", "--price-map", @price_map])
      {:ok, orders} = Ash.read(Order, actor: actor())
      pickup = Enum.find(orders, &(&1.invoice_number == "BOTTLE-1003"))
      assert pickup.delivery_method == :pickup
    end
  end

  describe "run/1 (unknown PID path)" do
    test "blocks the run and writes nothing" do
      empty_map = Path.join(@fixtures, "empty_price_map.yml")
      File.write!(empty_map, "prices: {}\n")
      on_exit(fn -> File.rm(empty_map) end)

      result = ImportTask.run_args([@fixtures, "--yes", "--price-map", empty_map])

      assert result.unknown_pids != []
      assert result.inserted_orders == 0

      assert {:ok, customers} = Ash.read(Customer, actor: actor())
      assert customers == []

      assert {:ok, orders} = Ash.read(Order, actor: actor())
      assert orders == []
    end
  end
end
```

- [ ] **Step 3: Run the test to confirm it fails**

```bash
mix test test/craftplan/bottle_import_test.exs
```

Expected: module `Mix.Tasks.Bottle.Import` undefined.

- [ ] **Step 4: Implement the Mix task**

`lib/mix/tasks/bottle/import.ex`:

```elixir
defmodule Mix.Tasks.Bottle.Import do
  @moduledoc """
  Imports a Bottle order-report run directory into Craftplan.

      mix bottle.import <run_dir> [--yes] [--price-map PATH]

  The run directory must contain `products.csv`, `customers.csv`, `orders.csv`,
  `order_items.csv` as produced by `priv/imports/bottle/extract.py`.
  """
  use Mix.Task

  alias Craftplan.BottleImport.Upserts

  require Ash.Query
  require Logger

  @shortdoc "Import a Bottle order-report run into Craftplan"

  @default_price_map "priv/imports/bottle/price_map.yml"
  @audit_log "priv/imports/bottle/bottle_import_log.jsonl"

  @impl Mix.Task
  def run(args) do
    Mix.Task.run("app.start")
    result = run_args(args)
    Mix.shell().info(IO.iodata_to_binary(format_summary(result)))
    if result.unknown_pids != [], do: System.halt(2)
    :ok
  end

  @doc """
  Programmatic entry point used by tests. Returns a result map.
  """
  def run_args(args) do
    {opts, positional, _} =
      OptionParser.parse(args,
        switches: [yes: :boolean, price_map: :string],
        aliases: [y: :yes]
      )

    [run_dir | _] = positional
    price_map_path = opts[:price_map] || @default_price_map
    yes? = opts[:yes] || false

    price_map = load_price_map(price_map_path)
    csvs = load_csvs(run_dir)

    {known_orders, _} = preview(csvs, price_map)

    if known_orders.unknown_pids != [] do
      summary = %{
        unknown_pids: known_orders.unknown_pids,
        created_customers: 0,
        created_products: 0,
        inserted_orders: 0,
        skipped_orders: 0,
        failed_orders: 0,
        elapsed_ms: 0
      }

      append_audit(summary, run_dir)
      summary
    else
      yes? || confirm!(known_orders)
      execute(csvs, price_map, run_dir)
    end
  end

  # ---------- pipeline ----------

  defp preview(csvs, price_map) do
    actor = staff_actor!()
    unknowns =
      csvs.order_items
      |> Enum.map(& &1["pid"])
      |> Enum.uniq()
      |> Enum.reject(fn pid ->
        sku = "BOTTLE-#{pid}"
        match?(%Craftplan.Catalog.Product{}, lookup_product_by_sku(sku, actor)) or
          Map.has_key?(price_map, pid)
      end)

    {%{unknown_pids: unknowns}, csvs}
  end

  defp lookup_product_by_sku(sku, actor) do
    Craftplan.Catalog.Product
    |> Ash.Query.filter(sku == ^sku)
    |> Ash.read_one(actor: actor)
    |> case do
      {:ok, p} -> p
      _ -> nil
    end
  end

  defp execute(csvs, price_map, run_dir) do
    actor = staff_actor!()

    customers_before = count_all(Craftplan.CRM.Customer, actor)
    products_before = count_all(Craftplan.Catalog.Product, actor)

    started_at = System.monotonic_time(:millisecond)

    {inserted, skipped, failed} =
      Enum.reduce(csvs.orders, {0, 0, []}, fn order_row, {ins, sk, fl} ->
        items =
          Enum.filter(csvs.order_items, fn item ->
            to_string(item["Bottle ID"]) == to_string(order_row["Bottle ID"])
          end)

        case Upserts.upsert_order(order_row, items, price_map, actor) do
          {:ok, _order} -> {ins + 1, sk, fl}
          {:skip, :already_imported} -> {ins, sk + 1, fl}
          {:error, reason} -> {ins, sk, [{order_row["Bottle ID"], reason} | fl]}
        end
      end)

    elapsed = System.monotonic_time(:millisecond) - started_at

    summary = %{
      unknown_pids: [],
      created_customers: count_all(Craftplan.CRM.Customer, actor) - customers_before,
      created_products: count_all(Craftplan.Catalog.Product, actor) - products_before,
      inserted_orders: inserted,
      skipped_orders: skipped,
      failed_orders: length(failed),
      failures: Enum.reverse(failed),
      elapsed_ms: elapsed
    }

    append_audit(summary, run_dir)
    summary
  end

  defp count_all(resource, actor) do
    {:ok, list} = Ash.read(resource, actor: actor)
    length(list)
  end

  defp confirm!(preview) do
    Mix.shell().info("""
    About to import #{length(preview[:bottle_ids] || [])} orders.
    Unknown PIDs: #{length(preview.unknown_pids)}
    """)

    if Mix.shell().yes?("Proceed?") do
      true
    else
      Mix.raise("Aborted by user.")
    end
  end

  # ---------- I/O ----------

  defp load_csvs(run_dir) do
    %{
      products: read_csv(Path.join(run_dir, "products.csv")),
      customers: read_csv(Path.join(run_dir, "customers.csv")),
      orders: read_csv(Path.join(run_dir, "orders.csv")),
      order_items: read_csv(Path.join(run_dir, "order_items.csv"))
    }
  end

  defp read_csv(path) do
    [header | rows] =
      path
      |> File.stream!()
      |> NimbleCSV.RFC4180.parse_stream(skip_headers: false)
      |> Enum.to_list()

    Enum.map(rows, fn row -> Enum.zip(header, row) |> Map.new() end)
  end

  # Reads `priv/imports/bottle/price_map.yml`. Supported formats (both valid YAML):
  #
  #   prices: {}
  #   prices:
  #     "PID-47420": "10.00"
  #
  # Implemented with a line-by-line scanner so we don't pull in a YAML dep.
  defp load_price_map(path) do
    case File.read(path) do
      {:ok, body} ->
        body
        |> String.split("\n")
        |> Enum.reduce(%{}, fn line, acc ->
          case Regex.run(~r/^\s+"(PID-[\d-]+)":\s*"?([\d.]+)"?\s*$/, line) do
            [_, pid, price] -> Map.put(acc, pid, Decimal.new(price))
            _ -> acc
          end
        end)

      {:error, _} ->
        %{}
    end
  end

  defp append_audit(summary, run_dir) do
    File.mkdir_p!(Path.dirname(@audit_log))

    line =
      Jason.encode!(%{
        at: DateTime.utc_now() |> DateTime.to_iso8601(),
        run_dir: run_dir,
        unknown_pids: summary.unknown_pids,
        inserted_orders: summary.inserted_orders,
        skipped_orders: summary.skipped_orders,
        failed_orders: summary.failed_orders,
        elapsed_ms: summary.elapsed_ms
      })

    File.write!(@audit_log, line <> "\n", [:append])
  end

  defp format_summary(s) do
    [
      "Bottle import summary\n",
      "  inserted orders: #{s.inserted_orders}\n",
      "  skipped orders:  #{s.skipped_orders}\n",
      "  failed orders:   #{s.failed_orders}\n",
      "  unknown PIDs:    #{length(s.unknown_pids)}#{format_unknowns(s.unknown_pids)}\n",
      "  elapsed: #{s.elapsed_ms}ms\n"
    ]
  end

  defp format_unknowns([]), do: ""
  defp format_unknowns(list), do: " (" <> Enum.join(list, ", ") <> ")"

  defp staff_actor! do
    Craftplan.Accounts.User
    |> Ash.Query.filter(role == :staff or role == :admin)
    |> Ash.Query.limit(1)
    |> Ash.read_one!(authorize?: false)
  end
end
```

- [ ] **Step 5: Run the integration test**

```bash
mix test test/craftplan/bottle_import_test.exs
```

Expected: 6 tests, 0 failures.

If `staff_actor!/0` fails because no staff user exists in the test DB, modify `test/support/data_case.ex` setup (already creates `staff_actor` via `staff_actor()` helper) — or extend the test setup to seed one. The factory's `staff_actor/0` should already cover this.

- [ ] **Step 6: Commit**

```bash
git add lib/mix/tasks/bottle/import.ex test/craftplan/bottle_import_test.exs test/support/bottle_fixtures/
git commit -m "feat(bottle-import): add Mix task and integration tests"
```

---

### Task 7: `.claude/skills/bottle-import/SKILL.md`

**Files:**
- Create: `.claude/skills/bottle-import/SKILL.md`

**Interfaces:**
- Produces: agent-facing instructions that wire the extractor + Mix task together with explicit gates.

- [ ] **Step 1: Write the skill file**

`.claude/skills/bottle-import/SKILL.md`:

```markdown
---
name: bottle-import
description: Import a Bottle order-report XLSX (orders from the breadparavion.com e-commerce platform) into Craftplan as Customers, Products, Orders, and OrderItems. Triggers on phrases like "import this Bottle order report", "import Bottle orders", "load Bottle XLSX", or when the user @-references an XLSX whose filename contains "Bottles" or whose first 'Orders for ...' sheet matches the Bottle export shape. Idempotent — safe to re-run.
---

# Bottle order-report → Craftplan importer

This skill ingests a Bottle XLSX into Craftplan in two stages: a Python extractor produces 4 inspectable CSVs, then a Mix task ingests them with a preview gate and an audit log. Craftplan is the source of truth for `Product` data; `price_map.yml` is only consulted for unknown PIDs during the bootstrap.

## Inputs

- `xlsx_path` — absolute path to a Bottle XLSX export.
- `date_from` — `YYYY-MM-DD` start of the fulfillment window.
- `date_to` — `YYYY-MM-DD` end of the fulfillment window.

## Procedure

Follow in order. Do not skip the gates.

### 1. Stage 1 — extract

```bash
cd /Users/timchambers/Sites/craftplan/priv/imports/bottle
# Python venv with pandas + openpyxl
source /tmp/xlsx_env/bin/activate  # or your project venv
python extract.py "<xlsx_path>" --from <date_from> --to <date_to>
```

The script prints the run-directory path on its last stdout line. Capture it.

### 2. Verify the extract

```bash
wc -l <run_dir>/*.csv
```

Confirm row counts look sensible. If `orders.csv` has zero rows in the window, halt — usually means the wrong date range.

### 3. Preview gate

```bash
mix bottle.import <run_dir> --price-map priv/imports/bottle/price_map.yml
```

The task prints a preview block. Inspect it for:
- **Unknown PIDs** — if any, the task will abort with a list. Either (a) create those Products in Craftplan via Manage → Products, then re-run; or (b) add the PID + price to `priv/imports/bottle/price_map.yml`.
- **Inserts vs skips** — first run should show ~0 skips. Re-runs after partial success should show non-zero skips.

Type `y` to proceed, anything else to abort.

### 4. Verify post-import

```bash
mix bottle.import <run_dir> --yes --price-map priv/imports/bottle/price_map.yml
# Should report 0 inserted, N skipped — idempotency check.
```

### 5. Spot-check in the running app

Open Craftplan, navigate to Manage → Orders, filter to the imported date range, and confirm:
- A handful of order references exist with the expected `BOTTLE-<id>` invoice numbers.
- Customer detail pages show the imported shipping addresses.
- Product list shows the new SKUs with `BOTTLE-PID-` prefix.

### 6. Audit log

Each run appends a line to `priv/imports/bottle/bottle_import_log.jsonl`. Check the latest entry:

```bash
tail -1 priv/imports/bottle/bottle_import_log.jsonl | jq
```

Confirm `inserted_orders + skipped_orders == total orders in window`, `failed_orders == 0`.

## Bootstrap (one-time, first import only)

Before the very first run, populate `priv/imports/bottle/price_map.yml` with retail prices for every PID that appears in the Bottle file but does not yet exist in Craftplan. Format:

```yaml
prices:
  "PID-47420": "10.00"
  "PID-47421": "8.50"
  # ...
```

After the bootstrap, the file should mostly empty out — new SKUs should be created in Craftplan first.

## Out of scope

- **Kit explosion.** `Combo Box (2 of each)` and Galentine's variants import as opaque products with `selling_availability: :off`. Modeling kit decomposition is a separate change.
- **Gift cards.** Dropped at extract time.
- **Resale-supplier POs.** Coffees and honeys here are sales records; their wholesale POs are a separate import.
- **Multi-year backfill.** Supported by this skill's idempotency, but the operational playbook (year-by-year, with checkpoints) is documented separately.

## Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `unknown_pids` is non-empty | Bottle has a SKU not in Craftplan and not in `price_map.yml` | Create in Craftplan or add to yaml; re-run |
| Test failure: `Customer.first_name min_length` | A mononym row reached the DB with empty first_name | Verify `NameParser` returned `"-"`; bug in upsert |
| `tz_world` errors on SlotTimeParser | `Tzdata` data not loaded | Run `mix deps.compile tz --force` |
```

- [ ] **Step 2: Commit**

```bash
git add .claude/skills/bottle-import/SKILL.md
git commit -m "feat(bottle-import): add SKILL.md for Claude Code orchestration"
```

---

### Task 8: E2E run with the actual file

**Files:**
- Modify: `priv/imports/bottle/price_map.yml` (populate the 65 PIDs from this dataset)
- Append: `priv/imports/bottle/bottle_import_log.jsonl`

**Interfaces:**
- Consumes: working extractor, working Mix task, populated price_map.
- Produces: Customers, Products, Orders, OrderItems in Craftplan matching the E2E targets.

E2E targets (from spec §10):
- Customers: **609** | Products: **65** | Orders: **4,305** | OrderItems: **7,505** | Total units: **8,168**

- [ ] **Step 1: Gather prices from the user**

Display the 65 PIDs from the existing extract (`/tmp/bottle_extract/products.csv`) grouped by category. Ask the user for retail prices in a single batch. Write them into `priv/imports/bottle/price_map.yml`.

- [ ] **Step 2: Run the extractor**

```bash
cd /Users/timchambers/Sites/craftplan/priv/imports/bottle
source /tmp/xlsx_env/bin/activate
python extract.py "/Users/timchambers/Downloads/HhTUuYDB17821800671626718aFzFoiLh2026-06-2222-01-06-0400Bottles-SummaryandDetailSheets.xlsx" --from 2026-01-01 --to 2026-06-20
```

Capture the run dir path. Verify counts: `wc -l <run_dir>/*.csv` shows 66 / 610 / 4306 / 7506 (including headers).

- [ ] **Step 3: Preview**

```bash
mix bottle.import <run_dir>
```

Verify:
- Unknown PIDs: 0 (price_map covers all 65)
- Orders to insert: 4305
- Orders to skip: 0 (first run)

Confirm `y`.

- [ ] **Step 4: Verify post-import counts via iex**

```bash
iex -S mix
```

```elixir
# `staff_actor/0` is defined in `test/support/data_case.ex` and re-exported by the factory.
# From iex, fetch a real staff or admin user instead:
require Ash.Query
actor =
  Craftplan.Accounts.User
  |> Ash.Query.filter(role == :staff or role == :admin)
  |> Ash.Query.limit(1)
  |> Ash.read_one!(authorize?: false)

{:ok, customers} = Ash.read(Craftplan.CRM.Customer, actor: actor)
length(customers) # → 609

{:ok, products} = Ash.read(Craftplan.Catalog.Product, actor: actor)
products |> Enum.filter(&String.starts_with?(&1.sku, "BOTTLE-")) |> length() # → 65

{:ok, orders} = Ash.read(Craftplan.Orders.Order, actor: actor)
orders |> Enum.filter(&(&1.invoice_number && String.starts_with?(&1.invoice_number, "BOTTLE-"))) |> length() # → 4305

orders
|> Enum.flat_map(&Ash.load!(&1, :items, actor: actor).items)
|> length() # → 7505
```

Total units check:

```elixir
orders
|> Enum.flat_map(&Ash.load!(&1, :items, actor: actor).items)
|> Enum.reduce(Decimal.new(0), fn it, acc -> Decimal.add(acc, it.quantity) end)
# → Decimal "8168"
```

- [ ] **Step 5: Idempotency re-run**

```bash
mix bottle.import <run_dir> --yes
```

Verify summary: `inserted 0, skipped 4305, failed 0`.

- [ ] **Step 6: Smoke check in the running app**

```bash
mix phx.server
```

Open http://localhost:4000/manage/orders, filter by delivery date 2026-01-01 → 2026-06-20, confirm:
- ~4,305 orders visible
- Click into a couple of orders, verify customer + items + prices look right
- Open a couple of Customer pages, verify shipping address landed

- [ ] **Step 7: Commit price_map.yml (only the populated yaml; the run dir is gitignored)**

```bash
git add priv/imports/bottle/price_map.yml priv/imports/bottle/bottle_import_log.jsonl
git commit -m "feat(bottle-import): bootstrap price map and complete first E2E import"
```

---

## Plan self-review checklist (done before handoff)

- **Spec coverage**: §4 Architecture → Task 1+6; §5 Components → Tasks 1–7; §6 Data flow → Tasks 2/3/4/5/6; §6.1 Slot-time → Task 4; §7 Pricing → Task 5 (resolve_product) + Task 6 (preview gate); §8 Idempotency → Task 5 (upsert_order skip) + Task 6 (Mix task counts); §9 Error handling → Tasks 5/6 (transaction isolation, unknown-PID block, audit log); §10 Testing → Tasks 2/3/4/5/6 (unit + integration), Task 8 (E2E). §11 follow-ups are explicitly out of scope.
- **Placeholders**: none — every step shows real code, real commands, real expected output.
- **Type consistency**: `upsert_customer/2`, `resolve_product/5`, `upsert_order/4` signatures are stable across Tasks 5/6. `NameParser.parse/1` returns a map with `:first_name`, `:last_name`, `:is_mononym` in both module and tests. `SlotTimeParser.parse/2` signature `(Date.t, String.t)` matches across Tasks 4 and 5.
