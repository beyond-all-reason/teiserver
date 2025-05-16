defmodule Teiserver.Account.UserLib do
  @moduledoc false
  use TeiserverWeb, :library_newform
  require Logger
  alias Phoenix.PubSub
  alias Teiserver.{Account, Logging}
  alias Teiserver.Account.{User, RoleLib, UserQueries}

  # Functions
  @spec icon :: String.t()
  def icon(), do: "fa-regular fa-user"

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
  def make_bot_password() do
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

  @spec get_user(non_neg_integer() | nil, list) :: User.t() | nil
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

  def script_create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs, :script)
    |> Repo.insert()
    |> broadcast_create_user()
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
    Account.recache_user(user.id)

    user
    |> User.changeset(attrs, :limited_with_data)
    |> Repo.update()
    |> broadcast_update_user()
  end

  def update_user_plain_password(%User{} = user, attrs) do
    Account.recache_user(user.id)

    user
    |> User.changeset(attrs, :password)
    |> Repo.update()
    |> broadcast_update_user()
  end

  def update_user_user_form(%User{} = user, attrs) do
    Account.recache_user(user.id)

    user
    |> User.changeset(attrs, :user_form)
    |> Repo.update()
    |> broadcast_update_user()
  end

  def server_limited_update_user(%User{} = user, attrs) do
    Account.recache_user(user.id)

    user
    |> User.changeset(attrs, :server_limited_update_user)
    |> Repo.update()
    |> broadcast_update_user()
  end

  def server_update_user(%User{} = user, attrs) do
    Account.recache_user(user.id)

    user
    |> User.changeset(attrs)
    |> Repo.update()
    |> broadcast_update_user()
  end

  def script_update_user(%User{} = user, attrs) do
    Account.recache_user(user.id)

    user
    |> User.changeset(attrs, :script)
    |> Repo.update()
    |> broadcast_update_user()
  end

  def password_reset_update_user(%User{} = user, attrs) do
    Account.recache_user(user.id)

    user
    |> User.changeset(attrs, :password_reset)
    |> Repo.update()
    |> broadcast_update_user()
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

  def broadcast_create_user(v, _), do: v

  def broadcast_update_user(u), do: broadcast_update_user(u, :update)

  def broadcast_update_user({:ok, user}, reason) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "account_hooks",
      {:account_hooks, :update_user, user, reason}
    )

    {:ok, user}
  end

  def broadcast_update_user(v, _), do: v

  def merge_default_params(user_params) do
    Map.merge(
      %{
        "icon" => "fa-solid fa-" <> Teiserver.Helper.StylingHelper.random_icon(),
        "colour" => Teiserver.Helper.StylingHelper.random_colour()
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

  def authenticate_user(_conn, _, "") do
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
        authenticate_user(conn, user, plain_text_password)
    end
  end

  @spec has_access(integer() | map(), Plug.Conn.t()) :: {boolean, nil | :not_found | :no_access}
  def has_access(target_user_id, conn) when is_integer(target_user_id) do
    if allow?(conn.permissions, "Server") do
      {true, nil}
    else
      {false, :no_access}
    end
  end

  def has_access(nil, _user), do: {false, :not_found}

  def has_access(target_user, conn) do
    cond do
      # Server can access anything
      allow?(conn, "Server") ->
        {true, nil}

      # Admin can access anything except Server
      not allow?(conn, "Server") and allow?(target_user, "Server") ->
        {false, :restricted_user}

      allow?(conn, "Admin") ->
        {true, nil}

      not allow?(conn, "Admin") and allow?(target_user, "Admin") ->
        {false, :restricted_user}

      allow?(conn, "Moderator") ->
        {true, nil}

      # By default, nobody can access other users
      true ->
        {false, :no_access}
    end
  end

  @spec has_access!(integer() | map(), Plug.Conn.t()) :: boolean
  def has_access!(target_user, conn) do
    {result, _} = has_access(target_user, conn)
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
  def list_restrictions() do
    Teiserver.store_get(:restriction_lookup_store, :categories)
    |> Enum.map(fn key ->
      {key, Teiserver.store_get(:restriction_lookup_store, key)}
    end)
  end

  defp can_login(user) do
    cond do
      Teiserver.CacheUser.is_restricted?(user, ["Login"]) ->
        {:error,
         "Your account is currently suspended. Check the suspension's status at https://discord.gg/beyond-all-reason -> #moderation-bot"}

      user.smurf_of_id != nil ->
        {:error,
         "Alt account detected. Please log in using your original account instead. If you're not sure what that account is or have trouble accessing it, please contact the moderation team at https://discord.gg/beyond-all-reason -> #open-ticket"}

      true ->
        :ok
    end
  end
end
