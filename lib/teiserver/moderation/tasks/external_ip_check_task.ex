defmodule Teiserver.Moderation.Tasks.ExternalIPCheckTask do
  @moduledoc """
  Downloads the IP API data
  """
  alias Teiserver.Config
  alias Teiserver.IpCheck
  alias Teiserver.IpCheck.IpInfo

  require Logger

  @spec get_ban_reasons(ip :: String.t()) :: [atom()]
  def get_ban_reasons(ip) do
    if Config.get_site_config_cache("teiserver.External IP check enabled") do
      case IpCheck.query_ip(ip) do
        {:ok, %IpInfo{} = result} ->
          [
            {:is_abuser, :abuser?, "teiserver.external_ip_ban_is_abuser"},
            {:is_bogon, :bogon?, "teiserver.external_ip_ban_is_bogon"},
            {:is_crawler, :crawler?, "teiserver.external_ip_ban_is_crawler"},
            {:is_datacenter, :datacenter?, "teiserver.external_ip_ban_is_datacenter"},
            {:is_proxy, :proxy?, "teiserver.external_ip_ban_is_proxy"},
            {:is_tor, :tor?, "teiserver.external_ip_ban_is_tor"},
            {:is_vpn, :vpn?, "teiserver.external_ip_ban_is_vpn"}
          ]
          |> Enum.map(fn {reason, result_key, reason_enabled_key} ->
            if Config.get_site_config_cache(reason_enabled_key) and Map.get(result, result_key),
              do: reason,
              else: nil
          end)
          |> Enum.reject(&is_nil/1)

        {:error, reason} ->
          Logger.error("Failed to get ban reasons for ip #{ip} - #{inspect(reason)}")
          []
      end
    else
      []
    end
  end
end
