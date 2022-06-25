defmodule Teiserver.Battle do
  @moduledoc """
  The Battle context.
  """

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo
  alias Teiserver.{Telemetry, Coordinator}
  alias Teiserver.Battle.Lobby
  alias Phoenix.PubSub

  alias Teiserver.Battle.Match
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Data.Types, as: T

  alias Teiserver.Protocols.Spring

  @spec match_query(List.t()) :: Ecto.Query.t()
  def match_query(args) do
    match_query(nil, args)
  end

  @spec match_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def match_query(id, args) do
    MatchLib.query_matches
      |> MatchLib.search(%{id: id})
      |> MatchLib.search(args[:search])
      |> MatchLib.preload(args[:preload])
      |> MatchLib.order_by(args[:order_by])
      |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of matches.

  ## Examples

      iex> list_matches()
      [%Match{}, ...]

  """
  @spec list_matches(List.t()) :: List.t()
  def list_matches(args \\ []) do
    match_query(args)
      |> QueryHelpers.limit_query(args[:limit] || 50)
      |> Repo.all
  end

  @doc """
  Gets a single match.

  Raises `Ecto.NoResultsError` if the Match does not exist.

  ## Examples

      iex> get_match!(123)
      %Match{}

      iex> get_match!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_match!(Integer.t() | List.t()) :: Match.t()
  @spec get_match!(Integer.t(), List.t()) :: Match.t()
  def get_match!(id) when not is_list(id) do
    match_query(id, [])
    |> Repo.one!
  end
  def get_match!(args) do
    match_query(nil, args)
    |> Repo.one!
  end
  def get_match!(id, args) do
    match_query(id, args)
    |> Repo.one!
  end

  @doc """
  Gets a single match.

  Returns `nil` if the Match does not exist.

  ## Examples

      iex> get_match(123)
      %Match{}

      iex> get_match(456)
      nil

  """
  @spec get_match(Integer.t() | List.t()) :: Match.t()
  @spec get_match(Integer.t(), List.t()) :: Match.t()
  def get_match(id) when not is_list(id) do
    match_query(id, [])
    |> Repo.one
  end
  def get_match(args) do
    match_query(nil, args)
    |> Repo.one
  end
  def get_match(id, args) do
    match_query(id, args)
    |> Repo.one
  end

  @doc """
  Creates a match.

  ## Examples

      iex> create_match(%{field: value})
      {:ok, %Match{}}

      iex> create_match(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_match(Map.t()) :: {:ok, Match.t()} | {:error, Ecto.Changeset.t()}
  def create_match(attrs \\ %{}) do
    %Match{}
    |> Match.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a match.

  ## Examples

      iex> update_match(match, %{field: new_value})
      {:ok, %Match{}}

      iex> update_match(match, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_match(Match.t(), Map.t()) :: {:ok, Match.t()} | {:error, Ecto.Changeset.t()}
  def update_match(%Match{} = match, attrs) do
    match
    |> Match.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Match.

  ## Examples

      iex> delete_match(match)
      {:ok, %Match{}}

      iex> delete_match(match)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_match(Match.t()) :: {:ok, Match.t()} | {:error, Ecto.Changeset.t()}
  def delete_match(%Match{} = match) do
    Repo.delete(match)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match changes.

  ## Examples

      iex> change_match(match)
      %Ecto.Changeset{source: %Match{}}

  """
  @spec change_match(Match.t()) :: Ecto.Changeset.t()
  def change_match(%Match{} = match) do
    Match.changeset(match, %{})
  end


  alias Teiserver.Battle.Lobby

  # Not to be confused with protocol related adding, this
  # tells the battle lobby to proceed as if the user was just accepted into
  # the battle. It should never be called directly from a protocol
  # related command, only via things like matchmaking our tourneys
  # Teiserver.Battle.add_player_to_battle(3, 678371)
  @spec add_player_to_battle(T.userid(), T.lobby_id()) :: :ok | {:error, String.t()}
  def add_player_to_battle(userid, lobby_id) do
    case Teiserver.Client.get_client_by_id(userid) do
      nil ->
        {:error, "no client"}
      _ ->
        case Lobby.get_battle(lobby_id) do
          nil ->
            {:error, "no battle"}
          _ ->
            Teiserver.Battle.Lobby.accept_join_request(3, lobby_id)
        end
    end
  end

  alias Teiserver.Battle.{MatchMonitorServer, MatchLib}
  alias Teiserver.Battle.{LobbyChat, LobbyCache}
  require Logger

  @spec start_match(nil | T.lobby_id()) :: :ok
  def start_match(nil), do: :ok
  def start_match(lobby_id) do
    Telemetry.increment(:matches_started)

    LobbyCache.cast_lobby(lobby_id, :start_match)

    {match_params, members} = MatchLib.match_from_lobby(lobby_id)
    case create_match(match_params) do
      {:ok, match} ->
        members
        |> Enum.map(fn m ->
          create_match_membership(Map.merge(m, %{
            match_id: match.id
          }))
        end)
      error ->
        Logger.error("Error inserting match: #{Kernel.inspect error}")
        :ok
    end

    Coordinator.cast_consul(lobby_id, :match_start)
    :ok
  end

  @spec stop_match(nil | T.lobby_id()) :: :ok
  def stop_match(nil), do: :ok
  def stop_match(lobby_id) do
    Telemetry.increment(:matches_stopped)
    {uuid, params} = MatchLib.stop_match(lobby_id)

    LobbyCache.cast_lobby(lobby_id, :stop_match)

    case list_matches(search: [uuid: uuid]) do
      [match] ->
        update_match(match, params)
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_global_match_updates",
          {:global_match_updates, :match_completed, match.id}
        )
      _ ->
        :ok
    end

    Coordinator.cast_consul(lobby_id, :match_stop)
    :ok
  end

  def generate_lobby_uuid() do
    uuid = UUID.uuid1()

    # Check if this uuid is present in the current set of lobbies
    active_lobbies = Lobby.list_lobbies()
    |> Enum.filter(fn lobby -> lobby.tags["server/match/uuid"] == uuid end)

    case Enum.empty?(active_lobbies) do
      false ->
        generate_lobby_uuid()

      true ->
        # Not in an active lobby, lets check the DB
        case list_matches(search: [uuid: uuid]) do
          [] ->
            uuid
          _ ->
            generate_lobby_uuid()
        end
    end
  end

  @spec save_match_stats(String.t()) :: :success | {:error, String.t()}
  def save_match_stats(stats) do
    case Spring.read_compressed_base64(stats) do
      {:error, reason} ->
        Logger.error("save_match_stats error #{reason}")
        {:error, reason}
      {:ok, json_string} ->
        case Jason.decode(json_string) do
          {:ok, data} ->
            # We have to get the UUID from the script tags sent
            # because the bot itself is in a new lobby since the last one finished
            uuid = data["battleContext"]["scriptTags"]["server/match/uuid"]

            case list_matches(search: [uuid: uuid]) do
              [match] ->
                filtered_data = data
                |> Map.drop(~w(battleContext bots))

                new_data = Map.put((match.data || %{}), "export_data", filtered_data)
                update_match(match, %{data: new_data})

                # "Got match export data for #{uuid} of: #{json_string}"
                # |> Central.Helpers.StringHelper.multisplit(800)
                # |> Enum.map(fn part ->
                #   Logger.info("'#{part}'")
                # end)
                :success
              match_list ->
                Logger.error("Error finding match uuid of #{uuid} (got #{Enum.count(match_list)})")
                {:error, "No match found"}
            end
          _ ->
            Logger.error("Error with json decode of save_match_stats")
            {:error, "JSON decode"}
        end
    end
  end

  @spec start_match_monitor() :: :ok | {:failure, String.t()}
  def start_match_monitor() do
    cond do
      MatchMonitorServer.get_match_monitor_userid() != nil ->
        {:failure, "Already started"}

      true ->
        MatchMonitorServer.do_start()
    end
  end

  alias Teiserver.Battle.MatchMembership
  alias Teiserver.Battle.MatchMembershipLib

  def list_match_memberships(args) do
    MatchMembershipLib.get_match_memberships()
      |> MatchMembershipLib.search(args[:search])
      |> MatchMembershipLib.preload(args[:joins])
      |> QueryHelpers.select(args[:select])
      # |> QueryHelpers.limit_query(50)
      |> Repo.all()
  end

  @doc """
  Gets a single match_membership.

  Raises `Ecto.NoResultsError` if the MatchMembership does not exist.

  ## Examples

      iex> get_match_membership!(123)
      %MatchMembership{}

      iex> get_match_membership!(456)
      ** (Ecto.NoResultsError)

  """
  # def get_match_membership!(user_id, match_id) do
  #   MatchMembershipLib.get_match_memberships()
  #   |> MatchMembershipLib.search(user_id: user_id, match_id: match_id)
  #   |> Repo.one!()
  # end

  def create_match_membership(attrs \\ %{}) do
    %MatchMembership{}
    |> MatchMembership.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a match_membership.

  ## Examples

      iex> update_match_membership(match_membership, %{field: new_value})
      {:ok, %MatchMembership{}}

      iex> update_match_membership(match_membership, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_match_membership(%MatchMembership{} = match_membership, attrs) do
    match_membership
    |> MatchMembership.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a MatchMembership.

  ## Examples

      iex> delete_match_membership(match_membership)
      {:ok, %MatchMembership{}}

      iex> delete_match_membership(match_membership)
      {:error, %Ecto.Changeset{}}

  """
  def delete_match_membership(%MatchMembership{} = match_membership) do
    Repo.delete(match_membership)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking match_membership changes.

  ## Examples

      iex> change_match_membership(match_membership)
      %Ecto.Changeset{source: %MatchMembership{}}

  """
  def change_match_membership(%MatchMembership{} = match_membership) do
    MatchMembership.changeset(match_membership, %{})
  end


  # LobbyServer process
  @spec get_lobby_pid(T.lobby_id()) :: pid() | nil
  defdelegate get_lobby_pid(lobby_id), to: LobbyCache

  @spec call_lobby(T.lobby_id(), any) :: any | nil
  defdelegate call_lobby(lobby_id, msg), to: LobbyCache

  @spec cast_lobby(T.lobby_id(), any) :: any | nil
  defdelegate cast_lobby(lobby_id, msg), to: LobbyCache

  @spec lobby_exists?(T.lobby_id()) :: boolean()
  defdelegate lobby_exists?(lobby_id), to: LobbyCache

  # Registry
  @spec list_lobby_ids :: [T.lobby_id()]
  defdelegate list_lobby_ids(), to: LobbyCache

  @spec list_lobbies() :: [T.lobby()]
  defdelegate list_lobbies(), to: LobbyCache

  # Query
  @spec get_lobby(T.lobby_id() | nil) :: T.lobby() | nil
  defdelegate get_lobby(id), to: LobbyCache

  @spec get_lobby_by_uuid(String.t()) :: T.lobby() | nil
  defdelegate get_lobby_by_uuid(uuid), to: LobbyCache

  @spec get_lobby_member_list(T.lobby_id()) :: [T.userid()]
  defdelegate get_lobby_member_list(id), to: LobbyCache

  @spec get_lobby_players(T.lobby_id()) :: [integer()]
  defdelegate get_lobby_players(id), to: LobbyCache

  @spec get_lobby_member_count(T.lobby_id()) :: integer() | :lobby
  defdelegate get_lobby_member_count(lobby_id), to: LobbyCache

  @spec get_lobby_player_count(T.lobby_id()) :: integer() | :lobby
  defdelegate get_lobby_player_count(lobby_id), to: LobbyCache

  # Update
  @spec update_lobby_value(T.lobby_id(), atom, any) :: :ok
  defdelegate update_lobby_value(lobby_id, key, value), to: LobbyCache

  @spec update_lobby(T.lobby(), nil | atom, any) :: T.lobby()
  defdelegate update_lobby(lobby, data, reason), to: LobbyCache

  @spec add_lobby(T.lobby()) :: T.lobby()
  defdelegate add_lobby(lobby), to: LobbyCache

  # Actions
  @spec close_lobby(integer() | nil, atom) :: :ok
  defdelegate close_lobby(lobby_id, reason \\ :closed), to: LobbyCache

  @spec add_user_to_lobby(T.userid(), T.lobby_id(), String.t()) :: :ok
  defdelegate add_user_to_lobby(userid, lobby_id, script_password), to: LobbyCache

  @spec remove_user_from_lobby(T.userid(), T.lobby_id()) :: :ok
  defdelegate remove_user_from_lobby(userid, lobby_id), to: LobbyCache


  # Chat
  @spec say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  defdelegate say(userid, msg, lobby_id), to: LobbyChat

  @spec sayex(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  defdelegate sayex(userid, msg, lobby_id), to: LobbyChat

  @spec sayprivateex(Types.userid(), Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  defdelegate sayprivateex(from_id, to_id, msg, lobby_id), to: LobbyChat

  @spec say_to_all_lobbies(String.t()) :: :ok
  def say_to_all_lobbies(msg) do
    coordinator_id = Coordinator.get_coordinator_userid()

    list_lobby_ids()
      |> Enum.each(fn lobby_id ->
        Lobby.say(coordinator_id, msg, lobby_id)
      end)
  end
end
