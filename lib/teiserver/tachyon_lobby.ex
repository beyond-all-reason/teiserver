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

  @spec lookup(Lobby.id()) :: pid() | nil
  defdelegate lookup(lobby_id), to: TachyonLobby.Registry

  @type player_join_data :: Lobby.player_join_data()
  @spec join(id(), player_join_data(), pid()) ::
          {:ok, lobby_pid :: pid(), details()} | {:error, reason :: term()}
  defdelegate join(lobby_id, join_data, pid), to: Lobby

  @spec leave(id(), T.userid()) :: :ok | {:error, reason :: term()}
  defdelegate leave(lobby_id, user_id), to: Lobby

  @spec update_mods(id(), T.userid(), [Lobby.mod()]) :: :ok | {:error, reason :: term()}
  defdelegate update_mods(lobby_id, user_id, mods), to: Lobby

  @spec update_sync(id(), T.userid(), map()) :: :ok | {:error, reason :: term()}
  defdelegate update_sync(lobby_id, user_id, sync_status), to: Lobby

  @spec start_battle(id(), T.userid()) :: :ok | {:error, reason :: term()}
  defdelegate start_battle(lobby_id, user_id), to: Lobby
end
