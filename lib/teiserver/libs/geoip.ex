# To install: sudo apt-get install geoip-bin
defmodule Teiserver.Geoip do
  @moduledoc false
  alias Teiserver.Config

  @spec get_flag(String.t()) :: String.t()
  def get_flag(nil), do: "??"
  def get_flag(ip), do: get_flag(ip, nil)

  @spec get_flag(String.t(), String.t() | nil) :: String.t()
  def get_flag("127." <> _rest, _default), do: "??"
  def get_flag("::ffff:127.0.0.1", _default), do: "??"
  def get_flag("::1", _default), do: "??"

  def get_flag(ip, default) do
    if Config.get_site_config_cache("system.Use geoip") do
      {result, 0} = System.cmd("geoiplookup", [ip], env: %{})

      case Regex.run(~r/: ([A-Z][A-Z]),/, result) do
        [_match, code] -> code
        _other -> default || "??"
      end
    else
      default || "??"
    end
  rescue
    _e in ErlangError ->
      "??"
  end
end
