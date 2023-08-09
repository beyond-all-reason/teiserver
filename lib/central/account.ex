defmodule Central.Account do
  @moduledoc """
  The Account context.
  """

  import Ecto.Query, warn: false
  alias Teiserver.Helper.QueryHelpers
  alias Phoenix.PubSub
  alias Teiserver.Repo

  alias Argon2

  alias Central.Account.User
  alias Central.Account.UserLib
  import Teiserver.Logging.Helpers, only: [add_anonymous_audit_log: 3]

  @spec icon :: String.t()
  def icon, do: "fa-duotone fa-user-alt"

  defp user_query(args) do
    user_query(nil, args)
  end

  defp user_query(id, args) do
    UserLib.get_users()
    |> UserLib.search(%{id: id})
    |> UserLib.search(args[:search])
    |> UserLib.preload(args[:joins])
    |> UserLib.order(args[:order])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users(args \\ []) do
    user_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
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
  @spec get_user!(Integer.t() | List.t()) :: User.t()
  @spec get_user!(Integer.t(), List.t()) :: User.t()
  def get_user!(id) when not is_list(id) do
    Central.cache_get_or_store(:account_user_cache_bang, id, fn ->
      user_query(id, [])
      |> QueryHelpers.limit_query(1)
      |> Repo.one!()
    end)
  end

  def get_user!(args) do
    user_query(nil, args)
    |> QueryHelpers.limit_query(args[:limit] || 1)
    |> Repo.one!()
  end

  def get_user!(id, args) do
    user_query(id, args)
    |> QueryHelpers.limit_query(args[:limit] || 1)
    |> Repo.one!()
  end

  @doc """
  Gets a single classname.

  Returns `nil` if the Classname does not exist.

  ## Examples

      iex> get_classname(123)
      %Classname{}

      iex> get_classname(456)
      nil

  """
  @spec get_user(Integer.t() | List.t()) :: User.t() | nil
  @spec get_user(Integer.t(), List.t()) :: User.t() | nil
  def get_user(id) when not is_list(id) do
    Central.cache_get_or_store(:account_user_cache, id, fn ->
      user_query(id, [])
      |> Repo.one()
    end)
  end

  def get_user(args) do
    user_query(nil, args)
    |> Repo.one()
  end

  def get_user(id, args) do
    user_query(id, args)
    |> Repo.one()
  end

  @spec get_user_by_name(String.t()) :: User.t() | nil
  def get_user_by_name(name) do
    UserLib.get_users()
    |> UserLib.search(%{name: String.trim(name)})
    |> Repo.one()
  end

  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) do
    UserLib.get_users()
    |> UserLib.search(%{email_lower: String.trim(email)})
    |> Repo.one()
  end

  def recache_user(nil), do: nil
  def recache_user(%User{} = user), do: recache_user(user.id)

  def recache_user(id) do
    Central.cache_delete(:account_user_cache, id)
    Central.cache_delete(:account_user_cache_bang, id)
    Central.cache_delete(:account_membership_cache, id)
    Central.cache_delete(:config_user_cache, id)
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
    |> broadcast_create_user
  end

  def self_create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs, :self_create)
    |> Repo.insert()
    |> broadcast_create_user
  end

  def create_throwaway_user(attrs \\ %{}) do
    params =
      %{
        "name" => generate_throwaway_name(),
        "email" => "#{UUID.uuid1()}@throwaway",
        "password" => UUID.uuid1()
      }
      |> Teiserver.Helper.StylingHelper.random_styling()
      |> Map.merge(attrs)

    %User{}
    |> User.changeset(params)
    |> Repo.insert()
    |> broadcast_create_user
  end

  def merge_default_params(user_params) do
    Map.merge(
      %{
        "icon" => "fa-solid fa-" <> Teiserver.Helper.StylingHelper.random_icon(),
        "colour" => Teiserver.Helper.StylingHelper.random_colour()
      },
      user_params
    )
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs, changeset_type \\ nil) do
    recache_user(user.id)

    user
    |> User.changeset(attrs, changeset_type)
    |> Repo.update()
    |> broadcast_update_user
  end

  # @doc """
  # Deletes a User.

  # ## Examples

  #     iex> delete_user(user)
  #     {:ok, %User{}}

  #     iex> delete_user(user)
  #     {:error, %Ecto.Changeset{}}

  # """
  # def delete_user(%User{} = user) do
  #   Repo.delete(user)
  # end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
  end

  def authenticate_user(conn, %User{} = user, plain_text_password) do
    if User.verify_password(plain_text_password, user.password) do
      {:ok, user}
    else
      # Authentication failure handler
      Teiserver.Account.spring_auth_check(conn, user, plain_text_password)
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
    case get_user_by_email(email) do
      nil ->
        Argon2.no_user_verify()
        Argon2.no_user_verify()
        add_anonymous_audit_log(conn, "Account:Failed login", %{reason: "No user", email: email})
        {:error, "Invalid credentials"}

      user ->
        authenticate_user(conn, user, plain_text_password)
    end
  end

  def login_failure(conn, user) do
    add_anonymous_audit_log(conn, "Account:Failed login", %{
      reason: "Bad password",
      user_id: user.id,
      email: user.email
    })

    {:error, "Invalid credentials"}
  end

  def user_as_json(users) when is_list(users) do
    users
    |> Enum.map(&user_as_json/1)
  end

  def user_as_json(user) do
    %{
      id: user.id,
      name: user.name,
      email: user.email,
      icon: user.icon,
      colour: user.colour,
      html_label: "#{user.name} - #{user.email}",
      html_value: "##{user.id}, #{user.name}"
    }
  end

  @doc """
  Uses :application_metadata_cache store to generate a random username
  based on the keys random_names_1, random_names_2 and random_names_3
  if you override these keys with an empty list you can generate shorter names
  """
  @spec generate_throwaway_name() :: String.t()
  def generate_throwaway_name do
    [
      Central.store_get(:application_metadata_cache, "random_names_1"),
      Central.store_get(:application_metadata_cache, "random_names_2"),
      Central.store_get(:application_metadata_cache, "random_names_3")
    ]
    |> Enum.filter(fn l -> l != [] end)
    |> Enum.map_join(" ", fn l -> Enum.random(l) |> String.capitalize() end)
  end
end
