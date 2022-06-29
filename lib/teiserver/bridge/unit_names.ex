defmodule Teiserver.Bridge.UnitNames do
  # Key is the old name, value is {new name, unit_code}
  @old_to_new %{
    # Armada T2 bots
    "zipper" => {"sprinter", "armfast"},

    # Cortex T2 bots
    "pyro" => {"fiend", "corpyro"}
  }

  # Key is the new name, value is {old_name, unit_code}
  @new_to_old @old_to_new |> Map.new(fn {k, {v, c}} -> {v, {k, c}} end)

  def get_name(name) do
    case @old_to_new[name] do
      nil ->
        case @new_to_old[name] do
          nil -> nil
          {name, code} -> {:new_to_old, name, code}
        end
      {name, code} -> {:old_to_new, name, code}
    end
  end
end
