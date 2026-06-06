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
      |> BannedPhraseQueries.order_by_severity(:desc)
      |> Repo.all()
      |> Enum.map(&BannedPhrase.load_phrase/1)

    CacheHelper.store_put(
      :application_metadata_cache,
      "banned_phrases",
      banned_phrases
    )
  end

  def cache_if_ok({:ok, struct}) do
    perform()
    {:ok, struct}
  end

  def cache_if_ok(result), do: result
end
