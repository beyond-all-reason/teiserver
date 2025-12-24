defmodule Teiserver.Tachyon.Config do
  alias Teiserver.Config

  @restore_state_key "tachyon.should-restore-state"

  def setup_site_configs() do
    Config.add_site_config_type(%{
      key: @restore_state_key,
      section: "Tachyon",
      type: "boolean",
      permissions: ["Admin"],
      description: "Should the server store and restore state accross restarts?",
      default: false
    })

    :ok
  end

  def enable_state_restoration(), do: Config.update_site_config(@restore_state_key, true)

  def disable_state_restoration(), do: Config.update_site_config(@restore_state_key, false)

  def should_restore_state?(), do: Config.get_site_config_cache(@restore_state_key)
end
