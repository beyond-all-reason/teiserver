defmodule Teiserver.Chat.WordLib do
  @moduledoc false
  alias Central.Config
  alias Central.Helpers.StringHelper

  @flagged_regex ~r/(n[i1]gg[e3]r|cun[t7][s5]?|\b(r[e3])?[t7]ards?\b)/iu

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

  # def plurals(words) when is_list(words), do: Enum.map(words, &plurals/1)
  # def plurals(w) do
  #   [
  #     w,
  #     w <> "s",
  #     w <> "ed"
  #   ]
  # end

  # Curse words in group A are very bad and treated worse, C are casual and scored less harshly
  @curse_words_a ~w(nigger) |> StringHelper.plurals |> List.flatten
  @curse_words_b ~w(cunt retard tards) |> StringHelper.plurals |> List.flatten
  @curse_words_c ~w(shit fuck faggot) |> StringHelper.plurals |> List.flatten

  @spec curse_score(String.t()) :: non_neg_integer()
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

  @spec acceptable_name?(String.t()) :: boolean()
  def acceptable_name?(name) do
    if flagged_words(name) > 0 do
      false
    else
      true
    end
  end
end
