defmodule Craftplan.VaultTest do
  use ExUnit.Case, async: true

  alias Craftplan.Vault

  test "encrypted fields use authenticated AES-GCM and reject altered ciphertext" do
    ciphers = Application.fetch_env!(:craftplan, Vault)[:ciphers]
    assert ciphers != []
    assert Enum.all?(ciphers, fn {_label, {cipher, _opts}} -> cipher == Cloak.Ciphers.AES.GCM end)

    assert {:ok, ciphertext} = Vault.encrypt("smtp-password")
    assert {:ok, "smtp-password"} = Vault.decrypt(ciphertext)

    prefix_size = byte_size(ciphertext) - 1
    <<prefix::binary-size(^prefix_size), last_byte>> = ciphertext
    altered = <<prefix::binary, Bitwise.bxor(last_byte, 1)>>

    refute match?({:ok, plaintext} when is_binary(plaintext), Vault.decrypt(altered))
  end
end
