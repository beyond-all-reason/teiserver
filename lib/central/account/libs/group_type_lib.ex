defmodule Central.Account.GroupTypeLib do
  @moduledoc false
  @spec blank_type() :: map()
  def blank_type() do
    %{name: "No type", fields: []}
  end

  @spec get_all_group_types :: List.t()
  def get_all_group_types do
    Central.store_get(:group_type_store, "-all") || []
  end

  @spec get_group_type(nil | String.t()) :: map()
  def get_group_type(nil), do: blank_type()
  def get_group_type(key) do
    r = Central.store_get(:group_type_store, key)
    if r, do: r, else: blank_type()
  end

  # Expects a name for the group type
  # group_type is a map with the following keys:
  # - fields: A list of maps each with the following keys:
  # ---- Name: The name of the field
  # ---- Opts: Empty string?
  # ---- Type: :boolean | :string | :choice
  # ---- Required: Boolean
  @spec add_group_type(String.t(), map) :: :ok
  def add_group_type(key, group_type) do
    group_type = Map.put(group_type, :name, key)

    Central.store_get_or_store(:group_type_store, key, fn ->
      group_type
    end)

    new_all = [group_type | (get_all_group_types() || [])]
    Central.store_put(:group_type_store, "-all", new_all)
  end
end
