defmodule Central.General.QuickAction do
  @moduledoc false
  alias Central.Helpers.StylingHelper

  @doc """
  Each action is a map such as the below:
    %{label: "Preferences", icon: "fa-regular fa-cog", url: "/config/user"},

  Optionally you can include a few other options like so:
    %{label: "Preferences", icon: "fa-regular fa-cog", url: "/config/user", keywords: ["Settings"], permissions: "user-settings"},

  If you want to make a two part form you can use something like:
    %{label: "List users", icon: Central.Account.UserLib.icon(), input: "s", method: "get", placeholder: "Search username and/or email", url: "/admin/users", permissions: "admin.admin.limited"},
  """
  @spec add_items(list()) :: :ok
  def add_items(items) do
    new_items = Enum.map(items, &convert_item/1)

    Central.store_put(:application_metadata_cache, :quick_action_items, get_items() ++ new_items)
  end

  @spec get_items :: list()
  def get_items(), do: Central.store_get(:application_metadata_cache, :quick_action_items) || []

  @icon_atoms ~w(list new edit delete report)a
  defp convert_item(item) do
    icons =
      Enum.map(item.icons, fn i ->
        if Enum.member?(@icon_atoms, i) do
          StylingHelper.icon(:list)
        else
          i
        end
      end)

    Map.merge(item, %{
      icons: icons
    })
  end
end
