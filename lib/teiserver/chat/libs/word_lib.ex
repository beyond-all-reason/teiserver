defmodule Teiserver.Chat.WordLib do
  @moduledoc false
  alias Teiserver.Config
  alias Teiserver.Helper.StringHelper
  require Logger

  @flagged_regex ~r/(n[i1l]gg(:?[e3]r|a)|cun[t7][s5]?|\b(r[e3])?[t7]ards?\b|卐)/iu
  @blacklisted_regexs [
    ~r(superinnapropriateword),
    ~r(anotherreallybadword)
  ]

  @doc """
  Given a text message it will look for a set of flagged words.
  The number of flagged words is returned as an integer
  """
  @spec flagged_words(String.t()) :: non_neg_integer()
  def flagged_words(text) when is_list(text), do: flagged_words(text |> Enum.join("\n"))

  def flagged_words(text) do
    Regex.scan(@flagged_regex, text)
    |> Enum.count()
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
  @curse_words_a ~w(nigger 卐) |> StringHelper.plurals() |> List.flatten()
  @curse_words_b ~w(cunt retard tards) |> StringHelper.plurals() |> List.flatten()
  @curse_words_c ~w(shit fuck faggot) |> StringHelper.plurals() |> List.flatten()

  @spec curse_score(String.t()) :: non_neg_integer()
  def curse_score(string) do
    a_score = Config.get_site_config_cache("teiserver.Curse word score A")
    b_score = Config.get_site_config_cache("teiserver.Curse word score B")
    c_score = Config.get_site_config_cache("teiserver.Curse word score C")

    words =
      string
      |> String.downcase()
      |> String.split(" ")

    words
    |> Enum.reduce(0, fn word, score ->
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
      non_barcode = Regex.replace(~r/^[LliI10oO|]+$/, name, "")

      if String.length(non_barcode) < 3 do
        Logger.info("Blocked rename to name `#{name}`")
        false
      else
        true
      end
    end
  end

  @spec reserved_name?(String.t()) :: boolean()
  def reserved_name?(name) do
    name = String.downcase(name)

    cond do
      String.contains?(name, "[lm]") -> true
      String.contains?(name, "[ts]") -> true
      String.contains?(name, "[tei]") -> true
      String.contains?(name, "Host[") -> true
      true -> false
    end
  end

  @spec blacklisted_phrase?(String.t()) :: boolean()
  def blacklisted_phrase?(text) do
    @blacklisted_regexs
    |> Enum.reduce(false, fn
      _, true ->
        true

      r, false ->
        Regex.match?(r, text)
    end)
  end
end
