defmodule Teiserver.Account.UserCacheLib do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.User

  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

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

  @spec get_userid_from_name(String.t() | nil) :: User.id() | nil
  def get_userid_from_name(nil), do: nil
  def get_userid_from_name(""), do: nil

  def get_userid_from_name(username) do
    username = cachename(username)

    case Teiserver.cache_get(:users_lookup_id_with_name, username) do
      nil ->
        user =
          Account.query_user(search: [name_lower: username])

        case user do
          nil ->
            nil

          user ->
            recache_user(user)
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
    |> get_userid_from_name()
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

  @spec list_users_by_ids(list) :: list
  def list_users_by_ids(id_list) do
    id_list
    |> Enum.map(&get_user_by_id/1)
    |> Enum.filter(fn user -> user != nil end)
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
    user = get_user_by_id(userid)

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
