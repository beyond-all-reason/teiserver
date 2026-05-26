defmodule Teiserver.Moderation.LoadBannedPhrasesTask do
  @moduledoc """
  Loads the list of banned phrases from the database into the cache.
  """
  alias Teiserver.Helpers.CacheHelper
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedPhrase

  def perform do
    banned_phrases =
      Moderation.list_banned_phrases()
      |> Enum.map(&load_phrase/1)

    CacheHelper.store_put(
      :application_metadata_cache,
      "banned_phrases",
      banned_phrases
    )
  end

  defp load_phrase(%BannedPhrase{type: :regex, phrase: phrase} = banned_phrase) do
    compiled_phrase = Regex.compile(phrase)
    %BannedPhrase{banned_phrase | loaded_phrase: compiled_phrase}
  end

  defp load_phrase(%BannedPhrase{phrase: phrase} = banned_phrase) do
    %BannedPhrase{banned_phrase | loaded_phrase: phrase}
  end
end
