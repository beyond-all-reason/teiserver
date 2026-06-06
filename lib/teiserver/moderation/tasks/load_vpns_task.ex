defmodule Teiserver.Moderation.Tasks.LoadVpnsTask do
  @moduledoc """
  Loads the list of IPs known to be VPNs into a cache.
  """
  alias IP.Subnet
  alias Req.Response
  alias Teiserver.Config
  alias Teiserver.Helpers.CacheHelper

  require Logger

  @spec perform() :: :ok
  def perform do
    url = Config.get_site_config_cache("teiserver.VPN blocklist URL")

    blocked_vpn_ranges =
      with true <- url != nil and url != "",
           {:ok, %Response{status: 200, body: body}} <- Req.get(url),
           cidr_list <- String.split(body, "\n") do
        cidr_list
        |> Enum.map(&Subnet.from_string/1)
        |> Enum.filter(fn {status, _value} -> status == :ok end)
        |> Enum.map(fn {_status, value} -> value end)
      else
        false ->
          []

        {:error, error} ->
          Logger.error("Error loading VPN list - #{inspect(error)}")
          []

        _any ->
          []
      end

    CacheHelper.store_put(
      :application_metadata_cache,
      "blocked_vpn_ranges",
      blocked_vpn_ranges
    )
  end
end
