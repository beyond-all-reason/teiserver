defmodule Central.Account do
  @moduledoc """
  The Account context.
  """

  import Ecto.Query, warn: false
  alias Central.Helpers.QueryHelpers
  alias Central.Repo

  alias Argon2

  alias Central.Account.User
  alias Central.Account.UserQueries
  import Central.Logging.Helpers, only: [add_anonymous_audit_log: 3]

  def icon, do: "fad fa-user-alt"

  defp user_query(args) do
    user_query(nil, args)
  end

  defp user_query(id, args) do
    UserQueries.get_users()
    |> UserQueries.search(%{id: id})
    |> UserQueries.search(args[:search])
    |> UserQueries.preload(args[:joins])
    |> UserQueries.order(args[:order])
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
    ConCache.get_or_store(:account_user_cache_bang, id, fn ->
      user_query(id, [])
      |> Repo.one!()
    end)
  end

  def get_user!(args) do
    user_query(nil, args)
    |> Repo.one!()
  end

  def get_user!(id, args) do
    user_query(id, args)
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
    ConCache.get_or_store(:account_user_cache, id, fn ->
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
    UserQueries.get_users()
    |> UserQueries.search(%{name: String.trim(name)})
    |> Repo.one()
  end

  @spec get_user_by_email(String.t()) :: User.t() | nil
  def get_user_by_email(email) do
    UserQueries.get_users()
    |> UserQueries.search(%{email: String.trim(email)})
    |> Repo.one()
  end

  def recache_user(nil), do: nil
  def recache_user(%User{} = user), do: recache_user(user.id)

  def recache_user(id) do
    ConCache.dirty_delete(:account_user_cache, id)
    ConCache.dirty_delete(:account_user_cache_bang, id)
    ConCache.dirty_delete(:account_membership_cache, id)
    ConCache.dirty_delete(:communication_user_notifications, id)
    ConCache.dirty_delete(:config_user_cache, id)
  end

  def broadcast_create_user({:ok, user}) do
    CentralWeb.Endpoint.broadcast(
      "account_hooks",
      "create_user",
      user.id
    )

    {:ok, user}
  end

  def broadcast_create_user(v), do: v

  def broadcast_update_user({:ok, user}) do
    CentralWeb.Endpoint.broadcast(
      "account_hooks",
      "update_user",
      user.id
    )

    {:ok, user}
  end

  def broadcast_update_user(v), do: v

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

  def merge_default_params(user_params) do
    Map.merge(
      %{
        "icon" => "fas fa-" <> Central.Helpers.StylingHelper.random_icon(),
        "colour" => Central.Helpers.StylingHelper.random_colour()
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

  def authenticate_user(conn, %User{} = user, plain_text_password) do
    if User.verify_password(plain_text_password, user.password) do
      {:ok, user}
    else
      add_anonymous_audit_log(conn, "Account: Failed login", %{
        reason: "Bad password",
        user_id: user.id,
        email: user.email
      })

      {:error, "Invalid credentials"}
    end
  end

  def authenticate_user(conn, email, plain_text_password) do
    query = from u in User, where: u.email == ^email

    case Repo.one(query) do
      nil ->
        Argon2.no_user_verify()
        add_anonymous_audit_log(conn, "Account: Failed login", %{reason: "No user", email: email})
        {:error, "Invalid credentials"}

      user ->
        authenticate_user(conn, user, plain_text_password)
    end
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

  alias Central.Account.Group
  alias Central.Account.GroupLib

  defp group_query(args) do
    group_query(nil, args)
  end

  defp group_query(id, args) do
    GroupLib.get_groups()
    |> GroupLib.search(%{id: id})
    |> GroupLib.search(args[:search])
    |> GroupLib.preload(args[:joins])
    |> GroupLib.order(args[:order])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of groups.

  ## Examples

      iex> list_groups()
      [%Group{}, ...]

  """
  def list_groups(args \\ []) do
    group_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single group.

  Raises `Ecto.NoResultsError` if the Group does not exist.

  ## Examples

      iex> get_group!(123)
      %Group{}

      iex> get_group!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group!(id) when not is_list(id) do
    group_query(id, [])
    |> Repo.one!()
  end

  def get_group!(args) do
    group_query(nil, args)
    |> Repo.one!()
  end

  def get_group!(id, args) do
    group_query(id, args)
    |> Repo.one!()
  end

  def get_group(id, args \\ []) when not is_list(id) do
    group_query(id, args)
    |> Repo.one()
  end

  def create_group(attrs \\ %{}) do
    %Group{}
    |> Group.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a group.

  ## Examples

      iex> update_group(group, %{field: new_value})
      {:ok, %Group{}}

      iex> update_group(group, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_group(%Group{} = group, attrs) do
    group
    |> Group.changeset(attrs)
    |> Repo.update()
  end

  def update_group_non_admin(%Group{} = group, attrs) do
    group
    |> Group.non_admin_changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a Group.

  ## Examples

      iex> delete_group(group)
      {:ok, %Group{}}

      iex> delete_group(group)
      {:error, %Ecto.Changeset{}}

  """
  def delete_group(%Group{} = group) do
    Repo.delete(group)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group changes.

  ## Examples

      iex> change_group(group)
      %Ecto.Changeset{source: %Group{}}

  """
  def change_group(%Group{} = group) do
    Group.changeset(group, %{})
  end

  def group_as_json(groups) when is_list(groups) do
    groups
    |> Enum.map(&group_as_json/1)
  end

  def group_as_json(group) do
    %{
      id: group.id,
      name: group.name,
      icon: group.icon,
      colour: group.colour,
      html_label: "#{group.name}",
      html_value: "##{group.id} - #{group.name}"
    }
  end

  alias Central.Account.GroupMembership
  alias Central.Account.GroupMembershipLib

  def list_group_memberships([user_id: user_id] = args) do
    GroupMembershipLib.get_group_memberships()
    |> GroupMembershipLib.search(user_id: user_id)
    |> GroupMembershipLib.search(args)
    |> GroupMembershipLib.preload(args[:joins])
    |> QueryHelpers.select(args[:select])
    # |> QueryHelpers.limit_query(50)
    |> Repo.all()
  end

  def list_group_memberships_cache(user_id) do
    ConCache.get_or_store(:account_membership_cache, user_id, fn ->
      query =
        from ugm in GroupMembership,
          join: ug in Group,
          on: ugm.group_id == ug.id,
          where: ugm.user_id == ^user_id,
          select: {ug.id, ug.children_cache}

      Repo.all(query)
      |> Enum.map(fn {g, gc} -> gc ++ [g] end)
      |> List.flatten()
      |> Enum.uniq()
    end)
  end

  @doc """
  Gets a single group_membership.

  Raises `Ecto.NoResultsError` if the GroupMembership does not exist.

  ## Examples

      iex> get_group_membership!(123)
      %GroupMembership{}

      iex> get_group_membership!(456)
      ** (Ecto.NoResultsError)

  """
  def get_group_membership!(user_id, group_id) do
    GroupMembershipLib.get_group_memberships()
    |> GroupMembershipLib.search(user_id: user_id, group_id: group_id)
    |> Repo.one!()
  end

  def create_group_membership(attrs \\ %{}) do
    r =
      %GroupMembership{}
      |> GroupMembership.changeset(attrs)
      |> Repo.insert()

    recache_user(attrs["user_id"])
    r
  end

  @doc """
  Updates a group_membership.

  ## Examples

      iex> update_group_membership(group_membership, %{field: new_value})
      {:ok, %GroupMembership{}}

      iex> update_group_membership(group_membership, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_group_membership(%GroupMembership{} = group_membership, attrs) do
    group_membership
    |> GroupMembership.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a GroupMembership.

  ## Examples

      iex> delete_group_membership(group_membership)
      {:ok, %GroupMembership{}}

      iex> delete_group_membership(group_membership)
      {:error, %Ecto.Changeset{}}

  """
  def delete_group_membership(%GroupMembership{} = group_membership) do
    recache_user(group_membership.user_id)
    Repo.delete(group_membership)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking group_membership changes.

  ## Examples

      iex> change_group_membership(group_membership)
      %Ecto.Changeset{source: %GroupMembership{}}

  """
  def change_group_membership(%GroupMembership{} = group_membership) do
    GroupMembership.changeset(group_membership, %{})
  end

  alias Central.Account.Code
  alias Central.Account.CodeLib

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
    |> Repo.one()
  end

  def get_code!(value, args \\ []) do
    code_query(value, args)
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

  alias Central.Account.Report
  alias Central.Account.ReportLib

  def report_query(args) do
    report_query(nil, args)
  end

  def report_query(id, args) do
    ReportLib.query_reports()
    |> ReportLib.search(%{id: id})
    |> ReportLib.search(args[:search])
    |> ReportLib.preload(args[:preload])
    |> ReportLib.order_by(args[:order_by])
    |> QueryHelpers.select(args[:select])
  end

  @doc """
  Returns the list of reports.

  ## Examples

      iex> list_reports()
      [%Report{}, ...]

  """
  def list_reports(args \\ []) do
    report_query(args)
    |> QueryHelpers.limit_query(args[:limit] || 50)
    |> Repo.all()
  end

  @doc """
  Gets a single report.

  Raises `Ecto.NoResultsError` if the Report does not exist.

  ## Examples

      iex> get_report!(123)
      %Report{}

      iex> get_report!(456)
      ** (Ecto.NoResultsError)

  """
  def get_report!(id) when not is_list(id) do
    report_query(id, [])
    |> Repo.one!()
  end

  def get_report!(args) do
    report_query(nil, args)
    |> Repo.one!()
  end

  def get_report!(id, args) do
    report_query(id, args)
    |> Repo.one!()
  end

  # Uncomment this if needed, default files do not need this function
  # @doc """
  # Gets a single report.

  # Returns `nil` if the Report does not exist.

  # ## Examples

  #     iex> get_report(123)
  #     %Report{}

  #     iex> get_report(456)
  #     nil

  # """
  # def get_report(id, args \\ []) when not is_list(id) do
  #   report_query(id, args)
  #   |> Repo.one
  # end

  @doc """
  Creates a report.

  ## Examples

      iex> create_report(%{field: value})
      {:ok, %Report{}}

      iex> create_report(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_report(attrs \\ %{}) do
    %Report{}
    |> Report.create_changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a report.

  ## Examples

      iex> update_report(report, %{field: new_value})
      {:ok, %Report{}}

      iex> update_report(report, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_report(%Report{} = report, attrs) do
    report
    |> Report.respond_changeset(attrs)
    |> Repo.update()
    |> broadcast_update_report
  end

  def broadcast_update_report({:ok, report}) do
    CentralWeb.Endpoint.broadcast(
      "account_hooks",
      "update_report",
      report.id
    )

    {:ok, report}
  end

  def broadcast_update_report(v), do: v

  @doc """
  Deletes a Report.

  ## Examples

      iex> delete_report(report)
      {:ok, %Report{}}

      iex> delete_report(report)
      {:error, %Ecto.Changeset{}}

  """
  def delete_report(%Report{} = report) do
    Repo.delete(report)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking report changes.

  ## Examples

      iex> change_report(report)
      %Ecto.Changeset{source: %Report{}}

  """
  def change_report(%Report{} = report) do
    Report.changeset(report, %{})
  end
end
