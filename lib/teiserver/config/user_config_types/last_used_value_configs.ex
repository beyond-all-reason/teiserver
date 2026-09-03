defmodule Teiserver.Config.UserConfigTypes.LastUsedValueConfigs do
  @moduledoc """
  A set of user configs used to track the last-used-state of various site components (e.g. search forms)
  """

  import Teiserver.Config, only: [add_user_config_type: 1]

  @spec create() :: :ok
  def create do
    add_user_config_type(%{
      key: "last_used.anti_abuse_search_page_size",
      type: "integer",
      default: 5,
      visible: false
    })
  end
end
