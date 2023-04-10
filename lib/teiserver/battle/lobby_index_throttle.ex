defmodule Teiserver.Battle.LobbyIndexThrottle do
  @moduledoc """

  """
  use GenServer
  alias Phoenix.PubSub
  alias Teiserver.Battle
  require Logger

  @update_interval 1_000

  def handle_call({:get_cache, cache}, _from, state) do
    resp =
      case cache do
        :complete ->
          state.complete_lobby_list

        :public ->
          state.public_lobby_list

        :tournament ->
          state.tournament_lobby_list

        _ ->
          Logger.error("No get_cache handler for #{cache}")
          []
      end

    {:reply, resp, state}
  end

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    state = Map.merge(state, update_lobby_list())
    broadcast(state)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    state = Map.merge(state, update_lobby_list())
    broadcast(state)
    {:noreply, state}
  end

  defp update_lobby_list() do
    complete_list =
      Battle.list_lobbies()
      |> Enum.map(fn lobby ->
        lobby =
          Map.take(
            lobby,
            ~w(id name map_name passworded locked public tournament in_progress member_count player_count)a
          )

        Map.merge(lobby, %{
          member_count: Battle.get_lobby_member_count(lobby.id) || 0,
          player_count: Battle.get_lobby_player_count(lobby.id) || 0
          # uuid: Battle.get_lobby_match_uuid(lobby.id)
        })
      end)
      |> Enum.reject(&(&1 == nil))

    public_list =
      complete_list
      |> Enum.reject(fn lobby ->
        lobby.passworded or
          lobby.locked or
          lobby.tournament
      end)

    tournament_list =
      complete_list
      |> Enum.filter(fn lobby ->
        lobby.tournament
      end)

    %{
      complete_lobby_list: complete_list,
      public_lobby_list: public_list,
      tournament_lobby_list: tournament_list
    }
  end

  defp broadcast(_) do
    :ok =
      PubSub.broadcast(
        Central.PubSub,
        "teiserver_liveview_lobby_index_updates",
        %{
          channel: "teiserver_liveview_lobby_index_updates",
          event: :updated_data
        }
      )
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def init(_opts) do
    send(self(), :startup)
    :timer.send_interval(@update_interval, self(), :tick)

    Horde.Registry.register(
      Teiserver.ThrottleRegistry,
      "LobbyIndexThrottle",
      :index
    )

    {:ok,
     %{
       complete_lobby_list: [],
       public_lobby_list: [],
       tournament_lobby_list: [],
       last_update: System.system_time(:second)
     }}
  end
end
