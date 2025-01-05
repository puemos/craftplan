# Allergens

try do
  Ash.Seed.seed!(
    Microcraft.Inventory.Allergen,
    [
      %{name: "Gluten"},
      %{name: "Fish"},
      %{name: "Milk"},
      %{name: "Mustard"},
      %{name: "Lupin"},
      %{name: "Crustaceans"},
      %{name: "Peanuts"},
      %{name: "Tree Nuts"},
      %{name: "Sesame"},
      %{name: "Mollusks"},
      %{name: "Eggs"},
      %{name: "Soy"},
      %{name: "Celery"},
      %{name: "Sulphur Dioxide"}
    ],
    identity: :name
  )
rescue
  _ -> :ok
end
