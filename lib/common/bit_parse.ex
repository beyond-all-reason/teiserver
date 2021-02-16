defmodule Teiserver.BitParse do
  @doc """
  Given an integer represented as a string it will convert it to
  bits on the assumption the length of bits should be bit_length.
  The reason being [0,0,1,0] and [0,0,0,0,1,0] would both be represented
  the same way with an integer
  """
  def parse_bits(string, bit_length) do
    result =
      string
      |> String.to_integer()
      |> Integer.digits(2)

    if bit_length > Enum.count(result) do
      padding =
        List.duplicate([0], bit_length - Enum.count(result))
        |> List.flatten()

      padding ++ result
    else
      result
    end
  end
end
