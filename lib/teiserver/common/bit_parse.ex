defmodule Teiserver.BitParse do
  @moduledoc """
  Given an integer represented as a string it will convert it to
  bits on the assumption the length of bits should be bit_length.
  The reason being [0,0,1,0] and [0,0,0,0,1,0] would both be represented
  the same way with an integer
  """
  def parse_bits(string, bit_length) do
    int = String.to_integer(string)

    if int == 0 do
      List.duplicate(0, bit_length)
    else
      min_len = :math.log2(int) |> :math.ceil() |> trunc
      for <<(bit::1 <- <<int::size(max(bit_length, min_len))>>)>>, do: bit
    end
  end
end
