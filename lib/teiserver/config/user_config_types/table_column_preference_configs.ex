defmodule Teiserver.Config.UserConfigTypes.TableColumnPreferenceConfigs do
  @moduledoc """
  A set of user configs used to track the last-used-state of various site components (e.g. search forms)
  """

  import Teiserver.Config, only: [add_user_config_type: 1]

  @spec create() :: :ok
  def create do
    # Staff; text callbacks
    add_preference("col_pref.staff_text_callbacks.response_size", "100")
    add_preference("col_pref.staff_text_callbacks.show_link", "row-click")

    # Moderation; user list
    add_preference("col_pref.mod_users.table_class", "table-zebra")
    add_preference("col_pref.mod_users.email", "partial")
    add_preference("col_pref.mod_users.client?", true)
  end

  defp add_preference(key, default) do
    type =
      if is_boolean(default) do
        "boolean"
      else
        "string"
      end

    add_user_config_type(%{
      key: key,
      type: type,
      default: default,
      visible: false
    })
  end
end
