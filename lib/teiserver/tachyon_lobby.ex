defmodule Teiserver.TachyonLobby do
  @moduledoc """
  Everything related to lobbies using tachyon
  """

  alias Teiserver.TachyonLobby
  alias Teiserver.TachyonLobby.Lobby

  @type id() :: Lobby.id()

  @spec create(Lobby.start_params()) ::
          {:ok, %{pid: pid(), id: id()}}
          | {:error, {:already_started, pid()} | :max_children | term()}
  defdelegate create(start_params), to: TachyonLobby.Supervisor, as: :start_lobby

  @spec lookup(Lobby.id()) :: pid() | nil
  defdelegate lookup(lobby_id), to: TachyonLobby.Registry
end
