defmodule Teiserver.Account.UserCache do
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.{Account, User}
  alias Teiserver.Data.Types, as: T
  alias Central.Account.Guardian
  alias Teiserver.Client
  require Logger

  @spec get_username(T.userid()) :: String.t()
  def get_username(userid) do
    ConCache.get(:users_lookup_name_with_id, int_parse(userid))
  end

  @spec get_userid(String.t()) :: integer() | nil
  def get_userid(username) do
    ConCache.get(:users_lookup_id_with_name, cachename(username))
  end

  @spec get_user_by_name(String.t()) :: User.t() | nil
  def get_user_by_name(username) do
    id = get_userid(username)
    ConCache.get(:users, id)
  end

  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) do
    id = ConCache.get(:users_lookup_id_with_email, cachename(email))
    ConCache.get(:users, id)
  end

  @spec get_user_by_token(String.t()) :: User.t() | nil
  def get_user_by_token(token) do
    case Guardian.resource_from_token(token) do
      {:error, _bad_token} ->
        nil

      {:ok, db_user, _claims} ->
        get_user_by_id(db_user.id)
    end
  end

  @spec get_user_by_id(T.userid()) :: User.t() | nil
  def get_user_by_id(id) do
    ConCache.get(:users, int_parse(id))
  end

  @spec list_users(list) :: list
  def list_users(id_list) do
    id_list
    |> Enum.map(fn userid ->
      ConCache.get(:users, userid)
    end)
  end

  @spec recache_user(Integer.t()) :: :ok
  def recache_user(id) do
    if get_user_by_id(id) do
      Account.get_user!(id)
      |> convert_user
      |> update_user
    else
      Account.get_user!(id)
      |> convert_user
      |> add_user
    end

    :ok
  end

  @spec pre_cache_users(:active | :remaining) :: :ok
  def pre_cache_users(:active) do
    user_count =
      Account.list_users(limit: :infinity)
      |> Parallel.map(fn user ->
        user
        |> convert_user
        |> add_user
      end)
      |> Enum.count()

    Logger.info("pre_cache_users:active, got #{user_count} users")
  end

  # def pre_cache_users(:remaining) do
  #   user_count =
  #     Account.list_users(limit: :infinity)
  #     |> Parallel.map(fn user ->
  #       user
  #       |> convert_user
  #       |> add_user
  #     end)
  #     |> Enum.count()

  #   Logger.info("pre_cache_users:remaining, got #{user_count} users")
  # end

  @spec convert_user(User.t()) :: User.t()
  def convert_user(user) do
    data =
      User.data_keys
      |> Map.new(fn k -> {k, Map.get(user.data || %{}, to_string(k), User.default_data()[k])} end)

    user
    |> Map.take(User.keys())
    |> Map.merge(User.default_data())
    |> Map.merge(data)
  end

  @spec add_user(User.t()) :: User.t()
  def add_user(user) do
    update_user(user)
    ConCache.put(:users_lookup_name_with_id, user.id, user.name)
    ConCache.put(:users_lookup_id_with_name, cachename(user.name), user.id)
    ConCache.put(:users_lookup_id_with_email, cachename(user.email), user.id)

    user
  end

  # Persists the changes into the database so they will
  # be pulled out next time the user is accessed/recached
  # The special case here is to prevent the benchmark and test users causing issues
  @spec persist_user(User.t()) :: User.t() | nil
  defp persist_user(%{name: "TEST_" <> _}), do: nil

  defp persist_user(user) do
    db_user = Account.get_user!(user.id)

    data =
      User.data_keys
      |> Map.new(fn k -> {to_string(k), Map.get(user, k, User.default_data()[k])} end)

    Account.update_user(db_user, %{"data" => data})
  end

  @spec update_user(User.t(), boolean) :: User.t()
  def update_user(user, persist \\ false) do
    ConCache.put(:users, user.id, user)
    if persist, do: persist_user(user)
    user
  end

  @spec delete_user(T.userid()) :: :ok | :no_user
  def delete_user(userid) do
    user = get_user_by_id(userid)

    if user do
      Client.disconnect(userid, "User cache deletion")
      :timer.sleep(100)

      ConCache.delete(:users, userid)
      ConCache.delete(:users_lookup_name_with_id, user.id)
      ConCache.delete(:users_lookup_id_with_name, cachename(user.name))
      ConCache.delete(:users_lookup_id_with_email, cachename(user.email))
      :ok
    else
      :no_user
    end
  end

  defp cachename(str) do
    str
    |> String.trim
    |> String.downcase
  end
end
