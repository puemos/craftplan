defmodule Craftplan.Organizations.ProvisioningTest do
  use Craftplan.DataCase, async: true

  alias Craftplan.Organizations.Provisioning

  describe "provision/1" do
    test "creates an organization with derived slug and preference defaults" do
      assert {:ok, organization} =
               Provisioning.provision(%{
                 name: "Sunrise Bakery",
                 timezone: "America/Chicago",
                 locale: "en"
               })

      assert organization.slug == "sunrise-bakery"
      assert organization.preferences["timezone"] == "America/Chicago"
      assert organization.preferences["locale"] == "en"
    end

    test "returns an error when the slug already exists" do
      {:ok, _} = Provisioning.provision(%{name: "Bluebird Cafe", slug: "bluebird"})

      assert {:error, %Ash.Error.Invalid{}} =
               Provisioning.provision(%{name: "Bluebird Cafe", slug: "bluebird"})
    end
  end

  describe "slug derivation" do
    test "raises when the name is blank" do
      assert_raise ArgumentError, fn -> Provisioning.provision(%{name: "   "}) end
    end

    test "converts mixed characters into a slug" do
      assert {:ok, organization} = Provisioning.provision(%{name: "L'éclair & Co."})
      assert organization.slug == "l-eclair-co"
    end
  end
end
