defmodule Teiserver.LobbyIdServer do
  @moduledoc """
  Allocates legacy lobby IDs in the range Chobby can represent exactly.
  """
  alias Teiserver.Lobby.LobbyLib

  use GenServer

  # Chobby uses single-precision floats for battle IDs.
  @max_id 16_777_216
  @restart_gap 1_000

  @spec get_next_id() :: pos_integer() | {:error, :no_pid}
  def get_next_id do
    GenServer.call(__MODULE__, :next_id)
  catch
    :exit, {reason, {GenServer, :call, _args}}
    when reason in [:noproc, :normal, :shutdown, :killed] ->
      {:error, :no_pid}
  end

  @spec start_link(list()) :: GenServer.on_start()
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl GenServer
  def init(_opts) do
    case LobbyLib.list_lobby_ids() do
      [] -> {:ok, 1}
      ids -> {:ok, wrap(Enum.max(ids) + @restart_gap)}
    end
  end

  @impl GenServer
  def handle_call(:next_id, _from, next_id) do
    id = find_free_id(next_id)
    {:reply, id, wrap(id + 1)}
  end

  defp find_free_id(id) do
    if LobbyLib.lobby_exists?(id), do: find_free_id(wrap(id + 1)), else: id
  end

  defp wrap(id), do: Integer.mod(id - 1, @max_id) + 1
end
