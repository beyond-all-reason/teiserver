defmodule Teiserver.Account.RecalculateUserHWTask do

  @spec calculate_hw_fingerprint(map()) :: String.t()
  def calculate_hw_fingerprint(data) do
    base = ~w(hardware:cpuinfo hardware:gpuinfo hardware:osinfo hardware:raminfo)
      |> Enum.map(fn hw_key -> Map.get(data, hw_key, "") end)
      |> Enum.join("")

    if base == "" do
      ""
    else
      :crypto.hash(:md5, base)
        |> Base.encode64()
        |> String.trim
    end
  end
end
