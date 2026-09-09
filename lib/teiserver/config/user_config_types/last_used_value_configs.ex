defmodule Teiserver.Config.UserConfigTypes.LastUsedValueConfigs do
  @moduledoc """
  A set of user configs used to track the last-used-state of various site components (e.g. search forms)
  """

  import Teiserver.Config, only: [add_user_config_type: 1]

  @spec create() :: :ok
  def create do
    add_last_used("last_used.anti_abuse_search_page_size")
    add_last_used("last_used.banned_phrase_search_page_size")
    add_last_used("last_used.banned_ip_search_page_size")
    add_last_used("last_used.banned_domain_search_page_size")
    add_last_used("last_used.users_search_page_size")
  end

  defp add_last_used(key, default \\ 50) do
    add_user_config_type(%{
      key: key,
      type: "integer",
      default: default,
      visible: false
    })
  end
end
