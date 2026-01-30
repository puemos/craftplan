defmodule Craftplan.Types.EncryptedBinary do
  @moduledoc """
  An Ash type that stores strings encrypted at rest via Cloak.

  Uses `Craftplan.Encrypted.Binary` (a Cloak.Ecto.Binary type) under the hood
  so values are transparently encrypted on write and decrypted on read.
  """
  use Ash.Type

  alias Craftplan.Encrypted.Binary

  @impl true
  def storage_type(_), do: :binary

  @impl true
  def cast_input(nil, _), do: {:ok, nil}
  def cast_input(value, _) when is_binary(value), do: {:ok, value}
  def cast_input(_, _), do: :error

  @impl true
  def cast_stored(nil, _), do: {:ok, nil}

  def cast_stored(value, _) when is_binary(value) do
    Binary.load(value)
  end

  def cast_stored(_, _), do: :error

  @impl true
  def dump_to_native(nil, _), do: {:ok, nil}

  def dump_to_native(value, _) when is_binary(value) do
    Binary.dump(value)
  end

  def dump_to_native(_, _), do: :error
end
