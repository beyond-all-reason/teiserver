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

  alias Teiserver.Game.{AchievementType, AchievementTypeLib}

  @spec achievement_type_query(List.t()) :: Ecto.Query.t()
  def achievement_type_query(args) do
    achievement_type_query(nil, args)
  end

  @spec achievement_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def achievement_type_query(id, args) do
    AchievementTypeLib.query_achievement_types
    |> AchievementTypeLib.search(%{id: id})
    |> AchievementTypeLib.search(args[:search])
    |> AchievementTypeLib.preload(args[:preload])
    |> AchievementTypeLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of achievement_types.

  ## Examples

      iex> list_achievement_types()
      [%AchievementType{}, ...]

  """
  @spec list_achievement_types(List.t()) :: List.t()
  def list_achievement_types(args \\ []) do
    achievement_type_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single achievement_type.

  Raises `Ecto.NoResultsError` if the AchievementType does not exist.

  ## Examples

      iex> get_achievement_type!(123)
      %AchievementType{}

      iex> get_achievement_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_achievement_type!(Integer.t() | List.t()) :: AchievementType.t()
  @spec get_achievement_type!(Integer.t(), List.t()) :: AchievementType.t()
  def get_achievement_type!(id) when not is_list(id) do
    achievement_type_query(id, [])
    |> Repo.one!
  end
  def get_achievement_type!(args) do
    achievement_type_query(nil, args)
    |> Repo.one!
  end
  def get_achievement_type!(id, args) do
    achievement_type_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single achievement_type.

  # Returns `nil` if the AchievementType does not exist.

  # ## Examples

  #     iex> get_achievement_type(123)
  #     %AchievementType{}

  #     iex> get_achievement_type(456)
  #     nil

  # """
  # def get_achievement_type(id, args \\ []) when not is_list(id) do
  #   achievement_type_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a achievement_type.

  ## Examples

      iex> create_achievement_type(%{field: value})
      {:ok, %AchievementType{}}

      iex> create_achievement_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_achievement_type(Map.t()) :: {:ok, AchievementType.t()} | {:error, Ecto.Changeset.t()}
  def create_achievement_type(attrs \\ %{}) do
    %AchievementType{}
    |> AchievementType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a achievement_type.

  ## Examples

      iex> update_achievement_type(achievement_type, %{field: new_value})
      {:ok, %AchievementType{}}

      iex> update_achievement_type(achievement_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_achievement_type(AchievementType.t(), Map.t()) :: {:ok, AchievementType.t()} | {:error, Ecto.Changeset.t()}
  def update_achievement_type(%AchievementType{} = achievement_type, attrs) do
    achievement_type
    |> AchievementType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a AchievementType.

  ## Examples

      iex> delete_achievement_type(achievement_type)
      {:ok, %AchievementType{}}

      iex> delete_achievement_type(achievement_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_achievement_type(AchievementType.t()) :: {:ok, AchievementType.t()} | {:error, Ecto.Changeset.t()}
  def delete_achievement_type(%AchievementType{} = achievement_type) do
    Repo.delete(achievement_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking achievement_type changes.

  ## Examples

      iex> change_achievement_type(achievement_type)
      %Ecto.Changeset{source: %AchievementType{}}

  """
  @spec change_achievement_type(AchievementType.t()) :: Ecto.Changeset.t()
  def change_achievement_type(%AchievementType{} = achievement_type) do
    AchievementType.changeset(achievement_type, %{})
  end

  alias Teiserver.Game.{UserAchievement, UserAchievementLib}

  @spec user_achievement_query(List.t()) :: Ecto.Query.t()
  def user_achievement_query(args) do
    user_achievement_query(nil, args)
  end

  @spec user_achievement_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def user_achievement_query(id, args) do
    UserAchievementLib.query_user_achievements
    |> UserAchievementLib.search(%{id: id})
    |> UserAchievementLib.search(args[:search])
    |> UserAchievementLib.preload(args[:preload])
    |> UserAchievementLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of user_achievements.

  ## Examples

      iex> list_user_achievements()
      [%UserAchievement{}, ...]

  """
  @spec list_user_achievements(List.t()) :: List.t()
  def list_user_achievements(args \\ []) do
    user_achievement_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single user_achievement.

  Raises `Ecto.NoResultsError` if the UserAchievement does not exist.

  ## Examples

      iex> get_user_achievement!(123)
      %UserAchievement{}

      iex> get_user_achievement!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_user_achievement!(Integer.t() | List.t()) :: UserAchievement.t()
  @spec get_user_achievement!(Integer.t(), List.t()) :: UserAchievement.t()
  def get_user_achievement!(id) when not is_list(id) do
    user_achievement_query(id, [])
    |> Repo.one!
  end
  def get_user_achievement!(args) do
    user_achievement_query(nil, args)
    |> Repo.one!
  end
  def get_user_achievement!(id, args) do
    user_achievement_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single user_achievement.

  # Returns `nil` if the UserAchievement does not exist.

  # ## Examples

  #     iex> get_user_achievement(123)
  #     %UserAchievement{}

  #     iex> get_user_achievement(456)
  #     nil

  # """
  # def get_user_achievement(id, args \\ []) when not is_list(id) do
  #   user_achievement_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a user_achievement.

  ## Examples

      iex> create_user_achievement(%{field: value})
      {:ok, %UserAchievement{}}

      iex> create_user_achievement(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_user_achievement(Map.t()) :: {:ok, UserAchievement.t()} | {:error, Ecto.Changeset.t()}
  def create_user_achievement(attrs \\ %{}) do
    %UserAchievement{}
    |> UserAchievement.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_achievement.

  ## Examples

      iex> update_user_achievement(user_achievement, %{field: new_value})
      {:ok, %UserAchievement{}}

      iex> update_user_achievement(user_achievement, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_user_achievement(UserAchievement.t(), Map.t()) :: {:ok, UserAchievement.t()} | {:error, Ecto.Changeset.t()}
  def update_user_achievement(%UserAchievement{} = user_achievement, attrs) do
    user_achievement
    |> UserAchievement.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserAchievement.

  ## Examples

      iex> delete_user_achievement(user_achievement)
      {:ok, %UserAchievement{}}

      iex> delete_user_achievement(user_achievement)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_user_achievement(UserAchievement.t()) :: {:ok, UserAchievement.t()} | {:error, Ecto.Changeset.t()}
  def delete_user_achievement(%UserAchievement{} = user_achievement) do
    Repo.delete(user_achievement)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_achievement changes.

  ## Examples

      iex> change_user_achievement(user_achievement)
      %Ecto.Changeset{source: %UserAchievement{}}

  """
  @spec change_user_achievement(UserAchievement.t()) :: Ecto.Changeset.t()
  def change_user_achievement(%UserAchievement{} = user_achievement) do
    UserAchievement.changeset(user_achievement, %{})
  end

end
