# To install: sudo apt-get install geoip-bin
defmodule Teiserver.Geoip do
  alias Teiserver.Config

  @spec get_flag(String.t()) :: String.t()
  def get_flag(nil), do: "??"
  def get_flag(ip), do: get_flag(ip, nil)

  @spec get_flag(String.t(), String.t() | nil) :: String.t()
  def get_flag("127." <> _, _), do: "??"

  def get_flag(ip, default) do
    if Config.get_site_config_cache("system.Use geoip") do
      {result, 0} = System.cmd("geoiplookup", [ip])

      case Regex.run(~r/: ([A-Z][A-Z]),/, result) do
        [_, code] -> code
        _ -> default || "??"
      end
    else
      default || "??"
    end
  end
end
