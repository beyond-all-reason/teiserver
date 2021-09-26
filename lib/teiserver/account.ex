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
    |> QueryHelpers.select(args[:select])
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

  def get_user(id, args \\ []) do
    UserLib.get_user()
    |> UserLib.search(%{id: id})
    |> UserLib.search(args[:search])
    |> UserLib.preload(args[:joins])
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
    |> Central.Account.broadcast_create_user()
  end

  def script_create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs, :script)
    |> Repo.insert()
    |> Central.Account.broadcast_create_user()
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

  @spec smurf_search(Plug.Conn.t, User.t()) :: {list(), map()}
  def smurf_search(conn, user) do
    ip_ids = get_smurfs_by_ip(user)
    hash_ids = get_smurfs_by_hash(user)
    hw_ids = get_smurfs_by_hw(user)

    reasons = %{
      ip: ip_ids,
      hash: hash_ids,
      hw: hw_ids
    }

    ids = (ip_ids ++ hash_ids ++ hw_ids)
    |> Enum.uniq

    users = list_users(search: [
        admin_group: conn,
        id_in: ids
      ],
      order_by: "Name (A-Z)",
      limit: 50
    )

    {users, reasons}
  end

  defp get_smurfs_by_ip(%{data: %{"ip_list" => []}}), do: []
  defp get_smurfs_by_ip(user) do
    ip_fragments = user.data["ip_list"]
    |> Enum.map(fn ip ->
      "u.data -> 'ip_list' ? '#{ip}'"
    end)
    |> Enum.join(" or ")

    query = """
    SELECT u.id
    FROM account_users u
    WHERE #{ip_fragments}
"""

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, results} ->
        results.rows
        |> List.flatten

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp get_smurfs_by_hash(user) do
    lobby_hash = user.data["lobby_hash"]
    lobby_hash_fragment = "u.data ->> 'lobby_hash' = '#{lobby_hash}'"

    query = """
    SELECT u.id
    FROM account_users u
    WHERE #{lobby_hash_fragment}
"""

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, results} ->
        results.rows
        |> List.flatten

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  defp get_smurfs_by_hw(user) do
    user_stats = get_user_stat(user.id).data

    hw_fingerprint = user_stats["hw_fingerprint"]
    hw_fragement = "u.data ->> 'hw_fingerprint' = '#{hw_fingerprint}'"

    query = """
    SELECT u.user_id
    FROM teiserver_account_user_stats u
    WHERE #{hw_fragement}
"""

    case Ecto.Adapters.SQL.query(Repo, query, []) do
      {:ok, results} ->
        results.rows
        |> List.flatten

      {a, b} ->
        raise "ERR: #{a}, #{b}"
    end
  end

  # Gets the the roles for the user based on their flags/data
  @spec get_roles(User.t()) :: [String.t()]
  def get_roles(user) do
    [
      (if user.data["moderator"] == true, do: "Moderator"),
      (if user.data["bot"] == true, do: "Bot"),
      (if user.data["verified"] == true, do: "Verified"),

      (if "Streamer" in (user.data["roles"] || []), do: "Streamer"),
      (if "Tester" in (user.data["roles"] || []), do: "Tester"),
      (if "Donor" in (user.data["roles"] || []), do: "Donor"),
      (if "Contributor" in (user.data["roles"] || []), do: "Contributor"),
      (if "Developer" in (user.data["roles"] || []), do: "Developer"),
    ]
    |> Enum.filter(fn r -> r != nil end)
    |> Enum.map(fn r -> String.downcase(r) end)
  end

  def update_user_roles(user) do
    # First we remove all these permissions
    remove_permissions = Teiserver.User.role_list()
    |> Enum.map(fn r -> "teiserver.player.#{r}" end)

    base_permissions = user.permissions
    |> Enum.filter(fn r -> not Enum.member?(remove_permissions, r) end)

    # Then we add back in the ones we want this person to have
    add_permissions = get_roles(user)
    |> Enum.map(fn r -> "teiserver.player.#{r}" end)

    permissions = base_permissions ++ add_permissions

    Central.Account.update_user(user, %{"permissions" => permissions})
  end

  # Group stuff
  def create_group_membership(params),
    do: Central.Account.create_group_membership(params)

  # Reports
  def list_reports(args), do: Central.Account.list_reports(args)
  def get_report!(id), do: Central.Account.get_report!(id)
  def get_report!(id, args), do: Central.Account.get_report!(id, args)

  def create_report(_, nil, _, _, _), do: {:error, "no target user"}
  def create_report(reporter_id, target_id, location, location_id, reason) do
    params = %{
      "reason" => reason,
      "target_id" => target_id,
      "location" => location,
      "location_id" => location_id,
      "reporter_id" => reporter_id
    }

    case Central.Account.create_report(params) do
      {:ok, report} -> {:ok, report}
      {:error, _} -> {:error, "database error"}
    end
  end

  # User stat table
  alias Teiserver.Account.UserStat
  alias Teiserver.Account.UserStatLib

  def user_stat_query(args) do
    user_stat_query(nil, args)
  end

  def user_stat_query(id, args) do
    UserStatLib.query_user_stats()
    |> UserStatLib.search(%{user_id: id})
    |> UserStatLib.search(args[:search])
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
    |> Repo.one
  end

  def get_user_stat_data(userid) do
    ConCache.get_or_store(:teiserver_user_stat_cache, userid, fn ->
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
  def update_user_stat(userid, new_data) when is_integer(userid) do
    case get_user_stat(userid) do
      nil ->
        create_user_stat(%{user_id: userid, data: new_data})
      user_stat ->
        ConCache.dirty_delete(:teiserver_user_stat_cache, userid)
        new_data = Map.merge(user_stat.data, new_data)
        update_user_stat(user_stat, %{data: new_data})
    end
  end
  # Teiserver.Account.update_user_stat(3, %{"key1" => "valueXXXX"})
  # Teiserver.Account.get_user_stat(3)

  # This is the database call, typically you'd not need to use this
  def update_user_stat(%UserStat{} = user_stat, attrs) do
    user_stat
    |> UserStat.changeset(attrs)
    |> Repo.update()
  end
end
