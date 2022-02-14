defmodule Teiserver.Chat.WordLib do
  @moduledoc false
  alias Central.Config

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

  # Curse words in group A are very bad and treated worse, C are casual and scored less harshly
  @curse_words_a ~w(nigger)
  @curse_words_b ~w(cunt retard tards)
  @curse_words_c ~w(shit fuck faggot)

  def curse_score(string) do
    a_score = Config.get_site_config_cache("teiserver.Curse word score A")
    b_score = Config.get_site_config_cache("teiserver.Curse word score B")
    c_score = Config.get_site_config_cache("teiserver.Curse word score C")

    words = string
      |> String.downcase()
      |> String.split(" ")

    words
    |> Enum.reduce(0, fn (word, score) ->
      cond do
        Enum.member?(@curse_words_a, word) -> score + a_score
        Enum.member?(@curse_words_b, word) -> score + b_score
        Enum.member?(@curse_words_c, word) -> score + c_score
        true -> score
      end
    end)
  end

  def acceptable_name?(name) do
    if flagged_words(name) > 0 do
      false
    else
      true
    end
  end
end
