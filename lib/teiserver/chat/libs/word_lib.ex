defmodule Teiserver.Chat.WordLib do
  @moduledoc false

  @flagged_regex ~r/(n[i1]gg[e3]r|cun[t7][s5]?|\b(r[e3])?[t7]ards?\b)/i

  @doc """
  Given a text message it will look for a set of flagged words.
  The number of flagged words is returned as an integer
  """
  @spec flagged_words(String.t()) :: non_neg_integer()
  def flagged_words(text) when is_list(text), do: flagged_words(text |> Enum.join("\n"))
  def flagged_words(text) do
    Regex.scan(@flagged_regex, text)
    |> Enum.count
  end
end
