defmodule Teiserver.Moderation.LoadBannedDomainsTask do
  @moduledoc """
  Loads the list of banned domains from the database into the cache.
  """
  alias Req.Response
  alias Teiserver.Config
  alias Teiserver.Helpers.CacheHelper
  alias Teiserver.Moderation
  alias Teiserver.Moderation.BannedDomain

  require Logger

  def perform do
    url = Config.get_site_config_cache("teiserver.Email domain blocklist URL")

    external_banned_domains =
      with true <- url != nil and url != "",
           {:ok, %Response{status: 200, body: body}} <- Req.get(url) do
        String.split(body, "\n")
      else
        {:error, error} ->
          Logger.error("Error loading email domain list - #{inspect(error)}")
          []

        _any ->
          []
      end

    internal_banned_domains =
      Moderation.list_banned_domains()
      |> Enum.map(fn %BannedDomain{domain: domain} -> domain end)

    CacheHelper.store_put(
      :application_metadata_cache,
      "banned_domains",
      MapSet.new(external_banned_domains ++ internal_banned_domains)
    )
  end

  def cache_if_ok({:ok, struct}) do
    perform()
    {:ok, struct}
  end

  def cache_if_ok(result), do: result
end
