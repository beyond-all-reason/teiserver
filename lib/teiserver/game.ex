defmodule Teiserver.Game do
  @moduledoc """
  The Game context.
  """

  alias Teiserver.Account
  alias Teiserver.Game.AchievementType
  alias Teiserver.Game.AchievementTypeLib
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Game.RatingLog
  alias Teiserver.Game.RatingLogLib
  alias Teiserver.Game.RatingType
  alias Teiserver.Game.RatingTypeLib
  alias Teiserver.Game.UserAchievement
  alias Teiserver.Game.UserAchievementLib
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo

  import Ecto.Query, warn: false

  @spec achievement_type_query(List.t()) :: Ecto.Query.t()
  def achievement_type_query(args) do
    achievement_type_query(nil, args)
  end

  @spec achievement_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def achievement_type_query(id, args) do
    AchievementTypeLib.query_achievement_types()
    |> AchievementTypeLib.search(%{id: id})
    |> AchievementTypeLib.search(args[:search])
    |> AchievementTypeLib.preload(args[:preload])
    |> AchievementTypeLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
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
    |> Repo.all()
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
    |> Repo.one!()
  end

  def get_achievement_type!(args) do
    achievement_type_query(nil, args)
    |> Repo.one!()
  end

  def get_achievement_type!(id, args) do
    achievement_type_query(id, args)
    |> Repo.one!()
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
  @spec create_achievement_type(map()) ::
          {:ok, AchievementType.t()} | {:error, Ecto.Changeset.t()}
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
  @spec update_achievement_type(AchievementType.t(), map()) ::
          {:ok, AchievementType.t()} | {:error, Ecto.Changeset.t()}
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
  @spec delete_achievement_type(AchievementType.t()) ::
          {:ok, AchievementType.t()} | {:error, Ecto.Changeset.t()}
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

  @spec user_achievement_query(List.t()) :: Ecto.Query.t()
  def user_achievement_query(args) do
    user_achievement_query(nil, nil, args)
  end

  @spec user_achievement_query(Integer.t(), Integer.t(), List.t()) :: Ecto.Query.t()
  def user_achievement_query(userid, type_id, args) do
    UserAchievementLib.query_user_achievements()
    |> UserAchievementLib.search(%{user_id: userid})
    |> UserAchievementLib.search(%{type_id: type_id})
    |> UserAchievementLib.search(args[:search])
    |> UserAchievementLib.preload(args[:preload])
    |> UserAchievementLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
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
    |> Repo.all()
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
  @spec get_user_achievement!(Integer.t(), Integer.t()) :: UserAchievement.t()
  @spec get_user_achievement!(Integer.t(), Integer.t(), List.t()) :: UserAchievement.t()
  def get_user_achievement!(userid, type_id, args \\ []) do
    user_achievement_query(userid, type_id, args)
    |> Repo.one!()
  end

  @doc """
  Gets a single user_achievement.

  Returns `nil` if the UserAchievement does not exist.

  ## Examples

      iex> get_user_achievement(123)
      %UserAchievement{}

      iex> get_user_achievement(456)
      nil

  """
  @spec get_user_achievement(Integer.t(), Integer.t()) :: UserAchievement.t()
  @spec get_user_achievement(Integer.t(), Integer.t(), List.t()) :: UserAchievement.t()
  def get_user_achievement(userid, type_id, args \\ []) do
    user_achievement_query(userid, type_id, args)
    |> Repo.one()
  end

  @doc """
  Creates a user_achievement.

  ## Examples

      iex> create_user_achievement(%{field: value})
      {:ok, %UserAchievement{}}

      iex> create_user_achievement(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_user_achievement(map()) ::
          {:ok, UserAchievement.t()} | {:error, Ecto.Changeset.t()}
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
  @spec update_user_achievement(UserAchievement.t(), map()) ::
          {:ok, UserAchievement.t()} | {:error, Ecto.Changeset.t()}
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
  @spec delete_user_achievement(UserAchievement.t()) ::
          {:ok, UserAchievement.t()} | {:error, Ecto.Changeset.t()}
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

  @spec rating_type_query(List.t()) :: Ecto.Query.t()
  def rating_type_query(args) do
    rating_type_query(nil, args)
  end

  @spec rating_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def rating_type_query(id, args) do
    RatingTypeLib.query_rating_types()
    |> RatingTypeLib.search(%{id: id})
    |> RatingTypeLib.search(args[:search])
    |> RatingTypeLib.preload(args[:preload])
    |> RatingTypeLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of rating_types.

  ## Examples

      iex> list_rating_types()
      [%RatingType{}, ...]

  """
  @spec list_rating_types(List.t()) :: List.t()
  def list_rating_types(args \\ []) do
    rating_type_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single rating_type.

  Raises `Ecto.NoResultsError` if the RatingType does not exist.

  ## Examples

      iex> get_rating_type!(123)
      %RatingType{}

      iex> get_rating_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_rating_type!(Integer.t() | List.t()) :: RatingType.t()
  @spec get_rating_type!(Integer.t(), List.t()) :: RatingType.t()
  def get_rating_type!(id) when not is_list(id) do
    rating_type_query(id, [])
    |> Repo.one!()
  end

  def get_rating_type!(args) do
    rating_type_query(nil, args)
    |> Repo.one!()
  end

  def get_rating_type!(id, args) do
    rating_type_query(id, args)
    |> Repo.one!()
  end

  @spec get_rating_type_by_name!(String.t()) :: RatingType.t()
  def get_rating_type_by_name!(name) do
    rating_type_query(search: [name: name])
    |> Repo.one!()
  end

  @spec get_ratings_for_users(user_ids :: [integer()]) :: [RatingType.t()]
  def get_ratings_for_users(user_ids),
    do: get_ratings_for_users(user_ids, MatchRatingLib.active_season())

  @spec get_ratings_for_users(user_ids :: [integer()], season :: integer()) :: [RatingType.t()]
  def get_ratings_for_users(user_ids, season) do
    query = Account.rating_query(search: [user_id_in: user_ids, season: season])

    rating_type_query(preload: [ratings: query])
    |> Repo.all()
  end

  @spec get_or_add_rating_type(String.t()) :: non_neg_integer()
  def get_or_add_rating_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:teiserver_game_rating_types, name, fn ->
      case list_rating_types(search: [name: name], select: [:id], order_by: "ID (Lowest first)") do
        [] ->
          {:ok, rating_type} =
            %RatingType{}
            |> RatingType.changeset(%{
              name: name,
              colour: "#777777",
              icon: "fa-house"
            })
            |> Repo.insert()

          rating_type.id

        [%{id: id} | _rest] ->
          id
      end
    end)
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single rating_type.

  # Returns `nil` if the RatingType does not exist.

  # ## Examples

  #     iex> get_rating_type(123)
  #     %RatingType{}

  #     iex> get_rating_type(456)
  #     nil

  # """
  # def get_rating_type(id, args \\ []) when not is_list(id) do
  #   rating_type_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a rating_type.

  ## Examples

      iex> create_rating_type(%{field: value})
      {:ok, %RatingType{}}

      iex> create_rating_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_rating_type(map()) :: {:ok, RatingType.t()} | {:error, Ecto.Changeset.t()}
  def create_rating_type(attrs \\ %{}) do
    %RatingType{}
    |> RatingType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rating_type.

  ## Examples

      iex> update_rating_type(rating_type, %{field: new_value})
      {:ok, %RatingType{}}

      iex> update_rating_type(rating_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_rating_type(RatingType.t(), map()) ::
          {:ok, RatingType.t()} | {:error, Ecto.Changeset.t()}
  def update_rating_type(%RatingType{} = rating_type, attrs) do
    rating_type
    |> RatingType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a RatingType.

  ## Examples

      iex> delete_rating_type(rating_type)
      {:ok, %RatingType{}}

      iex> delete_rating_type(rating_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_rating_type(RatingType.t()) :: {:ok, RatingType.t()} | {:error, Ecto.Changeset.t()}
  def delete_rating_type(%RatingType{} = rating_type) do
    Repo.delete(rating_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rating_type changes.

  ## Examples

      iex> change_rating_type(rating_type)
      %Ecto.Changeset{source: %RatingType{}}

  """
  @spec change_rating_type(RatingType.t()) :: Ecto.Changeset.t()
  def change_rating_type(%RatingType{} = rating_type) do
    RatingType.changeset(rating_type, %{})
  end

  @spec rating_log_query(List.t()) :: Ecto.Query.t()
  def rating_log_query(args) do
    rating_log_query(nil, args)
  end

  @spec rating_log_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def rating_log_query(id, args) do
    RatingLogLib.query_rating_logs()
    |> RatingLogLib.search(%{id: id})
    |> RatingLogLib.search(args[:search])
    |> RatingLogLib.preload(args[:preload])
    |> RatingLogLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of rating_logs.

  ## Examples

      iex> list_rating_logs()
      [%RatingLog{}, ...]

  """
  @spec list_rating_logs(List.t()) :: List.t()
  def list_rating_logs(args \\ []) do
    rating_log_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> QueryHelpers.offset_query(args[:offset])
    |> Repo.all()
  end

  @doc """
  Returns the count of rating_logs matching the given criteria.

  ## Examples

      iex> count_rating_logs()
      42

      iex> count_rating_logs(search: [user_id: 123])
      15

  """
  @spec count_rating_logs(List.t()) :: integer()
  def count_rating_logs(args \\ []) do
    rating_log_query(args)
    |> Repo.aggregate(:count, :id)
  end

  @doc """
  Gets a single rating_log.

  Raises `Ecto.NoResultsError` if the RatingLog does not exist.

  ## Examples

      iex> get_rating_log!(123)
      %RatingLog{}

      iex> get_rating_log!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_rating_log!(Integer.t() | List.t()) :: RatingLog.t()
  @spec get_rating_log!(Integer.t(), List.t()) :: RatingLog.t()
  def get_rating_log!(id) when not is_list(id) do
    rating_log_query(id, [])
    |> Repo.one!()
  end

  def get_rating_log!(args) do
    rating_log_query(nil, args)
    |> Repo.one!()
  end

  def get_rating_log!(id, args) do
    rating_log_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single rating_log.

  # Returns `nil` if the RatingLog does not exist.

  # ## Examples

  #     iex> get_rating_log(123)
  #     %RatingLog{}

  #     iex> get_rating_log(456)
  #     nil

  # """
  # def get_rating_log(id, args \\ []) when not is_list(id) do
  #   rating_log_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a rating_log.

  ## Examples

      iex> create_rating_log(%{field: value})
      {:ok, %RatingLog{}}

      iex> create_rating_log(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_rating_log(map()) :: {:ok, RatingLog.t()} | {:error, Ecto.Changeset.t()}
  def create_rating_log(attrs \\ %{}) do
    %RatingLog{}
    |> RatingLog.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a rating_log.

  ## Examples

      iex> update_rating_log(rating_log, %{field: new_value})
      {:ok, %RatingLog{}}

      iex> update_rating_log(rating_log, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_rating_log(RatingLog.t(), map()) ::
          {:ok, RatingLog.t()} | {:error, Ecto.Changeset.t()}
  def update_rating_log(%RatingLog{} = rating_log, attrs) do
    rating_log
    |> RatingLog.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a RatingLog.

  ## Examples

      iex> delete_rating_log(rating_log)
      {:ok, %RatingLog{}}

      iex> delete_rating_log(rating_log)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_rating_log(RatingLog.t()) :: {:ok, RatingLog.t()} | {:error, Ecto.Changeset.t()}
  def delete_rating_log(%RatingLog{} = rating_log) do
    Repo.delete(rating_log)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking rating_log changes.

  ## Examples

      iex> change_rating_log(rating_log)
      %Ecto.Changeset{source: %RatingLog{}}

  """
  @spec change_rating_log(RatingLog.t()) :: Ecto.Changeset.t()
  def change_rating_log(%RatingLog{} = rating_log) do
    RatingLog.changeset(rating_log, %{})
  end
end
