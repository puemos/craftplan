# seeds.exs

alias Microcraft.Accounts
alias Microcraft.Catalog
alias Microcraft.CRM
alias Microcraft.Inventory
alias Microcraft.Orders
alias Microcraft.Repo
alias Microcraft.Settings

# ------------------------------------------------------------------------------
# 1. Define helper functions for readability and code organization
# ------------------------------------------------------------------------------

seed_allergens = fn ->
  seed_single_allergen = fn name ->
    [allergen] =
      Ash.Seed.seed!(
        Inventory.Allergen,
        [%{name: name}],
        identity: :name
      )

    allergen
  end

  %{
    gluten: seed_single_allergen.("Gluten"),
    fish: seed_single_allergen.("Fish"),
    milk: seed_single_allergen.("Milk"),
    mustard: seed_single_allergen.("Mustard"),
    lupin: seed_single_allergen.("Lupin"),
    crustaceans: seed_single_allergen.("Crustaceans"),
    peanuts: seed_single_allergen.("Peanuts"),
    nuts: seed_single_allergen.("Tree Nuts"),
    sesame: seed_single_allergen.("Sesame"),
    mollusks: seed_single_allergen.("Mollusks"),
    eggs: seed_single_allergen.("Eggs"),
    soy: seed_single_allergen.("Soy"),
    celery: seed_single_allergen.("Celery"),
    sulphur: seed_single_allergen.("Sulphur Dioxide")
  }
end

# Add a function to seed nutritional facts
seed_nutritional_facts = fn ->
  seed_single_nutritional_fact = fn name ->
    [nutritional_fact] =
      Ash.Seed.seed!(
        Inventory.NutritionalFact,
        [%{name: name}],
        identity: :name
      )

    nutritional_fact
  end

  %{
    calories: seed_single_nutritional_fact.("Calories"),
    fat: seed_single_nutritional_fact.("Fat"),
    saturated_fat: seed_single_nutritional_fact.("Saturated Fat"),
    carbohydrates: seed_single_nutritional_fact.("Carbohydrates"),
    sugar: seed_single_nutritional_fact.("Sugar"),
    fiber: seed_single_nutritional_fact.("Fiber"),
    protein: seed_single_nutritional_fact.("Protein"),
    salt: seed_single_nutritional_fact.("Salt"),
    sodium: seed_single_nutritional_fact.("Sodium"),
    calcium: seed_single_nutritional_fact.("Calcium"),
    iron: seed_single_nutritional_fact.("Iron"),
    vitamin_a: seed_single_nutritional_fact.("Vitamin A"),
    vitamin_c: seed_single_nutritional_fact.("Vitamin C"),
    vitamin_d: seed_single_nutritional_fact.("Vitamin D")
  }
end

