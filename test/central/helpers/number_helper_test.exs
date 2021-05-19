defmodule Central.General.NumberHelperTest do
  use Central.DataCase, async: true

  alias Central.Helpers.NumberHelper

  test "int_parse" do
    params = [
      {"", 0},
      {nil, 0},
      {1, 1},
      {1.4, 1},
      {[1, 2, 3], [1, 2, 3]},
      {"10", 10},
      {"102 ", 102}
    ]

    for {input, expected} <- params do
      result = NumberHelper.int_parse(input)
      assert result == expected
    end

    assert_raise ArgumentError, fn ->
      NumberHelper.int_parse("10.2")
    end
  end

  test "float_parse" do
    params = [
      {"", 0},
      {nil, 0},
      {1, 1.0},
      {1.4, 1.4},
      {[1.1, 2.2, 3], [1.1, 2.2, 3.0]},
      {"10", 10.0},
      {"11.2 ", 11.2}
    ]

    for {input, expected} <- params do
      result = NumberHelper.float_parse(input)
      assert result == expected
    end
  end

  # test "dec_parse" do
  #   params = [
  #     {"", Decimal.new(0)},
  #     {"ABC", Decimal.new(0)},
  #     {nil, Decimal.new(0)},
  #     {"10", Decimal.new(10)},
  #     {"11", Decimal.new(11)},
  #     {"10.23", Decimal.new(10.23)},
  #     {"10.11 ", Decimal.new(10.11)},
  #     {"10.00 ", Decimal.new(10)}
  #   ]

  #   for {input, expected} <- params do
  #     result = NumberHelper.dec_parse(input)
  #     assert result == expected
  #   end
  # end
end
