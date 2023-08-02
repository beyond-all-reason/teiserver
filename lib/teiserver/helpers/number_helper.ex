defmodule Teiserver.Helper.NumberHelper do
  @moduledoc false
  require Decimal

  @spec int_parse(String.t() | nil | number() | List.t()) :: Integer.t() | List.t()
  def int_parse(""), do: 0
  def int_parse(nil), do: 0
  def int_parse(i) when is_number(i), do: round(i)
  def int_parse(l) when is_list(l), do: Enum.map(l, &int_parse/1)
  def int_parse(s), do: String.trim(s) |> String.to_integer()

  @spec float_parse(String.t() | nil | number() | List.t()) :: Float.t() | List.t()
  def float_parse(""), do: 0.0
  def float_parse(nil), do: 0.0
  def float_parse(i) when is_number(i), do: i / 1
  def float_parse(l) when is_list(l), do: Enum.map(l, &float_parse/1)

  def float_parse(s) do
    if String.contains?(s, ".") do
      String.trim(s) |> String.to_float()
    else
      (String.trim(s) |> String.to_integer()) / 1
    end
  end

  def normalize(v) when is_list(v), do: Enum.map(v, &normalize/1)
  def normalize(v) when is_integer(v), do: _normalize(v)
  def normalize(v), do: v

  defp _normalize(v) when v > 1_000_000_000_000_000,
    do: "#{Float.round(v / 1_000_000_000_000_000, 2)}Q"

  defp _normalize(v) when v > 1_000_000_000_000, do: "#{Float.round(v / 1_000_000_000_000, 2)}T"
  defp _normalize(v) when v > 1_000_000_000, do: "#{Float.round(v / 1_000_000_000, 2)}B"
  defp _normalize(v) when v > 1_000_000, do: "#{Float.round(v / 1_000_000, 2)}M"
  defp _normalize(v) when v > 1_000, do: "#{Float.round(v / 1_000, 2)}K"
  defp _normalize(v), do: v

  @doc """
  Allows us to round any number type with just one function call, useful for when we're
  not certain if we will get back a decimal or not
  """
  @spec c_round(nil | number | Decimal.t()) :: integer
  def c_round(nil), do: 0

  def c_round(v) when Decimal.is_decimal(v) do
    v
    |> Decimal.round()
    |> Decimal.to_integer()
  end

  def c_round(v), do: round(v)

  @spec c_round(nil | number | Decimal.t(), non_neg_integer()) :: integer | float()
  def c_round(nil, _), do: 0

  def c_round(v, decimal_places) when Decimal.is_decimal(v) do
    round(Decimal.to_float(v), decimal_places)
  end

  def c_round(v, places), do: round(v, places)

  @spec round(number(), non_neg_integer()) :: integer() | float()
  def round(value, decimal_places) do
    dp_mult = :math.pow(10, decimal_places)
    round(value * dp_mult) / dp_mult
  end

  # def dec_parse(""), do: Decimal.new(0)
  # def dec_parse(nil), do: Decimal.new(0)
  # def dec_parse(d) when is_number(d), do: Decimal.new(d)
  # def dec_parse(s) do
  #   # Special handler we put in to handle some CSV stuff
  #   new_s = s
  #   |> String.replace("+AC0-", "-")
  #   |> String.replace("+AC0+", "")

  #   new_s = ~r/[^0-9\-\.]/
  #   |> Regex.replace(new_s, "")
  #   |> String.replace("..", ".")

  #   try do
  #     if new_s == "" do
  #       Decimal.new(0)
  #     else
  #       Decimal.new(new_s)
  #     end
  #   catch
  #     :error, e ->
  #       raise %Decimal.Error{
  #         message: "Error converting decimal value of '#{new_s}', original string '#{s}'",
  #         reason: e.reason,
  #         result: e.result,
  #         signal: e.signal
  #       }
  #   end
  # end

  # def dec_sum(decimals) do
  #   decimals
  #   |> Enum.reduce(Decimal.new(0), fn (d, acc) ->
  #     Decimal.add(d, acc)
  #   end)
  # end

  # # This is for summing objects with a decimal as a property
  # def dec_sum(objects, key) do
  #   objects
  #   |> Enum.reduce(Decimal.new(0), fn (obj, acc) ->
  #     Decimal.add(Map.get(obj, key), acc)
  #   end)
  # end

  @spec percent(number) :: integer
  def percent(v) do
    round(v * 100)
  end

  @spec percent(number, number) :: number
  def percent(v, dp) do
    round(v * 100, dp)
  end
end
