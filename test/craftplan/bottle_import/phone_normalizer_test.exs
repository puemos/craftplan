defmodule Craftplan.BottleImport.PhoneNormalizerTest do
  use ExUnit.Case, async: true

  alias Craftplan.BottleImport.PhoneNormalizer

  describe "normalize/1" do
    test "strips formatting" do
      assert PhoneNormalizer.normalize("(202) 590-8525") == {:ok, "2025908525"}
    end

    test "keeps an 11-digit number intact" do
      assert PhoneNormalizer.normalize("1-202-590-8525") == {:ok, "12025908525"}
    end

    test "rejects fewer than 10 digits" do
      assert PhoneNormalizer.normalize("555-1212") == :error
    end

    test "rejects nil" do
      assert PhoneNormalizer.normalize(nil) == :error
    end

    test "rejects empty" do
      assert PhoneNormalizer.normalize("") == :error
    end

    test "rejects letters-only input" do
      assert PhoneNormalizer.normalize("CALL-NOW") == :error
    end
  end
end
