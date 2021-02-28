defmodule Central.General.QuickAction do
  alias Central.General.QuickAction.Cache
  alias Central.Helpers.StylingHelper

  @doc """
  Each action is a map such as the below:
    %{label: "Preferences", icon: "far fa-cog", url: "/config/user"},

  Optionally you can include a few other options like so:
    %{label: "Preferences", icon: "far fa-cog", url: "/config/user", keywords: ["Settings"], permissions: "user-settings"},

  If you want to make a two part form you can use something like: 
    %{label: "List users", icon: Central.Account.UserLib.icon(), input: "s", method: "get", placeholder: "Search username and/or email", url: "/admin/users", permissions: "admin.admin.limited"},
  """
  def add_items(items) do
    items = Enum.map(items, &convert_item/1)

    Cache.add_items(items)
  end

  def get_items(), do: Cache.get_items()

  defp convert_item(item) do
    icons =
      Enum.map(item.icons, fn i ->
        case i do
          :list -> StylingHelper.icon(:list)
          :new -> StylingHelper.icon(:new)
          :edit -> StylingHelper.icon(:edit)
          :delete -> StylingHelper.icon(:delete)
          :report -> StylingHelper.icon(:report)
          _ -> i
        end
      end)

    Map.merge(item, %{
      icons: icons
    })
  end
end
