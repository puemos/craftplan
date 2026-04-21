defmodule Craftplan.Repo.Seeds.SeedOrder do
  @moduledoc false
  use Craftplan.Seed

  envs([:dev, :prod])

  def up(_repo, _) do
    customers = Craftplan.CRM.list_customers!(authorize?: false)

    Enum.each(1..25, fn _ ->
      customer = Enum.random(customers)
      delivery_in_days = Enum.random(1..25)

      status =
        Enum.random([
          :unconfirmed,
          :confirmed,
          :in_progress,
          :ready,
          :delivered,
          :completed,
          :cancelled
        ])

      payment_status =
        Enum.random([
          :pending,
          :paid,
          :to_be_refunded,
          :refunded
        ])

      Craftplan.Orders.Order
      |> Ash.Changeset.for_create(:create, %{
        customer_id: customer.id,
        delivery_date: DateTime.add(DateTime.utc_now(), delivery_in_days, :day),
        status: status,
        payment_status: payment_status
      })
      |> Ash.create(authorize?: false)
    end)
  end
end
