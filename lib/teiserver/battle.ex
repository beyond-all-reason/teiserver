defmodule Teiserver.Battle do
  @moduledoc """
  The Battle context.
  """

  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo
  alias Teiserver.{Account, Telemetry, Coordinator}
  alias Teiserver.Lobby
  alias Teiserver.Battle.{MatchMembership, MatchMembershipLib}
  alias Phoenix.PubSub

  alias Teiserver.Battle.Match
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Data.Types, as: T

  alias Teiserver.Protocols.Spring
  require Logger

  @spec match_query(List.t()) :: Ecto.Query.t()
  def match_query(args) do
    match_query(nil, args)
  end

  @spec match_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def match_query(id, args) do
    MatchLib.query_matches()
    |> MatchLib.search(%{id: id})
    |> MatchLib.search(args[:search])
    |> MatchLib.preload(args[:preload])
    |> MatchLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit])
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
    |> Repo.all()
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
    |> Repo.one!()
  end

  def get_match!(args) do
    match_query(nil, args)
    |> Repo.one!()
  end

  def get_match!(id, args) do
    match_query(id, args)
    |> Repo.one!()
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
    |> Repo.one()
  end

  def get_match(nil), do: nil

  def get_match(args) do
    match_query(nil, args)
    |> Repo.one()
  end

  def get_match(id, args) do
    match_query(id, args)
    |> Repo.one()
  end

  def get_next_match(nil), do: nil

  def get_next_match(match_id) when is_integer(match_id) do
    match_id
    |> get_match(select: [:id, :server_uuid])
    |> get_next_match()
  end

  def get_next_match(%{server_uuid: server_uuid, id: match_id}) do
    match_query(nil,
      search: [
        server_uuid: server_uuid,
        id_after: match_id
      ],
      order_by: "Oldest first",
      limit: 1,
      select: [:id]
    )
    |> Repo.one()
  end

  def get_prev_match(nil), do: nil

  def get_prev_match(match_id) when is_integer(match_id) do
    match_id
    |> get_match(select: [:id, :server_uuid])
    |> get_prev_match()
  end

  def get_prev_match(%{server_uuid: server_uuid, id: match_id}) do
    match_query(nil,
      search: [
        server_uuid: server_uuid,
        id_before: match_id
      ],
      order_by: "Newest first",
      limit: 1,
      select: [:id]
    )
    |> Repo.one()
  end

  @doc """
  Creates a match.

  ## Examples

      iex> create_match(%{field: value})
      {:ok, %Match{}}

      iex> create_match(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_match(map()) :: {:ok, Match.t()} | {:error, Ecto.Changeset.t()}
  def create_match(attrs \\ %{}) do
    %Match{}
    |> Match.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Creates a match based on starting a lobby.

  ## Examples

      iex> create_match(%{field: value})
      {:ok, %Match{}}

      iex> create_match(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_match_from_founder_id(T.userid()) ::
          {:ok, Match.t()} | {:error, Ecto.Changeset.t()}
  def create_match_from_founder_id(founder_id) do
    %Match{}
    |> Match.initial_changeset(%{founder_id: founder_id, map: "Not started"})
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
  @spec update_match(Match.t(), map()) :: {:ok, Match.t()} | {:error, Ecto.Changeset.t()}
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

  # Not to be confused with protocol related adding, this
  # tells the battle lobby to proceed as if the user was just accepted into
  # the battle. It should never be called directly from a protocol
  # related command, only via things like matchmaking our tourneys
  # It is currently not actually used so might be ripe for removal
  # @spec add_player_to_battle(T.userid(), T.lobby_id()) :: :ok | {:error, String.t()}
  # def add_player_to_battle(userid, lobby_id) do
  #   case Teiserver.Client.get_client_by_id(userid) do
  #     nil ->
  #       {:error, "no client"}
  #     _ ->
  #       case lobby_exists?(lobby_id) do
  #         false ->
  #           {:error, "no battle"}
  #         true ->
  #           Teiserver.Lobby.accept_join_request(userid, lobby_id)
  #       end
  #   end
  # end

  alias Teiserver.Battle.{MatchMonitorServer, MatchLib}
  alias Teiserver.Lobby.{ChatLib, LobbyLib}

  @spec start_match(nil | T.lobby_id()) :: :ok
  def start_match(nil), do: :ok

  def start_match(lobby_id) do
    empty_match =
      get_lobby_match_id(lobby_id)
      |> get_match!()

    Telemetry.increment(:matches_started)

    LobbyLib.cast_lobby(lobby_id, :start_match)
    current_balance = get_lobby_current_balance(lobby_id)

    case MatchLib.match_from_lobby(lobby_id) do
      {match_params, members} ->
        # We want to ensure any existing memberships for this match are removed
        member_ids = Enum.map(members, fn %{user_id: user_id} -> user_id end)

        # Delete existing memberships for this match
        MatchMembershipLib.get_match_memberships()
        |> MatchMembershipLib.search(
          match_id: empty_match.id,
          user_id_in: member_ids
        )
        |> Repo.delete_all()

        case update_match(empty_match, match_params) do
          {:ok, match} ->
            members
            |> Enum.filter(fn m ->
              m.team_id != nil
            end)
            |> Enum.each(fn m ->
              # In some rare situations it is possible to get into a situation where
              # the membership already exists and this can cause a cascading failure
              existing_membership = get_match_membership(m.user_id, match.id)

              # If balance mode is solo we need to strip party_id from the
              # membership or it will mess with records, if no balance mode
              # listed then it defaults to grouped
              params =
                if current_balance == nil or current_balance.balance_mode == :grouped do
                  Map.merge(m, %{
                    match_id: match.id
                  })
                else
                  Map.merge(m, %{
                    party_id: nil,
                    match_id: match.id
                  })
                end

              Account.update_user_stat(m.user_id, %{"last_match_id" => match.id})

              if existing_membership == nil do
                create_match_membership(params)
              else
                Logger.error("Found existing match membership for a user despite deleting them")
                update_match_membership(existing_membership, params)
              end
            end)

          error ->
            Logger.error("Error inserting match: #{Kernel.inspect(error)}")
            :ok
        end

      nil ->
        # No human players, we're not going to create a match with that!
        :ok
    end

    Coordinator.cast_consul(lobby_id, :match_start)
    :ok
  end

  @spec stop_match(nil | T.lobby_id()) :: :ok
  def stop_match(nil), do: :ok

  def stop_match(lobby_id) do
    founder_id = get_lobby_founder_id(lobby_id)
    uuid = get_lobby_match_uuid(lobby_id)

    match_by_founder = find_open_match_by_founder_id(founder_id)

    if match_by_founder do
      do_stop_match(match_by_founder, lobby_id)
    else
      case list_matches(search: [uuid: uuid]) do
        [match] ->
          do_stop_match(match, lobby_id)

        _ ->
          :ok
      end
    end

    Coordinator.cast_consul(lobby_id, :match_stop)
    :ok
  end

  defp do_stop_match(match, lobby_id) do
    {_uuid, params} = MatchLib.stop_match(lobby_id)
    Telemetry.increment(:matches_stopped)

    LobbyLib.cast_lobby(lobby_id, :stop_match)

    update_match(match, params)

    PubSub.broadcast(
      Teiserver.PubSub,
      "global_match_updates",
      %{
        channel: "global_match_updates",
        event: :match_completed,
        match_id: match.id
      }
    )
  end

  defp find_open_match_by_founder_id(founder_id) do
    started_after = Timex.now() |> Timex.shift(hours: -2)

    matches =
      list_matches(
        search: [
          founder_id: founder_id,
          has_finished: false,
          started_after: started_after
        ],
        limit: 1
      )

    case matches do
      [m] ->
        m

      _ ->
        nil
    end
  end

  @spec generate_lobby_uuid :: String.t()
  @spec generate_lobby_uuid([T.lobby_id()]) :: String.t()
  def generate_lobby_uuid(skip_ids \\ []) do
    uuid = ExULID.ULID.generate()

    # Check if this uuid is present in the current set of lobbies
    existing_uuid =
      list_lobby_ids()
      |> Enum.filter(fn id -> not Enum.member?(skip_ids, id) end)
      |> Enum.map(fn lobby_id -> get_modoptions(lobby_id) end)
      |> Enum.filter(fn modoptions ->
        modoptions != nil and modoptions["server/match/uuid"] == uuid
      end)

    case Enum.empty?(existing_uuid) do
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
            script_tags = data["battleContext"]["scriptTags"]

            # TODO the server/match/id is legacy and should be removed
            # After updating Teiserver, there may be some ongoing matches with the legacy tags
            id = script_tags["game/server_match_id"] || script_tags["server/match/id"]

            case get_match(id) do
              nil ->
                Logger.error("Error finding match id of #{id}")

                {:error, "No match found"}

              match ->
                filtered_data =
                  data
                  |> Map.drop(~w(battleContext bots))

                new_data = Map.put(match.data || %{}, "export_data", filtered_data)
                update_match(match, %{data: new_data})
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

  def list_match_memberships(args) do
    MatchMembershipLib.get_match_memberships()
    |> MatchMembershipLib.search(args[:search])
    |> MatchMembershipLib.preload(args[:joins])
    |> QueryHelpers.query_select(args[:select])
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

  def get_match_membership(user_id, match_id) do
    MatchMembershipLib.get_match_memberships()
    |> MatchMembershipLib.search(user_id: user_id, match_id: match_id)
    |> Repo.one()
  end

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
  @spec lobby_exists?(T.lobby_id()) :: boolean()
  defdelegate lobby_exists?(lobby_id), to: LobbyLib

  # Registry
  @spec list_lobby_ids :: [T.lobby_id()]
  defdelegate list_lobby_ids(), to: LobbyLib

  @spec list_lobbies() :: [T.lobby()]
  defdelegate list_lobbies(), to: LobbyLib

  @spec list_throttled_lobbies(atom) :: [T.lobby()]
  defdelegate list_throttled_lobbies(type), to: LobbyLib

  # Query
  @spec get_lobby(T.lobby_id() | nil) :: T.lobby() | nil
  defdelegate get_lobby(id), to: LobbyLib

  @doc """
  Returns a map with the following keys
    match_uuid, server_uuid, lobby, bots, modoptions, member_list, player_list, queue_id
  """
  @spec get_combined_lobby_state(T.lobby_id()) :: map() | nil
  defdelegate get_combined_lobby_state(id), to: LobbyLib

  @spec get_lobby_founder_id(T.lobby_id()) :: T.userid() | nil
  defdelegate get_lobby_founder_id(id), to: LobbyLib

  @spec get_lobby_match_uuid(T.lobby_id()) :: String.t() | nil
  defdelegate get_lobby_match_uuid(id), to: LobbyLib

  @spec get_lobby_match_id(T.lobby_id()) :: T.match_id() | nil
  defdelegate get_lobby_match_id(lobby_id), to: LobbyLib

  @spec get_match_id_from_userid(T.userid()) :: T.match_id() | nil
  defdelegate get_match_id_from_userid(userid), to: LobbyLib

  @spec get_lobby_server_uuid(T.lobby_id()) :: String.t() | nil
  defdelegate get_lobby_server_uuid(id), to: LobbyLib

  @spec get_lobby_by_match_id(String.t()) :: T.lobby() | nil
  defdelegate get_lobby_by_match_id(uuid), to: LobbyLib

  @spec get_lobby_by_server_uuid(String.t()) :: T.lobby() | nil
  defdelegate get_lobby_by_server_uuid(uuid), to: LobbyLib

  @spec get_lobby_member_list(T.lobby_id()) :: [T.userid()] | nil
  defdelegate get_lobby_member_list(id), to: LobbyLib

  @spec list_lobby_players(T.lobby_id()) :: [T.client()] | nil
  defdelegate list_lobby_players(id), to: LobbyLib

  @spec get_lobby_member_count(T.lobby_id()) :: integer() | :lobby
  defdelegate get_lobby_member_count(lobby_id), to: LobbyLib

  @spec get_lobby_spectator_count(T.lobby_id()) :: integer()
  defdelegate get_lobby_spectator_count(lobby_id), to: LobbyLib

  @spec get_lobby_player_count(T.lobby_id()) :: integer() | :lobby
  defdelegate get_lobby_player_count(lobby_id), to: LobbyLib

  # Update
  @spec update_lobby_values(T.lobby_id(), map()) :: :ok | nil
  defdelegate update_lobby_values(lobby_id, new_values), to: LobbyLib

  @spec update_lobby(T.lobby(), nil | atom, any) :: T.lobby()
  defdelegate update_lobby(lobby, data, reason), to: LobbyLib

  @spec rename_lobby(T.lobby_id(), String.t(), T.userid() | nil) :: :ok | nil
  defdelegate rename_lobby(lobby_id, new_base_name, renamer_id), to: LobbyLib

  # Requests
  @spec can_join?(T.userid(), T.lobby_id(), String.t() | nil) ::
          {:failure, String.t()} | true
  defdelegate can_join?(userid, lobby_id, password \\ nil), to: Lobby

  @spec server_allows_join?(T.userid(), T.lobby_id(), String.t() | nil) ::
          {:failure, String.t()} | true
  defdelegate server_allows_join?(userid, lobby_id, password \\ nil), to: Lobby

  # Chat
  @spec say(T.userid(), String.t(), T.lobby_id()) :: :ok | {:error, any}
  defdelegate say(userid, msg, lobby_id), to: ChatLib

  @spec sayex(T.userid(), String.t(), T.lobby_id()) :: :ok | {:error, any}
  defdelegate sayex(userid, msg, lobby_id), to: ChatLib

  @spec sayprivateex(T.userid(), T.userid(), String.t(), T.lobby_id()) :: :ok | {:error, any}
  defdelegate sayprivateex(from_id, to_id, msg, lobby_id), to: ChatLib

  # Bots
  @spec get_bots(T.lobby_id()) :: map() | nil
  defdelegate get_bots(lobby_id), to: LobbyLib

  @spec add_bot_to_lobby(T.lobby_id(), map()) :: :ok | nil
  defdelegate add_bot_to_lobby(lobby_id, bot), to: LobbyLib

  @spec update_bot(T.lobby_id(), String.t(), map()) :: nil | :ok
  defdelegate update_bot(lobby_id, bot_name, bot), to: LobbyLib

  @spec remove_bot(T.lobby_id(), String.t()) :: :ok | nil
  defdelegate remove_bot(lobby_id, bot_name), to: LobbyLib

  # Disabled units
  @spec enable_all_units(T.lobby_id()) :: :ok | nil
  defdelegate enable_all_units(lobby_id), to: LobbyLib

  @spec enable_units(T.lobby_id(), [String.t()]) :: :ok | nil
  defdelegate enable_units(lobby_id, units), to: LobbyLib

  @spec disable_units(T.lobby_id(), [String.t()]) :: :ok | nil
  defdelegate disable_units(lobby_id, units), to: LobbyLib

  # Modoptions
  @spec get_modoptions(T.lobby_id()) :: map() | nil
  defdelegate get_modoptions(lobby_id), to: LobbyLib

  @spec set_modoption(T.lobby_id(), String.t(), String.t()) :: :ok | nil
  defdelegate set_modoption(lobby_id, key, value), to: LobbyLib

  @spec set_modoptions(T.lobby_id(), map()) :: :ok | nil
  defdelegate set_modoptions(lobby_id, options), to: LobbyLib

  @spec remove_modoptions(T.lobby_id(), [String.t()]) :: :ok | nil
  defdelegate remove_modoptions(lobby_id, keys), to: LobbyLib

  # Actions
  @spec add_user_to_lobby(T.userid(), T.lobby_id(), String.t()) :: :ok
  defdelegate add_user_to_lobby(userid, lobby_id, script_password), to: LobbyLib

  @spec remove_user_from_lobby(T.userid(), T.lobby_id()) :: :ok
  defdelegate remove_user_from_lobby(userid, lobby_id), to: LobbyLib

  @spec force_add_user_to_lobby(T.userid(), T.lobby_id()) :: :ok | nil
  defdelegate force_add_user_to_lobby(userid, lobby_id), to: Lobby

  # Balance
  @spec get_lobby_current_balance(T.lobby_id()) :: map() | nil
  defdelegate get_lobby_current_balance(lobby_id), to: LobbyLib

  @spec get_lobby_balance_mode(T.lobby_id()) :: :solo | :grouped
  defdelegate get_lobby_balance_mode(lobby_id), to: LobbyLib

  defdelegate get_team_config(arg), to: Teiserver.Lobby.LobbyLib
end
