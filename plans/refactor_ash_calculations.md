
# Refactoring Ash Calculations for Performance

**Last updated**: 2025-11-01
**Status**: In Progress

## 1. Objective

This document outlines a plan to refactor two inefficient Ash calculations within the `Craftplan.Catalog` domain. The goal is to align them with Ash framework best practices, eliminating "N+1 query" performance issues and improving code maintainability. This work supports **Milestone 1: Production Costing Foundations** by ensuring that cost lookups are fast and efficient.

## 2. Analysis & Problem Statement

An audit of the codebase revealed that the `Product` resource calculations for `:materials_cost` and `:bom_unit_cost` are performing their own data fetching inside the `calculate/3` callback.

- **The Anti-Pattern**: The calculation module's `load/3` function returns an empty list `[]`, signaling to Ash that no data is needed. The `calculate/3` function then proceeds to fetch data imperatively for each record in the list. This results in a classic "N+1 query" problem, where one query fetches the initial records and N subsequent queries fetch the related data, one by one. This is highly inefficient and scales poorly.

- **The Correct Pattern**: Ash is designed for a declarative approach. The `load/3` function should be used to specify all required relationships and attributes. Ash's query engine then uses this information to build a single, efficient query to fetch all data at once. The `calculate/3` function should be a "pure" function that operates only on this preloaded data.

The audit confirmed that other calculations in the system (`Allergens`, `NutritionalFacts`, `GrossProfit`, etc.) already follow the correct pattern, making `MaterialCost` and `UnitCost` outliers.

The `BOMRollup` resource, which is the target of the relationship, already contains the correct, pre-calculated `material_cost` and `unit_cost` fields. The relationships are defined correctly; they are simply not being used properly in these two calculations.

## 3. Detailed Refactoring Plan

This plan will be executed in two phases, one for each identified file.

---

### **Phase 1: Refactor `UnitCost` Calculation**

- **File**: `lib/craftplan/catalog/product/calculations/unit_cost.ex`
- **Objective**: Replace the inefficient, manual data-fetching logic with a declarative `load` and a simple, safe calculation function.

#### **Current Implementation (Incorrect)**:
```elixir
defmodule Craftplan.Catalog.Product.Calculations.UnitCost do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.NotLoaded
  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Services.BatchCostCalculator
  alias Decimal, as: D

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  # Do not rely on Ash preloading for this calculation; we'll fetch what we need.
  def load(_query, _opts, _context), do: []

  @impl true
  def calculate(records, _opts, context) do
    actor = context.actor
    authorize? = context.authorize?
    Enum.map(records, &unit_cost(&1, actor, authorize?))
  end

  defp unit_cost(%{active_bom: %NotLoaded{}, id: product_id}, actor, authorize?) do
    fetch_and_compute(product_id, actor, authorize?)
  end

  defp unit_cost(%{active_bom: nil, id: product_id}, actor, authorize?) do
    fetch_and_compute(product_id, actor, authorize?)
  end

  defp unit_cost(%{active_bom: bom}, _actor, _authorize?) do
    case Map.get(bom, :rollup) do
      %NotLoaded{} -> compute_unit_cost(bom)
      nil -> compute_unit_cost(bom)
      rollup -> Map.get(rollup, :unit_cost) || D.new(0)
    end
  end

  defp fetch_and_compute(product_id, actor, authorize?) do
    case Catalog.get_active_bom_for_product(%{product_id: product_id},
           actor: actor,
           authorize?: authorize?
         ) do
      {:ok, %BOM{} = bom} -> compute_unit_cost(bom)
      _ -> D.new(0)
    end
  end

  defp compute_unit_cost(bom) do
    bom
    |> BatchCostCalculator.calculate(D.new(1), authorize?: false)
    |> Map.get(:unit_cost, D.new(0))
  rescue
    _ -> D.new(0)
  end
end
```

#### **New Implementation (Correct)**:
```elixir
defmodule Craftplan.Catalog.Product.Calculations.UnitCost do
  @moduledoc """
  Calculates the total unit cost for a product from its active BOM rollup.
  """
  use Ash.Resource.Calculation

  alias Decimal, as: D

  @impl true
  def load(_query, _opts, _context), do: [active_bom: :rollup]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      case record.active_bom do
        # The rollup is now preloaded and safe to access
        %{rollup: %{unit_cost: cost}} -> cost
        _ -> D.new(0)
      end
    end)
  end
end
```

---

### **Phase 2: Refactor `MaterialCost` Calculation**

- **File**: `lib/craftplan/catalog/product/calculations/material_cost.ex`
- **Objective**: Apply the same efficient pattern to this calculation.

#### **Current Implementation (Incorrect)**:
```elixir
defmodule Craftplan.Catalog.Product.Calculations.MaterialCost do
  @moduledoc false

  use Ash.Resource.Calculation

  alias Ash.NotLoaded
  alias Craftplan.Catalog
  alias Craftplan.Catalog.BOM
  alias Craftplan.Catalog.Services.BatchCostCalculator
  alias Decimal, as: D

  @impl true
  def init(_opts), do: {:ok, []}

  @impl true
  # Avoid preloading via Calcs; fetch what we need inside
  def load(_query, _opts, _context), do: []

  @impl true
  def calculate(records, _opts, context) do
    actor = context.actor
    authorize? = context.authorize?
    Enum.map(records, &material_cost(&1, actor, authorize?))
  end

  defp material_cost(%{active_bom: %NotLoaded{}, id: product_id}, actor, authorize?) do
    fetch_and_compute(product_id, actor, authorize?)
  end

  defp material_cost(%{active_bom: nil, id: product_id}, actor, authorize?) do
    fetch_and_compute(product_id, actor, authorize?)
  end

  defp material_cost(%{active_bom: bom}, _actor, _authorize?) do
    case Map.get(bom, :rollup) do
      %NotLoaded{} -> compute_material_cost(bom)
      nil -> compute_material_cost(bom)
      rollup -> Map.get(rollup, :material_cost) || D.new(0)
    end
  end

  defp fetch_and_compute(product_id, actor, authorize?) do
    case Catalog.get_active_bom_for_product(%{product_id: product_id},
           actor: actor,
           authorize?: authorize?
         ) do
      {:ok, %BOM{} = bom} -> compute_material_cost(bom)
      _ -> D.new(0)
    end
  end

  defp compute_material_cost(bom) do
    bom
    |> BatchCostCalculator.calculate(D.new(1), authorize?: false)
    |> Map.get(:material_cost, D.new(0))
  rescue
    _ -> D.new(0)
  end
end
```

#### **New Implementation (Correct)**:
```elixir
defmodule Craftplan.Catalog.Product.Calculations.MaterialCost do
  @moduledoc """
  Calculates the material cost for a product from its active BOM rollup.
  """
  use Ash.Resource.Calculation

  alias Decimal, as: D

  @impl true
  def load(_query, _opts, _context), do: [active_bom: :rollup]

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      case record.active_bom do
        # The rollup is now preloaded and safe to access
        %{rollup: %{material_cost: cost}} -> cost
        _ -> D.new(0)
      end
    end)
  end
end
```

---

## 4. Verification

After applying the changes, the entire project test suite must be run to ensure that the refactoring has not introduced any regressions.

- **Command**: `mix test`

A successful test run will confirm that the new calculation logic is correct and that downstream consumers of this data (e.g., UI components, other calculations) are unaffected.

## 5. Progress

- [ ] Phase 1: Refactor `UnitCost` calculation to use declarative loads
- [ ] Phase 2: Refactor `MaterialCost` calculation to follow the same pattern
