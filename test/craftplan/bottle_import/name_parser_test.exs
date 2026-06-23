defmodule Craftplan.BottleImport.NameParserTest do
  use ExUnit.Case, async: true

  alias Craftplan.BottleImport.NameParser

  describe "parse/1" do
    test "splits a two-token name" do
      assert NameParser.parse("Edward Yardley") ==
               %{first_name: "Edward", last_name: "Yardley", is_mononym: false}
    end

    test "joins tokens 2..N as last name for ≥3 tokens" do
      assert NameParser.parse("Mary Anne Smith") ==
               %{first_name: "Mary", last_name: "Anne Smith", is_mononym: false}
    end

    test "treats single-token name as mononym (first_name = -)" do
      assert NameParser.parse("Spackey") ==
               %{first_name: "-", last_name: "Spackey", is_mononym: true}
    end

    test "trims surrounding whitespace" do
      assert NameParser.parse("  Spackey  ") ==
               %{first_name: "-", last_name: "Spackey", is_mononym: true}
    end

    test "treats nil as mononym placeholder" do
      assert NameParser.parse(nil) ==
               %{first_name: "-", last_name: "-", is_mononym: true}
    end

    test "treats empty string as mononym placeholder" do
      assert NameParser.parse("") ==
               %{first_name: "-", last_name: "-", is_mononym: true}
    end
  end
end
