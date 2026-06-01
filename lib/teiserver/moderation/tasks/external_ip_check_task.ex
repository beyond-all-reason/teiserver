defmodule Teiserver.Moderation.Tasks.ExternalIPCheckTask do
  @moduledoc """
  Downloads the IP API data.

  Data is expected to arrive in JSON format with keys in the body
  for things like "is_proxy". Any missing will just be ignored.

  If the check is not enabled/configured you will receive a list with
  one atom saying why the check did not take place. This is intended
  to help with debugging on a production system if the checks
  are not coming back with valid data.
  """
  alias Req.Response
  alias Teiserver.Config
  alias Teiserver.Plugins

  use Plugins

  require Logger

  @spec query_ip(String.t()) :: [atom()]
  def query_ip(ip) do
    enabled? = Config.get_site_config_cache("teiserver.External IP check enabled")

    if enabled? do
      do_query(ip)
    else
      [:not_enabled]
    end
  end

  defp do_query(ip) do
    key = Config.get_site_config_cache("teiserver.External IP check key")
    endpoint = Config.get_site_config_cache("teiserver.External IP check endpoint")

    if key != "" and endpoint != "" do
      case Req.get(endpoint, params: [q: ip, key: key]) do
        {:ok, %Response{body: body}} ->
          parse_body(body)

        {:error, error} ->
          Logger.error("Failed to lookup ip #{ip} - #{inspect(error)}")
          []
      end
    else
      [:not_configured]
    end
  end

  @decorate Plugins.plugin(:parse_external_ip_response)
  @spec parse_body(%{String.t() => any()}) :: [atom()]
  def parse_body(body) do
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
      Config.get_site_config_cache(v) and body[to_string(k)] == true
    end)
    |> Enum.map(fn {k, _v} -> k end)
  end
end
