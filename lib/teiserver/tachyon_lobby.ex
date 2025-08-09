defmodule Teiserver.TachyonLobby do
  @moduledoc """
  Everything related to lobbies using tachyon
  """

  alias Teiserver.TachyonLobby
  alias Teiserver.TachyonLobby.Lobby

  @type id() :: Lobby.id()

  @spec create() ::
          {:ok, %{pid: pid(), id: id()}}
          | {:error, {:already_started, pid()} | :max_children | term()}
  defdelegate create(), to: TachyonLobby.Supervisor, as: :start_lobby

end
