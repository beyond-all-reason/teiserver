defmodule Teiserver.Moderation.LoadBannedDomainsTask do
  @moduledoc """
  Loads the list of banned domains from the database into the cache.
  """
  alias Teiserver.Helpers.CacheHelper
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedDomain

  def perform do
    banned_domains =
      Moderation.list_banned_domains()
      |> Enum.map(fn %BannedDomain{domain: domain} -> domain end)

    CacheHelper.store_put(
      :application_metadata_cache,
      "banned_domains",
      banned_domains
    )
  end
end
