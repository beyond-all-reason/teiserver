defmodule Teiserver.Moderation.LoadBannedPhrasesTask do
  @moduledoc """
  Loads the list of banned phrases from the database into the cache.
  """
  alias Teiserver.Helpers.CacheHelper
  alias Teiserver.Moderation.BannedPhrase
  alias Teiserver.Moderation.BannedPhraseQueries
  alias Teiserver.Repo

  def perform do
    banned_phrases =
      BannedPhraseQueries.banned_phrases()
      |> Repo.all()
      |> Enum.map(&BannedPhrase.load_phrase/1)

    # Cache a per-use_case list
    BannedPhrase.use_cases()
    |> Enum.each(fn use_case ->
      filtered_phrases =
        banned_phrases
        |> Enum.filter(fn %BannedPhrase{} = phrase ->
          Enum.member?(phrase.use_cases, use_case)
        end)

      CacheHelper.store_put(
        :application_metadata_cache,
        "banned_phrases/#{use_case}",
        filtered_phrases
      )
    end)

    # And finally a list of all of them
    CacheHelper.store_put(
      :application_metadata_cache,
      "banned_phrases/all",
      banned_phrases
    )
  end

  def cache_if_ok({:ok, struct}) do
    perform()
    {:ok, struct}
  end

  def cache_if_ok(result), do: result
end
