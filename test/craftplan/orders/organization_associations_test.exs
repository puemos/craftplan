defmodule Craftplan.Orders.OrganizationAssociationsTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Catalog.Product
  alias Craftplan.CRM.Customer
  alias Craftplan.Orders.Order
  alias Craftplan.Organizations

  test "orders and order items store organization references" do
    actor = Craftplan.DataCase.staff_actor()
    admin = Craftplan.DataCase.admin_actor()

    organization =
      Organizations.create_organization!(
        %{
          name: "Org Assoc",
          slug: "org-assoc-#{System.unique_integer([:positive])}",
          status: :active
        },
        actor: admin
      )

    {:ok, customer} =
      Customer
      |> Ash.Changeset.for_create(:create, %{
        type: :individual,
        first_name: "Multi",
        last_name: "Tenant",
        email: "multi@example.com",
        phone: "0000000000",
        billing_address: %{street: "1", city: "City", state: "ST", zip: "00000", country: "USA"},
        shipping_address: %{street: "1", city: "City", state: "ST", zip: "00000", country: "USA"}
      })
      |> Ash.Changeset.set_tenant(organization.id)
      |> Ash.create(actor: actor)

    {:ok, product} =
      Product
      |> Ash.Changeset.for_create(:create, %{
        name: "Org Product",
        sku: "ORG-#{System.unique_integer([:positive])}",
        status: :active,
        price: Decimal.new("9.99")
      })
      |> Ash.Changeset.set_tenant(organization.id)
      |> Ash.create(actor: actor)

    {:ok, order} =
      Order
      |> Ash.Changeset.for_create(
        :create,
        %{
          customer_id: customer.id,
          delivery_date: DateTime.utc_now(),
          status: :confirmed,
          payment_status: :pending
        },
        arguments: %{
          items: [
            %{
              product_id: product.id,
              quantity: Decimal.new("2"),
              unit_price: Decimal.new("9.99")
            }
          ]
        }
      )
      |> Ash.Changeset.set_tenant(organization.id)
      |> Ash.create(actor: actor)

    loaded_order = Ash.load!(order, [:items])

    assert loaded_order.organization_id == organization.id
    assert Enum.all?(loaded_order.items, &(&1.organization_id == organization.id))
  end
end
