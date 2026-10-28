defmodule Teiserver.Matchmaking.Config do
  @moduledoc false
  alias Teiserver.Config
  alias Teiserver.Matchmaking.QueueSupervisor

  @enable_test_queues_key "matchmaking.enable-test-queues?"

  def setup_site_configs do
    Config.add_site_config_type(%{
      key: @enable_test_queues_key,
      section: "Matchmaking",
      type: "boolean",
      permissions: ["Admin"],
      description: "Should the test queues be enabled?",
      default: false,
      update_callback: fn _val -> QueueSupervisor.setup_queues!() end
    })
  end

  @spec test_queues_enabled?() :: boolean()
  def test_queues_enabled? do
    Config.get_site_config_val(@enable_test_queues_key)
  end
end
