defmodule Teiserver.Battle do
  @moduledoc """
  The Battle context.
  """

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo

  alias Teiserver.Battle.Match
  alias Teiserver.Battle.MatchLib

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

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single match.

  # Returns `nil` if the Match does not exist.

  # ## Examples

  #     iex> get_match(123)
  #     %Match{}

  #     iex> get_match(456)
  #     nil

  # """
  # def get_match(id, args \\ []) when not is_list(id) do
  #   match_query(id, args)
  #   |> Repo.one
  # end

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
  @spec add_player_to_battle(T.userid(), T.battle_id()) :: :ok | {:error, String.t()}
  def add_player_to_battle(userid, battle_id) do
    case Teiserver.Client.get_client_by_id(userid) do
      nil ->
        {:error, "no client"}
      _ ->
        case Lobby.get_battle(battle_id) do
          nil ->
            {:error, "no battle"}
          _ ->
            Teiserver.Battle.Lobby.accept_join_request(3, battle_id)
        end
    end
  end

  alias Teiserver.Battle.MatchMonitorServer
  require Logger

  def start_match(match_id) do
    Logger.error("start_match(#{match_id})")
  end

  def end_match(match_id) do
    Logger.error("end_match(#{match_id})")
  end

  def save_match_stats(match_id, stats) do
    Logger.error("save_match_stats(#{match_id}, #{stats})")
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
end