if Mix.env() == :dev do
  # ------------------------------------------------------------------------------
  # 2. Clear existing data (cleanup for repeated seeds in dev)
  # ------------------------------------------------------------------------------
  Repo.delete_all(Orders.OrderItem)
  Repo.delete_all(Orders.Order)
  Repo.delete_all(Catalog.RecipeMaterial)
  Repo.delete_all(Catalog.Recipe)
  Repo.delete_all(Catalog.Product)
  Repo.delete_all(Inventory.Movement)
  Repo.delete_all(Inventory.MaterialNutritionalFact)
  Repo.delete_all(Inventory.NutritionalFact)
  Repo.delete_all(Inventory.MaterialAllergen)
  Repo.delete_all(Inventory.Material)
  Repo.delete_all(Inventory.Allergen)
  Repo.delete_all(CRM.Customer)
  Repo.delete_all(Accounts.User)
  Repo.delete_all(Settings.Settings)

  # ------------------------------------------------------------------------------
  # 3. Seed necessary data
  # ------------------------------------------------------------------------------

  seed_user = fn email, role ->
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

  seed_material = fn name, sku, unit, price, min, max ->
    Ash.Seed.seed!(Inventory.Material, %{
      name: name,
      sku: sku,
      unit: unit,
      price: Decimal.new(price),
      minimum_stock: Decimal.new(min),
      maximum_stock: Decimal.new(max)
    })
  end

  link_material_allergen = fn material, allergen ->
    Ash.Seed.seed!(Inventory.MaterialAllergen, %{
      material_id: material.id,
      allergen_id: allergen.id
    })
  end

  # Add a function to link materials to nutritional facts with amounts and units
  link_material_nutritional_fact = fn material, nutritional_fact, amount, unit ->
    Ash.Seed.seed!(Inventory.MaterialNutritionalFact, %{
      material_id: material.id,
      nutritional_fact_id: nutritional_fact.id,
      amount: Decimal.new(amount),
      unit: unit
    })
  end

  add_initial_stock = fn material, quantity ->
    Ash.Seed.seed!(Inventory.Movement, %{
      material_id: material.id,
      occurred_at: DateTime.utc_now(),
      quantity: Decimal.new(quantity),
      reason: "Initial stock"
    })
  end

  seed_product = fn name, sku, price ->
    Ash.Seed.seed!(Catalog.Product, %{
      name: name,
      sku: sku,
      status: :active,
      price: Decimal.new(price)
    })
  end

  seed_recipe = fn product, notes ->
    Ash.Seed.seed!(Catalog.Recipe, %{
      product_id: product.id,
      notes: notes
    })
  end

  link_recipe_material = fn recipe, material, quantity ->
    Ash.Seed.seed!(Catalog.RecipeMaterial, %{
      recipe_id: recipe.id,
      material_id: material.id,
      quantity: Decimal.new(quantity)
    })
  end

  seed_customer = fn first_name, last_name, email, phone, address_map ->
    Ash.Seed.seed!(CRM.Customer, %{
      type: :individual,
      first_name: first_name,
      last_name: last_name,
      email: email,
      phone: phone,
      billing_address: address_map,
      shipping_address: address_map
    })
  end

  seed_order = fn customer, delivery_in_days, status, payment_status ->
    Ash.Seed.seed!(Orders.Order, %{
      customer_id: customer.id,
      delivery_date: DateTime.add(DateTime.utc_now(), delivery_in_days, :day),
      status: status,
      payment_status: payment_status
    })
  end

  seed_order_item = fn order, product, quantity, status ->
    Ash.Seed.seed!(Orders.OrderItem, %{
      order_id: order.id,
      product_id: product.id,
      quantity: Decimal.new(quantity),
      unit_price: product.price,
      status: status
    })
  end

  # -- 3.1 Create users
  _admin_user = seed_user.("test@test.com", :admin)
  _staff_user = seed_user.("staff@staff.com", :staff)
  _customer_user = seed_user.("customer@customer.com", :customer)

  # -- 3.2 Set up global bakery settings
  Ash.Seed.seed!(Settings.Settings, %{})

  # -- 3.3 Allergen data
  allergens = seed_allergens.()

  # -- 3.4 Nutritional facts data
  nutritional_facts = seed_nutritional_facts.()

  # -- 3.5 Materials
  materials = %{
    flour: seed_material.("All Purpose Flour", "FLOUR-001", :gram, "0.002", "5000", "20000"),
    whole_wheat: seed_material.("Whole Wheat Flour", "FLOUR-002", :gram, "0.003", "3000", "15000"),
    rye_flour: seed_material.("Rye Flour", "FLOUR-003", :gram, "0.004", "2000", "8000"),
    gluten_free_mix: seed_material.("Gluten-Free Flour Mix", "GF-001", :gram, "0.005", "1000", "7000"),
    oats: seed_material.("Rolled Oats", "OATS-001", :gram, "0.0025", "2000", "10000"),
    almonds: seed_material.("Whole Almonds", "NUTS-001", :gram, "0.02", "2000", "10000"),
    walnuts: seed_material.("Walnuts", "NUTS-002", :gram, "0.025", "1500", "8000"),
    eggs: seed_material.("Fresh Eggs", "EGG-001", :piece, "0.15", "100", "500"),
    milk: seed_material.("Whole Milk", "MILK-001", :milliliter, "0.003", "2000", "10000"),
    butter: seed_material.("Butter", "DAIRY-001", :gram, "0.01", "1000", "5000"),
    cream_cheese: seed_material.("Cream Cheese", "DAIRY-002", :gram, "0.015", "500", "3000"),
    sugar: seed_material.("White Sugar", "SUGAR-001", :gram, "0.003", "3000", "15000"),
    brown_sugar: seed_material.("Brown Sugar", "SUGAR-002", :gram, "0.004", "2000", "10000"),
    chocolate: seed_material.("Dark Chocolate", "CHOC-001", :gram, "0.02", "2000", "8000"),
    vanilla: seed_material.("Vanilla Extract", "FLAV-001", :milliliter, "0.15", "500", "2000"),
    cinnamon: seed_material.("Ground Cinnamon", "SPICE-001", :gram, "0.006", "300", "1500"),
    yeast: seed_material.("Active Dry Yeast", "YEAST-001", :gram, "0.05", "500", "2000"),
    salt: seed_material.("Sea Salt", "SALT-001", :gram, "0.001", "1000", "5000")
  }

  # -- 3.6 Link materials to relevant allergens
  link_material_allergen.(materials.flour, allergens.gluten)
  link_material_allergen.(materials.whole_wheat, allergens.gluten)
  link_material_allergen.(materials.rye_flour, allergens.gluten)
  link_material_allergen.(materials.gluten_free_mix, allergens.nuts)
  link_material_allergen.(materials.almonds, allergens.nuts)
  link_material_allergen.(materials.walnuts, allergens.nuts)
  link_material_allergen.(materials.eggs, allergens.eggs)
  link_material_allergen.(materials.milk, allergens.milk)
  link_material_allergen.(materials.butter, allergens.milk)
  link_material_allergen.(materials.cream_cheese, allergens.milk)

  # -- 3.7 Link materials to nutritional facts
  # Flour
  link_material_nutritional_fact.(materials.flour, nutritional_facts.calories, "350", :gram)
  link_material_nutritional_fact.(materials.flour, nutritional_facts.carbohydrates, "73", :gram)
  link_material_nutritional_fact.(materials.flour, nutritional_facts.protein, "10", :gram)
  link_material_nutritional_fact.(materials.flour, nutritional_facts.fat, "1", :gram)

  # Whole Wheat Flour
  link_material_nutritional_fact.(materials.whole_wheat, nutritional_facts.calories, "340", :gram)

  link_material_nutritional_fact.(
    materials.whole_wheat,
    nutritional_facts.carbohydrates,
    "72",
    :gram
  )

  link_material_nutritional_fact.(materials.whole_wheat, nutritional_facts.protein, "13", :gram)
  link_material_nutritional_fact.(materials.whole_wheat, nutritional_facts.fiber, "11", :gram)

  # Almonds
  link_material_nutritional_fact.(materials.almonds, nutritional_facts.calories, "580", :gram)
  link_material_nutritional_fact.(materials.almonds, nutritional_facts.fat, "50", :gram)
  link_material_nutritional_fact.(materials.almonds, nutritional_facts.protein, "21", :gram)

  # Eggs
  link_material_nutritional_fact.(materials.eggs, nutritional_facts.calories, "155", :piece)
  link_material_nutritional_fact.(materials.eggs, nutritional_facts.protein, "13", :gram)
  link_material_nutritional_fact.(materials.eggs, nutritional_facts.fat, "11", :gram)

  # Milk
  link_material_nutritional_fact.(materials.milk, nutritional_facts.calories, "42", :milliliter)
  link_material_nutritional_fact.(materials.milk, nutritional_facts.protein, "3.4", :gram)
  link_material_nutritional_fact.(materials.milk, nutritional_facts.calcium, "125", :milliliter)

  # Butter
  link_material_nutritional_fact.(materials.butter, nutritional_facts.calories, "717", :gram)
  link_material_nutritional_fact.(materials.butter, nutritional_facts.fat, "81", :gram)
  link_material_nutritional_fact.(materials.butter, nutritional_facts.saturated_fat, "51", :gram)

  # Chocolate
  link_material_nutritional_fact.(materials.chocolate, nutritional_facts.calories, "546", :gram)
  link_material_nutritional_fact.(materials.chocolate, nutritional_facts.fat, "31", :gram)

  link_material_nutritional_fact.(
    materials.chocolate,
    nutritional_facts.carbohydrates,
    "61",
    :gram
  )

  link_material_nutritional_fact.(materials.chocolate, nutritional_facts.iron, "8", :gram)

  # -- 3.8 Add some initial stock
  Enum.each(materials, fn {_key, material} ->
    add_initial_stock.(material, "5000")
  end)

  # -- 3.9 Seed products
  products = %{
    almond_cookies: seed_product.("Almond Cookies", "COOK-001", "3.99"),
    choc_cake: seed_product.("Chocolate Cake", "CAKE-001", "15.99"),
    bread: seed_product.("Artisan Bread", "BREAD-001", "4.99"),
    muffins: seed_product.("Blueberry Muffins", "MUF-001", "2.99"),
    croissants: seed_product.("Butter Croissants", "PAST-001", "2.50"),
    gf_cupcakes: seed_product.("Gluten-Free Cupcakes", "CUP-001", "3.49"),
    rye_loaf: seed_product.("Rye Loaf Bread", "BREAD-002", "5.49"),
    carrot_cake: seed_product.("Carrot Cake", "CAKE-002", "12.99"),
    oatmeal_cookies: seed_product.("Oatmeal Cookies", "COOK-002", "3.49"),
    cheese_danish: seed_product.("Cheese Danish", "PAST-002", "2.99")
  }

  # -- 3.10 Seed recipes
  recipes = %{
    almond_cookies:
      seed_recipe.(
        products.almond_cookies,
        "Mix flour, ground almonds, sugar, and butter. Add eggs. Bake at 180°C for 12 minutes."
      ),
    choc_cake:
      seed_recipe.(
        products.choc_cake,
        "Combine dry and wet ingredients; bake at 170°C for 45 minutes, then let cool."
      ),
    bread:
      seed_recipe.(
        products.bread,
        "Proof for 2 hours, shape loaves, bake at 220°C for 35 minutes."
      ),
    muffins:
      seed_recipe.(
        products.muffins,
        "Combine mixture, fill muffin tins 3/4. Bake at 190°C for 20 minutes."
      ),
    croissants:
      seed_recipe.(
        products.croissants,
        "Laminate dough with butter, shape, proof, bake at 200°C for 15-20 minutes."
      ),
    gf_cupcakes:
      seed_recipe.(
        products.gf_cupcakes,
        "Use GF flour, sugar, eggs, butter, vanilla. Bake at 180°C for 15-18 minutes."
      ),
    rye_loaf:
      seed_recipe.(
        products.rye_loaf,
        "Combine rye and all-purpose flours, proof 1.5 hours, bake at 210°C."
      ),
    carrot_cake:
      seed_recipe.(
        products.carrot_cake,
        "Mix shredded carrots, flour, sugar, eggs, cinnamon. Bake at 175°C for ~40 minutes."
      ),
    oatmeal_cookies:
      seed_recipe.(
        products.oatmeal_cookies,
        "Blend oats, flour, brown sugar, butter, eggs. Bake at 180°C for 10-12 minutes."
      ),
    cheese_danish:
      seed_recipe.(
        products.cheese_danish,
        "Fill pastry dough w/ sweet cream cheese, bake at 190°C for 15 minutes."
      )
  }

  # -- 3.11 Link recipes to their materials
  # Almond Cookies
  link_recipe_material.(recipes.almond_cookies, materials.flour, "50")
  link_recipe_material.(recipes.almond_cookies, materials.almonds, "25")
  link_recipe_material.(recipes.almond_cookies, materials.sugar, "30")
  link_recipe_material.(recipes.almond_cookies, materials.butter, "25")
  link_recipe_material.(recipes.almond_cookies, materials.eggs, "1")

  # Chocolate Cake
  link_recipe_material.(recipes.choc_cake, materials.flour, "200")
  link_recipe_material.(recipes.choc_cake, materials.chocolate, "150")
  link_recipe_material.(recipes.choc_cake, materials.sugar, "180")
  link_recipe_material.(recipes.choc_cake, materials.eggs, "4")
  link_recipe_material.(recipes.choc_cake, materials.milk, "250")
  link_recipe_material.(recipes.choc_cake, materials.butter, "100")

  # Artisan Bread
  link_recipe_material.(recipes.bread, materials.flour, "500")
  link_recipe_material.(recipes.bread, materials.yeast, "7")
  link_recipe_material.(recipes.bread, materials.salt, "10")

  # Blueberry Muffins
  link_recipe_material.(recipes.muffins, materials.flour, "250")
  link_recipe_material.(recipes.muffins, materials.sugar, "100")
  link_recipe_material.(recipes.muffins, materials.eggs, "2")
  link_recipe_material.(recipes.muffins, materials.milk, "150")
  link_recipe_material.(recipes.muffins, materials.butter, "75")

  # Butter Croissants
  link_recipe_material.(recipes.croissants, materials.flour, "300")
  link_recipe_material.(recipes.croissants, materials.butter, "200")
  link_recipe_material.(recipes.croissants, materials.yeast, "5")
  link_recipe_material.(recipes.croissants, materials.milk, "100")

  # Gluten-Free Cupcakes
  link_recipe_material.(recipes.gf_cupcakes, materials.gluten_free_mix, "200")
  link_recipe_material.(recipes.gf_cupcakes, materials.sugar, "100")
  link_recipe_material.(recipes.gf_cupcakes, materials.eggs, "2")
  link_recipe_material.(recipes.gf_cupcakes, materials.butter, "50")
  link_recipe_material.(recipes.gf_cupcakes, materials.vanilla, "5")

  # Rye Loaf
  link_recipe_material.(recipes.rye_loaf, materials.rye_flour, "250")
  link_recipe_material.(recipes.rye_loaf, materials.flour, "150")
  link_recipe_material.(recipes.rye_loaf, materials.salt, "8")
  link_recipe_material.(recipes.rye_loaf, materials.yeast, "7")

  # Carrot Cake
  link_recipe_material.(recipes.carrot_cake, materials.flour, "200")
  link_recipe_material.(recipes.carrot_cake, materials.sugar, "150")
  link_recipe_material.(recipes.carrot_cake, materials.eggs, "3")
  link_recipe_material.(recipes.carrot_cake, materials.butter, "75")
  link_recipe_material.(recipes.carrot_cake, materials.cinnamon, "5")

  # Oatmeal Cookies
  link_recipe_material.(recipes.oatmeal_cookies, materials.flour, "50")
  link_recipe_material.(recipes.oatmeal_cookies, materials.oats, "100")
  link_recipe_material.(recipes.oatmeal_cookies, materials.brown_sugar, "40")
  link_recipe_material.(recipes.oatmeal_cookies, materials.butter, "30")
  link_recipe_material.(recipes.oatmeal_cookies, materials.eggs, "1")

  # Cheese Danish
  link_recipe_material.(recipes.cheese_danish, materials.flour, "200")
  link_recipe_material.(recipes.cheese_danish, materials.cream_cheese, "100")
  link_recipe_material.(recipes.cheese_danish, materials.sugar, "50")
  link_recipe_material.(recipes.cheese_danish, materials.butter, "50")
  link_recipe_material.(recipes.cheese_danish, materials.eggs, "1")

  # -- 3.12 Seed customers
  customers = %{
    john:
      seed_customer.(
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
      seed_customer.(
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
      seed_customer.(
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
      ),
    alice:
      seed_customer.(
        "Alice",
        "Anderson",
        "alice@example.com",
        "2225557777",
        %{
          street: "101 Apple Rd",
          city: "Denver",
          state: "CO",
          zip: "80203",
          country: "USA"
        }
      ),
    michael:
      seed_customer.(
        "Michael",
        "Brown",
        "michael@example.com",
        "1112223333",
        %{
          street: "202 Banana Blvd",
          city: "Phoenix",
          state: "AZ",
          zip: "85001",
          country: "USA"
        }
      ),
    grace:
      seed_customer.(
        "Grace",
        "Thomas",
        "grace@example.com",
        "4445556666",
        %{
          street: "350 Elm St",
          city: "Austin",
          state: "TX",
          zip: "73301",
          country: "USA"
        }
      ),
    taylor:
      seed_customer.(
        "Taylor",
        "Evans",
        "taylor@example.com",
        "7778889999",
        %{
          street: "999 Maple Ave",
          city: "Boston",
          state: "MA",
          zip: "02215",
          country: "USA"
        }
      ),
    emily:
      seed_customer.(
        "Emily",
        "Clark",
        "emily@example.com",
        "6667778888",
        %{
          street: "202 Cedar St",
          city: "Chicago",
          state: "IL",
          zip: "60601",
          country: "USA"
        }
      )
  }

  # ------------------------------------------------------------------------------
  # 4. Create orders for these customers (simulate real bakery operations)
  # ------------------------------------------------------------------------------
  # -----------------------------
  # PAST WEEK (Days -7 to -1)
  # -----------------------------

  # Last Week - Monday (Day -7)
  order1 = seed_order.(customers.john, -7, :delivered, :paid)
  seed_order_item.(order1, products.bread, "2", :done)
  seed_order_item.(order1, products.muffins, "6", :done)
  seed_order_item.(order1, products.croissants, "4", :done)

  order2 = seed_order.(customers.jane, -7, :delivered, :paid)
  seed_order_item.(order2, products.choc_cake, "1", :done)
  seed_order_item.(order2, products.gf_cupcakes, "8", :done)

  order3 = seed_order.(customers.michael, -7, :delivered, :paid)
  seed_order_item.(order3, products.oatmeal_cookies, "12", :done)
  seed_order_item.(order3, products.bread, "1", :done)
  seed_order_item.(order3, products.rye_loaf, "1", :done)

  # Last Week - Tuesday (Day -6)
  order4 = seed_order.(customers.alice, -6, :delivered, :paid)
  seed_order_item.(order4, products.bread, "3", :done)
  seed_order_item.(order4, products.carrot_cake, "1", :done)

  order5 = seed_order.(customers.grace, -6, :delivered, :paid)
  seed_order_item.(order5, products.cheese_danish, "5", :done)
  seed_order_item.(order5, products.croissants, "6", :done)
  seed_order_item.(order5, products.almond_cookies, "10", :done)

  order6 = seed_order.(customers.bob, -6, :cancelled, :refunded)
  seed_order_item.(order6, products.choc_cake, "1", :done)

  # Last Week - Thursday (Day -4)
  order7 = seed_order.(customers.taylor, -4, :delivered, :paid)
  seed_order_item.(order7, products.choc_cake, "2", :done)
  seed_order_item.(order7, products.bread, "2", :done)

  order8 = seed_order.(customers.emily, -4, :delivered, :paid)
  seed_order_item.(order8, products.rye_loaf, "1", :done)
  seed_order_item.(order8, products.croissants, "12", :done)
  seed_order_item.(order8, products.muffins, "4", :done)

  # Last Weekend - Saturday (Day -2)
  order9 = seed_order.(customers.john, -2, :delivered, :paid)
  seed_order_item.(order9, products.choc_cake, "1", :done)
  seed_order_item.(order9, products.muffins, "12", :done)
  seed_order_item.(order9, products.bread, "2", :done)
  seed_order_item.(order9, products.croissants, "8", :done)

  order10 = seed_order.(customers.michael, -2, :delivered, :paid)
  seed_order_item.(order10, products.choc_cake, "1", :done)
  seed_order_item.(order10, products.gf_cupcakes, "12", :done)

  order11 = seed_order.(customers.grace, -2, :delivered, :paid)
  seed_order_item.(order11, products.carrot_cake, "1", :done)
  seed_order_item.(order11, products.oatmeal_cookies, "24", :done)

  order12 = seed_order.(customers.jane, -2, :delivered, :paid)
  seed_order_item.(order12, products.choc_cake, "1", :done)
  seed_order_item.(order12, products.almond_cookies, "15", :done)

  # -----------------------------
  # CURRENT WEEK (Days 0 to 7)
  # -----------------------------

  # Today (Day 0)
  order13 = seed_order.(customers.alice, 0, :completed, :paid)
  seed_order_item.(order13, products.bread, "2", :done)
  seed_order_item.(order13, products.croissants, "6", :done)

  order14 = seed_order.(customers.bob, 0, :completed, :paid)
  seed_order_item.(order14, products.carrot_cake, "1", :done)
  seed_order_item.(order14, products.gf_cupcakes, "6", :done)
  seed_order_item.(order14, products.rye_loaf, "1", :done)

  order15 = seed_order.(customers.taylor, 0, :ready, :pending)
  seed_order_item.(order15, products.bread, "3", :done)
  seed_order_item.(order15, products.muffins, "8", :in_progress)

  order16 = seed_order.(customers.emily, 0, :ready, :pending)
  seed_order_item.(order16, products.choc_cake, "1", :done)
  seed_order_item.(order16, products.cheese_danish, "8", :in_progress)

  # Tomorrow (Day 1)
  order17 = seed_order.(customers.john, 1, :confirmed, :pending)
  seed_order_item.(order17, products.bread, "2", :in_progress)
  seed_order_item.(order17, products.croissants, "4", :todo)

  order18 = seed_order.(customers.jane, 1, :confirmed, :pending)
  seed_order_item.(order18, products.bread, "1", :done)
  seed_order_item.(order18, products.almond_cookies, "10", :todo)

  order19 = seed_order.(customers.michael, 1, :confirmed, :pending)
  seed_order_item.(order19, products.bread, "2", :in_progress)
  seed_order_item.(order19, products.oatmeal_cookies, "15", :done)
  seed_order_item.(order19, products.muffins, "6", :todo)

  # This Week - Wednesday (Day 3)
  order20 = seed_order.(customers.bob, 3, :confirmed, :pending)
  seed_order_item.(order20, products.choc_cake, "1", :in_progress)
  seed_order_item.(order20, products.rye_loaf, "2", :todo)

  order21 = seed_order.(customers.grace, 3, :confirmed, :pending)
  seed_order_item.(order21, products.choc_cake, "1", :done)
  seed_order_item.(order21, products.croissants, "8", :in_progress)
  seed_order_item.(order21, products.almond_cookies, "12", :todo)

  order22 = seed_order.(customers.alice, 3, :confirmed, :pending)
  seed_order_item.(order22, products.choc_cake, "1", :done)
  seed_order_item.(order22, products.muffins, "4", :in_progress)

  # This Week - Friday (Day 5)
  order23 = seed_order.(customers.taylor, 5, :unconfirmed, :pending)
  seed_order_item.(order23, products.carrot_cake, "2", :done)
  seed_order_item.(order23, products.bread, "3", :in_progress)
  seed_order_item.(order23, products.croissants, "6", :todo)

  order24 = seed_order.(customers.emily, 5, :unconfirmed, :pending)
  seed_order_item.(order24, products.carrot_cake, "1", :in_progress)
  seed_order_item.(order24, products.gf_cupcakes, "12", :todo)

  # Weekend Event Orders (Day 6-7)
  order25 = seed_order.(customers.john, 6, :unconfirmed, :pending)
  seed_order_item.(order25, products.carrot_cake, "1", :done)
  seed_order_item.(order25, products.cheese_danish, "12", :in_progress)
  seed_order_item.(order25, products.bread, "5", :in_progress)
  seed_order_item.(order25, products.croissants, "12", :todo)
  seed_order_item.(order25, products.muffins, "24", :todo)

  order26 = seed_order.(customers.jane, 6, :unconfirmed, :pending)
  seed_order_item.(order26, products.carrot_cake, "1", :done)
  seed_order_item.(order26, products.oatmeal_cookies, "20", :in_progress)

  order27 = seed_order.(customers.michael, 7, :unconfirmed, :pending)
  seed_order_item.(order27, products.choc_cake, "2", :done)
  seed_order_item.(order27, products.gf_cupcakes, "15", :in_progress)
  seed_order_item.(order27, products.rye_loaf, "3", :todo)

  # -----------------------------
  # NEXT WEEK (Days 8 to 14)
  # -----------------------------

  # Next Week - Monday (Day 8)
  order28 = seed_order.(customers.alice, 8, :unconfirmed, :pending)
  seed_order_item.(order28, products.bread, "2", :todo)
  seed_order_item.(order28, products.croissants, "6", :todo)

  order29 = seed_order.(customers.bob, 8, :unconfirmed, :pending)
  seed_order_item.(order29, products.choc_cake, "1", :todo)
  seed_order_item.(order29, products.muffins, "6", :todo)

  # Next Week - Tuesday (Day 9)
  order30 = seed_order.(customers.grace, 9, :unconfirmed, :pending)
  seed_order_item.(order30, products.cheese_danish, "10", :todo)
  seed_order_item.(order30, products.rye_loaf, "2", :todo)

  order31 = seed_order.(customers.taylor, 9, :unconfirmed, :pending)
  seed_order_item.(order31, products.bread, "3", :todo)
  seed_order_item.(order31, products.almond_cookies, "15", :todo)
  seed_order_item.(order31, products.croissants, "8", :todo)

  # Office Party Orders (Day 10)
  order32 = seed_order.(customers.emily, 10, :unconfirmed, :pending)
  seed_order_item.(order32, products.oatmeal_cookies, "30", :todo)
  seed_order_item.(order32, products.croissants, "24", :todo)
  seed_order_item.(order32, products.muffins, "18", :todo)

  order33 = seed_order.(customers.john, 10, :unconfirmed, :pending)
  seed_order_item.(order33, products.gf_cupcakes, "12", :todo)
  seed_order_item.(order33, products.cheese_danish, "15", :todo)

  # Next Week - Friday (Day 12)
  order34 = seed_order.(customers.jane, 12, :unconfirmed, :pending)
  seed_order_item.(order34, products.carrot_cake, "1", :todo)
  seed_order_item.(order34, products.bread, "2", :todo)

  order35 = seed_order.(customers.michael, 12, :unconfirmed, :pending)
  seed_order_item.(order35, products.choc_cake, "1", :todo)
  seed_order_item.(order35, products.almond_cookies, "12", :todo)
  seed_order_item.(order35, products.rye_loaf, "1", :todo)

  # Weekend Event (Day 13-14)
  order36 = seed_order.(customers.bob, 13, :unconfirmed, :pending)
  seed_order_item.(order36, products.choc_cake, "2", :todo)
  seed_order_item.(order36, products.carrot_cake, "1", :todo)
  seed_order_item.(order36, products.bread, "4", :todo)
  seed_order_item.(order36, products.muffins, "12", :todo)

  order37 = seed_order.(customers.alice, 14, :unconfirmed, :pending)
  seed_order_item.(order37, products.croissants, "18", :todo)
  seed_order_item.(order37, products.oatmeal_cookies, "24", :todo)

  order38 = seed_order.(customers.grace, 14, :unconfirmed, :pending)
  seed_order_item.(order38, products.gf_cupcakes, "12", :todo)
  seed_order_item.(order38, products.cheese_danish, "10", :todo)

  IO.puts("Done!")
else
  IO.puts("Seeds are only allowed in the dev environment.")
end
