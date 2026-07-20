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

    case deprecated_get_user_by_id(userid) do
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

  @spec deprecated_get_user_by_name(String.t() | nil) :: T.user() | nil
  def deprecated_get_user_by_name(nil), do: nil
  def deprecated_get_user_by_name(""), do: nil

  def deprecated_get_user_by_name(username) do
    username
    |> get_userid()
    |> deprecated_get_user_by_id()
  end

  @spec deprecated_get_user_by_email(String.t()) :: T.user() | nil
  def deprecated_get_user_by_email(nil), do: nil
  def deprecated_get_user_by_email(""), do: nil

  def deprecated_get_user_by_email(email) do
    cachename_email = cachename(email)

    id =
      Teiserver.cache_get_or_store(:users_lookup_id_with_email, cachename_email, fn ->
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
            deprecated_recache_user(id)
            id
        end
      end)

    deprecated_get_user_by_id(id)
  end

  @spec deprecated_get_user_by_id(User.id() | nil) :: T.user() | nil
  def deprecated_get_user_by_id(nil), do: nil
  def deprecated_get_user_by_id(""), do: nil

  def deprecated_get_user_by_id(id) do
    id = int_parse(id)

    case Teiserver.cache_get(:users, id) do
      nil ->
        deprecated_recache_user(id)
        Teiserver.cache_get(:users, id)

      user ->
        user
    end
  end

  @spec get_userid_by_discord_id(String.t() | nil) :: User.id() | nil
  def get_userid_by_discord_id(nil), do: nil

  def get_userid_by_discord_id(discord_id) do
    Teiserver.cache_get_or_store(:users_lookup_id_with_discord, discord_id, fn ->
      user =
        Account.query_user(
          search: [
            data_equal: {"discord_id", discord_id}
          ],
          select: [:id]
        )

      case user do
        nil ->
          nil

        %{id: id} ->
          deprecated_recache_user(id)
          id
      end
    end)
  end

  @spec deprecated_get_user_by_discord_id(String.t() | nil) :: T.user() | nil
  def deprecated_get_user_by_discord_id(nil), do: nil
  def deprecated_get_user_by_discord_id(""), do: nil

  def deprecated_get_user_by_discord_id(discord_id) do
    discord_id
    |> to_string()
    |> get_userid_by_discord_id()
    |> deprecated_get_user_by_id()
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
    Teiserver.cache_delete(:account_user_cache, id)
    Teiserver.cache_delete(:account_user_cache_bang, id)
    Teiserver.cache_delete(:account_membership_cache, id)
    Teiserver.cache_delete(:config_user_cache, id)

    Account.decache_relationships(id)

    user
    |> convert_user()
    |> add_user()

    :ok
  end

  def deprecated_recache_user(id) when is_integer(id) do
    Account.get_user(id) |> deprecated_recache_user()
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
      discord_dm_channel_id: user.discord_dm_channel_id,
      steam_id: user.steam_id,
      smurf_of_id: user.smurf_of_id,
      inserted_at: user.inserted_at,

      # User data fields
      rank: user_data.rank,
      country: user_data.country,
      bot: user_data.bot,
      email_change_code: user_data.email_change_code,
      last_login_mins: user_data.last_login_mins,
      lobby_hash: user_data.lobby_hash,
      chobby_hash: user_data.chobby_hash,
      lobby_client: user_data.lobby_client,
      discord_dm_channel: user_data.discord_dm_channel
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
    Teiserver.cache_put(:users, user.id, user)
    if persist, do: persist_user(user)
    user
  end

  @spec update_cache_user(User.id(), map()) :: CacheUser.t() | map()
  def update_cache_user(userid, data) do
    user = deprecated_get_user_by_id(userid)
    new_user = Map.merge(user, data)
    Teiserver.cache_put(:users, user.id, new_user)
    persist_user(new_user)
    new_user
  end

  @doc """
  A function purely for UserLib to be able to flash the cache when a User is updated
  and we want to ensure these caches are cleared correctly.
  """
  def decache_user_on_ok({:ok, %User{} = user} = result) do
    Teiserver.cache_delete(:users, user.id)
    Teiserver.cache_delete(:users_lookup_id_with_name, cachename(user.name))
    Teiserver.cache_delete(:users_lookup_id_with_email, cachename(user.email))

    if user.discord_id do
      Teiserver.cache_delete(:users_lookup_id_with_discord, user.discord_id)
    end

    result
  end

  def decache_user_on_ok(result), do: result

  @spec decache_user(User.id()) :: :ok | :no_user
  def decache_user(userid) do
    user = deprecated_get_user_by_id(userid)

    if user do
      # This is used by the UserLib, to prevent us having to have both functions
      # call the other we instead have the UserLib call here and once this is removed
      # we just need to remove the call to this.
      Teiserver.cache_delete(:users_by_id, user.id)

      Teiserver.cache_delete(:users, user.id)
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
