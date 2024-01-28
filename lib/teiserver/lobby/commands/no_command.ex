defmodule Barserver.Lobby.Commands.NoCommand do
  @behaviour Barserver.Lobby.LobbyCommandBehaviour
  @moduledoc """
  Documentation for explain command here
  """

  alias Barserver.Data.Types, as: T
  # alias Barserver.{Account, Battle, Coordinator}
  # alias Barserver.Lobby.LobbyCommandBehaviour
  # import Barserver.Helper.NumberHelper, only: [round: 2]

  # @splitter "---------------------------"

  @impl true
  @spec name() :: String.t()
  def name(), do: "no-command"

  @impl true
  @spec execute(T.lobby_server_state(), map) :: T.lobby_server_state()
  def execute(state, _cmd) do
    state
  end
end
