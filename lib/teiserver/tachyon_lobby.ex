defmodule Teiserver.TachyonLobby do
  @moduledoc """
  Everything related to lobbies using tachyon
  """

  alias Teiserver.Data.Types, as: T
  alias Teiserver.TachyonLobby
  alias Teiserver.TachyonLobby.Lobby
  alias Teiserver.Asset

  @type id :: Lobby.id()
  @type details :: Lobby.details()
  @type overview :: TachyonLobby.List.overview()
  @type team :: Lobby.team()
  @type ally_team_config :: Lobby.ally_team_config()

  @spec list() :: %{Lobby.id() => overview()}
  defdelegate list(), to: TachyonLobby.List

  @spec subscribe_updates() :: {non_neg_integer(), %{Lobby.id() => overview()}}
  defdelegate subscribe_updates(), to: TachyonLobby.List
  defdelegate unsubscribe_updates(), to: TachyonLobby.List

  @type start_params :: Lobby.start_params()
  @spec create(Lobby.start_params()) ::
          {:ok, pid(), details()}
          | {:error, {:already_started, pid()} | :max_children | term()}
  def create(start_params)
      when not is_map_key(start_params, :game_version) or start_params.game_version == nil do
    # This is certainly not what we want to have long term, but for now it makes
    # it easier to change this parameter than having to redeploy
    case Asset.get_default_lobby_game() do
      nil -> {:error, :no_game_version_found}
      game -> Map.put(start_params, :game_version, game.name) |> create()
    end
  end

  def create(start_params)
      when not is_map_key(start_params, :engine_version) or start_params.engine_version == nil do
    # Same as above, it's unlikely we end up with that but it'll do for now
    case Asset.get_default_lobby_engine() do
      nil -> {:error, :no_engine_version_found}
      game -> Map.put(start_params, :engine_version, game.name) |> create()
    end
  end

  def create(start_params) do
    with {:ok, %{pid: pid, id: id}} <- TachyonLobby.Supervisor.start_lobby(start_params),
         {:ok, details} <- Lobby.get_details(id) do
      {:ok, pid, details}
    end
  end

  @spec rejoin(id(), T.userid()) ::
          {:ok, lobby_pid :: pid(), details()} | {:error, :invalid_lobby}
  def rejoin(lobby_id, user_id), do: rejoin(lobby_id, user_id, self())

  @spec rejoin(id(), T.userid(), pid()) ::
          {:ok, lobby_pid :: pid(), details()} | {:error, :invalid_lobby}
  defdelegate rejoin(lobby_id, user_id, pid), to: Lobby

  @type client_status_update_data :: Lobby.client_status_update_data()
  @spec update_client_status(id(), T.userid(), client_status_update_data()) ::
          :ok | {:error, :invalid_lobby | :not_in_lobby}
  defdelegate update_client_status(lobby_id, user_id, update_data), to: Lobby

  def restore_lobbies() do
    Teiserver.Tachyon.System.restore_state("lobby", __MODULE__, :restore_lobby)
  end

  def restore_lobby(id, serialized_state) do
    TachyonLobby.Supervisor.start_lobby_from_snapshot(id, serialized_state)
  end

  @spec lookup(Lobby.id()) :: pid() | nil
  defdelegate lookup(lobby_id), to: TachyonLobby.Registry

  @spec count() :: non_neg_integer()
  defdelegate count(), to: TachyonLobby.Registry

  @type player_join_data :: Lobby.player_join_data()
  @spec join(id(), player_join_data(), pid()) ::
          {:ok, lobby_pid :: pid(), details()} | {:error, reason :: term()}
  defdelegate join(lobby_id, join_data, pid \\ self()), to: Lobby

  @spec spectate(id(), T.userid()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  defdelegate spectate(lobby_id, user_id), to: Lobby

  @type add_bot_opt ::
          {:name, String.t()} | {:version, String.t()} | {:options, %{String.t() => String.t()}}
  @type add_bot_opts :: [add_bot_opt]
  @spec add_bot(
          id(),
          T.userid(),
          ally_team :: non_neg_integer(),
          short_name :: String.t(),
          add_bot_opts()
        ) :: {:ok, bot_id :: String.t()} | {:error, reason :: term()}
  defdelegate add_bot(
                lobby_id,
                user_id,
                ally_team,
                short_name,
                opts \\ []
              ),
              to: Lobby

  @spec remove_bot(id(), bot_id :: String.t()) :: :ok | {:error, :invalid_bot_id | term()}
  defdelegate remove_bot(lobby_id, bot_id), to: Lobby

  @type bot_update_data :: Lobby.bot_update_data()
  @spec update_bot(id(), bot_update_data()) :: :ok | {:error, reason :: :invalid_bot_id | term()}
  defdelegate update_bot(lobby_id, update_data), to: Lobby

  @type lobby_update_data :: Lobby.lobby_update_data()
  @spec update_properties(id(), T.userid(), lobby_update_data()) ::
          :ok | {:error, :invalid_lobby | term()}
  defdelegate update_properties(lobby_id, user_id, update_data), to: Lobby

  @spec join_queue(id(), T.userid()) :: :ok | {:error, :invalid_lobby | :not_in_lobby}
  defdelegate join_queue(lobby_id, user_id), to: Lobby

  @spec leave(id(), T.userid()) :: :ok | {:error, reason :: term()}
  defdelegate leave(lobby_id, user_id), to: Lobby

  @spec join_ally_team(id(), T.userid(), allyTeam :: non_neg_integer()) ::
          {:ok, details()}
          | {:error,
             reason :: :invalid_lobby | :not_in_lobby | :invalid_ally_team | :ally_team_full}
  defdelegate join_ally_team(lobby_id, user_id, ally_team), to: Lobby

  @spec start_battle(id(), T.userid()) ::
          :ok | {:error, reason :: :not_in_lobby | :battle_already_started | term()}
  defdelegate start_battle(lobby_id, user_id), to: Lobby
end
