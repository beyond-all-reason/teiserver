defmodule Teiserver.Account.UserCacheLib do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.User
  alias Teiserver.CacheUser
  alias Teiserver.Data.Types, as: T

  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @spec get_username(User.id() | nil) :: String.t() | nil
  def get_username(userid), do: get_username_by_id(userid)

  @spec get_username_by_id(User.id() | nil) :: String.t() | nil
  def get_username_by_id(nil), do: nil
  def get_username_by_id(""), do: nil

  def get_username_by_id(userid) do
    userid = int_parse(userid)

    case get_user_by_id(userid) do
      nil -> nil
      user -> user.name
    end
  end

  @spec get_userid(String.t() | nil) :: User.id() | nil
  def get_userid(nil), do: nil
  def get_userid(""), do: nil

  def get_userid(username) do
    username = cachename(username)

    case Teiserver.cache_get(:users_lookup_id_with_name, username) do
      nil ->
        user =
          Account.query_user(search: [name_lower: username])

        case user do
          nil ->
            nil

          user ->
            deprecated_recache_user(user)
            user.id
        end

      id ->
        id
    end
  end

  @spec get_user_by_name(String.t() | nil) :: User.t() | nil
  def get_user_by_name(nil), do: nil
  def get_user_by_name(""), do: nil

  def get_user_by_name(username) do
    username
    |> get_userid()
    |> get_user_by_id()
  end

  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(nil), do: nil
  def get_user_by_email(""), do: nil

  def get_user_by_email(email) do
    id =
      Teiserver.cache_get_or_store(:users_lookup_id_with_email, cachename(email), fn ->
        user =
          Account.query_user(
            search: [
              email_lower: email
            ],
            select: [:id]
          )

        case user do
          nil ->
            nil

          %{id: id} ->
            recache_user(id)
            id
        end
      end)

    get_user_by_id(id)
  end

  @spec deprecated_get_user_by_id(User.id() | nil) :: T.user() | nil
  def deprecated_get_user_by_id(nil), do: nil
  def deprecated_get_user_by_id(""), do: nil

  def deprecated_get_user_by_id(id) do
    id = int_parse(id)

    case Teiserver.cache_get(:deprecated_users, id) do
      nil ->
        deprecated_recache_user(id)
        Teiserver.cache_get(:deprecated_users, id)

      user ->
        user
    end
  end

  @doc """
  Attempts to get the user from the cache, failing that it will get it from the database.

  Returns nil if no user found.
  """
  @spec get_user_by_id(User.id() | String.t()) :: User.t() | nil
  def get_user_by_id(user_id) do
    case User.parse_user_id(user_id) do
      {:ok, user_id} ->
        case Teiserver.cache_get(:users_by_id, user_id) do
          nil -> recache_user(user_id)
          user -> user
        end

      {:error, _reason} ->
        nil
    end
  end

  @doc """
  Identical to `get_user_by_id/1` but with a raise instead of a nil result in the event of
  no user found in the database.
  """
  @spec get_user_by_id!(User.id() | String.t()) :: User.t()
  def get_user_by_id!(user_id) do
    get_user_by_id(user_id) || raise "No user of the ID #{inspect(user_id)}"
  end

  @spec get_userid_by_discord_id(integer() | nil) :: User.id() | nil
  def get_userid_by_discord_id(nil), do: nil

  def get_userid_by_discord_id(discord_id) do
    Teiserver.cache_get_or_store(:users_lookup_id_with_discord, discord_id, fn ->
      user =
        Account.query_user(
          search: [
            discord_id: discord_id
          ],
          select: [:id]
        )

      case user do
        nil ->
          nil

        %{id: id} ->
          recache_user(id)
          id
      end
    end)
  end

  @spec get_user_by_discord_id(integer() | String.t() | nil) :: User.t() | nil
  def get_user_by_discord_id(nil), do: nil
  def get_user_by_discord_id(""), do: nil

  def get_user_by_discord_id(discord_id) when is_binary(discord_id) do
    int_parse(discord_id) |> get_user_by_discord_id()
  end

  def get_user_by_discord_id(discord_id) do
    discord_id
    |> get_userid_by_discord_id()
    |> get_user_by_id()
  end

  @spec deprecated_list_users(list) :: list
  def deprecated_list_users(id_list) do
    id_list
    |> Enum.map(&deprecated_get_user_by_id/1)
    |> Enum.filter(fn user -> user != nil end)
  end

  @spec deprecated_recache_user(User.id() | CacheUser.t() | map() | nil) :: :ok
  def deprecated_recache_user(nil), do: :ok

  def deprecated_recache_user(%{id: id} = user) do
    Teiserver.cache_delete(:deprecated_config_user_cache, id)

    Account.decache_relationships(id)

    user
    |> convert_user()
    |> add_user()

    :ok
  end

  def deprecated_recache_user(id) when is_integer(id) do
    Account.get_user(id) |> deprecated_recache_user()
  end

  @spec recache_user(User.id() | User.t() | nil) :: User.t() | nil
  def recache_user(nil), do: nil

  def recache_user(%User{id: id} = user) do
    # Decache
    Teiserver.cache_delete(:config_user_cache, id)

    Account.decache_relationships(id)

    # Recache
    Teiserver.cache_put(:users_by_id, id, user)
    Teiserver.cache_put(:users_lookup_id_with_name, cachename(user.name), id)
    Teiserver.cache_put(:users_lookup_id_with_email, cachename(user.email), id)

    if user.discord_id do
      Teiserver.cache_put(:users_lookup_id_with_discord, user.discord_id, id)
    end

    user
  end

  def recache_user(id) when is_integer(id) do
    Account.get_user(id) |> recache_user()
  end

  @doc """
  Given a database user it will convert it into a cached user
  """

  @spec convert_user(User.t() | nil) :: CacheUser.t() | nil
  def convert_user(nil), do: nil

  def convert_user(%User{} = user) do
    data =
      CacheUser.data_keys()
      |> Map.new(fn k ->
        {k, Map.get(user.data || %{}, to_string(k), Account.default_data()[k])}
      end)

    user_data =
      user
      |> Map.take(CacheUser.keys())
      |> Map.merge(Account.default_data())
      |> Map.merge(data)

    %CacheUser{
      id: user.id,
      name: user.name,
      email: user.email,
      password: user.password,
      icon: user.icon,
      colour: user.colour,
      roles: user.roles,
      permissions: user.permissions,
      restrictions: user.restrictions,
      restricted_until: user.restricted_until,
      shadowbanned: user.shadowbanned,
      last_login: user.last_login,
      last_played: user.last_played,
      last_logout: user.last_logout,
      discord_id: user.discord_id,
      steam_id: user.steam_id,
      smurf_of_id: user.smurf_of_id,
      inserted_at: user.inserted_at,

      # User data fields
      rank: user_data.rank,
      country: user_data.country,
      bot: user_data.bot,
      email_change_code: user_data.email_change_code,
      lobby_hash: user_data.lobby_hash,
      chobby_hash: user_data.chobby_hash,
      lobby_client: user_data.lobby_client
    }
  end

  @doc """
  Given a cacheable user it will update the relevant caches
  """
  @spec add_user(T.user() | nil) :: T.user() | nil
  def add_user(nil), do: nil

  def add_user(user) do
    deprecated_update_user(user)
    Teiserver.cache_put(:users_lookup_id_with_name, cachename(user.name), user.id)
    Teiserver.cache_put(:users_lookup_id_with_email, cachename(user.email), user.id)

    if user.discord_id do
      Teiserver.cache_put(:users_lookup_id_with_discord, user.discord_id, user.id)
    end

    user
  end

  # Persists the changes into the database so they will
  # be pulled out next time the user is accessed/recached
  # The special case here is to prevent the benchmark and test users causing issues
  @spec persist_user(CacheUser.t() | map()) :: CacheUser.t() | map() | nil
  defp persist_user(%{name: "test_" <> _rest}), do: nil

  defp persist_user(user) do
    db_user = Account.get_user!(user.id)

    data =
      CacheUser.data_keys()
      |> Map.new(fn k -> {to_string(k), Map.get(user, k, Account.default_data()[k])} end)

    obj_attrs =
      (CacheUser.keys() ++ CacheUser.duplicated_keys())
      |> Map.new(fn k -> {to_string(k), Map.get(user, k, Account.default_data()[k])} end)

    Account.script_update_user(db_user, Map.put(obj_attrs, "data", data))
  end

  @spec deprecated_update_user(CacheUser.t() | map(), [persist: boolean()] | nil) ::
          CacheUser.t() | map()
  def deprecated_update_user(user, opts \\ []) do
    persist = Keyword.get(opts, :persist, false)
    Teiserver.cache_put(:deprecated_users, user.id, user)
    if persist, do: persist_user(user)
    user
  end

  @spec update_cache_user(User.id(), map()) :: CacheUser.t() | map()
  def update_cache_user(userid, data) do
    user = deprecated_get_user_by_id(userid)
    new_user = Map.merge(user, data)
    Teiserver.cache_put(:users_by_id, user.id, new_user)
    persist_user(new_user)
    new_user
  end

  @doc """
  A function purely for UserLib to be able to flash the cache when a User is updated
  and we want to ensure these caches are cleared correctly.
  """
  def decache_user_on_ok({:ok, %User{} = _new_user} = result, %User{} = old_user) do
    Teiserver.cache_delete(:users_by_id, old_user.id)
    Teiserver.cache_delete(:deprecated_users, old_user.id)
    Teiserver.cache_delete(:users_lookup_id_with_name, cachename(old_user.name))
    Teiserver.cache_delete(:users_lookup_id_with_email, cachename(old_user.email))

    if old_user.discord_id do
      Teiserver.cache_delete(:users_lookup_id_with_discord, old_user.discord_id)
    end

    result
  end

  def decache_user_on_ok(result, _old_user), do: result

  @spec decache_user(User.id()) :: :ok | :no_user
  def decache_user(userid) do
    user = deprecated_get_user_by_id(userid)

    if user do
      Teiserver.cache_delete(:users_by_id, user.id)
      Teiserver.cache_delete(:users_lookup_id_with_name, cachename(user.name))
      Teiserver.cache_delete(:users_lookup_id_with_email, cachename(user.email))

      if user.discord_id do
        Teiserver.cache_delete(:users_lookup_id_with_discord, user.discord_id)
      end

      :ok
    else
      :no_user
    end
  end

  defp cachename(nil), do: nil

  defp cachename(str) do
    str
    |> String.trim()
    |> String.downcase()
  end
end
