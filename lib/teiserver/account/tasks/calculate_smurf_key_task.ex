defmodule Teiserver.Account.CalculateSmurfKeyTask do
  @moduledoc false
  alias Teiserver.Account

  def calculate_string_fingerprint(base) do
    if base == "" do
      ""
    else
      :crypto.hash(:md5, base)
      |> Base.encode64()
      |> String.trim()
    end
  end

  def join_and_hash(data, keys) do
    base =
      keys
      |> Enum.map_join("", fn hw_key -> Map.get(data, hw_key, "") end)

    calculate_string_fingerprint(base)
  end

  def calculate_apply_keys(stats, user) do
    for {keys, index} <-
          Enum.with_index(
            [
              ~w(hardware:cpuinfo hardware:gpuinfo hardware:osinfo hardware:raminfo),
              ~w(hardware:cpuinfo hardware:gpuinfo hardware:osinfo hardware:raminfo hardware:displaymax),
              ~w(hardware:gpuinfo hardware:osinfo hardware:raminfo hardware:displaymax),
              ~w(hardware:cpuinfo hardware:osinfo hardware:gpuinfo hardware:displaymax)
            ],
            1
          ) do
      hwkey = join_and_hash(stats, keys)
      Account.create_smurf_key(user.id, "hw#{index}", hwkey)
    end
  end
end
