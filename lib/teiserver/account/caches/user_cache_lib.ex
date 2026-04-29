defmodule Teiserver.Account.UserCacheLib do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.Guardian
  alias Teiserver.Account.User
  alias Teiserver.CacheUser
  alias Teiserver.Data.Types, as: T
  require Logger
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  @spec get_username(T.userid() | nil) :: String.t() | nil
  def get_username(userid), do: get_username_by_id(userid)

  @spec get_username_by_id(T.userid() | nil) :: String.t() | nil
  def get_username_by_id(nil), do: nil
  def get_username_by_id(""), do: nil

  def get_username_by_id(userid) do
    userid = int_parse(userid)

    Teiserver.cache_get_or_store(:users_lookup_name_with_id, int_parse(userid), fn ->
      case get_user_by_id(userid) do
        nil -> nil
        user -> user.name
      end
    end)
  end

  @spec get_userid(String.t() | nil) :: T.userid() | nil
  def get_userid(nil), do: nil
  def get_userid(""), do: nil

  def get_userid(username) do
    username = cachename(username)

    Teiserver.cache_get_or_store(:users_lookup_id_with_name, username, fn ->
      user =
        Account.query_user(
          search: [
            name_lower: username
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

  @spec get_user_by_name(String.t() | nil) :: T.user() | nil
  def get_user_by_name(nil), do: nil
  def get_user_by_name(""), do: nil

  def get_user_by_name(username) do
    username
    |> get_userid()
    |> get_user_by_id()
  end

  @spec get_user_by_email(String.t()) :: T.user() | nil
  def get_user_by_email(nil), do: nil
  def get_user_by_email(""), do: nil

  def get_user_by_email(email) do
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
            recache_user(id)
            id
        end
      end)

    get_user_by_id(id)
  end

  @spec get_user_by_token(String.t()) :: T.user() | nil
  def get_user_by_token(nil), do: nil
  def get_user_by_token(""), do: nil

  def get_user_by_token(token) do
    case Guardian.resource_from_token(token) do
      {:error, _bad_token} ->
        nil

      {:ok, db_user, _claims} ->
        get_user_by_id(db_user.id)
    end
  end

  @spec get_user_by_id(T.userid() | nil) :: T.user() | nil
  def get_user_by_id(nil), do: nil
  def get_user_by_id(""), do: nil

  def get_user_by_id(id) do
    id = int_parse(id)

    Teiserver.cache_get_or_store(:users, id, fn ->
      Account.get_user(id)
      |> convert_user()
      |> add_user()
    end)
  end

  @spec get_userid_by_discord_id(String.t() | nil) :: T.userid() | nil
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
          recache_user(id)
          id
      end
    end)
  end

  @spec get_user_by_discord_id(String.t() | nil) :: T.user() | nil
  def get_user_by_discord_id(nil), do: nil
  def get_user_by_discord_id(""), do: nil

  def get_user_by_discord_id(discord_id) do
    discord_id
    |> to_string()
    |> get_userid_by_discord_id()
    |> get_user_by_id()
  end

  @spec list_users(list) :: list
  def list_users(id_list) do
    id_list
    |> Enum.map(&get_user_by_id/1)
    |> Enum.filter(fn user -> user != nil end)
  end

  @spec recache_user(T.userid() | CacheUser.t() | map()) :: :ok
  def recache_user(id) when is_integer(id) do
    Teiserver.cache_delete(:account_user_cache, id)
    Teiserver.cache_delete(:account_user_cache_bang, id)
    Teiserver.cache_delete(:account_membership_cache, id)
    Teiserver.cache_delete(:config_user_cache, id)

    # decache_user(id)
    Account.decache_relationships(id)

    Account.get_user(id)
    |> convert_user()
    |> add_user()

    :ok
  end

  def recache_user(user) do
    Account.recache_user(user.id)

    user
    |> convert_user()
    |> add_user()

    :ok
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
      # For some reason the restrictions in user_data are different
      # and using the user restrictions breaks tests so we will be using
      # the data restrictions initially
      restrictions: user_data.restrictions,
      restricted_until: user.restricted_until,
      shadowbanned: user.shadowbanned,
      last_login: user.last_login,
      last_played: user.last_played,
      last_logout: user.last_logout,
      discord_id: user.discord_id,
      discord_dm_channel_id: user.discord_dm_channel_id,
      steam_id: user.steam_id,
      clan_id: user.clan_id,
      smurf_of_id: user.smurf_of_id,
      inserted_at: user.inserted_at,

      # User data fields
      rank: user_data.rank,
      country: user_data.country,
      bot: user_data.bot,
      email_change_code: user_data.email_change_code,
      last_login_mins: user_data.last_login_mins,
      lobby_hash: user_data.lobby_hash,
      hw_hash: user_data.hw_hash,
      chobby_hash: user_data.chobby_hash,
      lobby_client: user_data.lobby_client,
      print_client_messages: user_data.print_client_messages,
      print_server_messages: user_data.print_server_messages,
      discord_dm_channel: user_data.discord_dm_channel
    }
  end

  @doc """
  Given a cacheable user it will update the relevant caches
  """
  @spec add_user(T.user() | nil) :: T.user() | nil
  def add_user(nil), do: nil

  def add_user(user) do
    update_user(user)
    Teiserver.cache_put(:users_lookup_name_with_id, user.id, user.name)
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
      CacheUser.keys()
      |> Map.new(fn k -> {to_string(k), Map.get(user, k, Account.default_data()[k])} end)

    Account.script_update_user(db_user, Map.put(obj_attrs, "data", data))
  end

  @spec update_user(CacheUser.t() | map(), [persist: boolean()] | nil) :: CacheUser.t() | map()
  def update_user(user, opts \\ []) do
    persist = Keyword.get(opts, :persist, false)
    Teiserver.cache_put(:users, user.id, user)
    if persist, do: persist_user(user)
    user
  end

  @spec update_cache_user(T.userid(), map()) :: CacheUser.t() | map()
  def update_cache_user(userid, data) do
    user = get_user_by_id(userid)
    new_user = Map.merge(user, data)
    Teiserver.cache_put(:users, user.id, new_user)
    persist_user(new_user)
    new_user
  end

  @spec decache_user(T.userid()) :: :ok | :no_user
  def decache_user(userid) do
    user = get_user_by_id(userid)

    # Teiserver.cache_delete(:users, userid)
    if user do
      Teiserver.cache_delete(:users_lookup_name_with_id, user.id)
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
