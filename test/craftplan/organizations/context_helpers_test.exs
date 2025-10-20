defmodule Craftplan.Organizations.ContextHelpersTest do
  use Craftplan.DataCase, async: true

  alias Ash.Changeset
  alias Ash.Query
  alias Craftplan.Catalog.Product
  alias Craftplan.Organizations
  alias Craftplan.Test.Factory

  describe "put_tenant/2" do
    test "sets tenant on changesets" do
      organization = Factory.create_organization!()

      changeset =
        Changeset.for_create(Product, :create, %{
          name: "Helper Product",
          status: :active,
          price: Decimal.new("5.00"),
          sku: "helper-product"
        })

      assert Organizations.put_tenant(changeset, organization).tenant == organization.id
    end

    test "sets tenant on queries" do
      organization = Factory.create_organization!()

      query = Query.for_read(Product, :list, %{})

      assert Organizations.put_tenant(query, organization.id).tenant == organization.id
    end

    test "sets tenant option on keyword lists" do
      organization = Factory.create_organization!()

      opts = Organizations.put_tenant([actor: %{role: :staff}], organization)

      assert Keyword.get(opts, :tenant) == organization.id
    end
  end

  describe "put_actor/2" do
    test "adds organization to existing actor" do
      organization = Factory.create_organization!()

      actor = %{role: :staff}

      assert Organizations.put_actor(actor, organization) == %{
               role: :staff,
               organization_id: organization.id
             }
    end

    test "builds actor when none provided" do
      organization = Factory.create_organization!()

      assert Organizations.put_actor(nil, organization) == %{organization_id: organization.id}
    end

    test "converts user struct into actor map" do
      organization = Factory.create_organization!()
      user = Craftplan.DataCase.staff_actor()

      actor = Organizations.put_actor(user, organization)

      assert actor.organization_id == organization.id
      assert actor.role == :staff
      assert actor.id == user.id
    end
  end
end
