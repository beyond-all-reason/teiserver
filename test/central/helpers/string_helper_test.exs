defmodule Central.General.StringHelpersTest do
  use Central.DataCase, async: true

  alias Central.Helpers.StringHelper

  test "remove_spaces" do
    params = [
      {"abc", "abc"},
      {"a bc", "a_bc"}
    ]

    for {input, expected} <- params do
      result = StringHelper.remove_spaces(input)
      assert result == expected
    end
  end

  test "safe_name" do
    params = [
      {"abc", "abc"},
      {"a bc", "abc"},
      {"a\nbc", "abc"},
      {"a\tbc", "abc"},
      {"a.b\nc", "abc"},
      {"a.B\nc", "abc"}
    ]

    for {input, expected} <- params do
      result = StringHelper.safe_name(input)
      assert result == expected
    end
  end

  test "format_number" do
    params = [
      {nil, nil},
      {Decimal.new(100), "100"},
      {100, 100},
      {100.50, 100.5},
      {10_000.50, "10,000.5"},
      {100_000, "100,000"},
      {100_000_000_000_000, "100,000,000,000,000"}
    ]

    for {input, expected} <- params do
      result = StringHelper.format_number(input)
      assert result == expected
    end
  end

  test "pluralise" do
    pairs = [
      {nil, nil},
      {"policy", "policies"},
      {"journey", "journeys"},
      {"ship", "ships"}
    ]

    for {singular, expected} <- pairs do
      result = StringHelper.pluralise(singular)

      assert result == expected,
        message: "Input: #{singular}, Got: #{result}, Expected: #{expected}"
    end
  end

  test "singular" do
    pairs = [
      {nil, nil},
      {"colony", "a colony"},
      {"star ship", "a star ship"},
      {"eye", "an eye"}
    ]

    for {singular, expected} <- pairs do
      result = StringHelper.singular(singular)

      assert result == expected,
        message: "Input: #{singular}, Got: #{result}, Expected: #{expected}"
    end
  end

  test "get_hash_id" do
    pairs = [
      {nil, nil},
      {"100", nil},
      {"#100", 100},
      {"#100 name email", 100}
    ]

    for [name, expected] <- pairs do
      result = StringHelper.get_hash_id(name)

      assert result == expected, message: "Input: #{name}, Got: #{result}, Expected: #{expected}"
    end
  end
end
