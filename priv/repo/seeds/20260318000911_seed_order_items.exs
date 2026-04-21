defmodule Craftplan.Repo.Seeds.SeedOrderItems do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    orders = Craftplan.Orders.list_orders!(authorize?: false)
    products = Craftplan.Catalog.list_products!(authorize?: false)

    Enum.each(1..25, fn _ ->
      status = Enum.random([:todo, :in_progress, :done])
      order = Enum.random(orders)
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
    end)
  end
end
