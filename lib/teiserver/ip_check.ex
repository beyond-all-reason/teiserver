defmodule Teiserver.IpCheck do
  @moduledoc """
  When you need to get some properties about a given IP
  """
  alias Teiserver.IpCheck.IpInfo

  @spec query_ip(ip :: String.t()) :: {:ok, IpInfo.t()} | {:error, term()}
  def query_ip(ip) do
    module = Application.get_env(:teiserver, Teiserver.IpCheck)[:client_module]
    apply(module, :query_ip, [ip])
  end
end
