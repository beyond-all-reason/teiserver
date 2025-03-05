defmodule Teiserver.Helper.StringHelper do
  @moduledoc false

  @spec remove_spaces(String.t()) :: String.t()
  def remove_spaces(the_string) do
    the_string
    |> String.replace(" ", "_")
  end

  @spec safe_name(String.t() | nil) :: String.t()
  def safe_name(nil), do: ""

  def safe_name(name) do
    name
    |> String.replace(" ", "")
    |> String.replace("\n", "")
    |> String.replace("\t", "")
    |> String.replace(".", "")
    |> String.replace("'", "")
    |> String.downcase()
  end

  @spec html_safe(String.t()) :: String.t()
  def html_safe(s) do
    s
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\n", "<br />")
  end

  # def capitalize(the_string) do
  #   String.capitalize(the_string)
  #   |> String.replace("_", " ")
  # end

  def format_number(nil), do: nil
  def format_number(%Decimal{} = v), do: v |> Decimal.to_string() |> format_number
  def format_number(v) when v < 1000, do: v

  def format_number(v) when is_integer(v) do
    v
    |> Integer.to_string()
    |> format_number
  end

  def format_number(v) when is_float(v) do
    v
    |> Float.to_string()
    |> format_number
  end

  def format_number(v) do
    v
    |> String.replace(~r/[0-9](?=(?:[0-9]{3})+(?![0-9]))/, "\\0,")
  end

  def pluralise(nil), do: nil

  def pluralise(s) do
    last_1digit = String.slice(s, -1, 1)
    last_2digits = String.slice(s, -2, 2)

    cond do
      last_2digits == "ey" -> "#{s}s"
      last_1digit == "s" -> s
      last_1digit == "y" -> "#{String.slice(s, 0..-2//-1)}ies"
      true -> "#{s}s"
    end
  end

  def possessive(nil), do: nil

  def possessive(s) do
    last_1digit = String.slice(s, -1, 1)

    cond do
      last_1digit == "s" -> "#{s}'"
      true -> "#{s}'s"
    end
  end

  def singular(nil), do: nil

  def singular(s) do
    first_digit = String.slice(s, 0, 1)

    if Enum.member?(~w(a e i o u), String.downcase(first_digit)) do
      "an #{s}"
    else
      "a #{s}"
    end
  end

  def get_hash_id(nil), do: nil

  def get_hash_id(str) do
    result =
      ~r/#([0-9]+) ?/
      |> Regex.run(str)

    if result == nil do
      nil
    else
      result
      |> Enum.fetch!(1)
      |> String.to_integer()
    end
  end

  @spec multisplit(String.t(), integer, [String.t()]) :: [String.t()]
  def multisplit(string, length, existing \\ []) do
    {p1, p2} = String.split_at(string, length)

    if String.length(p2) > length do
      multisplit(p2, length, existing ++ [p1])
    else
      (existing ++ [p1, p2])
      |> Enum.filter(fn s -> s != "" end)
    end
  end

  def plurals(words) when is_list(words), do: Enum.map(words, &plurals/1)

  def plurals(w) do
    [
      w,
      w <> "s",
      w <> "ed",
      w <> "er",
      w <> "ers"
    ]
  end

  def breakup_long_words(s), do: breakup_long_words(s, 100)

  @spec breakup_long_words(nil | String.t(), non_neg_integer()) :: nil | String.t()
  def breakup_long_words(nil, _), do: nil

  def breakup_long_words(string, max_length) do
    string
    |> String.split(" ")
    |> Enum.map_join(" ", fn word ->
      String.slice(word, 0..max_length)
    end)
  end

  def convert_textarea_to_array(str) do
    str
    |> String.split("\n")
    |> Enum.map(&String.trim/1)
  end
end
