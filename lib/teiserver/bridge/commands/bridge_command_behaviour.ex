defmodule Teiserver.Bridge.BridgeCommandBehaviour do
  @moduledoc """
  Discord commands used by the bot
  """

  @doc """

  """
  @callback name() :: String.t()

  @doc """

  """
  @callback cmd_definition() :: map()

  @doc """

  """
  @callback execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map) :: map()
end
