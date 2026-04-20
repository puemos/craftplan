defmodule Craftplan.Repo.Seeds.SeedCustomer do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    email =
      Faker.Person.first_name() <>
        "_" <> Faker.Person.last_name() <> "@" <> Faker.Internet.En.free_email_service()

    params =
      for _ <- 1..50 do
        {Faker.Person.first_name(), Faker.Person.last_name(), email, "craftplan",
         %{
           street: Faker.Address.En.street_address(),
           city: Faker.Address.En.city(),
           state: Faker.Address.En.state_abbr(),
           zip: Faker.Address.En.zip_code(),
           country: Faker.Address.En.country()
         }}
      end

    Enum.each(params, fn {first_name, last_name, email, phone, address_map} ->
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
  end
end
