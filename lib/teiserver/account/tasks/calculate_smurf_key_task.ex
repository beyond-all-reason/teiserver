defmodule Teiserver.Account.CalculateSmurfKeyTask do
  @moduledoc false

  @spec calculate_hw1_fingerprint(map()) :: String.t()
  def calculate_hw1_fingerprint(data) do
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

  @spec calculate_hw2_fingerprint(map()) :: String.t()
  def calculate_hw2_fingerprint(data) do
    base = ~w(hardware:cpuinfo hardware:gpuinfo hardware:osinfo hardware:raminfo hardware:displaymax)
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
