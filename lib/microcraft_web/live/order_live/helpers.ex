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
end
