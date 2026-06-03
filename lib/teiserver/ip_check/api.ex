defmodule Teiserver.IpCheck.Api do
  @moduledoc """
  get data about IP address from 3rd party service
  """

  alias Req.Response
  alias Teiserver.Config
  alias Teiserver.IpCheck.IpInfo

  @spec query_ip(ip :: String.t()) :: {:ok, IpInfo.t()} | {:error, term()}
  def query_ip(ip) do
    with {:ok, endpoint} <- get_api_endpoint(),
         {:ok, key} <- get_api_key(),
         {:ok, %Response{body: body}} <- Req.get(endpoint, params: [q: ip, key: key]) do
      %IpInfo{
        abuser?: body["is_abuser"],
        bogon?: body["is_bogon"],
        crawler?: body["is_crawler"],
        datacenter?: body["is_datacenter"],
        proxy?: body["is_proxy"],
        tor?: body["is_tor"],
        vpn?: body["is_vpn"]
      }
    end
  end

  defp get_api_endpoint do
    endpoint = Config.get_site_config_cache("teiserver.External IP check key")

    if endpoint != nil || endpoint != "",
      do: {:ok, endpoint},
      else: {:error, :missing_api_endpoint}
  end

  defp get_api_key do
    key = Config.get_site_config_cache("teiserver.External IP check key")
    if key != nil, do: {:ok, key}, else: {:error, :missing_api_key}
  end
end
