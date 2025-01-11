# Allergens
make_allergens = fn ->
  try do
    make_allergen = fn name ->
      [allergen] =
        Ash.Seed.seed!(
          Microcraft.Inventory.Allergen,
          [%{name: name}],
          identity: :name
        )

      allergen
    end

    %{
      gluten: make_allergen.("Gluten"),
      fish: make_allergen.("Fish"),
      milk: make_allergen.("Milk"),
      mustard: make_allergen.("Mustard"),
      lupin: make_allergen.("Lupin"),
      crustaceans: make_allergen.("Crustaceans"),
      peanuts: make_allergen.("Peanuts"),
      nuts: make_allergen.("Tree Nuts"),
      sesame: make_allergen.("Sesame"),
      mollusks: make_allergen.("Mollusks"),
      eggs: make_allergen.("Eggs"),
      soy: make_allergen.("Soy"),
      celery: make_allergen.("Celery"),
      sulphur: make_allergen.("Sulphur Dioxide")
    }
  rescue
    _ -> :ok
  end
end

if Mix.env() == :dev do
  alias Microcraft.Accounts
  alias Microcraft.Catalog
  alias Microcraft.CRM
  alias Microcraft.Inventory
  alias Microcraft.Orders
  alias Microcraft.Repo
  alias Microcraft.Settings

  # Clear existing data
  Repo.delete_all(Microcraft.Orders.OrderItem)
  Repo.delete_all(Microcraft.Orders.Order)
  Repo.delete_all(Microcraft.Production.Task)
  Repo.delete_all(Microcraft.Catalog.RecipeMaterial)
  Repo.delete_all(Microcraft.Catalog.Recipe)
  Repo.delete_all(Microcraft.Catalog.Product)
  Repo.delete_all(Microcraft.Inventory.Movement)
  Repo.delete_all(Microcraft.Inventory.MaterialAllergen)
  Repo.delete_all(Microcraft.Inventory.Material)
  Repo.delete_all(Microcraft.Inventory.Allergen)
  Repo.delete_all(Microcraft.CRM.Customer)
  Repo.delete_all(Microcraft.Accounts.User)
  Repo.delete_all(Microcraft.Settings.Settings)

  # Create users
  create_user = fn email, role ->
    {:ok, user} =
      Accounts.User
      |> Ash.Changeset.for_create(:register_with_password, %{
        email: email,
        password: "Aa123123123123",
        password_confirmation: "Aa123123123123",
        role: role
      })
      |> Ash.create(
        context: %{
          strategy: AshAuthentication.Strategy.Password,
          private: %{ash_authentication?: true}
        }
      )

    user
  end

  admin = create_user.("test@test.com", :admin)

  # Create settings
  settings = Ash.Seed.seed!(Settings.Settings, %{})

  # Create allergens
  allergens = make_allergens.()

  # Create materials with helper function
  create_material = fn name, sku, unit, price, min, max ->
    Ash.Seed.seed!(Inventory.Material, %{
      name: name,
      sku: sku,
      unit: unit,
      price: Decimal.new(price),
      minimum_stock: Decimal.new(min),
      maximum_stock: Decimal.new(max)
    })
  end

  materials = %{
    flour: create_material.("All Purpose Flour", "FLOUR-001", :gram, "0.002", "5000", "20000"),
    whole_wheat: create_material.("Whole Wheat Flour", "FLOUR-002", :gram, "0.003", "3000", "15000"),
    almonds: create_material.("Whole Almonds", "NUTS-001", :gram, "0.02", "2000", "10000"),
    walnuts: create_material.("Walnuts", "NUTS-002", :gram, "0.025", "1500", "8000"),
    eggs: create_material.("Fresh Eggs", "EGG-001", :piece, "0.15", "100", "500"),
    milk: create_material.("Whole Milk", "MILK-001", :milliliter, "0.003", "2000", "10000"),
    butter: create_material.("Butter", "DAIRY-001", :gram, "0.01", "1000", "5000"),
    sugar: create_material.("White Sugar", "SUGAR-001", :gram, "0.003", "3000", "15000"),
    chocolate: create_material.("Dark Chocolate", "CHOC-001", :gram, "0.02", "2000", "8000"),
    vanilla: create_material.("Vanilla Extract", "FLAV-001", :milliliter, "0.15", "500", "2000"),
    yeast: create_material.("Active Dry Yeast", "YEAST-001", :gram, "0.05", "500", "2000"),
    salt: create_material.("Sea Salt", "SALT-001", :gram, "0.001", "1000", "5000")
  }

  # Create material allergens with helper function
  create_allergen_link = fn material, allergen ->
    Ash.Seed.seed!(Inventory.MaterialAllergen, %{
      material_id: material.id,
      allergen_id: allergen.id
    })
  end

  # Link materials to allergens
  create_allergen_link.(materials.flour, allergens.gluten)
  create_allergen_link.(materials.whole_wheat, allergens.gluten)
  create_allergen_link.(materials.almonds, allergens.nuts)
  create_allergen_link.(materials.walnuts, allergens.nuts)
  create_allergen_link.(materials.eggs, allergens.eggs)
  create_allergen_link.(materials.milk, allergens.milk)
  create_allergen_link.(materials.butter, allergens.milk)

  # Add initial stock with helper function
  add_stock = fn material, quantity ->
    Ash.Seed.seed!(Inventory.Movement, %{
      material_id: material.id,
      occurred_at: DateTime.utc_now(),
      quantity: Decimal.new(quantity),
      reason: "Initial stock"
    })
  end

  # Add initial stock for all materials
  Enum.each(materials, fn {_, material} ->
    add_stock.(material, "5000")
  end)

  # Create products
  create_product = fn name, sku, price ->
    Ash.Seed.seed!(Catalog.Product, %{
      name: name,
      sku: sku,
      status: :for_sale,
      price: Decimal.new(price)
    })
  end

  products = %{
    almond_cookies: create_product.("Almond Cookies", "COOK-001", "3.99"),
    choc_cake: create_product.("Chocolate Cake", "CAKE-001", "15.99"),
    bread: create_product.("Artisan Bread", "BREAD-001", "4.99"),
    muffins: create_product.("Blueberry Muffins", "MUF-001", "2.99"),
    croissants: create_product.("Butter Croissants", "PAST-001", "2.50")
  }

  # Create recipes
  create_recipe = fn product, notes ->
    Ash.Seed.seed!(Catalog.Recipe, %{
      product_id: product.id,
      notes: notes
    })
  end

  recipes = %{
    almond_cookies: create_recipe.(products.almond_cookies, "Mix well and bake at 180°C for 12 minutes"),
    choc_cake: create_recipe.(products.choc_cake, "Bake at 170°C for 45 minutes"),
    bread: create_recipe.(products.bread, "Proof for 2 hours, bake at 220°C for 35 minutes"),
    muffins: create_recipe.(products.muffins, "Fill muffin tins 3/4 full, bake at 190°C for 20 minutes"),
    croissants:
      create_recipe.(
        products.croissants,
        "Laminate dough, shape, proof, bake at 200°C for 15-20 minutes"
      )
  }

  # Create recipe materials
  create_recipe_material = fn recipe, material, quantity ->
    Ash.Seed.seed!(Catalog.RecipeMaterial, %{
      recipe_id: recipe.id,
      material_id: material.id,
      quantity: Decimal.new(quantity)
    })
  end

  # Add materials to recipes
  # Almond Cookies
  create_recipe_material.(recipes.almond_cookies, materials.flour, "50")
  create_recipe_material.(recipes.almond_cookies, materials.almonds, "25")
  create_recipe_material.(recipes.almond_cookies, materials.sugar, "30")
  create_recipe_material.(recipes.almond_cookies, materials.butter, "25")
  create_recipe_material.(recipes.almond_cookies, materials.eggs, "1")

  # Chocolate Cake
  create_recipe_material.(recipes.choc_cake, materials.flour, "200")
  create_recipe_material.(recipes.choc_cake, materials.chocolate, "150")
  create_recipe_material.(recipes.choc_cake, materials.sugar, "180")
  create_recipe_material.(recipes.choc_cake, materials.eggs, "4")
  create_recipe_material.(recipes.choc_cake, materials.milk, "250")
  create_recipe_material.(recipes.choc_cake, materials.butter, "100")

  # Bread
  create_recipe_material.(recipes.bread, materials.flour, "500")
  create_recipe_material.(recipes.bread, materials.yeast, "7")
  create_recipe_material.(recipes.bread, materials.salt, "10")

  # Muffins
  create_recipe_material.(recipes.muffins, materials.flour, "250")
  create_recipe_material.(recipes.muffins, materials.sugar, "100")
  create_recipe_material.(recipes.muffins, materials.eggs, "2")
  create_recipe_material.(recipes.muffins, materials.milk, "150")
  create_recipe_material.(recipes.muffins, materials.butter, "75")

  # Croissants
  create_recipe_material.(recipes.croissants, materials.flour, "300")
  create_recipe_material.(recipes.croissants, materials.butter, "200")
  create_recipe_material.(recipes.croissants, materials.yeast, "5")
  create_recipe_material.(recipes.croissants, materials.milk, "100")

  # Create customers
  create_customer = fn first_name, last_name, email, phone, address ->
    Ash.Seed.seed!(CRM.Customer, %{
      type: :individual,
      first_name: first_name,
      last_name: last_name,
      email: email,
      phone: phone,
      billing_address: address,
      shipping_address: address
    })
  end

  customers = %{
    john:
      create_customer.(
        "John",
        "Doe",
        "john@example.com",
        "1234567890",
        %{
          street: "123 Main St",
          city: "Springfield",
          state: "IL",
          zip: "12345",
          country: "USA"
        }
      ),
    jane:
      create_customer.(
        "Jane",
        "Smith",
        "jane@example.com",
        "9876543210",
        %{
          street: "456 Oak Ave",
          city: "Portland",
          state: "OR",
          zip: "97201",
          country: "USA"
        }
      ),
    bob:
      create_customer.(
        "Bob",
        "Johnson",
        "bob@example.com",
        "5551234567",
        %{
          street: "789 Pine St",
          city: "Seattle",
          state: "WA",
          zip: "98101",
          country: "USA"
        }
      )
  }

  # Create orders with items
  create_order = fn customer, delivery_days, status ->
    Ash.Seed.seed!(Orders.Order, %{
      customer_id: customer.id,
      delivery_date: DateTime.add(DateTime.utc_now(), delivery_days, :day),
      status: status
    })
  end

  create_order_item = fn order, product, quantity ->
    Ash.Seed.seed!(Orders.OrderItem, %{
      order_id: order.id,
      product_id: product.id,
      quantity: Decimal.new(quantity),
      unit_price: product.price
    })
  end

  # Create multiple orders for John
  order1 = create_order.(customers.john, 7, :pending)
  create_order_item.(order1, products.almond_cookies, "2")
  create_order_item.(order1, products.choc_cake, "1")

  order2 = create_order.(customers.john, 14, :fulfilled)
  create_order_item.(order2, products.bread, "2")
  create_order_item.(order2, products.croissants, "6")

  order3 = create_order.(customers.john, -7, :shipped)
  create_order_item.(order3, products.muffins, "4")

  # Create multiple orders for Jane
  order4 = create_order.(customers.jane, 3, :pending)
  create_order_item.(order4, products.bread, "3")
  create_order_item.(order4, products.muffins, "6")

  order5 = create_order.(customers.jane, -3, :cancelled)
  create_order_item.(order5, products.choc_cake, "1")

  order6 = create_order.(customers.jane, 10, :fulfilled)
  create_order_item.(order6, products.almond_cookies, "5")

  # Create multiple orders for Bob
  order7 = create_order.(customers.bob, 5, :pending)
  create_order_item.(order7, products.croissants, "4")
  create_order_item.(order7, products.choc_cake, "2")

  order8 = create_order.(customers.bob, -5, :fulfilled)
  create_order_item.(order8, products.bread, "2")
  create_order_item.(order8, products.muffins, "6")

  order9 = create_order.(customers.bob, 8, :fulfilled)
  create_order_item.(order9, products.almond_cookies, "3")
  create_order_item.(order9, products.croissants, "4")

  IO.puts("Extended seed data created successfully!")
else
  make_allergens.()
end
