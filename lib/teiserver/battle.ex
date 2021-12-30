defmodule Teiserver.Battle do
  @moduledoc """
  The Battle context.
  """

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo
  alias Teiserver.{Telemetry, Coordinator}
  alias Teiserver.Battle.Lobby
  alias Teiserver.Account.AccoladeLib
  alias Phoenix.PubSub

  alias Teiserver.Battle.Match
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Data.Types, as: T

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

  alias Teiserver.Battle.MatchMonitorServer
  alias Teiserver.Battle.MatchLib
  require Logger

  def start_match(nil), do: :ok
  def start_match(lobby_id) do
    Telemetry.increment(:matches_started)

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
  end

  def stop_match(nil), do: :ok
  def stop_match(lobby_id) do
    Telemetry.increment(:matches_stopped)
    {uuid, params} = MatchLib.stop_match(lobby_id)

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

  @spec save_match_stats(T.lobby_id(), String.t()) :: :success | {:error, String.t()}
  def save_match_stats(_match_id, stats) do
    case Base.url_decode64(stats) do
      {:ok, data} ->
        Logger.info("save_match_stats - good decode with url_decode64 - #{Kernel.inspect data}")
      _ ->
        case Base.decode64(stats) do
          {:ok, data} ->
            Logger.info("save_match_stats - good decode with decode64 - #{Kernel.inspect data}")
            {:error, "base64 decode error"}

          _ ->
            Central.Helpers.StringHelper.multisplit(stats, 800)
            |> Enum.map(fn part ->
              Logger.info("save_match_stats - bad decode part - '#{part}'")
            end)
            :success
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
end
