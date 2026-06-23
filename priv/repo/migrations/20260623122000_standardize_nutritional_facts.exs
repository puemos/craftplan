defmodule Craftplan.Repo.Migrations.StandardizeNutritionalFacts do
  use Ecto.Migration

  def up do
    alter table(:inventory_nutritional_facts) do
      add :key, :text
      add :default_unit, :text, null: false, default: "gram"
      add :parent_key, :text
      add :sort_order, :bigint, null: false, default: 1000
      add :eu_required, :boolean, null: false, default: false
      add :system, :boolean, null: false, default: false
    end

    set_standard_fact("energy_kj", "Energy (kJ)", "kilojoule", nil, 10, [
      "energy (kj)",
      "energy kj",
      "kilojoules",
      "kj"
    ])

    set_standard_fact("energy_kcal", "Energy (kcal)", "kcal", nil, 20, [
      "calories",
      "energy",
      "energy (kcal)",
      "energy kcal",
      "kcal"
    ])

    set_standard_fact("fat", "Fat", "gram", nil, 30, ["fat"])
    set_standard_fact("saturates", "Saturates", "gram", "fat", 40, ["saturated fat", "saturates"])

    set_standard_fact("carbohydrate", "Carbohydrate", "gram", nil, 50, [
      "carbohydrate",
      "carbohydrates"
    ])

    set_standard_fact("sugars", "Sugars", "gram", "carbohydrate", 60, ["sugar", "sugars"])
    set_standard_fact("protein", "Protein", "gram", nil, 70, ["protein"])
    set_standard_fact("salt", "Salt", "gram", nil, 80, ["salt"])

    execute("""
    UPDATE inventory_nutritional_facts
    SET key = 'custom:' || id::text
    WHERE key IS NULL
    """)

    alter table(:inventory_nutritional_facts) do
      modify :key, :text, null: false
    end

    create unique_index(:inventory_nutritional_facts, [:key],
             name: "inventory_nutritional_facts_key_index"
           )

    insert_standard_facts()

    alter table(:inventory_material_nutritional_fact) do
      add :basis_quantity, :decimal, null: false, default: fragment("100")
      add :basis_unit, :text, null: false, default: "gram"
    end

    alter table(:catalog_products) do
      add :nutrition_output_quantity, :decimal
      add :nutrition_output_unit, :text
    end
  end

  def down do
    alter table(:catalog_products) do
      remove :nutrition_output_unit
      remove :nutrition_output_quantity
    end

    alter table(:inventory_material_nutritional_fact) do
      remove :basis_unit
      remove :basis_quantity
    end

    drop_if_exists unique_index(:inventory_nutritional_facts, [:key],
                     name: "inventory_nutritional_facts_key_index"
                   )

    alter table(:inventory_nutritional_facts) do
      remove :system
      remove :eu_required
      remove :sort_order
      remove :parent_key
      remove :default_unit
      remove :key
    end
  end

  defp set_standard_fact(key, name, unit, parent_key, sort_order, names) do
    quoted_names =
      names
      |> Enum.map(&"'#{&1}'")
      |> Enum.join(", ")

    parent_value =
      case parent_key do
        nil -> "NULL"
        value -> "'#{value}'"
      end

    execute("""
    WITH candidates AS (
      SELECT id
      FROM inventory_nutritional_facts
      WHERE lower(name) IN (#{quoted_names})
      ORDER BY
        CASE WHEN lower(name) = lower('#{name}') THEN 0 ELSE 1 END,
        array_position(ARRAY[#{quoted_names}]::text[], lower(name)),
        inserted_at,
        id
      LIMIT 1
    )
    UPDATE inventory_nutritional_facts
    SET key = '#{key}',
        name = '#{name}',
        default_unit = '#{unit}',
        parent_key = #{parent_value},
        sort_order = #{sort_order},
        eu_required = true,
        system = true,
        updated_at = (now() AT TIME ZONE 'utc')
    WHERE id IN (SELECT id FROM candidates)
    """)
  end

  defp insert_standard_facts do
    execute("""
    INSERT INTO inventory_nutritional_facts
      (id, name, key, default_unit, parent_key, sort_order, eu_required, system, inserted_at, updated_at)
    VALUES
      (gen_random_uuid(), 'Energy (kJ)', 'energy_kj', 'kilojoule', NULL, 10, true, true, (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc')),
      (gen_random_uuid(), 'Energy (kcal)', 'energy_kcal', 'kcal', NULL, 20, true, true, (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc')),
      (gen_random_uuid(), 'Fat', 'fat', 'gram', NULL, 30, true, true, (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc')),
      (gen_random_uuid(), 'Saturates', 'saturates', 'gram', 'fat', 40, true, true, (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc')),
      (gen_random_uuid(), 'Carbohydrate', 'carbohydrate', 'gram', NULL, 50, true, true, (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc')),
      (gen_random_uuid(), 'Sugars', 'sugars', 'gram', 'carbohydrate', 60, true, true, (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc')),
      (gen_random_uuid(), 'Protein', 'protein', 'gram', NULL, 70, true, true, (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc')),
      (gen_random_uuid(), 'Salt', 'salt', 'gram', NULL, 80, true, true, (now() AT TIME ZONE 'utc'), (now() AT TIME ZONE 'utc'))
    ON CONFLICT (key) DO UPDATE SET
      name = EXCLUDED.name,
      default_unit = EXCLUDED.default_unit,
      parent_key = EXCLUDED.parent_key,
      sort_order = EXCLUDED.sort_order,
      eu_required = EXCLUDED.eu_required,
      system = EXCLUDED.system,
      updated_at = EXCLUDED.updated_at
    """)
  end
end
