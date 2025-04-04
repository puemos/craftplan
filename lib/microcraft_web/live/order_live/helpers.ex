defmodule MicrocraftWeb.OrderLive.Helpers do
  @moduledoc false
  def available_status_transitions(current_status) do
    case current_status do
      :pending -> [:confirmed, :cancelled]
      :confirmed -> [:in_production, :cancelled]
      :in_production -> [:ready, :cancelled]
      :ready -> [:completed, :cancelled]
      :completed -> []
      :cancelled -> []
      _ -> []
    end
  end

  def emoji_for_payment(:pending), do: "⌛"
  def emoji_for_payment(:paid), do: "💰"
  def emoji_for_payment(:to_be_refunded), do: "↩️"
  def emoji_for_payment(:refunded), do: "✅"
  def emoji_for_payment(_), do: "❓"
end
