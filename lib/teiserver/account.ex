defmodule Teiserver.Account do
  import Ecto.Query, warn: false
  alias Central.Repo
  require Logger
  alias Teiserver.Data.Types, as: T

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

  @spec smurf_search(User.t()) :: [{{String.t(), String.t()}, [SmurfKey.t()]}]
  def smurf_search(user) do
    values = list_smurf_keys(
      search: [
        user_id: user.id
      ],
      limit: :infinity,
      select: [:value]
    )
      |> Enum.map(fn %{value: value} -> value end)

    list_smurf_keys(
      search: [
        value_in: values,
        not_user_id: user.id
      ],
      preload: [:user, :type],
      limit: :infinity
    )
      |> Enum.group_by(fn sk -> {sk.type.name, sk.value} end)
      |> Enum.sort_by(fn {key, _value} -> key end, &<=/2)
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

  @spec spring_auth_check(Plug.Conn.t(), User.t, String.t()) :: {:ok, User.t} | {:error, String.t()}
  def spring_auth_check(conn, user, plain_text_password) do
    tei_user = get_user_by_id(user.id)
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


  alias Teiserver.Account.SmurfKey
  alias Teiserver.Account.SmurfKeyLib

  @spec smurf_key_query(List.t()) :: Ecto.Query.t()
  def smurf_key_query(args) do
    smurf_key_query(nil, args)
  end

  @spec smurf_key_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def smurf_key_query(id, args) do
    SmurfKeyLib.query_smurf_keys
      |> SmurfKeyLib.search(%{id: id})
      |> SmurfKeyLib.search(args[:search])
      |> SmurfKeyLib.preload(args[:preload])
      |> SmurfKeyLib.order_by(args[:order_by])
      |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of smurf_keys.

  ## Examples

      iex> list_smurf_keys()
      [%SmurfKey{}, ...]

  """
  @spec list_smurf_keys(List.t()) :: List.t()
  def list_smurf_keys(args \\ []) do
    smurf_key_query(args)
      |> QueryHelpers.limit_query(args[:limit] || 50)
      |> Repo.all
  end

  @doc """
  Gets a single smurf_key.

  Raises `Ecto.NoResultsError` if the SmurfKey does not exist.

  ## Examples

      iex> get_smurf_key!(123)
      %SmurfKey{}

      iex> get_smurf_key!(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_smurf_key!(Integer.t() | List.t()) :: SmurfKey.t()
  @spec get_smurf_key!(Integer.t(), List.t()) :: SmurfKey.t()
  def get_smurf_key!(id) when not is_list(id) do
    smurf_key_query(id, [])
    |> Repo.one!
  end
  def get_smurf_key!(args) do
    smurf_key_query(nil, args)
    |> Repo.one!
  end
  def get_smurf_key!(id, args) do
    smurf_key_query(id, args)
    |> Repo.one!
  end

  @doc """
  Gets a single smurf_key.

  Returns `nil` if the SmurfKey does not exist.

  ## Examples

      iex> get_smurf_key(123)
      %SmurfKey{}

      iex> get_smurf_key(456)
      nil

  """
  @spec get_smurf_key(Integer.t() | List.t()) :: SmurfKey.t()
  @spec get_smurf_key(Integer.t(), List.t()) :: SmurfKey.t()
  def get_smurf_key(id) when not is_list(id) do
    smurf_key_query(id, [])
    |> Repo.one
  end
  def get_smurf_key(args) do
    smurf_key_query(nil, args)
    |> Repo.one
  end
  def get_smurf_key(id, args) do
    smurf_key_query(id, args)
    |> Repo.one
  end

  @spec get_smurf_key(T.user_id, non_neg_integer(), String.t()) :: list()
  def get_smurf_key(user_id, type_id, value) do
    smurf_key_query(nil, search: [
      user_id: user_id,
      type_id: type_id,
      value: value
    ])
    |> Repo.all
  end

  @doc """
  Creates a smurf_key.

  ## Examples

      iex> create_smurf_key(%{field: value})
      {:ok, %SmurfKey{}}

      iex> create_smurf_key(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_smurf_key(non_neg_integer(), String.t(), String.t()) :: {:ok, SmurfKey.t()} | {:error, Ecto.Changeset.t()}
  def create_smurf_key(user_id, type_name, value) do
    type_id = get_or_add_smurf_key_type(type_name)

    case get_smurf_key(user_id, type_id, value) do
      [] ->
        %SmurfKey{}
          |> SmurfKey.changeset(%{user_id: user_id, value: value, type_id: type_id, last_updated: Timex.now()})
          |> Repo.insert()
      [existing] ->
        update_smurf_key(existing, %{last_updated: Timex.now()})
        {:ok, existing}
      [existing | _] ->
        Logger.error("#{__MODULE__}.create_smurf_key found user with two identical keys: #{user_id}, #{type_id}, #{value}")
        {:ok, existing}
    end
  end

  @doc """
  Updates a smurf_key.

  ## Examples

      iex> update_smurf_key(smurf_key, %{field: new_value})
      {:ok, %SmurfKey{}}

      iex> update_smurf_key(smurf_key, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec update_smurf_key(SmurfKey.t(), Map.t()) :: {:ok, SmurfKey.t()} | {:error, Ecto.Changeset.t()}
  def update_smurf_key(%SmurfKey{} = smurf_key, attrs) do
    smurf_key
    |> SmurfKey.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a SmurfKey.

  ## Examples

      iex> delete_smurf_key(smurf_key)
      {:ok, %SmurfKey{}}

      iex> delete_smurf_key(smurf_key)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_smurf_key(SmurfKey.t()) :: {:ok, SmurfKey.t()} | {:error, Ecto.Changeset.t()}
  def delete_smurf_key(%SmurfKey{} = smurf_key) do
    Repo.delete(smurf_key)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking smurf_key changes.

  ## Examples

      iex> change_smurf_key(smurf_key)
      %Ecto.Changeset{source: %SmurfKey{}}

  """
  @spec change_smurf_key(SmurfKey.t()) :: Ecto.Changeset.t()
  def change_smurf_key(%SmurfKey{} = smurf_key) do
    SmurfKey.changeset(smurf_key, %{})
  end

  alias Teiserver.Account.SmurfKeyType
  alias Teiserver.Account.SmurfKeyTypeLib

  @spec smurf_key_type_query(List.t()) :: Ecto.Query.t()
  def smurf_key_type_query(args) do
    smurf_key_type_query(nil, args)
  end

  @spec smurf_key_type_query(Integer.t(), List.t()) :: Ecto.Query.t()
  def smurf_key_type_query(id, args) do
    SmurfKeyTypeLib.query_smurf_key_types
      |> SmurfKeyTypeLib.search(%{id: id})
      |> SmurfKeyTypeLib.search(args[:search])
      |> SmurfKeyTypeLib.preload(args[:preload])
      |> SmurfKeyTypeLib.order_by(args[:order_by])
      |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of smurf_key_types.

  ## Examples

      iex> list_smurf_key_types()
      [%SmurfKeyType{}, ...]

  """
  @spec list_smurf_key_types(List.t()) :: List.t()
  def list_smurf_key_types(args \\ []) do
    smurf_key_type_query(args)
      |> QueryHelpers.limit_query(args[:limit] || 50)
      |> Repo.all
  end

  @doc """
  Gets a single smurf_key_type.

  Raises `Ecto.NoResultsError` if the SmurfKeyType does not exist.

  ## Examples

      iex> get_smurf_key_type(123)
      %SmurfKeyType{}

      iex> get_smurf_key_type(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_smurf_key_type(Integer.t() | List.t()) :: SmurfKeyType.t()
  @spec get_smurf_key_type(Integer.t(), List.t()) :: SmurfKeyType.t()
  def get_smurf_key_type(id) when not is_list(id) do
    smurf_key_type_query(id, [])
      |> Repo.one
  end
  def get_smurf_key_type(args) do
    smurf_key_type_query(nil, args)
      |> Repo.one
  end
  def get_smurf_key_type(id, args) do
    smurf_key_type_query(id, args)
      |> Repo.one
  end

  @doc """
  Creates a smurf_key_type.

  ## Examples

      iex> create_smurf_key_type(%{field: value})
      {:ok, %SmurfKeyType{}}

      iex> create_smurf_key_type(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_smurf_key_type(Map.t()) :: {:ok, SmurfKeyType.t()} | {:error, Ecto.Changeset.t()}
  def create_smurf_key_type(attrs \\ %{}) do
    %SmurfKeyType{}
      |> SmurfKeyType.changeset(attrs)
      |> Repo.insert()
  end

  @doc """
  Deletes a SmurfKeyType.

  ## Examples

      iex> delete_smurf_key_type(smurf_key_type)
      {:ok, %SmurfKeyType{}}

      iex> delete_smurf_key_type(smurf_key_type)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_smurf_key_type(SmurfKeyType.t()) :: {:ok, SmurfKeyType.t()} | {:error, Ecto.Changeset.t()}
  def delete_smurf_key_type(%SmurfKeyType{} = smurf_key_type) do
    Repo.delete(smurf_key_type)
  end

  def get_or_add_smurf_key_type(name) do
    name = String.trim(name)

    Central.cache_get_or_store(:teiserver_account_smurf_key_types, name, fn ->
      case list_smurf_key_types(search: [name: name], select: [:id], order_by: "ID (Lowest first)") do
        [] ->
          {:ok, key_type} = %SmurfKeyType{}
            |> SmurfKeyType.changeset(%{name: name})
            |> Repo.insert()

          key_type.id
        [%{id: id} | _] ->
          id
      end
    end)
  end

  alias Teiserver.Account.{Rating, RatingLib}

  @spec rating_query(List.t()) :: Ecto.Query.t()
  def rating_query(args) do
    RatingLib.query_ratings
      |> RatingLib.search(args[:search])
      |> RatingLib.preload(args[:preload])
      |> RatingLib.order_by(args[:order_by])
      |> QueryHelpers.select(args[:select])
      |> QueryHelpers.limit_query(args[:limit] || 50)
  end

  @doc """
  Returns the list of ratings.

  ## Examples

      iex> list_ratings()
      [%Rating{}, ...]

  """
  @spec list_ratings(List.t()) :: List.t()
  def list_ratings(args \\ []) do
    rating_query(args)
      |> Repo.all
  end

  @doc """
  Gets a single rating.

  Raises `Ecto.NoResultsError` if the Rating does not exist.

  ## Examples

      iex> get_rating(123)
      %Rating{}

      iex> get_rating(456)
      ** (Ecto.NoResultsError)

  """
  @spec get_rating(Integer.t() | List.t()) :: Rating.t()
  @spec get_rating(Integer.t(), List.t()) :: Rating.t()
  def get_rating(args) do
    rating_query(args)
      |> Repo.one
  end

  def get_rating(user_id, rating_type_id) when is_integer(user_id) and is_integer(rating_type_id) do
    Central.cache_get_or_store(:teiserver_user_ratings, {user_id, rating_type_id}, fn ->
      rating_query(search: [
        user_id: user_id,
        rating_type_id: rating_type_id
      ], limit: 1)
        |> Repo.one
    end)
  end

  @spec get_player_highest_leaderboard_rating(T.userid()) :: number()
  def get_player_highest_leaderboard_rating(user_id) do
    result = rating_query(
      search: [
        user_id: user_id,
      ],
      select: [:leaderboard_rating],
      order_by: "Leaderboard rating high to low",
      limit: 1
    )
      |> Repo.one

    if result do
      result.leaderboard_rating
    else
      0
    end
  end

  @doc """
  Creates a rating.

  ## Examples

      iex> create_rating(%{field: value})
      {:ok, %Rating{}}

      iex> create_rating(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_rating(Map.t()) :: {:ok, Rating.t()} | {:error, Ecto.Changeset.t()}
  def create_rating(attrs \\ %{}) do
    %Rating{}
      |> Rating.changeset(attrs)
      |> Repo.insert()
  end

  @spec update_rating(Rating.t(), map()) :: {:ok, Rating.t()} | {:error, Ecto.Changeset.t()}
  def update_rating(%Rating{} = rating, attrs) do
    Central.cache_delete(:teiserver_user_ratings, {rating.user_id, rating.rating_type_id})

    rating
      |> Rating.changeset(attrs)
      |> Repo.update()
  end

  @spec create_or_update_rating(Map.t()) :: {:ok, Rating.t()} | {:error, Ecto.Changeset.t()}
  def create_or_update_rating(attrs \\ %{}) do
    case get_rating(attrs.user_id, attrs.rating_type_id) do
      nil ->
        create_rating(attrs)
      existing ->
        update_rating(existing, attrs)
    end
  end

  @doc """
  Deletes a Rating.

  ## Examples

      iex> delete_rating(rating)
      {:ok, %Rating{}}

      iex> delete_rating(rating)
      {:error, %Ecto.Changeset{}}

  """
  @spec delete_rating(Rating.t()) :: {:ok, Rating.t()} | {:error, Ecto.Changeset.t()}
  def delete_rating(%Rating{} = rating) do
    Central.cache_delete(:teiserver_user_ratings, {rating.user_id, rating.rating_type_id})
    Repo.delete(rating)
  end



  # Codes
  alias Central.Account.{Code, CodeLib}

  def code_query(args) do
    code_query(nil, args)
  end

  def code_query(value, args) do
    CodeLib.query_codes()
      |> CodeLib.search(%{value: value})
      |> CodeLib.search(args[:search])
      |> CodeLib.preload(args[:preload])
      |> CodeLib.order_by(args[:order_by])
      |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of codes.

  ## Examples

      iex> list_codes()
      [%Code{}, ...]

  """
  def list_codes(args \\ []) do
    code_query(args)
      |> QueryHelpers.limit_query(args[:limit] || 50)
      |> Repo.all()
  end

  @doc """
  Gets a single code.

  Raises `Ecto.NoResultsError` if the Code does not exist.

  ## Examples

      iex> get_code!(123)
      %Code{}

      iex> get_code!(456)
      ** (Ecto.NoResultsError)

  """
  def get_code(value, args \\ []) do
    code_query(value, args)
      |> QueryHelpers.limit_query(args[:limit] || 1)
      |> Repo.one()
  end

  def get_code!(value, args \\ []) do
    code_query(value, args)
      |> QueryHelpers.limit_query(args[:limit] || 1)
      |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single code.

  # Returns `nil` if the Code does not exist.

  # ## Examples

  #     iex> get_code(123)
  #     %Code{}

  #     iex> get_code(456)
  #     nil

  # """
  # def get_code(id, args \\ []) when not is_list(id) do
  #   code_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a code.

  ## Examples

      iex> create_code(%{field: value})
      {:ok, %Code{}}

      iex> create_code(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  @spec create_code(map) :: {:ok, Code.t()} | {:error, Ecto.Changeset.t()}
  def create_code(attrs \\ %{}) do
    %Code{}
      |> Code.changeset(attrs)
      |> Repo.insert()
  end

  @doc """
  Updates a code.

  ## Examples

      iex> update_code(code, %{field: new_value})
      {:ok, %Code{}}

      iex> update_code(code, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_code(%Code{} = code, attrs) do
    code
      |> Code.changeset(attrs)
      |> Repo.update()
  end

  @doc """
  Deletes a Code.

  ## Examples

      iex> delete_code(code)
      {:ok, %Code{}}

      iex> delete_code(code)
      {:error, %Ecto.Changeset{}}

  """
  def delete_code(%Code{} = code) do
    Repo.delete(code)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking code changes.

  ## Examples

      iex> change_code(code)
      %Ecto.Changeset{source: %Code{}}

  """
  def change_code(%Code{} = code) do
    Code.changeset(code, %{})
  end

  # User functions
  alias alias Teiserver.Account.UserCache

  @spec get_username(T.userid()) :: String.t() | nil
  defdelegate get_username(userid), to: UserCache

  @spec get_username_by_id(T.userid()) :: String.t() | nil
  defdelegate get_username_by_id(userid), to: UserCache

  @spec get_userid_from_name(String.t()) :: integer() | nil
  def get_userid_from_name(name), do: UserCache.get_userid(name)

  @spec get_user_by_name(String.t()) :: T.user() | nil
  defdelegate get_user_by_name(username), to: UserCache

  @spec get_user_by_email(String.t()) :: T.user() | nil
  defdelegate get_user_by_email(email), to: UserCache

  @spec get_user_by_discord_id(String.t()) :: T.user() | nil
  defdelegate get_user_by_discord_id(discord_id), to: UserCache

  @spec get_userid_by_discord_id(String.t()) :: T.userid() | nil
  defdelegate get_userid_by_discord_id(discord_id), to: UserCache

  @spec get_user_by_token(String.t()) :: T.user() | nil
  defdelegate get_user_by_token(token), to: UserCache

  @spec get_user_by_id(T.userid()) :: T.user() | nil
  defdelegate get_user_by_id(id), to: UserCache

  @spec list_users_from_cache(list) :: list
  def list_users_from_cache(id_list), do: UserCache.list_users(id_list)

  @spec recache_user(Integer.t()) :: :ok
  defdelegate recache_user(id), to: UserCache

  @spec convert_user(T.user()) :: T.user()
  defdelegate convert_user(user), to: UserCache

  @spec add_user(T.user()) :: T.user()
  defdelegate add_user(user), to: UserCache

  @spec update_cache_user(T.userid(), map()) :: T.user()
  def update_cache_user(userid, user), do: UserCache.update_cache_user(userid, user)

  @spec delete_user(T.userid()) :: :ok | :no_user
  defdelegate delete_user(userid), to: UserCache

  @spec decache_user(T.userid()) :: :ok | :no_user
  defdelegate decache_user(userid), to: UserCache

  @spec unbridge_user(T.user(), String.t(), non_neg_integer(), String.t()) :: any
  defdelegate unbridge_user(user, message, flagged_word_count, location), to: Teiserver.User


  # Client stuff
  alias Teiserver.Account.ClientLib

  @spec get_client_by_name(String.t()) :: nil | T.client()
  defdelegate get_client_by_name(name), to: ClientLib

  @spec get_client_by_id(T.userid()) :: nil | T.client()
  defdelegate get_client_by_id(userid), to: ClientLib

  @spec client_exists?(T.userid()) :: boolean()
  defdelegate client_exists?(userid), to: ClientLib

  @spec get_clients([T.userid()]) :: List.t()
  defdelegate get_clients(id_list), to: ClientLib

  @spec list_client_ids() :: [T.userid()]
  defdelegate list_client_ids(), to: ClientLib

  @spec list_clients() :: [T.client()]
  defdelegate list_clients(), to: ClientLib

  @spec list_clients([T.userid()]) :: [T.client()]
  defdelegate list_clients(id_list), to: ClientLib

  @spec merge_update_client(Map.t()) :: :ok
  defdelegate merge_update_client(client), to: ClientLib

  @spec merge_update_client(T.userid(), Map.t()) :: :ok
  defdelegate merge_update_client(userid, client), to: ClientLib

  @spec replace_update_client(Map.t(), :silent | :client_updated_status | :client_updated_battlestatus) :: T.client()
  defdelegate replace_update_client(client, reason), to: ClientLib

  @spec move_client_to_party(T.userid(), T.party_id()) :: :ok | nil
  defdelegate move_client_to_party(userid, party_id), to: ClientLib

  @spec get_client_pid(T.userid()) :: pid() | nil
  defdelegate get_client_pid(userid), to: ClientLib

  @spec cast_client(T.userid(), any) :: any
  defdelegate cast_client(userid, msg), to: ClientLib

  @spec call_client(T.userid(), any) :: any | nil
  defdelegate call_client(userid, msg), to: ClientLib

  # Party stuff
  alias Teiserver.Account.PartyLib

  @spec list_party_ids() :: [T.party_id()]
  defdelegate list_party_ids(), to: PartyLib

  @spec list_parties([T.party_id()]) :: [T.party()]
  defdelegate list_parties(ids), to: PartyLib

  @spec get_party(T.party_id()) :: T.party()
  defdelegate get_party(party_id), to: PartyLib

  @spec create_party(T.userid()) :: T.party()
  defdelegate create_party(userid), to: PartyLib

  @spec create_party_invite(T.party_id(), T.userid()) :: :ok | nil
  defdelegate create_party_invite(party_id, userid), to: PartyLib

  @spec accept_party_invite(T.party_id(), T.userid()) :: {true, map()} | {false, String.t()} | nil
  defdelegate accept_party_invite(party_id, userid), to: PartyLib

  @spec cancel_party_invite(T.party_id(), T.userid()) :: :ok | nil
  defdelegate cancel_party_invite(party_id, userid), to: PartyLib

  @spec leave_party(T.party_id(), T.userid()) :: :ok | nil
  defdelegate leave_party(party_id, userid), to: PartyLib

  @spec kick_user_from_party(T.party_id(), T.userid()) :: :ok | nil
  defdelegate kick_user_from_party(party_id, userid), to: PartyLib

  @spec party_exists?(T.party_id()) :: boolean()
  defdelegate party_exists?(party_id), to: PartyLib

  @spec cast_party(T.party_id(), any) :: any | nil
  defdelegate cast_party(party_id, msg), to: PartyLib

  @spec call_party(T.party_id(), any) :: any | nil
  defdelegate call_party(party_id, msg), to: PartyLib
end
