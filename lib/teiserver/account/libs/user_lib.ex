defmodule Teiserver.Account.UserLib do
  @moduledoc false

  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.RoleLib
  alias Teiserver.Account.User
  alias Teiserver.Account.UserCacheLib
  alias Teiserver.Account.UserQueries
  alias Teiserver.CacheUser
  alias Teiserver.Client
  alias Teiserver.Config
  alias Teiserver.Helper.StylingHelper
  alias Teiserver.Logging
  alias Teiserver.Repo

  use TeiserverWeb, :library_newform

  import Teiserver.Helpers.CacheHelper,
    only: [cache_get_or_store: 3, cache_put_on_ok: 2, cache_delete_on_ok: 2]

  import Teiserver.Helper.NumberHelper, only: [int_parse!: 1]
  import Teiserver.Logging.Helpers, only: [add_audit_log: 4]

  @bigint_max Integer.pow(2, 63) - 1
  @bigint_min -Integer.pow(2, 63)

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-user"

  @spec colours :: atom
  def colours, do: :success

  @spec colour :: atom
  def colour, do: :success

  @spec make_favourite(Teiserver.Account.User.t()) :: map()
  def make_favourite(user) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: user.id,
      item_type: "teiserver_user",
      item_colour: user.colour,
      item_icon: user.icon,
      item_label: "#{user.name}",
      url: "/teiserver/admin/user/#{user.id}"
    }
  end

  @spec generate_user_icons(T.user()) :: map()
  def generate_user_icons(user) do
    role_icons =
      user.roles
      |> Enum.filter(fn r -> RoleLib.role_data(r) != nil end)
      |> Map.new(fn r -> {r, 1} end)

    %{
      "play_time_rank" => user.rank
    }
    |> Map.merge(role_icons)
  end

  @spec make_bot_password() :: String.t()
  def make_bot_password do
    :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false) |> binary_part(0, 64)
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  @spec list_users(list) :: list
  def list_users(args \\ []) do
    args
    |> UserQueries.query_users()
    |> Repo.all()
  end

  @spec list_users_by_data(%{String.t() => String.t()}) :: [User.t()]
  def list_users_by_data(data_search_params) do
    # If nil is returned then the arguments passed in were invalid or
    # problematic in some way and we will not be running the query
    case UserQueries.user_search_by_data(data_search_params) do
      {:ok, query} ->
        query
        |> QueryHelpers.limit_query(200)
        |> Repo.all()

      _any_other ->
        []
    end
  end

  @spec count_users() :: integer
  def count_users do
    count_users([])
  end

  @spec count_users(list) :: integer
  def count_users(args) do
    args
    |> UserQueries.count_users()
    |> Repo.aggregate(:count, :id)
  end

  @spec parse_user_id(User.id() | String.t()) :: {:ok, User.id()} | {:error, atom}
  def parse_user_id(user_id) when is_integer(user_id) do
    if user_id >= @bigint_min and user_id <= @bigint_max do
      {:ok, user_id}
    else
      {:error, :out_of_range}
    end
  end

  def parse_user_id(user_id) when is_binary(user_id) do
    case user_id |> String.trim() |> Integer.parse() do
      {id, ""} -> parse_user_id(id)
      _reason -> {:error, :not_an_integer}
    end
  end

  @doc """
  Attempts to get the user from the cache, failing that it will get it from the database.

  Returns nil if no user found.
  """
  @spec get_user_by_id(User.id() | String.t()) :: User.t() | nil
  def get_user_by_id(user_id) do
    case parse_user_id(user_id) do
      {:ok, id} -> cache_get_or_store(:users_by_id, id, fn -> get_user(id) end)
      {:error, _reason} -> nil
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

  @spec decache_user(User.t() | User.id()) :: :ok | {:error, any}
  def decache_user(%User{id: user_id}), do: decache_user(user_id)

  def decache_user(user_id) do
    user_id = int_parse!(user_id)
    Teiserver.cache_delete(:users_by_id, user_id)

    # This to be removed as part of the removal of CacheUser removal
    UserCacheLib.decache_user(user_id)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_user!(non_neg_integer()) :: User.t()
  def get_user!(user_id, args \\ []) do
    (args ++ [id: user_id])
    |> UserQueries.query_users()
    |> Repo.one!()
  end

  @spec get_user(non_neg_integer() | nil, keyword()) :: User.t() | nil
  def get_user(user_id, args \\ []) do
    (args ++ [id: user_id])
    |> UserQueries.query_users()
    |> Repo.one()
  end

  @spec query_users(list) :: [User.t()]
  def query_users(query_args \\ []) do
    UserQueries.query_users(query_args)
    |> Repo.all()
  end

  @spec query_user(list) :: User.t() | nil
  def query_user(query_args \\ []) do
    UserQueries.query_users(query_args)
    |> Repo.one()
  end

  @doc """
  Creates a user.

  ## Examples

      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
    |> broadcast_create_user()
  end

  def script_create_user(attrs \\ %{}, pass_type \\ :md5_password) do
    %User{}
    |> User.changeset(attrs, :script_create, pass_type)
    |> Repo.insert()
    |> broadcast_create_user()
  end

  def register_user(attrs \\ %{}, pass_type, ip \\ nil) do
    res =
      %User{}
      |> User.changeset(attrs, :register, pass_type)
      |> Repo.insert()
      |> broadcast_create_user()

    case res do
      {:ok, user} -> {:ok, CacheUser.post_user_creation_actions(user, ip)}
      err -> err
    end
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    Account.deprecated_recache_user(user.id)

    user
    |> User.changeset(attrs, :limited_with_data)
    |> Repo.update()
    |> broadcast_update_user()
    |> cache_put_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  def update_user_plain_password(%User{} = user, attrs) do
    Account.deprecated_recache_user(user.id)

    user
    |> User.changeset(attrs, :password)
    |> Repo.update()
    |> broadcast_update_user()
    |> cache_put_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  def update_user_user_form(%User{} = user, attrs) do
    Account.deprecated_recache_user(user.id)

    user
    |> User.changeset(attrs, :user_form)
    |> Repo.update()
    |> broadcast_update_user()
    |> cache_put_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  def server_limited_update_user(%User{} = user, attrs) do
    Account.deprecated_recache_user(user.id)

    user
    |> User.changeset(attrs, :server_limited_update_user)
    |> Repo.update()
    |> broadcast_update_user()
    |> cache_put_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  def server_update_user(%User{} = user, attrs) do
    Account.deprecated_recache_user(user.id)

    user
    |> User.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_user()
    |> cache_put_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  def script_update_user(%User{} = user, attrs) do
    Account.deprecated_recache_user(user.id)

    user
    |> User.changeset(attrs, :script)
    |> Repo.update()
    |> broadcast_update_user()
    |> cache_put_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  def password_reset_update_user(%User{} = user, attrs) do
    Account.deprecated_recache_user(user.id)

    user
    |> User.changeset(attrs, :password_reset)
    |> Repo.update()
    |> broadcast_update_user()
    |> cache_put_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  def update_user_smurf(%User{} = user, attrs) do
    user
    |> User.smurf_changeset(attrs)
    |> Repo.update()
    |> broadcast_update_user()
    |> cache_put_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
    |> cache_delete_on_ok(:users_by_id)
    |> UserCacheLib.decache_user_on_ok()
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  def broadcast_create_user(u), do: broadcast_create_user(u, :create)

  def broadcast_create_user({:ok, user}, reason) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "account_hooks",
      {:account_hooks, :create_user, user, reason}
    )

    {:ok, user}
  end

  def broadcast_create_user(v, _reason), do: v

  def broadcast_update_user(u), do: broadcast_update_user(u, :update)

  def broadcast_update_user({:ok, user}, reason) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "account_hooks",
      {:account_hooks, :update_user, user, reason}
    )

    {:ok, user}
  end

  def broadcast_update_user(v, _reason), do: v

  def merge_default_params(user_params) do
    Map.merge(
      %{
        "icon" => "fa-solid fa-" <> StylingHelper.random_icon(),
        "colour" => StylingHelper.random_colour()
      },
      user_params
    )
  end

  def authenticate_user(_conn, %User{} = user, plain_text_password) do
    verified_user =
      if Account.verify_plain_password(plain_text_password, user.password) do
        {:ok, user}
      else
        # Authentication failure handler
        {:error, "Invalid credentials"}
      end

    with {:ok, user} <- verified_user,
         :ok <- can_login(user) do
      {:ok, user}
    end
  end

  def authenticate_user(_conn, "", _plain_text_password) do
    Argon2.no_user_verify()
    Argon2.no_user_verify()
    {:error, "Invalid credentials"}
  end

  def authenticate_user(_conn, _email, "") do
    Argon2.no_user_verify()
    Argon2.no_user_verify()
    {:error, "Invalid credentials"}
  end

  def authenticate_user(conn, email, plain_text_password) do
    user = get_user(nil, where: [email: email]) || get_user(nil, where: [email_lower: email])

    case user do
      nil ->
        Argon2.no_user_verify()
        Argon2.no_user_verify()

        Logging.add_anonymous_audit_log(conn, "Account:Failed login", %{
          reason: "No user",
          email: email
        })

        {:error, "Invalid credentials"}

      user ->
        if Auth.can_login?(user) do
          authenticate_user(conn, user, plain_text_password)
        else
          :telemetry.execute([:tachyon, :login, :error], %{count: 1}, %{
            reason: :rate_limited,
            user_id: user.id
          })

          {:error, "Rate limit"}
        end
    end
  end

  @spec has_access(integer() | map(), Plug.Conn.t() | User.t()) ::
          {boolean, nil | :not_found | :no_access}
  def has_access(target_user_id, conn_or_user) when is_integer(target_user_id) do
    if allow?(conn_or_user, "Server") do
      {true, nil}
    else
      {false, :no_access}
    end
  end

  def has_access(nil, _user), do: {false, :not_found}

  def has_access(target_user, conn_or_user) do
    cond do
      # Server can access anything
      allow?(conn_or_user, "Server") ->
        {true, nil}

      # Admin can access anything except Server
      not allow?(conn_or_user, "Server") and allow?(target_user, "Server") ->
        {false, :restricted_user}

      allow?(conn_or_user, "Admin") ->
        {true, nil}

      not allow?(conn_or_user, "Admin") and allow?(target_user, "Admin") ->
        {false, :restricted_user}

      allow?(conn_or_user, "Moderator") ->
        {true, nil}

      # By default, nobody can access other users
      true ->
        {false, :no_access}
    end
  end

  @spec has_access!(integer() | map(), Plug.Conn.t() | User.t()) :: boolean
  def has_access!(target_user, conn_or_user) do
    {result, _msg} = has_access(target_user, conn_or_user)
    result
  end

  @spec add_report_restriction_types(String.t(), list) :: :ok
  def add_report_restriction_types(key, items) do
    categories = Teiserver.store_get(:restriction_lookup_store, :categories) || []
    new_categories = categories ++ [key]

    Teiserver.store_put(:restriction_lookup_store, :categories, new_categories)
    Teiserver.store_put(:restriction_lookup_store, key, items)
    :ok
  end

  @spec list_restrictions :: list
  def list_restrictions do
    Teiserver.store_get(:restriction_lookup_store, :categories)
    |> Enum.map(fn key ->
      {key, Teiserver.store_get(:restriction_lookup_store, key)}
    end)
  end

  defp can_login(%User{} = user) do
    cond do
      Account.restricted?(user, ["Login"]) ->
        {:error,
         "Your account is currently suspended. Check the suspension's status at https://discord.gg/beyond-all-reason -> #moderation-bot"}

      user.smurf_of_id != nil ->
        {:error,
         "Alt account detected. Please log in using your original account instead. If you're not sure what that account is or have trouble accessing it, please contact the moderation team at https://discord.gg/beyond-all-reason -> #open-ticket"}

      Account.get_account_locked(user.id) ->
        {:error,
         "The MFA one time password has been entered wrong too many times. Please reset your password to remove MFA from your account."}

      Account.get_user_totp_status(user.id) == :active ->
        {:requires_mfa, user}

      true ->
        :ok
    end
  end

  @spec new_account?(User.id()) :: boolean()
  def new_account?(user_id) do
    user_stats = Account.get_user_stat_data(user_id)
    play_hours = (user_stats["player_minutes"] || 0) / 60
    play_time_cutoff = Config.get_site_config_cache("teiserver.New player cutoff")
    play_hours < play_time_cutoff
  end

  @doc """
  We use a map as the parameter to make it abundantly clear at the site of
  the caller which is the origin and which the smurf.
  """
  @spec mark_user_as_smurf_of(User.t(), %{smurf: User.t(), origin: User.t()}) ::
          :ok | {:error, String.t()}
  def mark_user_as_smurf_of(%User{} = moderator, %{
        smurf: %User{} = smurf,
        origin: %User{} = origin
      }) do
    with true <- smurf.id != origin.id,
         true <- moderator.id != smurf.id,
         true <- moderator.id != origin.id,
         true <- origin.smurf_of_id != smurf.id,
         {true, _roles} <- has_access(smurf, moderator),
         {true, _roles} <- has_access(origin, moderator) do
      do_mark_user_as_smurf_of(moderator.id, %{smurf: %User{} = smurf, origin: %User{} = origin})
    else
      false -> {:error, "Invalid combination of users selected"}
      {false, :no_access} -> {:error, "No access to one or both users"}
      {false, :not_found} -> {:error, "Unable to find one or more of the users"}
    end
  end

  defp do_mark_user_as_smurf_of(moderator_id, %{
         smurf: %User{} = smurf,
         origin: %User{} = origin
       }) do
    # If the origin user has a smurf_id somehow then we just point to that
    actual_origin_id = origin.smurf_of_id || origin.id

    result =
      Repo.transact(fn ->
        with {:ok, _updated_user} <-
               update_user_smurf(smurf, %{smurf_of_id: actual_origin_id}),
             {:ok, %User{}} <- Auth.add_roles(origin.id, ["Smurfer"]),
             :ok <- Account.deprecated_recache_user(smurf.id) do
          add_audit_log(
            moderator_id,
            nil,
            "Moderation:Mark as smurf",
            %{
              smurf_id: smurf.id,
              origin_id: origin.id,
              actual_origin_id: actual_origin_id
            }
          )

          # Now we update stats for the origin
          smurf_count =
            UserQueries.users()
            |> UserQueries.where_smurf_of(actual_origin_id)
            |> Repo.aggregate(:count, :id)

          Account.update_user_stat(origin.id, %{"smurf_count" => smurf_count})

          Client.disconnect(smurf.id, "Marked as smurf")
          {:ok, :ok}
        end
      end)

    case result do
      {:ok, :ok} -> :ok
      error -> error
    end
  end
end
