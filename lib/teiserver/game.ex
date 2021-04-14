defmodule Teiserver.Game do
  @moduledoc """
  The Game context.
  """

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo

  alias Teiserver.Game.Party
  alias Teiserver.Game.PartyLib

  @spec party_query(List.t()) :: Ecto.Query.t()
  def party_query(args) do
    party_query(nil, args)
  end

  @spec party_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def party_query(id, args) do
    PartyLib.query_parties
    |> PartyLib.search(%{id: id})
    |> PartyLib.search(args[:search])
    |> PartyLib.preload(args[:preload])
    |> PartyLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of parties.

  ## Examples

      iex> list_parties()
      [%Party{}, ...]

  """
  @spec list_parties(List.t()) :: List.t()
  def list_parties(args \\ []) do
    party_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single party.

  Raises `Ecto.NoResultsError` if the Party does not exist.

  ## Examples

      iex> get_party!(123)
      %Party{}

      iex> get_party!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_party!(Integer.t() | List.t()) :: Party.t()
  @spec get_party!(Integer.t(), List.t()) :: Party.t()
  def get_party!(id) when not is_list(id) do
    party_query(id, [])
    |> Repo.one!
  end
  def get_party!(args) do
    party_query(nil, args)
    |> Repo.one!
  end
  def get_party!(id, args) do
    party_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single party.

  # Returns `nil` if the Party does not exist.

  # ## Examples

  #     iex> get_party(123)
  #     %Party{}

  #     iex> get_party(456)
  #     nil

  # """
  # def get_party(id, args \\ []) when not is_list(id) do
  #   party_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a party.

  ## Examples

      iex> create_party(%{field: value})
      {:ok, %Party{}}

      iex> create_party(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_party(Map.t()) :: {:ok, Party.t()} | {:error, Ecto.Changeset.t()}
  def create_party(attrs \\ %{}) do
    %Party{}
    |> Party.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a party.

  ## Examples

      iex> update_party(party, %{field: new_value})
      {:ok, %Party{}}

      iex> update_party(party, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_party(Party.t(), Map.t()) :: {:ok, Party.t()} | {:error, Ecto.Changeset.t()}
  def update_party(%Party{} = party, attrs) do
    party
    |> Party.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Party.

  ## Examples

      iex> delete_party(party)
      {:ok, %Party{}}

      iex> delete_party(party)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_party(Party.t()) :: {:ok, Party.t()} | {:error, Ecto.Changeset.t()}
  def delete_party(%Party{} = party) do
    Repo.delete(party)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking party changes.

  ## Examples

      iex> change_party(party)
      %Ecto.Changeset{source: %Party{}}

  """
  @spec change_party(Party.t()) :: Ecto.Changeset.t()
  def change_party(%Party{} = party) do
    Party.changeset(party, %{})
  end

    alias Teiserver.Game.Queue
  alias Teiserver.Game.QueueLib

  @spec queue_query(List.t()) :: Ecto.Query.t()
  def queue_query(args) do
    queue_query(nil, args)
  end

  @spec queue_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def queue_query(id, args) do
    QueueLib.query_queues
    |> QueueLib.search(%{id: id})
    |> QueueLib.search(args[:search])
    |> QueueLib.preload(args[:preload])
    |> QueueLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of queues.

  ## Examples

      iex> list_queues()
      [%Queue{}, ...]

  """
  @spec list_queues(List.t()) :: List.t()
  def list_queues(args \\ []) do
    queue_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single queue.

  Raises `Ecto.NoResultsError` if the Queue does not exist.

  ## Examples

      iex> get_queue!(123)
      %Queue{}

      iex> get_queue!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_queue!(Integer.t() | List.t()) :: Queue.t()
  @spec get_queue!(Integer.t(), List.t()) :: Queue.t()
  def get_queue!(id) when not is_list(id) do
    queue_query(id, [])
    |> Repo.one!
  end
  def get_queue!(args) do
    queue_query(nil, args)
    |> Repo.one!
  end
  def get_queue!(id, args) do
    queue_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single queue.

  # Returns `nil` if the Queue does not exist.

  # ## Examples

  #     iex> get_queue(123)
  #     %Queue{}

  #     iex> get_queue(456)
  #     nil

  # """
  # def get_queue(id, args \\ []) when not is_list(id) do
  #   queue_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a queue.

  ## Examples

      iex> create_queue(%{field: value})
      {:ok, %Queue{}}

      iex> create_queue(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_queue(Map.t()) :: {:ok, Queue.t()} | {:error, Ecto.Changeset.t()}
  def create_queue(attrs \\ %{}) do
    %Queue{}
    |> Queue.changeset(attrs)
    |> Repo.insert()
    |> cache_new_queue
  end

  defp cache_new_queue({:ok, queue}) do
    Teiserver.Data.Matchmaking.add_queue(queue)
    {:ok, queue}
  end
  defp cache_new_queue(v), do: v

  @doc """
  Updates a queue.

  ## Examples

      iex> update_queue(queue, %{field: new_value})
      {:ok, %Queue{}}

      iex> update_queue(queue, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_queue(Queue.t(), Map.t()) :: {:ok, Queue.t()} | {:error, Ecto.Changeset.t()}
  def update_queue(%Queue{} = queue, attrs) do
    queue
    |> Queue.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Queue.

  ## Examples

      iex> delete_queue(queue)
      {:ok, %Queue{}}

      iex> delete_queue(queue)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_queue(Queue.t()) :: {:ok, Queue.t()} | {:error, Ecto.Changeset.t()}
  def delete_queue(%Queue{} = queue) do
    Repo.delete(queue)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking queue changes.

  ## Examples

      iex> change_queue(queue)
      %Ecto.Changeset{source: %Queue{}}

  """
  @spec change_queue(Queue.t()) :: Ecto.Changeset.t()
  def change_queue(%Queue{} = queue) do
    Queue.changeset(queue, %{})
  end

    alias Teiserver.Game.Tournament
  alias Teiserver.Game.TournamentLib

  @spec tournament_query(List.t()) :: Ecto.Query.t()
  def tournament_query(args) do
    tournament_query(nil, args)
  end

  @spec tournament_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def tournament_query(id, args) do
    TournamentLib.query_tournaments
    |> TournamentLib.search(%{id: id})
    |> TournamentLib.search(args[:search])
    |> TournamentLib.preload(args[:preload])
    |> TournamentLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of tournaments.

  ## Examples

      iex> list_tournaments()
      [%Tournament{}, ...]

  """
  @spec list_tournaments(List.t()) :: List.t()
  def list_tournaments(args \\ []) do
    tournament_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single tournament.

  Raises `Ecto.NoResultsError` if the Tournament does not exist.

  ## Examples

      iex> get_tournament!(123)
      %Tournament{}

      iex> get_tournament!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_tournament!(Integer.t() | List.t()) :: Tournament.t()
  @spec get_tournament!(Integer.t(), List.t()) :: Tournament.t()
  def get_tournament!(id) when not is_list(id) do
    tournament_query(id, [])
    |> Repo.one!
  end
  def get_tournament!(args) do
    tournament_query(nil, args)
    |> Repo.one!
  end
  def get_tournament!(id, args) do
    tournament_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single tournament.

  # Returns `nil` if the Tournament does not exist.

  # ## Examples

  #     iex> get_tournament(123)
  #     %Tournament{}

  #     iex> get_tournament(456)
  #     nil

  # """
  # def get_tournament(id, args \\ []) when not is_list(id) do
  #   tournament_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a tournament.

  ## Examples

      iex> create_tournament(%{field: value})
      {:ok, %Tournament{}}

      iex> create_tournament(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_tournament(Map.t()) :: {:ok, Tournament.t()} | {:error, Ecto.Changeset.t()}
  def create_tournament(attrs \\ %{}) do
    %Tournament{}
    |> Tournament.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a tournament.

  ## Examples

      iex> update_tournament(tournament, %{field: new_value})
      {:ok, %Tournament{}}

      iex> update_tournament(tournament, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_tournament(Tournament.t(), Map.t()) :: {:ok, Tournament.t()} | {:error, Ecto.Changeset.t()}
  def update_tournament(%Tournament{} = tournament, attrs) do
    tournament
    |> Tournament.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Tournament.

  ## Examples

      iex> delete_tournament(tournament)
      {:ok, %Tournament{}}

      iex> delete_tournament(tournament)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_tournament(Tournament.t()) :: {:ok, Tournament.t()} | {:error, Ecto.Changeset.t()}
  def delete_tournament(%Tournament{} = tournament) do
    Repo.delete(tournament)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking tournament changes.

  ## Examples

      iex> change_tournament(tournament)
      %Ecto.Changeset{source: %Tournament{}}

  """
  @spec change_tournament(Tournament.t()) :: Ecto.Changeset.t()
  def change_tournament(%Tournament{} = tournament) do
    Tournament.changeset(tournament, %{})
  end
end
