# To install: sudo apt-get install geoip-bin
defmodule Teiserver.Geoip do
  def get_flag(ip) do
    {result, 0} = System.cmd("geoiplookup", [ip])
    case Regex.run(~r/: ([A-Z][A-Z]),/, result) do
      [_, code] -> code
      _ -> "??"
    end
  end
end
