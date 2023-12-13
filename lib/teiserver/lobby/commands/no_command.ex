defmodule Teiserver.Lobby.Commands.NoCommand do
  @behaviour Teiserver.Lobby.LobbyCommandBehaviour
  @moduledoc """
  Documentation for explain command here
  """

  alias Teiserver.Data.Types, as: T
  # alias Teiserver.{Account, Battle, Coordinator}
  # alias Teiserver.Lobby.LobbyCommandBehaviour
  # import Teiserver.Helper.NumberHelper, only: [round: 2]

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
