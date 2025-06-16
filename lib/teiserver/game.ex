defmodule Teiserver.Game do
  @moduledoc """
  The Game context.
  """

  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Repo

  alias Teiserver.Game.{AchievementType, AchievementTypeLib}

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

  alias Teiserver.Game.{UserAchievement, UserAchievementLib}

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

  alias Teiserver.Game.{RatingType, RatingTypeLib}

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

        [%{id: id} | _] ->
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

  alias Teiserver.Game.{RatingLog, RatingLogLib}

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
    |> Repo.all()
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

  alias Teiserver.Game.{LobbyPolicy, LobbyPolicyLib}

  @spec lobby_policy_query(List.t()) :: Ecto.Query.t()
  def lobby_policy_query(args) do
    lobby_policy_query(nil, args)
  end

  @spec lobby_policy_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def lobby_policy_query(id, args) do
    LobbyPolicyLib.query_lobby_policies()
    |> LobbyPolicyLib.search(%{id: id})
    |> LobbyPolicyLib.search(args[:search])
    |> LobbyPolicyLib.preload(args[:preload])
    |> LobbyPolicyLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of lobby_policies.

  ## Examples

      iex> list_lobby_policies()
      [%LobbyPolicy{}, ...]

  """
  @spec list_lobby_policies(List.t()) :: List.t()
  def list_lobby_policies(args \\ []) do
    lobby_policy_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single lobby_policy.

  Raises `Ecto.NoResultsError` if the LobbyPolicy does not exist.

  ## Examples

      iex> get_lobby_policy!(123)
      %LobbyPolicy{}

      iex> get_lobby_policy!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_lobby_policy!(Integer.t() | List.t()) :: LobbyPolicy.t()
  @spec get_lobby_policy!(Integer.t(), List.t()) :: LobbyPolicy.t()
  def get_lobby_policy!(id) when not is_list(id) do
    lobby_policy_query(id, [])
    |> Repo.one!()
  end

  def get_lobby_policy!(args) do
    lobby_policy_query(nil, args)
    |> Repo.one!()
  end

  def get_lobby_policy!(id, args) do
    lobby_policy_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single lobby_policy.

  # Returns `nil` if the LobbyPolicy does not exist.

  # ## Examples

  #     iex> get_lobby_policy(123)
  #     %LobbyPolicy{}

  #     iex> get_lobby_policy(456)
  #     nil

  # """
  # def get_lobby_policy(id, args \\ []) when not is_list(id) do
  #   lobby_policy_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a lobby_policy.

  ## Examples

      iex> create_lobby_policy(%{field: value})
      {:ok, %LobbyPolicy{}}

      iex> create_lobby_policy(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_lobby_policy(map()) :: {:ok, LobbyPolicy.t()} | {:error, Ecto.Changeset.t()}
  def create_lobby_policy(attrs \\ %{}) do
    %LobbyPolicy{}
    |> LobbyPolicy.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a lobby_policy.

  ## Examples

      iex> update_lobby_policy(lobby_policy, %{field: new_value})
      {:ok, %LobbyPolicy{}}

      iex> update_lobby_policy(lobby_policy, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_lobby_policy(LobbyPolicy.t(), map()) ::
          {:ok, LobbyPolicy.t()} | {:error, Ecto.Changeset.t()}
  def update_lobby_policy(%LobbyPolicy{} = lobby_policy, attrs) do
    lobby_policy
    |> LobbyPolicy.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a LobbyPolicy.

  ## Examples

      iex> delete_lobby_policy(lobby_policy)
      {:ok, %LobbyPolicy{}}

      iex> delete_lobby_policy(lobby_policy)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_lobby_policy(LobbyPolicy.t()) ::
          {:ok, LobbyPolicy.t()} | {:error, Ecto.Changeset.t()}
  def delete_lobby_policy(%LobbyPolicy{} = lobby_policy) do
    Repo.delete(lobby_policy)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking lobby_policy changes.

  ## Examples

      iex> change_lobby_policy(lobby_policy)
      %Ecto.Changeset{source: %LobbyPolicy{}}

  """
  @spec change_lobby_policy(LobbyPolicy.t()) :: Ecto.Changeset.t()
  def change_lobby_policy(%LobbyPolicy{} = lobby_policy) do
    LobbyPolicy.changeset(lobby_policy, %{})
  end

  # Lobby policy lib stuff
  alias Teiserver.Game.LobbyPolicyLib

  @spec pre_cache_policies() :: :ok
  defdelegate pre_cache_policies(), to: LobbyPolicyLib

  @spec add_policy_from_db(LobbyPolicy.t()) :: :ok | {:error, any}
  defdelegate add_policy_from_db(lobby_policy), to: LobbyPolicyLib

  @spec get_lobby_organiser_pid(T.lobby_policy_id()) :: pid() | nil
  defdelegate get_lobby_organiser_pid(lobby_policy_id), to: LobbyPolicyLib

  @spec call_lobby_organiser(T.lobby_policy_id(), any) :: any | nil
  defdelegate call_lobby_organiser(lobby_policy_id, msg), to: LobbyPolicyLib

  @spec cast_lobby_organiser(T.lobby_policy_id(), any) :: any | nil
  defdelegate cast_lobby_organiser(lobby_policy_id, msg), to: LobbyPolicyLib

  @spec list_cached_lobby_policies() :: list()
  defdelegate list_cached_lobby_policies(), to: LobbyPolicyLib

  @spec get_cached_lobby_policy(non_neg_integer()) :: LobbyPolicy.t()
  defdelegate get_cached_lobby_policy(id), to: LobbyPolicyLib
end
