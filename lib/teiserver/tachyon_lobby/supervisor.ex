defmodule Teiserver.TachyonLobby.Supervisor do
  @moduledoc false
  alias Teiserver.TachyonLobby.Lobby
  alias Teiserver.TachyonLobby.Types, as: LT

  use DynamicSupervisor

  @spec start_lobby(LT.Types.id(), LT.StartParams.t()) ::
          {:ok, %{pid: pid(), id: LT.Types.id()}}
          | {:error, {:already_started, pid()} | :max_children | term()}
  def start_lobby(id, %LT.StartParams{} = start_params) do
    case DynamicSupervisor.start_child(__MODULE__, {Lobby, {id, {:user, start_params}}}) do
      {:ok, pid} -> {:ok, %{id: id, pid: pid}}
      {:error, err} -> {:error, err}
      x -> raise "Unsupported return type for child lobby #{inspect(x)}"
    end
  end

  def start_lobby_from_snapshot(lobby_id, serialized_state) do
    DynamicSupervisor.start_child(
      __MODULE__,
      {Lobby, {lobby_id, {:snapshot, serialized_state}}}
    )
  end

  def start_replica(%LT.Data{} = data) do
    # TODO: handle race condition there
    {:ok, _pid} =
      DynamicSupervisor.start_child(
        __MODULE__,
        {Lobby, {data.id, {:replica, data}}}
      )

    :ok
  end

  def start_link(init_arg) do
    DynamicSupervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl DynamicSupervisor
  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end
end
