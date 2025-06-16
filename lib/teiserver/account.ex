defmodule Teiserver.Account do
  @moduledoc false
  import Ecto.Query, warn: false
  alias Teiserver.Repo
  require Logger
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Account.UserLib

  @type t :: UserLib.t()

  @spec icon :: String.t()
  def icon, do: "fa-solid fa-user-alt"

  defdelegate default_data(), to: Teiserver.Account.User

  @spec list_users() :: [User]
  defdelegate list_users(), to: UserLib

  @spec list_users(list) :: [User]
  defdelegate list_users(args), to: UserLib

  @spec get_user!(non_neg_integer()) :: User.t()
  defdelegate get_user!(user_id), to: UserLib

  @spec get_user!(non_neg_integer(), list) :: User.t() | nil
  defdelegate get_user!(user_id, args), to: UserLib

  @spec get_user(non_neg_integer()) :: User.t() | nil
  defdelegate get_user(user_id), to: UserLib

  @spec get_user(non_neg_integer(), list) :: User.t() | nil
  defdelegate get_user(user_id, args), to: UserLib

  @spec query_users(list) :: [User.t()]
  defdelegate query_users(query_args), to: UserLib

  @spec query_user(list) :: User.t() | nil
  defdelegate query_user(query_args), to: UserLib

  @spec create_user() :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate create_user(), to: UserLib

  @spec create_user(map) :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate create_user(attrs), to: UserLib

  @spec register_user(
          map,
          pass_type :: :md5_password | :plain_password | nil,
          ip :: String.t() | nil
        ) ::
          {:ok, User} | {:error, Ecto.Changeset.t()}
  defdelegate register_user(attrs, pass_type \\ nil, ip \\ nil), to: UserLib

  @spec script_create_user(map) :: {:ok, T.user()} | {:error, Ecto.Changeset.t()}
  defdelegate script_create_user(attrs), to: UserLib

  @spec update_user(User, map) :: {:ok, T.user()} | {:error, Ecto.Changeset}
  defdelegate update_user(user, attrs), to: UserLib

  @spec update_user_plain_password(User, map) :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate update_user_plain_password(user, attrs), to: UserLib

  @spec update_user_user_form(User, map) :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate update_user_user_form(user, attrs), to: UserLib

  @spec server_limited_update_user(User, map) :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate server_limited_update_user(user, attrs), to: UserLib

  @spec server_update_user(User, map) :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate server_update_user(user, attrs), to: UserLib

  @spec script_update_user(User, map) :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate script_update_user(user, attrs), to: UserLib

  @spec password_reset_update_user(User, map) :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate password_reset_update_user(user, attrs), to: UserLib

  @spec delete_user(User) :: {:ok, User} | {:error, Ecto.Changeset}
  defdelegate delete_user(user), to: UserLib

  @spec change_user(User) :: Ecto.Changeset
  defdelegate change_user(user), to: UserLib

  @spec change_user(User, map) :: Ecto.Changeset
  defdelegate change_user(user, attrs), to: UserLib

  # User stat table
  alias Teiserver.Account.UserStat
  alias Teiserver.Account.UserStatLib

  @spec user_stat_query(nil | maybe_improper_list | map) :: Ecto.Query.t()
  def user_stat_query(args) do
    user_stat_query(nil, args)
  end

  def user_stat_query(id, args) do
    UserStatLib.query_user_stats()
    |> UserStatLib.search(%{user_id: id})
    |> UserStatLib.search(args[:search])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of user_stats.

  ## Examples

      iex> list_user_stats()
      [%UserStat{}, ...]

  """
  def list_user_stats(args \\ []) do
    user_stat_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  # @doc """
  # Gets a single user_stat.

  # Returns `nil` if the UserStat does not exist.

  # ## Examples

  #     iex> get_user_stat(123)
  #     %UserStat{}

  #     iex> get_user_stat(456)
  #     nil

  # """
  def get_user_stat(id, args \\ []) when not is_list(id) do
    user_stat_query(id, args)
    |> Repo.one()
  end

  @spec get_user_stat_data(integer()) :: map()
  def get_user_stat_data(userid) do
    Teiserver.cache_get_or_store(:teiserver_user_stat_cache, userid, fn ->
      case get_user_stat(userid) do
        nil ->
          %{}

        user_stat ->
          user_stat.data
      end
    end)
  end

  defp create_user_stat(attrs) do
    %UserStat{}
    |> UserStat.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_stat with data directly.

  ## Examples

      iex> update_user_stat(123, %{field: new_value})
      :ok

  """
  def update_user_stat(userid, data) when is_integer(userid) do
    data =
      data
      |> Enum.map(fn {k, v} -> {to_string(k), v} end)
      |> Enum.filter(fn {_, v} -> v != nil end)
      |> Map.new()

    case get_user_stat(userid) do
      nil ->
        create_user_stat(%{user_id: userid, data: data})

      user_stat ->
        Teiserver.cache_delete(:teiserver_user_stat_cache, userid)
        new_data = Map.merge(user_stat.data, data)
        update_user_stat(user_stat, %{data: new_data})
    end
  end

  # This is the database call, typically you'd not need to use this
  def update_user_stat(%UserStat{} = user_stat, attrs) do
    user_stat
    |> UserStat.changeset(attrs)
    |> Repo.update()
  end

  def delete_user_stat_keys(userid, keys) when is_integer(userid) and is_list(keys) do
    case get_user_stat(userid) do
      nil ->
        :ok

      user_stat ->
        Teiserver.cache_delete(:teiserver_user_stat_cache, userid)
        new_data = Map.drop(user_stat.data, keys)
        update_user_stat(user_stat, %{data: new_data})
    end
  end

  @spec delete_user_stat(UserStat.t()) :: {:ok, UserStat.t()} | {:error, Ecto.Changeset.t()}
  def delete_user_stat(%UserStat{} = user_stat) do
    Teiserver.cache_delete(:teiserver_user_stat_cache, user_stat.user_id)
    Repo.delete(user_stat)
  end

  alias Teiserver.Account.{BadgeType, BadgeTypeLib}

  @spec badge_type_query(List.t()) :: Ecto.Query.t()
  def badge_type_query(args) do
    badge_type_query(nil, args)
  end

  @spec badge_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def badge_type_query(id, args) do
    BadgeTypeLib.query_badge_types()
    |> BadgeTypeLib.search(%{id: id})
    |> BadgeTypeLib.search(args[:search])
    |> BadgeTypeLib.preload(args[:preload])
    |> BadgeTypeLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of badge_types.

  ## Examples

      iex> list_badge_types()
      [%BadgeType{}, ...]

  """
  @spec list_badge_types(List.t()) :: List.t()
  def list_badge_types(args \\ []) do
    badge_type_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @spec list_accolade_types() :: List.t()
  def list_accolade_types() do
    args = [search: [purpose: "Accolade"], order_by: "Name (A-Z)"]

    badge_type_query(args)
    |> Repo.all()
  end

  @doc """
  Gets a single badge_type.

  Raises `Ecto.NoResultsError` if the BadgeType does not exist.

  ## Examples

      iex> get_badge_type!(123)
      %BadgeType{}

      iex> get_badge_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_badge_type!(Integer.t() | List.t()) :: BadgeType.t()
  @spec get_badge_type!(Integer.t(), List.t()) :: BadgeType.t()
  def get_badge_type!(id) when not is_list(id) do
    badge_type_query(id, [])
    |> Repo.one!()
  end

  def get_badge_type!(args) do
    badge_type_query(nil, args)
    |> Repo.one!()
  end

  def get_badge_type!(id, args) do
    badge_type_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single badge_type.

  # Returns `nil` if the BadgeType does not exist.

  # ## Examples

  #     iex> get_badge_type(123)
  #     %BadgeType{}

  #     iex> get_badge_type(456)
  #     nil

  # """
  # def get_badge_type(id, args \\ []) when not is_list(id) do
  #   badge_type_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a badge_type.

  ## Examples

      iex> create_badge_type(%{field: value})
      {:ok, %BadgeType{}}

      iex> create_badge_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_badge_type(map()) :: {:ok, BadgeType.t()} | {:error, Ecto.Changeset.t()}
  def create_badge_type(attrs \\ %{}) do
    %BadgeType{}
    |> BadgeType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a badge_type.

  ## Examples

      iex> update_badge_type(badge_type, %{field: new_value})
      {:ok, %BadgeType{}}

      iex> update_badge_type(badge_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_badge_type(BadgeType.t(), map()) ::
          {:ok, BadgeType.t()} | {:error, Ecto.Changeset.t()}
  def update_badge_type(%BadgeType{} = badge_type, attrs) do
    badge_type
    |> BadgeType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a BadgeType.

  ## Examples

      iex> delete_badge_type(badge_type)
      {:ok, %BadgeType{}}

      iex> delete_badge_type(badge_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_badge_type(BadgeType.t()) :: {:ok, BadgeType.t()} | {:error, Ecto.Changeset.t()}
  def delete_badge_type(%BadgeType{} = badge_type) do
    Repo.delete(badge_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking badge_type changes.

  ## Examples

      iex> change_badge_type(badge_type)
      %Ecto.Changeset{source: %BadgeType{}}

  """
  @spec change_badge_type(BadgeType.t()) :: Ecto.Changeset.t()
  def change_badge_type(%BadgeType{} = badge_type) do
    BadgeType.changeset(badge_type, %{})
  end

  alias Teiserver.Account.Accolade
  alias Teiserver.Account.AccoladeLib

  @spec accolade_query(List.t()) :: Ecto.Query.t()
  def accolade_query(args) do
    accolade_query(nil, args)
  end

  @spec accolade_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def accolade_query(id, args) do
    AccoladeLib.query_accolades()
    |> AccoladeLib.search(%{id: id})
    |> AccoladeLib.search(args[:search])
    |> AccoladeLib.preload(args[:preload])
    |> AccoladeLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of accolades.

  ## Examples

      iex> list_accolades()
      [%Accolade{}, ...]

  """
  @spec list_accolades(List.t()) :: List.t()
  def list_accolades(args \\ []) do
    accolade_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single accolade.

  Raises `Ecto.NoResultsError` if the Accolade does not exist.

  ## Examples

      iex> get_accolade!(123)
      %Accolade{}

      iex> get_accolade!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_accolade!(Integer.t() | List.t()) :: Accolade.t()
  @spec get_accolade!(Integer.t(), List.t()) :: Accolade.t()
  def get_accolade!(id) when not is_list(id) do
    accolade_query(id, [])
    |> Repo.one!()
  end

  def get_accolade!(args) do
    accolade_query(nil, args)
    |> Repo.one!()
  end

  def get_accolade!(id, args) do
    accolade_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single accolade.

  # Returns `nil` if the Accolade does not exist.

  # ## Examples

  #     iex> get_accolade(123)
  #     %Accolade{}

  #     iex> get_accolade(456)
  #     nil

  # """
  # def get_accolade(id, args \\ []) when not is_list(id) do
  #   accolade_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a accolade.

  ## Examples

      iex> create_accolade(%{field: value})
      {:ok, %Accolade{}}

      iex> create_accolade(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_accolade(map()) :: {:ok, Accolade.t()} | {:error, Ecto.Changeset.t()}
  def create_accolade(attrs \\ %{}) do
    %Accolade{}
    |> Accolade.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a accolade.

  ## Examples

      iex> update_accolade(accolade, %{field: new_value})
      {:ok, %Accolade{}}

      iex> update_accolade(accolade, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_accolade(Accolade.t(), map()) ::
          {:ok, Accolade.t()} | {:error, Ecto.Changeset.t()}
  def update_accolade(%Accolade{} = accolade, attrs) do
    accolade
    |> Accolade.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Accolade.

  ## Examples

      iex> delete_accolade(accolade)
      {:ok, %Accolade{}}

      iex> delete_accolade(accolade)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_accolade(Accolade.t()) :: {:ok, Accolade.t()} | {:error, Ecto.Changeset.t()}
  def delete_accolade(%Accolade{} = accolade) do
    Repo.delete(accolade)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking accolade changes.

  ## Examples

      iex> change_accolade(accolade)
      %Ecto.Changeset{source: %Accolade{}}

  """
  @spec change_accolade(Accolade.t()) :: Ecto.Changeset.t()
  def change_accolade(%Accolade{} = accolade) do
    Accolade.changeset(accolade, %{})
  end

  alias Teiserver.Account.SmurfKey
  alias Teiserver.Account.SmurfKeyLib

  @spec smurf_key_query(List.t()) :: Ecto.Query.t()
  def smurf_key_query(args) do
    smurf_key_query(nil, args)
  end

  @spec smurf_key_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def smurf_key_query(id, args) do
    SmurfKeyLib.query_smurf_keys()
    |> SmurfKeyLib.search(%{id: id})
    |> SmurfKeyLib.search(args[:search])
    |> SmurfKeyLib.preload(args[:preload])
    |> SmurfKeyLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of smurf_keys.

  ## Examples

      iex> list_smurf_keys()
      [%SmurfKey{}, ...]

  """
  @spec list_smurf_keys(List.t()) :: List.t()
  def list_smurf_keys(args \\ []) do
    smurf_key_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single smurf_key.

  Raises `Ecto.NoResultsError` if the SmurfKey does not exist.

  ## Examples

      iex> get_smurf_key!(123)
      %SmurfKey{}

      iex> get_smurf_key!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_smurf_key!(Integer.t() | List.t()) :: SmurfKey.t()
  @spec get_smurf_key!(Integer.t(), List.t()) :: SmurfKey.t()
  def get_smurf_key!(id) when not is_list(id) do
    smurf_key_query(id, [])
    |> Repo.one!()
  end

  def get_smurf_key!(args) do
    smurf_key_query(nil, args)
    |> Repo.one!()
  end

  def get_smurf_key!(id, args) do
    smurf_key_query(id, args)
    |> Repo.one!()
  end

  @doc """
  Gets a single smurf_key.

  Returns `nil` if the SmurfKey does not exist.

  ## Examples

      iex> get_smurf_key(123)
      %SmurfKey{}

      iex> get_smurf_key(456)
      nil

  """
  @spec get_smurf_key(Integer.t() | List.t()) :: SmurfKey.t()
  @spec get_smurf_key(Integer.t(), List.t()) :: SmurfKey.t()
  def get_smurf_key(id) when not is_list(id) do
    smurf_key_query(id, [])
    |> Repo.one()
  end

  def get_smurf_key(args) do
    smurf_key_query(nil, args)
    |> Repo.one()
  end

  def get_smurf_key(id, args) do
    smurf_key_query(id, args)
    |> Repo.one()
  end

  @spec get_smurf_key(T.user_id(), non_neg_integer(), String.t()) :: list()
  def get_smurf_key(user_id, type_id, value) do
    smurf_key_query(nil,
      search: [
        user_id: user_id,
        type_id: type_id,
        value: value
      ]
    )
    |> Repo.all()
  end

  @doc """
  Creates a smurf_key.

  ## Examples

      iex> create_smurf_key(%{field: value})
      {:ok, %SmurfKey{}}

      iex> create_smurf_key(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_smurf_key(non_neg_integer(), String.t(), String.t()) ::
          {:ok, SmurfKey.t()} | {:error, Ecto.Changeset.t()}
  def create_smurf_key(user_id, type_name, value) do
    type_id = get_or_add_smurf_key_type(type_name)

    case get_smurf_key(user_id, type_id, value) do
      [] ->
        %SmurfKey{}
        |> SmurfKey.changeset(%{
          user_id: user_id,
          value: value,
          type_id: type_id,
          last_updated: Timex.now()
        })
        |> Repo.insert()

      [existing] ->
        update_smurf_key(existing, %{last_updated: Timex.now()})
        {:ok, existing}

      [existing | _] ->
        Logger.error(
          "#{__MODULE__}.create_smurf_key found user with two identical keys: #{user_id}, #{type_id}, #{value}"
        )

        {:ok, existing}
    end
  end

  @doc """
  Updates a smurf_key.

  ## Examples

      iex> update_smurf_key(smurf_key, %{field: new_value})
      {:ok, %SmurfKey{}}

      iex> update_smurf_key(smurf_key, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_smurf_key(SmurfKey.t(), map()) ::
          {:ok, SmurfKey.t()} | {:error, Ecto.Changeset.t()}
  def update_smurf_key(%SmurfKey{} = smurf_key, attrs) do
    smurf_key
    |> SmurfKey.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SmurfKey.

  ## Examples

      iex> delete_smurf_key(smurf_key)
      {:ok, %SmurfKey{}}

      iex> delete_smurf_key(smurf_key)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_smurf_key(SmurfKey.t()) :: {:ok, SmurfKey.t()} | {:error, Ecto.Changeset.t()}
  def delete_smurf_key(%SmurfKey{} = smurf_key) do
    Repo.delete(smurf_key)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking smurf_key changes.

  ## Examples

      iex> change_smurf_key(smurf_key)
      %Ecto.Changeset{source: %SmurfKey{}}

  """
  @spec change_smurf_key(SmurfKey.t()) :: Ecto.Changeset.t()
  def change_smurf_key(%SmurfKey{} = smurf_key) do
    SmurfKey.changeset(smurf_key, %{})
  end

  @spec smurf_search(User.t()) :: [{{String.t(), String.t()}, [SmurfKey.t()]}]
  def smurf_search(user) do
    values =
      list_smurf_keys(
        search: [
          user_id: user.id
        ],
        limit: :infinity,
        select: [:value]
      )
      |> Enum.map(fn %{value: value} -> value end)

    list_smurf_keys(
      search: [
        value_in: values,
        not_user_id: user.id
      ],
      preload: [:user, :type],
      limit: :infinity
    )
    |> Enum.group_by(fn sk -> {sk.type.name, sk.value} end)
    |> Enum.sort_by(fn {key, _value} -> key end, &<=/2)
  end

  alias Teiserver.Account.SmurfKeyType
  alias Teiserver.Account.SmurfKeyTypeLib

  @spec smurf_key_type_query(List.t()) :: Ecto.Query.t()
  def smurf_key_type_query(args) do
    smurf_key_type_query(nil, args)
  end

  @spec smurf_key_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def smurf_key_type_query(id, args) do
    SmurfKeyTypeLib.query_smurf_key_types()
    |> SmurfKeyTypeLib.search(%{id: id})
    |> SmurfKeyTypeLib.search(args[:search])
    |> SmurfKeyTypeLib.preload(args[:preload])
    |> SmurfKeyTypeLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of smurf_key_types.

  ## Examples

      iex> list_smurf_key_types()
      [%SmurfKeyType{}, ...]

  """
  @spec list_smurf_key_types(List.t()) :: List.t()
  def list_smurf_key_types(args \\ []) do
    smurf_key_type_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single smurf_key_type.

  Raises `Ecto.NoResultsError` if the SmurfKeyType does not exist.

  ## Examples

      iex> get_smurf_key_type(123)
      %SmurfKeyType{}

      iex> get_smurf_key_type(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_smurf_key_type(Integer.t() | List.t()) :: SmurfKeyType.t()
  @spec get_smurf_key_type(Integer.t(), List.t()) :: SmurfKeyType.t()
  def get_smurf_key_type(id) when not is_list(id) do
    smurf_key_type_query(id, [])
    |> Repo.one()
  end

  def get_smurf_key_type(args) do
    smurf_key_type_query(nil, args)
    |> Repo.one()
  end

  def get_smurf_key_type(id, args) do
    smurf_key_type_query(id, args)
    |> Repo.one()
  end

  @doc """
  Creates a smurf_key_type.

  ## Examples

      iex> create_smurf_key_type(%{field: value})
      {:ok, %SmurfKeyType{}}

      iex> create_smurf_key_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_smurf_key_type(map()) :: {:ok, SmurfKeyType.t()} | {:error, Ecto.Changeset.t()}
  def create_smurf_key_type(attrs \\ %{}) do
    %SmurfKeyType{}
    |> SmurfKeyType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Deletes a SmurfKeyType.

  ## Examples

      iex> delete_smurf_key_type(smurf_key_type)
      {:ok, %SmurfKeyType{}}

      iex> delete_smurf_key_type(smurf_key_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_smurf_key_type(SmurfKeyType.t()) ::
          {:ok, SmurfKeyType.t()} | {:error, Ecto.Changeset.t()}
  def delete_smurf_key_type(%SmurfKeyType{} = smurf_key_type) do
    Repo.delete(smurf_key_type)
  end

  def get_or_add_smurf_key_type(name) do
    name = String.trim(name)

    Teiserver.cache_get_or_store(:teiserver_account_smurf_key_types, name, fn ->
      case list_smurf_key_types(
             search: [name: name],
             select: [:id],
             order_by: "ID (Lowest first)"
           ) do
        [] ->
          {:ok, key_type} =
            %SmurfKeyType{}
            |> SmurfKeyType.changeset(%{name: name})
            |> Repo.insert()

          key_type.id

        [%{id: id} | _] ->
          id
      end
    end)
  end

  alias Teiserver.Account.{Rating, RatingLib}

  @spec rating_query(List.t()) :: Ecto.Query.t()
  def rating_query(args) do
    RatingLib.query_ratings()
    |> RatingLib.search(args[:search])
    |> RatingLib.preload(args[:preload])
    |> RatingLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
    |> QueryHelpers.limit_query(args[:limit] || 50)
  end

  @doc """
  Returns the list of ratings.

  ## Examples

      iex> list_ratings()
      [%Rating{}, ...]

  """
  @spec list_ratings(List.t()) :: List.t()
  def list_ratings(args \\ []) do
    rating_query(args)
    |> Repo.all()
  end

  @doc """
  Gets a single rating.

  Raises `Ecto.NoResultsError` if the Rating does not exist.

  ## Examples

      iex> get_rating(123)
      %Rating{}

      iex> get_rating(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_rating(Integer.t() | List.t()) :: Rating.t()
  @spec get_rating(Integer.t(), List.t()) :: Rating.t()
  def get_rating(args) do
    rating_query(args)
    |> Repo.one()
  end

  def get_rating(user_id, rating_type_id)
      when is_integer(user_id) and is_integer(rating_type_id) do
    get_rating(user_id, rating_type_id, MatchRatingLib.active_season())
  end

  def get_rating(user_id, rating_type_id, season)
      when is_integer(user_id) and is_integer(rating_type_id) and is_integer(season) do
    Teiserver.cache_get_or_store(:teiserver_user_ratings, {user_id, rating_type_id, season}, fn ->
      rating_query(
        search: [
          user_id: user_id,
          rating_type_id: rating_type_id,
          season: season
        ],
        limit: 1
      )
      |> Repo.one()
    end)
  end

  @spec get_player_highest_leaderboard_rating(T.userid()) :: number()
  def get_player_highest_leaderboard_rating(user_id) do
    get_player_highest_leaderboard_rating(user_id, MatchRatingLib.active_season())
  end

  @spec get_player_highest_leaderboard_rating(T.userid(), integer()) :: number()
  def get_player_highest_leaderboard_rating(user_id, season) do
    result =
      rating_query(
        search: [
          user_id: user_id,
          season: season
        ],
        select: [:leaderboard_rating],
        order_by: "Leaderboard rating high to low",
        limit: 1
      )
      |> Repo.one()

    if result do
      result.leaderboard_rating
    else
      0
    end
  end

  @spec get_player_lowest_uncertainty(T.userid()) :: number()
  def get_player_lowest_uncertainty(user_id) do
    result =
      rating_query(
        search: [
          user_id: user_id
        ],
        select: [:uncertainty],
        order_by: "Uncertainty low to high",
        limit: 1
      )
      |> Repo.one()

    if result do
      result.uncertainty
    else
      0
    end
  end

  @doc """
  Creates a rating.

  ## Examples

      iex> create_rating(%{field: value})
      {:ok, %Rating{}}

      iex> create_rating(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_rating(map()) :: {:ok, Rating.t()} | {:error, Ecto.Changeset.t()}
  def create_rating(attrs \\ %{}) do
    %Rating{}
    |> Rating.changeset(attrs)
    |> Repo.insert()
  end

  @spec update_rating(Rating.t(), map()) :: {:ok, Rating.t()} | {:error, Ecto.Changeset.t()}
  def update_rating(%Rating{} = rating, attrs) do
    Teiserver.cache_delete(:teiserver_user_ratings, {rating.user_id, rating.rating_type_id})

    rating
    |> Rating.changeset(attrs)
    |> Repo.update()
  end

  @spec create_or_update_rating(map()) :: {:ok, Rating.t()} | {:error, Ecto.Changeset.t()}
  def create_or_update_rating(attrs \\ %{}) do
    case get_rating(attrs.user_id, attrs.rating_type_id) do
      nil ->
        create_rating(attrs)

      existing ->
        update_rating(existing, attrs)
    end
  end

  @doc """
  Deletes a Rating.

  ## Examples

      iex> delete_rating(rating)
      {:ok, %Rating{}}

      iex> delete_rating(rating)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_rating(Rating.t()) :: {:ok, Rating.t()} | {:error, Ecto.Changeset.t()}
  def delete_rating(%Rating{} = rating) do
    Teiserver.cache_delete(:teiserver_user_ratings, {rating.user_id, rating.rating_type_id})
    Repo.delete(rating)
  end

  # Codes
  alias Teiserver.Account.{Code, CodeLib}

  def code_query(args) do
    code_query(nil, args)
  end

  def code_query(value, args) do
    CodeLib.query_codes()
    |> CodeLib.search(%{value: value})
    |> CodeLib.search(args[:search])
    |> CodeLib.preload(args[:preload])
    |> CodeLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of codes.

  ## Examples

      iex> list_codes()
      [%Code{}, ...]

  """
  def list_codes(args \\ []) do
    code_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single code.

  Raises `Ecto.NoResultsError` if the Code does not exist.

  ## Examples

      iex> get_code!(123)
      %Code{}

      iex> get_code!(456)
      ** (Ecto.NoResultsError)

  """
  def get_code(value, args \\ []) do
    code_query(value, args)
    |> QueryHelpers.limit_query(args[:limit] || 1)
    |> Repo.one()
  end

  def get_code!(value, args \\ []) do
    code_query(value, args)
    |> QueryHelpers.limit_query(args[:limit] || 1)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single code.

  # Returns `nil` if the Code does not exist.

  # ## Examples

  #     iex> get_code(123)
  #     %Code{}

  #     iex> get_code(456)
  #     nil

  # """
  # def get_code(id, args \\ []) when not is_list(id) do
  #   code_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a code.

  ## Examples

      iex> create_code(%{field: value})
      {:ok, %Code{}}

      iex> create_code(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_code(map) :: {:ok, Code.t()} | {:error, Ecto.Changeset.t()}
  def create_code(attrs \\ %{}) do
    %Code{}
    |> Code.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a code.

  ## Examples

      iex> update_code(code, %{field: new_value})
      {:ok, %Code{}}

      iex> update_code(code, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_code(%Code{} = code, attrs) do
    code
    |> Code.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Code.

  ## Examples

      iex> delete_code(code)
      {:ok, %Code{}}

      iex> delete_code(code)
      {:error, %Ecto.Changeset{}}

  """
  def delete_code(%Code{} = code) do
    Repo.delete(code)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking code changes.

  ## Examples

      iex> change_code(code)
      %Ecto.Changeset{source: %Code{}}

  """
  def change_code(%Code{} = code) do
    Code.changeset(code, %{})
  end

  alias Teiserver.Account.{UserToken, UserTokenLib}

  def user_token_query(args) do
    user_token_query(nil, args)
  end

  def user_token_query(id, args) do
    UserTokenLib.query_user_tokens()
    |> UserTokenLib.search(%{id: id})
    |> UserTokenLib.search(args[:search])
    |> UserTokenLib.preload(args[:preload])
    |> UserTokenLib.order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
  end

  @doc """
  Returns the list of user_tokens.

  ## Examples

      iex> list_user_tokens()
      [%UserToken{}, ...]

  """
  def list_user_tokens(args \\ []) do
    user_token_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single user_token.

  Raises `Ecto.NoResultsError` if the UserToken does not exist.

  ## Examples

      iex> get_user_token!(123)
      %UserToken{}

      iex> get_user_token!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user_token(id, args \\ []) do
    user_token_query(id, args)
    |> QueryHelpers.limit_query(args[:limit] || 1)
    |> Repo.one()
  end

  def get_user_token!(id, args \\ []) do
    user_token_query(id, args)
    |> QueryHelpers.limit_query(args[:limit] || 1)
    |> Repo.one!()
  end

  @spec get_user_token_by_value(String.t()) :: UserToken.t() | nil
  def get_user_token_by_value(value) do
    user_token_query(nil,
      search: [
        value: value
      ],
      preload: [
        :user
      ]
    )
    |> QueryHelpers.limit_query(1)
    |> Repo.one()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single user_token.

  # Returns `nil` if the UserToken does not exist.

  # ## Examples

  #     iex> get_user_token(123)
  #     %UserToken{}

  #     iex> get_user_token(456)
  #     nil

  # """
  # def get_user_token(id, args \\ []) when not is_list(id) do
  #   user_token_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a user_token.

  ## Examples

      iex> create_user_token(%{field: value})
      {:ok, %UserToken{}}

      iex> create_user_token(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user_token(attrs \\ %{}) do
    %UserToken{}
    |> UserToken.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user_token.

  ## Examples

      iex> update_user_token(user_token, %{field: new_value})
      {:ok, %UserToken{}}

      iex> update_user_token(user_token, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user_token(%UserToken{} = user_token, attrs) do
    user_token
    |> UserToken.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a UserToken.

  ## Examples

      iex> delete_user_token(user_token)
      {:ok, %UserToken{}}

      iex> delete_user_token(user_token)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user_token(%UserToken{} = user_token) do
    Repo.delete(user_token)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user_token changes.

  ## Examples

      iex> change_user_token(user_token)
      %Ecto.Changeset{source: %UserToken{}}

  """
  def change_user_token(%UserToken{} = user_token) do
    UserToken.changeset(user_token, %{})
  end

  def create_token_value(length \\ 128) do
    :crypto.strong_rand_bytes(length)
    |> Base.encode64(padding: false)
    |> binary_part(0, length)
  end

  alias Teiserver.Account.{Relationship, RelationshipLib, RelationshipQueries}

  @doc """
  Returns the list of relationships.

  ## Examples

      iex> list_relationships()
      [%Relationship{}, ...]

  """
  @spec list_relationships(list) :: list
  def list_relationships(args \\ []) do
    args
    |> RelationshipQueries.query_relationships()
    |> Repo.all()
  end

  @doc """
  Gets a single relationship.

  Raises `Ecto.NoResultsError` if the Relationship does not exist.

  ## Examples

      iex> get_relationship!(123)
      %Relationship{}

      iex> get_relationship!(456)
      ** (Ecto.NoResultsError)

  """
  def get_relationship!(from_id, to_id), do: get_relationship!(from_id, to_id, [])

  def get_relationship!(from_id, to_id, args) do
    args = args ++ [from_user_id: from_id, to_user_id: to_id]

    args
    |> RelationshipQueries.query_relationships()
    |> Repo.one!()
  end

  @doc """
  Gets a single relationship, returns nil if the relationship doesn't exist

  ## Examples

      iex> get_relationship(123)
      %Relationship{}

      iex> get_relationship(456)
      nil

  """
  def get_relationship(from_id, to_id), do: get_relationship(from_id, to_id, [])

  def get_relationship(from_id, to_id, args) do
    args = args ++ [from_user_id: from_id, to_user_id: to_id]

    args
    |> RelationshipQueries.query_relationships()
    |> Repo.one()
  end

  @doc """
  Creates a relationship.

  ## Examples

      iex> create_relationship(%{field: value})
      {:ok, %Relationship{}}

      iex> create_relationship(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_relationship(attrs \\ %{}) do
    %Relationship{}
    |> Relationship.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates or inserts a relationship.

  ## Examples

      iex> upsert(%{field: value})
      {:ok, %Relationship{}}

      iex> upsert(%{field: value})
      {:error, %Ecto.Changeset{}}

  """
  def upsert_relationship(attrs) do
    conflict_sets =
      ~w(state ignore notes tags)a
      |> Enum.filter(fn key ->
        Map.has_key?(attrs, key) or Map.has_key?(attrs, to_string(key))
      end)
      |> Enum.map(fn key ->
        value = Map.get(attrs, key, Map.get(attrs, to_string(key), nil))
        {key, value}
      end)
      |> Keyword.new()

    %Relationship{}
    |> Relationship.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: conflict_sets],
      conflict_target: ~w(from_user_id to_user_id)a
    )

    # %Relationship{}
    # |> Relationship.changeset(attrs)
    # |> Repo.insert(
    #   on_conflict: [set: [
    #     state: Map.get(attrs, "state", Map.get(attrs, :state, nil)),
    #     ignore: Map.get(attrs, "ignore", Map.get(attrs, :ignore, nil)),
    #     notes: Map.get(attrs, "notes", Map.get(attrs, :notes, nil)),
    #     tags: Map.get(attrs, "tags", Map.get(attrs, :tags, nil))
    #   ]],
    #   conflict_target: ~w(from_user_id to_user_id)a
    # )
  end

  @doc """
  Updates a relationship.

  ## Examples

      iex> update_relationship(relationship, %{field: new_value})
      {:ok, %Relationship{}}

      iex> update_relationship(relationship, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_relationship(%Relationship{} = relationship, attrs) do
    relationship
    |> Relationship.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a relationship.

  ## Examples

      iex> delete_relationship(relationship)
      {:ok, %Relationship{}}

      iex> delete_relationship(relationship)
      {:error, %Ecto.Changeset{}}

  """
  def delete_relationship(%Relationship{} = relationship) do
    Repo.delete(relationship)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking relationship changes.

  ## Examples

      iex> change_relationship(relationship)
      %Ecto.Changeset{data: %Relationship{}}

  """
  def change_relationship(%Relationship{} = relationship, attrs \\ %{}) do
    Relationship.changeset(relationship, attrs)
  end

  @spec verb_of_state(String.t() | map) :: String.t()
  defdelegate verb_of_state(state), to: RelationshipLib

  @spec past_tense_of_state(String.t() | map) :: String.t()
  defdelegate past_tense_of_state(state), to: RelationshipLib

  @spec follow_user(T.userid(), T.userid()) :: {:ok, Relationship.t()}
  defdelegate follow_user(from_user_id, to_user_id), to: RelationshipLib

  @spec ignore_user(T.userid(), T.userid()) :: {:ok, Relationship.t()}
  defdelegate ignore_user(from_user_id, to_user_id), to: RelationshipLib

  @spec unignore_user(T.userid(), T.userid()) :: {:ok, Relationship.t()}
  defdelegate unignore_user(from_user_id, to_user_id), to: RelationshipLib

  @spec avoid_user(T.userid(), T.userid()) :: {:ok, Relationship.t()}
  defdelegate avoid_user(from_user_id, to_user_id), to: RelationshipLib

  @spec block_user(T.userid(), T.userid()) :: {:ok, Relationship.t()}
  defdelegate block_user(from_user_id, to_user_id), to: RelationshipLib

  @spec reset_relationship_state(T.userid(), T.userid()) :: {:ok, Relationship.t()}
  defdelegate reset_relationship_state(from_user_id, to_user_id), to: RelationshipLib

  @spec calculate_relationship_stats(T.userid()) :: :ok
  defdelegate calculate_relationship_stats(userid), to: RelationshipLib

  @spec decache_relationships(T.userid()) :: :ok
  defdelegate decache_relationships(userid), to: RelationshipLib

  @spec list_userids_avoiding_this_userid(T.userid()) :: [T.userid()]
  defdelegate list_userids_avoiding_this_userid(userid), to: RelationshipLib

  @spec list_userids_avoided_by_userid(T.userid()) :: [T.userid()]
  defdelegate list_userids_avoided_by_userid(userid), to: RelationshipLib

  @spec list_userids_blocking_this_userid(T.userid()) :: [T.userid()]
  defdelegate list_userids_blocking_this_userid(userid), to: RelationshipLib

  @spec list_userids_blocked_by_userid(T.userid()) :: [T.userid()]
  defdelegate list_userids_blocked_by_userid(userid), to: RelationshipLib

  @spec list_userids_ignored_by_userid(T.userid()) :: [T.userid()]
  defdelegate list_userids_ignored_by_userid(userid), to: RelationshipLib

  @spec list_userids_followed_by_userid(T.userid()) :: [T.userid()]
  defdelegate list_userids_followed_by_userid(userid), to: RelationshipLib

  @spec does_a_follow_b?(T.userid(), T.userid()) :: boolean
  defdelegate does_a_follow_b?(u1, u2), to: RelationshipLib

  @spec does_a_ignore_b?(T.userid(), T.userid()) :: boolean
  defdelegate does_a_ignore_b?(u1, u2), to: RelationshipLib

  @spec does_a_block_b?(T.userid(), T.userid()) :: boolean
  defdelegate does_a_block_b?(u1, u2), to: RelationshipLib

  @spec does_a_avoid_b?(T.userid(), T.userid()) :: boolean
  defdelegate does_a_avoid_b?(u1, u2), to: RelationshipLib

  @spec check_block_status(T.userid(), [T.userid()]) :: :ok | :blocking | :blocked
  defdelegate check_block_status(userid, userid_list), to: RelationshipLib

  @spec profile_view_permissions(
          T.user(),
          T.user(),
          nil | Account.Relationship,
          nil | Account.Friend,
          nil | Account.FriendRequest
        ) :: [atom]
  defdelegate profile_view_permissions(u1, u2, relationship, friend, friendship_request),
    to: RelationshipLib

  alias Teiserver.Account.{Friend, FriendLib, FriendQueries}

  @doc """
  Returns the list of friends.

  ## Examples

      iex> list_friends()
      [%Friend{}, ...]

  """
  @spec list_friends(list) :: list
  def list_friends(args \\ []) do
    args
    |> FriendQueries.query_friends()
    |> Repo.all()
  end

  @doc """
  Returns the list of friends for the given user
  """
  @spec list_friends_for_user(map() | T.userid()) :: [map()]
  def list_friends_for_user(%{id: id}), do: list_friends_for_user(id)

  def list_friends_for_user(user_id) do
    FriendQueries.query_friends(where: [either_user_is: user_id])
    |> Repo.all()
  end

  @doc """
  Gets a single friend.

  Raises `Ecto.NoResultsError` if the Friend does not exist.

  ## Examples

      iex> get_friend!(123)
      %Friend{}

      iex> get_friend!(456)
      ** (Ecto.NoResultsError)

  """
  def get_friend!(from_id, to_id), do: get_friend!(from_id, to_id, [])

  def get_friend!(from_id, to_id, args) do
    args = args ++ [users: [from_id, to_id]]

    args
    |> FriendQueries.query_friends()
    |> Repo.one!()
  end

  @doc """
  Gets a single friend, returns nil if the friend doesn't exist

  ## Examples

      iex> get_friend(123)
      %Friend{}

      iex> get_friend(456)
      nil

  """
  def get_friend(from_id, to_id), do: get_friend(from_id, to_id, [])

  def get_friend(from_id, to_id, args) do
    args = args ++ [users: [from_id, to_id]]

    args
    |> FriendQueries.query_friends()
    |> Repo.one()
  end

  @doc """
  Creates a friend.

  ## Examples

      iex> create_friend(%{field: value})
      {:ok, %Friend{}}

      iex> create_friend(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_friend() :: {:ok, Friend.t()} | {:error, Ecto.Changeset.t()}
  @spec create_friend(map) :: {:ok, Friend.t()} | {:error, Ecto.Changeset.t()}
  def create_friend(attrs \\ %{}) do
    result =
      %Friend{}
      |> Friend.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, friend} ->
        Teiserver.cache_delete(:account_friend_cache, friend.user1_id)
        Teiserver.cache_delete(:account_friend_cache, friend.user2_id)

      _ ->
        :ok
    end

    result
  end

  @spec create_friend(T.userid(), T.userid()) :: {:ok, Friend.t()} | {:error, Ecto.Changeset.t()}
  def create_friend(uid1, uid2) do
    [u1, u2] = Enum.sort([uid1, uid2])

    create_friend(%{
      user1_id: u1,
      user2_id: u2
    })
  end

  @doc """
  Updates a friend.

  ## Examples

      iex> update_friend(friend, %{field: new_value})
      {:ok, %Friend{}}

      iex> update_friend(friend, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_friend(%Friend{} = friend, attrs) do
    friend
    |> Friend.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a friend.

  ## Examples

      iex> delete_friend(friend)
      {:ok, %Friend{}}

      iex> delete_friend(friend)
      {:error, %Ecto.Changeset{}}

  """
  def delete_friend(%Friend{} = friend) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "account_user_relationships:#{friend.user1_id}",
      %{
        channel: "account_user_relationships:#{friend.user1_id}",
        event: :friend_deleted,
        userid: friend.user1_id,
        from_id: friend.user2_id
      }
    )

    PubSub.broadcast(
      Teiserver.PubSub,
      "account_user_relationships:#{friend.user2_id}",
      %{
        channel: "account_user_relationships:#{friend.user2_id}",
        event: :friend_deleted,
        userid: friend.user2_id,
        from_id: friend.user1_id
      }
    )

    Teiserver.cache_delete(:account_friend_cache, friend.user1_id)
    Teiserver.cache_delete(:account_friend_cache, friend.user2_id)
    Repo.delete(friend)
  end

  def delete_friend(u1, u2) do
    case get_friend(u1, u2) do
      nil ->
        :ok

      friend ->
        delete_friend(friend)
    end
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking friend changes.

  ## Examples

      iex> change_friend(friend)
      %Ecto.Changeset{data: %Friend{}}

  """
  def change_friend(%Friend{} = friend, attrs \\ %{}) do
    Friend.changeset(friend, attrs)
  end

  @spec list_friend_ids_of_user(T.userid()) :: [T.userid()]
  defdelegate list_friend_ids_of_user(userid), to: FriendLib

  alias Teiserver.Account.{FriendRequest, FriendRequestLib, FriendRequestQueries}

  @doc """
  Returns the list of friend_requests.

  ## Examples

      iex> list_friend_requests()
      [%FriendRequest{}, ...]

  """
  @spec list_friend_requests(list) :: list
  def list_friend_requests(args \\ []) do
    args
    |> FriendRequestQueries.query_friend_requests()
    |> Repo.all()
  end

  @doc """
  Gets a single friend_request.

  Raises `Ecto.NoResultsError` if the FriendRequest does not exist.

  ## Examples

      iex> get_friend_request!(123)
      %FriendRequest{}

      iex> get_friend_request!(456)
      ** (Ecto.NoResultsError)

  """
  def get_friend_request!(from_id, to_id), do: get_friend_request!(from_id, to_id, [])

  def get_friend_request!(from_id, to_id, args) do
    args = args ++ [from_user_id: from_id, to_user_id: to_id]

    args
    |> FriendRequestQueries.query_friend_requests()
    |> Repo.one!()
  end

  @doc """
  Gets a single friend_request, returns nil if the friend_request doesn't exist

  ## Examples

      iex> get_friend_request(123)
      %FriendRequest{}

      iex> get_friend_request(456)
      nil

  """
  def get_friend_request(from_id, to_id), do: get_friend_request(from_id, to_id, [])

  def get_friend_request(from_id, to_id, args) do
    args = args ++ [from_user_id: from_id, to_user_id: to_id]

    args
    |> FriendRequestQueries.query_friend_requests()
    |> Repo.one()
  end

  @doc """
  Creates a friend_request.

  ## Examples

      iex> create_friend_request(%{field: value})
      {:ok, %FriendRequest{}}

      iex> create_friend_request(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_friend_request(attrs \\ %{}) do
    result =
      %FriendRequest{}
      |> FriendRequest.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, friend_request} ->
        PubSub.broadcast(
          Teiserver.PubSub,
          "account_user_relationships:#{friend_request.to_user_id}",
          %{
            channel: "account_user_relationships:#{friend_request.to_user_id}",
            event: :new_incoming_friend_request,
            userid: friend_request.to_user_id,
            from_id: friend_request.from_user_id
          }
        )

        Teiserver.cache_delete(:account_incoming_friend_request_cache, friend_request.to_user_id)
        Teiserver.cache_delete(:account_outgoing_friend_request_cache, friend_request.to_user_id)

      _ ->
        :ok
    end

    result
  end

  def create_friend_request(from_user_id, to_user_id) do
    if from_user_id == to_user_id do
      {:error, "Cannot add yourself as a friend"}
    else
      create_friend_request(%{
        from_user_id: from_user_id,
        to_user_id: to_user_id
      })
    end
  end

  @doc """
  Updates a friend_request.

  ## Examples

      iex> update_friend_request(friend_request, %{field: new_value})
      {:ok, %FriendRequest{}}

      iex> update_friend_request(friend_request, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_friend_request(%FriendRequest{} = friend_request, attrs) do
    friend_request
    |> FriendRequest.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a friend_request.

  ## Examples

      iex> delete_friend_request(friend_request)
      {:ok, %FriendRequest{}}

      iex> delete_friend_request(friend_request)
      {:error, %Ecto.Changeset{}}

  """
  def delete_friend_request(%FriendRequest{} = friend_request) do
    Teiserver.cache_delete(:account_incoming_friend_request_cache, friend_request.to_user_id)
    Teiserver.cache_delete(:account_outgoing_friend_request_cache, friend_request.from_user_id)
    Repo.delete(friend_request)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking friend_request changes.

  ## Examples

      iex> change_friend_request(friend_request)
      %Ecto.Changeset{data: %FriendRequest{}}

  """
  def change_friend_request(%FriendRequest{} = friend_request, attrs \\ %{}) do
    FriendRequest.changeset(friend_request, attrs)
  end

  @spec can_send_friend_request?(T.userid(), T.userid()) :: boolean
  defdelegate can_send_friend_request?(from_id, to_id), to: FriendRequestLib

  @spec can_send_friend_request_with_reason?(T.userid(), T.userid()) ::
          {true, :ok} | {false, String.t()}
  defdelegate can_send_friend_request_with_reason?(from_id, to_id), to: FriendRequestLib

  @spec list_outgoing_friend_requests_of_userid(T.userid()) :: [T.userid()]
  defdelegate list_outgoing_friend_requests_of_userid(userid), to: FriendRequestLib

  @spec list_requests_for_user(T.userid()) :: {outgoing :: [map()], incoming :: [map()]}
  defdelegate list_requests_for_user(userid), to: FriendRequestLib

  @spec list_incoming_friend_requests_of_userid(T.userid()) :: [T.userid()]
  defdelegate list_incoming_friend_requests_of_userid(userid), to: FriendRequestLib

  @spec accept_friend_request(T.userid(), T.userid()) :: :ok | {:error, String.t()}
  defdelegate accept_friend_request(from_userid, to_userid), to: FriendRequestLib

  @spec accept_friend_request(FriendRequest.t()) :: :ok | {:error, String.t()}
  defdelegate accept_friend_request(req), to: FriendRequestLib

  @spec decline_friend_request(T.userid(), T.userid()) :: :ok | {:error, String.t()}
  defdelegate decline_friend_request(from_userid, to_userid), to: FriendRequestLib

  @spec decline_friend_request(FriendRequest.t()) :: :ok | {:error, String.t()}
  defdelegate decline_friend_request(req), to: FriendRequestLib

  @spec rescind_friend_request(T.userid(), T.userid()) :: :ok | {:error, String.t()}
  defdelegate rescind_friend_request(from_userid, to_userid), to: FriendRequestLib

  @spec rescind_friend_request(FriendRequest.t()) :: :ok | {:error, String.t()}
  defdelegate rescind_friend_request(req), to: FriendRequestLib

  # User functions
  alias Teiserver.Account.UserCacheLib

  @spec get_username(T.userid()) :: String.t() | nil
  defdelegate get_username(userid), to: UserCacheLib

  @spec get_username_by_id(T.userid()) :: String.t() | nil
  defdelegate get_username_by_id(userid), to: UserCacheLib

  @spec get_userid_from_name(String.t()) :: integer() | nil
  def get_userid_from_name(name), do: UserCacheLib.get_userid(name)

  @spec get_user_by_name(String.t()) :: T.user() | nil
  defdelegate get_user_by_name(username), to: UserCacheLib

  @spec get_user_by_email(String.t()) :: T.user() | nil
  defdelegate get_user_by_email(email), to: UserCacheLib

  @spec get_user_by_discord_id(String.t()) :: T.user() | nil
  defdelegate get_user_by_discord_id(discord_id), to: UserCacheLib

  @spec get_userid_by_discord_id(String.t()) :: T.userid() | nil
  defdelegate get_userid_by_discord_id(discord_id), to: UserCacheLib

  @spec get_user_by_token(String.t()) :: T.user() | nil
  defdelegate get_user_by_token(token), to: UserCacheLib

  @spec get_user_by_id(T.userid()) :: T.user() | nil
  defdelegate get_user_by_id(id), to: UserCacheLib

  @spec list_users_from_cache(list) :: list
  def list_users_from_cache(id_list), do: UserCacheLib.list_users(id_list)

  @spec recache_user(T.userid() | User.t()) :: :ok
  defdelegate recache_user(id), to: UserCacheLib

  @spec convert_user(T.user()) :: T.user()
  defdelegate convert_user(user), to: UserCacheLib

  @spec add_user(T.user()) :: T.user()
  defdelegate add_user(user), to: UserCacheLib

  @spec update_cache_user(T.userid(), map()) :: T.user()
  def update_cache_user(userid, user), do: UserCacheLib.update_cache_user(userid, user)

  @spec decache_user(T.userid()) :: :ok | :no_user
  defdelegate decache_user(userid), to: UserCacheLib

  @spec make_bot_password() :: String.t()
  defdelegate make_bot_password(), to: UserLib

  @spec rename_user(T.userid(), String.t(), boolean) :: :success | {:error, String.t()}
  defdelegate rename_user(userid, new_name, admin_action \\ false), to: Teiserver.CacheUser

  @spec valid_name?(String.t(), boolean()) :: :ok | {:error, String.t()}
  defdelegate valid_name?(new_name, admin_action), to: Teiserver.CacheUser

  @spec system_change_user_name(T.userid(), String.t()) :: :ok
  defdelegate system_change_user_name(userid, new_name), to: Teiserver.CacheUser

  @spec has_any_role?(T.userid() | T.user() | nil, String.t() | [String.t()]) :: boolean()
  defdelegate has_any_role?(user_or_userid, roles), to: Teiserver.CacheUser

  @spec has_all_roles?(T.userid() | T.user() | nil, String.t() | [String.t()]) :: boolean()
  defdelegate has_all_roles?(user_or_userid, roles), to: Teiserver.CacheUser

  @spec is_moderator?(T.userid()) :: boolean()
  defdelegate is_moderator?(userid), to: Teiserver.CacheUser

  @spec is_bot?(T.userid()) :: boolean()
  defdelegate is_bot?(userid), to: Teiserver.CacheUser

  @spec is_restricted?(T.userid() | T.user(), String.t()) :: boolean()
  defdelegate is_restricted?(user, restriction), to: Teiserver.CacheUser

  # Client stuff
  alias Teiserver.Account.ClientLib

  @spec get_client_by_name(String.t()) :: nil | T.client()
  defdelegate get_client_by_name(name), to: ClientLib

  @spec get_client_by_id(T.userid()) :: nil | T.client()
  defdelegate get_client_by_id(userid), to: ClientLib

  @spec client_exists?(T.userid()) :: boolean()
  defdelegate client_exists?(userid), to: ClientLib

  @spec get_clients([T.userid()]) :: List.t()
  defdelegate get_clients(id_list), to: ClientLib

  @spec list_client_ids() :: [T.userid()]
  defdelegate list_client_ids(), to: ClientLib

  @spec list_clients() :: [T.client()]
  defdelegate list_clients(), to: ClientLib

  @spec list_clients([T.userid()]) :: [T.client()]
  defdelegate list_clients(id_list), to: ClientLib

  @spec update_client(T.userid(), map()) :: nil | :ok
  defdelegate update_client(userid, partial_client), to: ClientLib

  # TODO: Remove these in favour of update_client
  @spec merge_update_client(map()) :: nil | :ok
  defdelegate merge_update_client(client), to: ClientLib

  @spec merge_update_client(T.userid(), map()) :: nil | :ok
  defdelegate merge_update_client(userid, client), to: ClientLib

  @spec replace_update_client(
          map(),
          :silent | :client_updated_status | :client_updated_battlestatus
        ) :: T.client()
  defdelegate replace_update_client(client, reason), to: ClientLib

  @spec move_client_to_party(T.userid(), T.party_id()) :: :ok | nil
  defdelegate move_client_to_party(userid, party_id), to: ClientLib

  @spec get_client_pid(T.userid()) :: pid() | nil
  defdelegate get_client_pid(userid), to: ClientLib

  @spec cast_client(T.userid(), any) :: any
  defdelegate cast_client(userid, msg), to: ClientLib

  @spec call_client(T.userid(), any) :: any | nil
  defdelegate call_client(userid, msg), to: ClientLib

  # Party stuff
  alias Teiserver.Account.PartyLib

  @spec list_party_ids() :: [T.party_id()]
  defdelegate list_party_ids(), to: PartyLib

  @spec list_parties([T.party_id()]) :: [T.party()]
  defdelegate list_parties(ids), to: PartyLib

  @spec get_party(T.party_id()) :: T.party()
  defdelegate get_party(party_id), to: PartyLib

  @spec create_party(T.userid()) :: T.party()
  defdelegate create_party(userid), to: PartyLib

  @spec create_party_invite(T.party_id(), T.userid()) :: :ok | nil
  defdelegate create_party_invite(party_id, userid), to: PartyLib

  @spec accept_party_invite(T.party_id(), T.userid()) :: {true, map()} | {false, String.t()} | nil
  defdelegate accept_party_invite(party_id, userid), to: PartyLib

  @spec cancel_party_invite(T.party_id(), T.userid()) :: :ok | nil
  defdelegate cancel_party_invite(party_id, userid), to: PartyLib

  @spec leave_party(T.party_id(), T.userid()) :: :ok | nil
  defdelegate leave_party(party_id, userid), to: PartyLib

  @spec kick_user_from_party(T.party_id(), T.userid()) :: :ok | nil
  defdelegate kick_user_from_party(party_id, userid), to: PartyLib

  @spec move_user_to_party(T.party_id(), T.userid()) :: :ok | nil
  defdelegate move_user_to_party(party_id, userid), to: PartyLib

  @spec party_exists?(T.party_id()) :: boolean()
  defdelegate party_exists?(party_id), to: PartyLib

  @spec cast_party(T.party_id(), any) :: any | nil
  defdelegate cast_party(party_id, msg), to: PartyLib

  @spec call_party(T.party_id(), any) :: any | nil
  defdelegate call_party(party_id, msg), to: PartyLib

  @spec hide_contributor_rank?(T.userid()) :: boolean()
  def hide_contributor_rank?(userid) do
    stats_data = get_user_stat_data(userid)
    Map.get(stats_data, "hide_contributor_rank", false)
  end

  @spec set_hide_contributor_rank(T.userid(), boolean()) :: any()
  def set_hide_contributor_rank(userid, boolean_value) do
    update_user_stat(userid, %{
      "hide_contributor_rank" => boolean_value
    })
  end

  @spec hash_password(any) :: binary | {binary, binary, {any, any, any, any, any}}
  def hash_password(password) do
    Argon2.hash_pwd_salt(password)
  end

  @spec spring_md5_password(String.t()) :: String.t()
  def spring_md5_password(password) do
    :crypto.hash(:md5, password) |> Base.encode64()
  end

  @spec verify_md5_password(String.t(), String.t()) :: boolean
  def verify_md5_password(md5_password, argon_hash) do
    Argon2.verify_pass(md5_password, argon_hash)
  end

  @spec verify_plain_password(String.t(), String.t()) :: boolean
  def verify_plain_password(plain_text_password, argon_hash) do
    spring_md5_password(plain_text_password)
    |> verify_md5_password(argon_hash)
  end

  @spec can_register?() :: boolean()
  def can_register?(),
    do: Teiserver.Config.get_site_config_cache("teiserver.Enable registrations")

  @spec can_register_with_web?() :: boolean()
  def can_register_with_web?() do
    can_register?() &&
      not Teiserver.Config.get_site_config_cache("teiserver.Require Chobby registration")
  end
end
