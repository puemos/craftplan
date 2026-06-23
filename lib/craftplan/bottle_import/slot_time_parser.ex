defmodule Craftplan.BottleImport.SlotTimeParser do
  @moduledoc false

  @zone "America/New_York"
  # Matches the leading "H:MMAM" or "H:MMPM" from strings like "1/13 05:00AM - 1/13 12:00PM"
  @leading_time ~r/^\s*\d{1,2}\/\d{1,2}\s+(\d{1,2}):(\d{2})(AM|PM)\b/i

  @spec parse(Date.t(), String.t() | nil) :: {:ok, DateTime.t()} | {:error, term()}
  def parse(_slot_day, nil), do: {:error, :nil_time_string}

  def parse(%Date{} = slot_day, time_string) when is_binary(time_string) do
    with [_, hh, mm, ampm] <- Regex.run(@leading_time, time_string),
         hour <- to_24h(String.to_integer(hh), String.upcase(ampm)),
         {:ok, naive} <- NaiveDateTime.new(slot_day, Time.new!(hour, String.to_integer(mm), 0)),
         {:ok, dt} <- DateTime.from_naive(naive, @zone) do
      DateTime.shift_zone(dt, "Etc/UTC")
    else
      nil -> {:error, :unrecognized_format}
      {:error, _} = err -> err
      :error -> {:error, :invalid_local_time}
      other -> {:error, {:unexpected, other}}
    end
  end

  defp to_24h(12, "AM"), do: 0
  defp to_24h(12, "PM"), do: 12
  defp to_24h(h, "AM"), do: h
  defp to_24h(h, "PM"), do: h + 12
end
