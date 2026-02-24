defmodule Teiserver.Tachyon.Config do
  alias Teiserver.Config

  @restore_state_key "tachyon.should-restore-state"
  @restore_timeout_key "tachyon.restore-timeout-ms"

  def setup_site_configs() do
    Config.add_site_config_type(%{
      key: @restore_state_key,
      section: "Tachyon",
      type: "boolean",
      permissions: ["Admin"],
      description: "Should the server store and restore state accross restarts?",
      default: false
    })

    Config.add_site_config_type(%{
      key: @restore_timeout_key,
      section: "Tachyon",
      type: "integer",
      permissions: ["Admin"],
      description: "How long a process should wait when restoring snapshot?",
      default: 10_000
    })

    :ok
  end

  def enable_state_restoration(), do: Config.update_site_config(@restore_state_key, true)

  def disable_state_restoration(), do: Config.update_site_config(@restore_state_key, false)

  def should_restore_state?(), do: Config.get_site_config_cache(@restore_state_key)

  @spec get_restoration_timeout() :: non_neg_integer()
  def get_restoration_timeout(), do: Config.get_site_config_cache(@restore_timeout_key)

  @spec set_restoration_timeout(non_neg_integer()) :: :ok
  def set_restoration_timeout(t), do: Config.update_site_config(@restore_timeout_key, t)

  @spec reset_restoration_timeout() :: :ok
  def reset_restoration_timeout(), do: Config.update_site_config(@restore_timeout_key, 10_000)
end
