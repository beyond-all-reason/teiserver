defmodule Teiserver.Chat.WordLib do
  @moduledoc false
  alias Teiserver.Helper.StringHelper
  alias Teiserver.Moderation.BannedPhrase
  alias Teiserver.Plugins

  use Plugins

  require Logger

  @flagged_regex ~r/(n[i1l]gg(:?[e3]r|a)|cun[t7][s5]?|\b(r[e3])?[t7]ards?\b|卐)/iu

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

  @spec acceptable_name?(String.t()) :: boolean()
  @decorate Plugins.plugin(:acceptable_name?)
  def acceptable_name?(name) do
    converted_name = StringHelper.leet_replace(name)

    if BannedPhrase.message_is_banned?(converted_name, "username") do
      false
    else
      # Not a banned phrase but we don't allow barcodes due to the
      # reliance on usernames at this stage
      non_barcode = Regex.replace(~r/^[LliI10oO|]+$/, name, "")

      if String.length(non_barcode) < 3 do
        Logger.info("Blocked rename to name `#{name}`")
        false
      else
        true
      end
    end
  end

  @spec blacklisted_phrase?(String.t()) :: boolean()
  @decorate Plugins.plugin(:blacklisted_phrase?)
  def blacklisted_phrase?(text) do
    text = StringHelper.leet_replace(text)

    # TODO: Break this out into different use cases
    BannedPhrase.message_is_banned?(text, nil)
  end
end
