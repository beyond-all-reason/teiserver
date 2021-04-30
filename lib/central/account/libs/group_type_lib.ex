defmodule Central.Account.GroupTypeLib do
  # def colours(), do: {"#908", "#FEF", "primary2"}
  # def icon(), do: "fab fa-connectdevelop"

  def blank_type() do
    %{name: "No type", fields: []}
  end

  @spec get_all_group_types :: List.t()
  def get_all_group_types do
    ConCache.get(:group_type_cache, "-all") || []
  end

  def get_group_type(nil), do: blank_type()

  def get_group_type(key) do
    r = ConCache.get(:group_type_cache, key)
    if r, do: r, else: blank_type()
  end

  # Expects a name for the group type
  # group_type is a map with the following keys:
  # - fields: A list of maps each with the following keys:
  # ---- Name: The name of the field
  # ---- Opts: Empty string?
  # ---- Type: :boolean | :string | :choice
  # ---- Required: Boolean
  def add_group_type(key, group_type) do
    group_type = Map.put(group_type, :name, key)

    ConCache.get_or_store(:group_type_cache, key, fn ->
      group_type
    end)

    new_all = (get_all_group_types() || []) ++ [group_type]
    ConCache.put(:group_type_cache, "-all", new_all)
  end
end
