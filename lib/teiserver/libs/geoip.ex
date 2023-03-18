# To install: sudo apt-get install geoip-bin
defmodule Teiserver.Geoip do
  alias Central.Config

  @spec get_flag(String.t()) :: String.t()
  def get_flag("127." <> _), do: "??"
  def get_flag(ip) do
    if Config.get_site_config_cache("system.Use geoip") do
      {result, 0} = System.cmd("geoiplookup", [ip])

      case Regex.run(~r/: ([A-Z][A-Z]),/, result) do
        [_, code] -> code
        _ -> "??"
      end
    else
      "??"
    end
  end
end
