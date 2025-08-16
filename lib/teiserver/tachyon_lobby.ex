defmodule Teiserver.TachyonLobby do
  @moduledoc """
  Everything related to lobbies using tachyon
  """

  alias Teiserver.TachyonLobby
  alias Teiserver.TachyonLobby.Lobby

  @type id :: Lobby.id()
  @type details :: Lobby.details()

  @spec create(Lobby.start_params()) ::
          {:ok, pid(), details()}
          | {:error, {:already_started, pid()} | :max_children | term()}
  def create(start_params) do
    with {:ok, %{pid: pid, id: id}} <- TachyonLobby.Supervisor.start_lobby(start_params),
         {:ok, details} <- Lobby.get_details(id) do
      {:ok, pid, details}
    end
  end

  @spec lookup(Lobby.id()) :: pid() | nil
  defdelegate lookup(lobby_id), to: TachyonLobby.Registry
end
