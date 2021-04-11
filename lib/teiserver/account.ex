defmodule Teiserver.Account do
  import Ecto.Query, warn: false
  alias Central.Repo

  # Mostly a wrapper around Central.Account
  alias Central.Account.User
  alias Teiserver.Account.UserLib
  alias Central.Helpers.QueryHelpers

  @doc """
  Returns the list of user.

  ## Examples

      iex> list_user()
      [%User{}, ...]

  """
  def list_users(args \\ []) do
    UserLib.get_user()
    |> UserLib.search(args[:search])
    |> UserLib.preload(args[:joins])
    |> UserLib.order_by(args[:order_by])
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
  def get_user!(id, args \\ []) do
    UserLib.get_user()
    |> UserLib.search(%{id: id})
    |> UserLib.search(args[:search])
    |> UserLib.preload(args[:joins])
    |> Repo.one!()
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
    |> Central.Account.broadcast_create_user
  end

  def script_create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs, :script)
    |> Repo.insert()
    |> Central.Account.broadcast_create_user
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
    Central.Account.recache_user(user.id)

    user
    |> User.changeset(attrs, :limited_with_data)
    |> Repo.update()
    |> Central.Account.broadcast_update_user()
  end

  def script_update_user(%User{} = user, attrs) do
    Central.Account.recache_user(user.id)

    user
    |> User.changeset(attrs, :script)
    |> Repo.update()
    |> Central.Account.broadcast_update_user()
  end

  @doc """
  Deletes a User.

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
      %Ecto.Changeset{source: %User{}}

  """
  def change_user(%User{} = user) do
    User.changeset(user, %{})
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
      html_label: "#{user.name}",
      html_value: "##{user.id}, #{user.name}"
    }
  end




  # Group stuff
  def create_group_membership(params),
    do: Central.Account.create_group_membership(params)


  # Reports
  def get_report!(id), do: Central.Account.get_report!(id)
end
