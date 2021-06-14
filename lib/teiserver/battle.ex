defmodule Teiserver.Battle do
  @moduledoc """
  The Battle context.
  """

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo

  alias Teiserver.Battle.BattleLog
  alias Teiserver.Battle.BattleLogLib

  @spec battle_log_query(List.t()) :: Ecto.Query.t()
  def battle_log_query(args) do
    battle_log_query(nil, args)
  end

  @spec battle_log_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def battle_log_query(id, args) do
    BattleLogLib.query_battle_logs
    |> BattleLogLib.search(%{id: id})
    |> BattleLogLib.search(args[:search])
    |> BattleLogLib.preload(args[:preload])
    |> BattleLogLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of battle_logs.

  ## Examples

      iex> list_battle_logs()
      [%BattleLog{}, ...]

  """
  @spec list_battle_logs(List.t()) :: List.t()
  def list_battle_logs(args \\ []) do
    battle_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single battle_log.

  Raises `Ecto.NoResultsError` if the BattleLog does not exist.

  ## Examples

      iex> get_battle_log!(123)
      %BattleLog{}

      iex> get_battle_log!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_battle_log!(Integer.t() | List.t()) :: BattleLog.t()
  @spec get_battle_log!(Integer.t(), List.t()) :: BattleLog.t()
  def get_battle_log!(id) when not is_list(id) do
    battle_log_query(id, [])
    |> Repo.one!
  end
  def get_battle_log!(args) do
    battle_log_query(nil, args)
    |> Repo.one!
  end
  def get_battle_log!(id, args) do
    battle_log_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single battle_log.

  # Returns `nil` if the BattleLog does not exist.

  # ## Examples

  #     iex> get_battle_log(123)
  #     %BattleLog{}

  #     iex> get_battle_log(456)
  #     nil

  # """
  # def get_battle_log(id, args \\ []) when not is_list(id) do
  #   battle_log_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a battle_log.

  ## Examples

      iex> create_battle_log(%{field: value})
      {:ok, %BattleLog{}}

      iex> create_battle_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_battle_log(Map.t()) :: {:ok, BattleLog.t()} | {:error, Ecto.Changeset.t()}
  def create_battle_log(attrs \\ %{}) do
    %BattleLog{}
    |> BattleLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a battle_log.

  ## Examples

      iex> update_battle_log(battle_log, %{field: new_value})
      {:ok, %BattleLog{}}

      iex> update_battle_log(battle_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_battle_log(BattleLog.t(), Map.t()) :: {:ok, BattleLog.t()} | {:error, Ecto.Changeset.t()}
  def update_battle_log(%BattleLog{} = battle_log, attrs) do
    battle_log
    |> BattleLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a BattleLog.

  ## Examples

      iex> delete_battle_log(battle_log)
      {:ok, %BattleLog{}}

      iex> delete_battle_log(battle_log)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_battle_log(BattleLog.t()) :: {:ok, BattleLog.t()} | {:error, Ecto.Changeset.t()}
  def delete_battle_log(%BattleLog{} = battle_log) do
    Repo.delete(battle_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking battle_log changes.

  ## Examples

      iex> change_battle_log(battle_log)
      %Ecto.Changeset{source: %BattleLog{}}

  """
  @spec change_battle_log(BattleLog.t()) :: Ecto.Changeset.t()
  def change_battle_log(%BattleLog{} = battle_log) do
    BattleLog.changeset(battle_log, %{})
  end


  alias Teiserver.Battle.BattleLobby

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
        case BattleLobby.get_battle(battle_id) do
          nil ->
            {:error, "no battle"}
          _ ->
            Teiserver.Battle.BattleLobby.accept_join_request(3, battle_id)
        end
    end
  end
end
