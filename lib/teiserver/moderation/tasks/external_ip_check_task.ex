defmodule Teiserver.Moderation.Tasks.ExternalIPCheckTask do
  @moduledoc """
  Downloads the IP API data
  """
  alias Req.Response
  alias Teiserver.Config

  require Logger

  def query_ip(ip) do
    key = Config.get_site_config_cache("teiserver.External IP check key")
    endpoint = Config.get_site_config_cache("teiserver.External IP check endpoint")

    query =
      URI.encode_query(%{
        "q" => ip,
        "key" => key
      })

    url = "#{endpoint}?#{query}"

    case Req.get(url) do
      {:ok, %Response{body: body}} ->
        data = body |> Jason.decode!()

        [
          {:is_abuser, "teiserver.external_ip_ban_is_abuser"},
          {:is_bogon, "teiserver.external_ip_ban_is_bogon"},
          {:is_crawler, "teiserver.external_ip_ban_is_crawler"},
          {:is_datacenter, "teiserver.external_ip_ban_is_datacenter"},
          {:is_proxy, "teiserver.external_ip_ban_is_proxy"},
          {:is_tor, "teiserver.external_ip_ban_is_tor"},
          {:is_vpn, "teiserver.external_ip_ban_is_vpn"}
        ]
        |> Enum.filter(fn {k, v} ->
          Config.get_site_config_cache(v) and data[to_string(k)]
        end)
        |> Enum.map(fn {k, _v} -> k end)

      {:error, error} ->
        Logger.error("Failed to lookup ip #{ip} - #{inspect(error)}")
        []
    end
  end
end
