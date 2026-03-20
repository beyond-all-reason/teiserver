defmodule Teiserver.TestBitParse do
  alias Teiserver.BitParse
  use ExUnit.Case, async: true

  test "bit_parse" do
    values = [
      {"0", 1, [0]},
      {"0", 4, [0, 0, 0, 0]},
      {"1", 4, [0, 0, 0, 1]},
      {"12", 4, [1, 1, 0, 0]},
      {"12", 5, [0, 1, 1, 0, 0]},
      {"12", 3, [1, 1, 0, 0]}
    ]

    for {string, length, expected} <- values do
      result = BitParse.parse_bits(string, length)

      assert expected == result,
        message:
          "Input of #{string}, expected #{Kernel.inspect(expected)}, got: #{Kernel.inspect(result)}"
    end
  end
end
