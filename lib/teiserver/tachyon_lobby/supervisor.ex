defmodule Teiserver.TachyonLobby.Supervisor do
  alias Horde.DynamicSupervisor, as: HordeSupervisor
  alias Teiserver.TachyonLobby.Lobby

  use Horde.DynamicSupervisor

  @spec start_lobby(Lobby.start_params()) ::
          {:ok, %{pid: pid(), id: Lobby.id()}}
          | {:error, {:already_started, pid()} | :max_children | term()}
  def start_lobby(start_params) do
    id = Lobby.gen_id()

    case HordeSupervisor.start_child(__MODULE__, {Lobby, {id, {:user, start_params}}}) do
      {:ok, pid} -> {:ok, %{id: id, pid: pid}}
      {:error, err} -> {:error, err}
      x -> raise "Unsupported return type for child lobby #{inspect(x)}"
    end
  end

  def start_lobby_from_snapshot(lobby_id, serialized_state) do
    HordeSupervisor.start_child(
      __MODULE__,
      {Lobby, {lobby_id, {:snapshot, serialized_state}}}
    )
  end

  def start_link(init_arg) do
    HordeSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl HordeSupervisor
  def init(_) do
    HordeSupervisor.init(strategy: :one_for_one, members: :auto)
  end
end
