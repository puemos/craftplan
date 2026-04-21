defmodule Craftplan.Seeder.Demo do
  @moduledoc false
  alias Craftplan.Inventory.Movement

  def run do
    params = [
      ["All Purpose Flour", "FLOUR-001", :gram, "0.002", "5000", "20000"],
      ["Whole Wheat Flour", "FLOUR-002", :gram, "0.003", "3000", "15000"],
      ["Rye Flour", "FLOUR-003", :gram, "0.004", "2000", "8000"],
      ["Gluten-Free Flour Mix", "GF-001", :gram, "0.005", "1000", "7000"],
      ["Gluten-Free Flour Mix", "GF-001", :gram, "0.005", "1000", "7000"],
      ["Whole Almonds", "NUTS-001", :gram, "0.02", "2000", "10000"],
      ["Walnuts", "NUTS-002", :gram, "0.025", "1500", "8000"],
      ["Fresh Eggs", "EGG-001", :piece, "0.15", "100", "500"],
      ["Whole Milk", "MILK-001", :milliliter, "0.003", "2000", "10000"],
      ["Butter", "DAIRY-001", :gram, "0.01", "1000", "5000"],
      ["Cream Cheese", "DAIRY-002", :gram, "0.015", "500", "3000"],
      ["White Sugar", "SUGAR-001", :gram, "0.003", "3000", "15000"],
      ["Brown Sugar", "SUGAR-002", :gram, "0.004", "2000", "10000"],
      ["Dark Chocolate", "CHOC-001", :gram, "0.02", "2000", "8000"],
      ["Vanilla Extract", "FLAV-001", :milliliter, "0.15", "500", "2000"],
      ["Ground Cinnamon", "SPICE-001", :gram, "0.006", "300", "1500"],
      ["Active Dry Yeast", "YEAST-001", :gram, "0.05", "500", "2000"],
      ["Sea Salt", "SALT-001", :gram, "0.001", "1000", "5000"]
    ]

    Enum.each(params, fn [name, sku, unit, price, min, max] ->
      Craftplan.Inventory.Material
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        unit: unit,
        price: Decimal.new(price),
        minimum_stock: Decimal.new(min),
        maximum_stock: Decimal.new(max)
      })
      |> Ash.create(authorize?: false)
    end)

    params = [
      "Gluten",
      "Fish",
      "Milk",
      "Mustard",
      "Lupin",
      "Crustaceans",
      "Peanuts",
      "Tree Nuts",
      "Sesame",
      "Mollusks",
      "Eggs",
      "Soy",
      "Celery",
      "Sulphur Dioxide"
    ]

    Enum.each(params, fn name ->
      Craftplan.Inventory.Allergen
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create(authorize?: false)
    end)

    params = [
      "Calories",
      "Fat",
      "Saturated Fat",
      "Carbohydrates",
      "Sugar",
      "Fiber",
      "Protein",
      "Salt",
      "Sodium",
      "Calcium",
      "Iron",
      "Vitamin A",
      "Vitamin C",
      "Vitamin D"
    ]

    Enum.each(params, fn name ->
      Craftplan.Inventory.NutritionalFact
      |> Ash.Changeset.for_create(:create, %{name: name})
      |> Ash.create(authorize?: false)
    end)

    materials = Craftplan.Inventory.list_materials!(authorize?: false)
    allergens = Craftplan.Inventory.list_allergens!(authorize?: false)

    Enum.each(1..50, fn _ ->
      material = Enum.random(materials)
      allergen = Enum.random(allergens)

      Craftplan.Inventory.MaterialAllergen
      |> Ash.Changeset.for_create(:create, %{
        material_id: material.id,
        allergen_id: allergen.id
      })
      |> Ash.create(authorize?: false)
    end)

    materials = Craftplan.Inventory.list_materials!(authorize?: false)
    nutritional_facts = Craftplan.Inventory.list_nutritional_facts!(authorize?: false)

    Enum.each(1..50, fn _ ->
      amount = Enum.random(1..200)
      material = Enum.random(materials)
      nutritional_fact = Enum.random(nutritional_facts)
      unit = Enum.random([:gram, :milligram, :kcal])

      Craftplan.Inventory.MaterialNutritionalFact
      |> Ash.Changeset.for_create(:create, %{
        material_id: material,
        nutritional_fact_id: nutritional_fact,
        amount: Decimal.new(amount),
        unit: unit
      })
      |> Ash.create(authorize?: false)
    end)

    params = [{"Fresh Dairy Ltd.", "sales@dairy.test"}, {"Miller & Co.", "hello@miller.test"}]

    Enum.each(params, fn {name, email} ->
      Craftplan.Inventory.Supplier
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        contact_email: email
      })
      |> Ash.create(authorize?: false)
    end)

    suppliers = Craftplan.Inventory.list_suppliers!(authorize?: false)

    Enum.each(Craftplan.Inventory.list_materials!(authorize?: false), fn material ->
      quantity = Enum.random(1..200)

      Movement
      |> Ash.Changeset.for_create(:adjust_stock, %{
        material_id: material.id,
        occurred_at: DateTime.utc_now(),
        quantity: Decimal.new(quantity),
        reason: "Initial stock"
      })
      |> Ash.create(authorize?: false)
    end)

    materials = Craftplan.Inventory.list_materials!(authorize?: false)

    Enum.each(1..50, fn x ->
      quantity = Enum.random(1..200)
      material = Enum.random(materials)
      supplier = Enum.random(suppliers)
      expiry_in_days = Enum.random(1..14)
      lot_code = "LOT#{material.name}_#{DateTime.to_string(DateTime.utc_now())}_#{x}"

      lot =
        Craftplan.Inventory.Lot
        |> Ash.Changeset.for_create(:create, %{
          lot_code: lot_code,
          material_id: material.id,
          supplier_id: supplier && supplier.id,
          received_at: DateTime.utc_now(),
          expiry_date: Date.add(Date.utc_today(), expiry_in_days)
        })
        |> Ash.create!(authorize?: false)

      Movement
      |> Ash.Changeset.for_create(:adjust_stock, %{
        material_id: material.id,
        lot_id: lot.id,
        occurred_at: DateTime.utc_now(),
        quantity: Decimal.new(quantity),
        reason: "Received lot #{lot_code}"
      })
      |> Ash.create(authorize?: false)
    end)

    params = [
      ["Almond Cookies", "COOK-001", "3.99"],
      ["Chocolate Cake", "CAKE-001", "15.99"],
      ["Artisan Bread", "BREAD-001", "4.99"],
      ["Blueberry Muffins", "MUF-001", "2.99"],
      ["Butter Croissants", "PAST-001", "2.50"],
      ["Gluten-Free Cupcakes", "CUP-001", "3.49"],
      ["Rye Loaf Bread", "BREAD-002", "5.49"],
      ["Carrot Cake", "CAKE-002", "12.99"],
      ["Oatmeal Cookies", "COOK-002", "3.49"],
      ["Cheese Danish", "PAST-002", "2.99"]
    ]

    Enum.each(params, fn [name, sku, price] ->
      Craftplan.Catalog.Product
      |> Ash.Changeset.for_create(:create, %{
        name: name,
        sku: sku,
        status: :active,
        price: Decimal.new(price)
      })
      |> Ash.create(authorize?: false)
    end)

    products = Craftplan.Catalog.list_products!(authorize?: false)
    materials = Craftplan.Inventory.list_materials!(authorize?: false)

    labor_types = [
      "Mix & knead",
      "Bake loaves",
      "Bulk proof",
      "Bake",
      "Fill tins",
      "Laminate butter",
      "Proof",
      "Pipe",
      "Frost & decorate",
      "Bake Layers",
      "Cream butter & sugar",
      "Fold dry ingredients",
      "Prepare filling",
      "Frost & finish",
      "Bake tests",
      "Prep dough"
    ]

    labor_defs =
      Enum.map(labor_types, fn x ->
        %{
          name: x,
          duration_minutes: Decimal.new(Enum.random(1..25)),
          units_per_run: Decimal.new(Enum.random(1..25))
        }
      end)

    component_defs =
      Enum.map(materials, fn x ->
        %{
          component_type: :material,
          material_id: x.id,
          quantity: Decimal.new(Enum.random(1..25))
        }
      end)

    Enum.each(products, fn product ->
      opts = [status: :active, name: "#{product.name}_v1"]

      component_defs = Enum.take(component_defs, Enum.random(1..Enum.count(component_defs)))
      labor_defs = Enum.take(labor_defs, Enum.random(1..Enum.count(labor_defs)))

      status = Keyword.get(opts, :status, :draft)

      published_at =
        case Keyword.get(opts, :published_at) do
          nil ->
            if status == :active do
              DateTime.utc_now()
            end

          value ->
            value
        end

      components =
        component_defs
        |> Enum.with_index(1)
        |> Enum.map(fn {attrs, position} ->
          Map.put(attrs, :position, position)
        end)

      labor_steps =
        labor_defs
        |> Enum.with_index(1)
        |> Enum.map(fn {attrs, sequence} ->
          attrs
          |> Map.put(:sequence, sequence)
          |> Map.put_new(:units_per_run, Decimal.new("1"))
        end)

      Craftplan.Catalog.BOM
      |> Ash.Changeset.for_create(:create, %{
        product_id: product.id,
        name: Keyword.get(opts, :name, "#{product.name} BOM"),
        status: status,
        published_at: published_at,
        components: components,
        labor_steps: labor_steps
      })
      |> Ash.create!(authorize?: false)
    end)

    Enum.each(1..25, fn _ ->
      status = Enum.random([:draft, :ordered, :received, :cancelled])
      supplier = Enum.random(suppliers)

      Craftplan.Inventory.PurchaseOrder
      |> Ash.Changeset.for_create(:create, %{
        supplier_id: supplier.id,
        ordered_at: DateTime.utc_now()
      })
      |> Ash.create(authorize?: false)
    end)

    materials = Craftplan.Inventory.list_materials!()
    purchase_orders = Craftplan.Inventory.list_purchase_orders!()

    Enum.each(purchase_orders, fn po ->
      material = Enum.random(materials)
      po = Enum.random(po)
      quantity = Enum.random(1..200)
      unit_price = Enum.random(1..200)

      Craftplan.Inventory.PurchaseOrderItem
      |> Ash.Changeset.for_create(:create, %{
        purchase_order_id: po.id,
        material_id: material.id,
        quantity: Decimal.new(quantity),
        unit_price: Decimal.new(unit_price)
      })
      |> Ash.create(authorize?: false)
    end)

    profiles =
      for _ <- 1..50 do
        email =
          Faker.Person.first_name() <>
            "_" <> Faker.Person.last_name() <> "@" <> Faker.Internet.En.free_email_service()

        {Faker.Person.first_name(), Faker.Person.last_name(), email, Faker.Phone.EnUs.phone(),
         %{
           street: Faker.Address.En.street_address(),
           city: Faker.Address.En.city(),
           state: Faker.Address.En.state_abbr(),
           zip: Faker.Address.En.zip_code(),
           country: Faker.Address.En.country()
         }}
      end

    Enum.each(profiles, fn {first_name, last_name, email, phone, address_map} ->
      Craftplan.CRM.Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: first_name,
        last_name: last_name,
        email: email,
        phone: phone,
        billing_address: address_map,
        shipping_address: address_map
      })
      |> Ash.create(authorize?: false)
    end)

    customers = Craftplan.CRM.list_customers!(authorize?: false)

    Enum.each(1..50, fn _ ->
      delivery_in_days = Enum.random(1..25)
      customer = Enum.random(customers)

      status =
        Enum.random([
          :delivered,
          :completed,
          :cancelled
        ])

      payment_status =
        Enum.random([
          :none,
          :issued,
          :paid
        ])

      Craftplan.Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.add(DateTime.utc_now(), delivery_in_days, :day),
        status: status,
        invoice_status: payment_status
      })
      |> Ash.create(authorize?: false)
    end)

    orders = Craftplan.Orders.list_orders!(authorize?: false)
    products = Craftplan.Catalog.list_products!(authorize?: false)

    Enum.each(orders, fn order ->
      status = Enum.random([:todo, :in_progress, :done])

      for i <- 1..Enum.random(1..5) do
        product = Enum.random(products)
        quantity = Enum.random(1..200)

        Craftplan.Orders.OrderItem
        |> Ash.Changeset.for_create(:create, %{
          order_id: order.id,
          product_id: product.id,
          quantity: Decimal.new(quantity),
          unit_price: product.price,
          status: status
        })
        |> Ash.create(authorize?: false)
      end
    end)
  end
end
