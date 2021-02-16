defmodule Teiserver.NumberHelper do
  def int_parse(""), do: 0
  def int_parse(nil), do: 0
  def int_parse(i) when is_number(i), do: round(i)
  def int_parse(l) when is_list(l), do: Enum.map(l, &int_parse/1)
  def int_parse(s), do: String.trim(s) |> String.to_integer()

  # def float_parse(""), do: 0.0
  # def float_parse(nil), do: 0.0
  # def float_parse(i) when is_number(i), do: i/1
  # def float_parse(l) when is_list(l), do: Enum.map(l, &float_parse/1)
  # def float_parse(s) do
  #   if String.contains?(s, ".") do
  #     String.trim(s) |> String.to_float
  #   else
  #     (String.trim(s) |> String.to_integer)/1
  #   end
  # end
end
