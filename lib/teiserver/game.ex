defmodule Teiserver.Game do
  @moduledoc """
  The Game context.
  """

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo

  alias Teiserver.Game.Queue
  alias Teiserver.Game.QueueLib

  @spec queue_query(List.t()) :: Ecto.Query.t()
  def queue_query(args) do
    queue_query(nil, args)
  end

  @spec queue_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def queue_query(id, args) do
    QueueLib.query_queues()
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
    |> Repo.all()
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
    |> Repo.one!()
  end

  def get_queue!(args) do
    queue_query(nil, args)
    |> Repo.one!()
  end

  def get_queue!(id, args) do
    queue_query(id, args)
    |> Repo.one!()
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
    Teiserver.Data.Matchmaking.add_queue_from_db(queue)
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
end
