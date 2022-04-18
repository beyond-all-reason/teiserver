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
    hash_ids = get_smurfs_by_hash(user)
    hw_ids = get_smurfs_by_hw(user)

    reasons = %{
      hash: hash_ids,
      hw: hw_ids
    }

    ids = (hash_ids ++ hw_ids)
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

  defp get_smurfs_by_hash(user) do
    user_stats = get_user_stat_data(user.id)
    lobby_hash = user_stats["lobby_hash"]

    if Enum.member?([nil, ""], lobby_hash) do
      []
    else
      hash_fragement = "u.data ->> 'lobby_hash' = '#{lobby_hash}'"

      query = """
      SELECT u.user_id
      FROM teiserver_account_user_stats u
      WHERE #{hash_fragement}
"""

      case Ecto.Adapters.SQL.query(Repo, query, []) do
        {:ok, results} ->
          results.rows
          |> List.flatten

        {a, b} ->
          raise "ERR: #{a}, #{b}"
      end
    end
  end

  defp get_smurfs_by_hw(user) do
    user_stats = get_user_stat_data(user.id)

    hw_fingerprint = user_stats["hw_fingerprint"]
    if hw_fingerprint == "" do
      []
    else
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
  end

  # Gets the the roles for the user based on their flags/data
  @spec get_roles(User.t()) :: [String.t()]
  def get_roles(user) do
    [
      (if user.data["moderator"] == true, do: "Moderator"),
      (if user.data["bot"] == true, do: "Bot"),
      (if user.data["verified"] == true, do: "Verified"),

      (if "Non-bridged" in (user.data["roles"] || []), do: "Non-bridged"),
      (if "Trusted" in (user.data["roles"] || []), do: "Trusted"),
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
    add_permissions = user.data["roles"]
    |> Enum.map(fn r -> "teiserver.player.#{String.downcase(r)}" end)

    permissions = base_permissions ++ add_permissions

    Central.Account.update_user(user, %{"permissions" => permissions})
  end

  # Group stuff
  def create_group_membership(params),
    do: Central.Account.create_group_membership(params)

  # Reports
  def list_reports(args), do: Central.Account.list_reports(args)
  def get_report(id), do: Central.Account.get_report(id)
  def get_report!(id), do: Central.Account.get_report!(id)
  def get_report!(id, args), do: Central.Account.get_report!(id, args)

  def update_report(report, params, reason), do: Central.Account.update_report(report, params, reason)

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

  def spring_auth_check(conn, user, plain_text_password) do
    tei_user = Teiserver.User.get_user_by_id(user.id)
    md5_password = Teiserver.User.spring_md5_password(plain_text_password)

    if Teiserver.User.test_password(md5_password, tei_user.password_hash) do
      update_user(user, %{password: plain_text_password})

      {:ok, user}
    else
      Central.Logging.Helpers.add_anonymous_audit_log(conn, "Account:Failed login", %{
        reason: "Bad password",
        user_id: user.id,
        email: user.email
      })

      {:error, "Invalid credentials"}
    end
  end

  # User stat table
  alias Teiserver.Account.UserStat
  alias Teiserver.Account.UserStatLib

  @spec user_stat_query(nil | maybe_improper_list | map) :: Ecto.Query.t()
  def user_stat_query(args) do
    user_stat_query(nil, args)
  end

  def user_stat_query(id, args) do
    UserStatLib.query_user_stats()
    |> UserStatLib.search(%{user_id: id})
    |> UserStatLib.search(args[:search])
    |> QueryHelpers.select(args[:select])
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

  @spec get_user_stat_data(integer()) :: Map.t()
  def get_user_stat_data(userid) do
    Central.cache_get_or_store(:teiserver_user_stat_cache, userid, fn ->
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
  def update_user_stat(userid, data) when is_integer(userid) do
    data = data
    |> Enum.map(fn {k, v} -> {to_string(k), v} end)
    |> Enum.filter(fn {_, v} -> v != nil end)
    |> Map.new

    case get_user_stat(userid) do
      nil ->
        create_user_stat(%{user_id: userid, data: data})
      user_stat ->
        Central.cache_delete(:teiserver_user_stat_cache, userid)
        new_data = Map.merge(user_stat.data, data)
        update_user_stat(user_stat, %{data: new_data})
    end
  end

  # This is the database call, typically you'd not need to use this
  def update_user_stat(%UserStat{} = user_stat, attrs) do
    user_stat
    |> UserStat.changeset(attrs)
    |> Repo.update()
  end

  def delete_user_stat_keys(userid, keys) when is_integer(userid) and is_list(keys) do
    case get_user_stat(userid) do
      nil ->
        :ok
      user_stat ->
        Central.cache_delete(:teiserver_user_stat_cache, userid)
        new_data = Map.drop(user_stat.data, keys)
        update_user_stat(user_stat, %{data: new_data})
    end
  end

  @spec delete_user_stat(UserStat.t()) :: {:ok, UserStat.t()} | {:error, Ecto.Changeset.t()}
  def delete_user_stat(%UserStat{} = user_stat) do
    Central.cache_delete(:teiserver_user_stat_cache, user_stat.user_id)
    Repo.delete(user_stat)
  end


  alias Teiserver.Account.AutomodAction
  alias Teiserver.Account.AutomodActionLib

  @spec automod_action_query(List.t()) :: Ecto.Query.t()
  def automod_action_query(args) do
    automod_action_query(nil, args)
  end

  @spec automod_action_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def automod_action_query(id, args) do
    AutomodActionLib.query_automod_actions
    |> AutomodActionLib.search(%{id: id})
    |> AutomodActionLib.search(args[:search])
    |> AutomodActionLib.preload(args[:preload])
    |> AutomodActionLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of automod_actions.

  ## Examples

      iex> list_automod_actions()
      [%AutomodAction{}, ...]

  """
  @spec list_automod_actions(List.t()) :: List.t()
  def list_automod_actions(args \\ []) do
    automod_action_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single automod_action.

  Raises `Ecto.NoResultsError` if the AutomodAction does not exist.

  ## Examples

      iex> get_automod_action!(123)
      %AutomodAction{}

      iex> get_automod_action!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_automod_action!(Integer.t() | List.t()) :: AutomodAction.t()
  @spec get_automod_action!(Integer.t(), List.t()) :: AutomodAction.t()
  def get_automod_action!(id) when not is_list(id) do
    automod_action_query(id, [])
    |> Repo.one!
  end
  def get_automod_action!(args) do
    automod_action_query(nil, args)
    |> Repo.one!
  end
  def get_automod_action!(id, args) do
    automod_action_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single automod_action.

  # Returns `nil` if the AutomodAction does not exist.

  # ## Examples

  #     iex> get_automod_action(123)
  #     %AutomodAction{}

  #     iex> get_automod_action(456)
  #     nil

  # """
  # def get_automod_action(id, args \\ []) when not is_list(id) do
  #   automod_action_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a automod_action.

  ## Examples

      iex> create_automod_action(%{field: value})
      {:ok, %AutomodAction{}}

      iex> create_automod_action(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_automod_action(Map.t()) :: {:ok, AutomodAction.t()} | {:error, Ecto.Changeset.t()}
  def create_automod_action(attrs \\ %{}) do
    %AutomodAction{}
    |> AutomodAction.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a automod_action.

  ## Examples

      iex> update_automod_action(automod_action, %{field: new_value})
      {:ok, %AutomodAction{}}

      iex> update_automod_action(automod_action, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_automod_action(AutomodAction.t(), Map.t()) :: {:ok, AutomodAction.t()} | {:error, Ecto.Changeset.t()}
  def update_automod_action(%AutomodAction{} = automod_action, attrs) do
    automod_action
    |> AutomodAction.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a AutomodAction.

  ## Examples

      iex> delete_automod_action(automod_action)
      {:ok, %AutomodAction{}}

      iex> delete_automod_action(automod_action)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_automod_action(AutomodAction.t()) :: {:ok, AutomodAction.t()} | {:error, Ecto.Changeset.t()}
  def delete_automod_action(%AutomodAction{} = automod_action) do
    Repo.delete(automod_action)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking automod_action changes.

  ## Examples

      iex> change_automod_action(automod_action)
      %Ecto.Changeset{source: %AutomodAction{}}

  """
  @spec change_automod_action(AutomodAction.t()) :: Ecto.Changeset.t()
  def change_automod_action(%AutomodAction{} = automod_action) do
    AutomodAction.changeset(automod_action, %{})
  end

  alias Teiserver.Account.BadgeType
  alias Teiserver.Account.BadgeTypeLib

  @spec badge_type_query(List.t()) :: Ecto.Query.t()
  def badge_type_query(args) do
    badge_type_query(nil, args)
  end

  @spec badge_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def badge_type_query(id, args) do
    BadgeTypeLib.query_badge_types
    |> BadgeTypeLib.search(%{id: id})
    |> BadgeTypeLib.search(args[:search])
    |> BadgeTypeLib.preload(args[:preload])
    |> BadgeTypeLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of badge_types.

  ## Examples

      iex> list_badge_types()
      [%BadgeType{}, ...]

  """
  @spec list_badge_types(List.t()) :: List.t()
  def list_badge_types(args \\ []) do
    badge_type_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single badge_type.

  Raises `Ecto.NoResultsError` if the BadgeType does not exist.

  ## Examples

      iex> get_badge_type!(123)
      %BadgeType{}

      iex> get_badge_type!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_badge_type!(Integer.t() | List.t()) :: BadgeType.t()
  @spec get_badge_type!(Integer.t(), List.t()) :: BadgeType.t()
  def get_badge_type!(id) when not is_list(id) do
    badge_type_query(id, [])
    |> Repo.one!
  end
  def get_badge_type!(args) do
    badge_type_query(nil, args)
    |> Repo.one!
  end
  def get_badge_type!(id, args) do
    badge_type_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single badge_type.

  # Returns `nil` if the BadgeType does not exist.

  # ## Examples

  #     iex> get_badge_type(123)
  #     %BadgeType{}

  #     iex> get_badge_type(456)
  #     nil

  # """
  # def get_badge_type(id, args \\ []) when not is_list(id) do
  #   badge_type_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a badge_type.

  ## Examples

      iex> create_badge_type(%{field: value})
      {:ok, %BadgeType{}}

      iex> create_badge_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_badge_type(Map.t()) :: {:ok, BadgeType.t()} | {:error, Ecto.Changeset.t()}
  def create_badge_type(attrs \\ %{}) do
    %BadgeType{}
    |> BadgeType.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a badge_type.

  ## Examples

      iex> update_badge_type(badge_type, %{field: new_value})
      {:ok, %BadgeType{}}

      iex> update_badge_type(badge_type, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_badge_type(BadgeType.t(), Map.t()) :: {:ok, BadgeType.t()} | {:error, Ecto.Changeset.t()}
  def update_badge_type(%BadgeType{} = badge_type, attrs) do
    badge_type
    |> BadgeType.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a BadgeType.

  ## Examples

      iex> delete_badge_type(badge_type)
      {:ok, %BadgeType{}}

      iex> delete_badge_type(badge_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_badge_type(BadgeType.t()) :: {:ok, BadgeType.t()} | {:error, Ecto.Changeset.t()}
  def delete_badge_type(%BadgeType{} = badge_type) do
    Repo.delete(badge_type)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking badge_type changes.

  ## Examples

      iex> change_badge_type(badge_type)
      %Ecto.Changeset{source: %BadgeType{}}

  """
  @spec change_badge_type(BadgeType.t()) :: Ecto.Changeset.t()
  def change_badge_type(%BadgeType{} = badge_type) do
    BadgeType.changeset(badge_type, %{})
  end

  alias Teiserver.Account.Accolade
  alias Teiserver.Account.AccoladeLib

  @spec accolade_query(List.t()) :: Ecto.Query.t()
  def accolade_query(args) do
    accolade_query(nil, args)
  end

  @spec accolade_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def accolade_query(id, args) do
    AccoladeLib.query_accolades
    |> AccoladeLib.search(%{id: id})
    |> AccoladeLib.search(args[:search])
    |> AccoladeLib.preload(args[:preload])
    |> AccoladeLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of accolades.

  ## Examples

      iex> list_accolades()
      [%Accolade{}, ...]

  """
  @spec list_accolades(List.t()) :: List.t()
  def list_accolades(args \\ []) do
    accolade_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all
  end

  @doc """
  Gets a single accolade.

  Raises `Ecto.NoResultsError` if the Accolade does not exist.

  ## Examples

      iex> get_accolade!(123)
      %Accolade{}

      iex> get_accolade!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_accolade!(Integer.t() | List.t()) :: Accolade.t()
  @spec get_accolade!(Integer.t(), List.t()) :: Accolade.t()
  def get_accolade!(id) when not is_list(id) do
    accolade_query(id, [])
    |> Repo.one!
  end
  def get_accolade!(args) do
    accolade_query(nil, args)
    |> Repo.one!
  end
  def get_accolade!(id, args) do
    accolade_query(id, args)
    |> Repo.one!
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single accolade.

  # Returns `nil` if the Accolade does not exist.

  # ## Examples

  #     iex> get_accolade(123)
  #     %Accolade{}

  #     iex> get_accolade(456)
  #     nil

  # """
  # def get_accolade(id, args \\ []) when not is_list(id) do
  #   accolade_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a accolade.

  ## Examples

      iex> create_accolade(%{field: value})
      {:ok, %Accolade{}}

      iex> create_accolade(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_accolade(Map.t()) :: {:ok, Accolade.t()} | {:error, Ecto.Changeset.t()}
  def create_accolade(attrs \\ %{}) do
    %Accolade{}
    |> Accolade.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a accolade.

  ## Examples

      iex> update_accolade(accolade, %{field: new_value})
      {:ok, %Accolade{}}

      iex> update_accolade(accolade, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_accolade(Accolade.t(), Map.t()) :: {:ok, Accolade.t()} | {:error, Ecto.Changeset.t()}
  def update_accolade(%Accolade{} = accolade, attrs) do
    accolade
    |> Accolade.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Accolade.

  ## Examples

      iex> delete_accolade(accolade)
      {:ok, %Accolade{}}

      iex> delete_accolade(accolade)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_accolade(Accolade.t()) :: {:ok, Accolade.t()} | {:error, Ecto.Changeset.t()}
  def delete_accolade(%Accolade{} = accolade) do
    Repo.delete(accolade)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking accolade changes.

  ## Examples

      iex> change_accolade(accolade)
      %Ecto.Changeset{source: %Accolade{}}

  """
  @spec change_accolade(Accolade.t()) :: Ecto.Changeset.t()
  def change_accolade(%Accolade{} = accolade) do
    Accolade.changeset(accolade, %{})
  end
end
