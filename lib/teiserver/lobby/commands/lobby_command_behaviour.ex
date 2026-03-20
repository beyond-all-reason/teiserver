defmodule Teiserver.Lobby.LobbyCommandBehaviour do
  @moduledoc """
  Lobby commands are executed from within lobbies.
  """

  alias Teiserver.Data.Types, as: T

  @doc """

  """
  @callback name() :: String.t()

  @doc """

  """
  @callback execute(state :: T.lobby_server_state(), command :: map) :: T.lobby_server_state()
end
