defmodule Teiserver.Account.Auth do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Account.User
  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy

  def authorize(:index, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:search, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:show, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:new, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:perform_action, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:rename_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:rename_post, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:reset_password, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:respond_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:respond_post, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:smurf_search, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:smurf_merge_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:smurf_merge_post, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:cancel_smurf_mark, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:mark_as_smurf_of, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:delete_smurf_key, conn, _data), do: allow?(conn, "admin.dev")
  def authorize(:automod_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:ratings, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:ratings_form, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:ratings_post, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:set_stat, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:edit, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:update, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:applying, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:data_search, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:relationships, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:gdpr_forget, conn, _data), do: allow?(conn, "Moderator")
  def authorize(_action, conn, _data), do: allow?(conn, "admin.dev")

  # credo:disable-for-lines:5 Credo.Check.Readability.PredicateFunctionNames
  @spec is_bot?(User.id() | User.t() | nil) :: boolean()
  def is_bot?(nil), do: false
  def is_bot?(userid) when is_integer(userid), do: is_bot?(Account.get_user(userid))
  def is_bot?(%User{} = %{roles: roles}), do: Enum.member?(roles, "Bot")
  def is_bot?(_user), do: false

  @spec moderator?(User.id() | User.t() | nil) :: boolean()
  def moderator?(nil), do: false

  def moderator?(userid) when is_integer(userid),
    do: moderator?(Account.get_user(userid))

  def moderator?(%User{} = user), do: allow?(user, "Moderator")
  def moderator?(_user), do: false

  # credo:disable-for-lines:8 Credo.Check.Readability.PredicateFunctionNames
  @spec is_event_organizer?(User.id() | User.t() | nil) :: boolean()
  def is_event_organizer?(nil), do: false

  def is_event_organizer?(userid) when is_integer(userid),
    do: is_event_organizer?(Account.get_user(userid))

  def is_event_organizer?(%User{} = user), do: allow?(user, "Event Organizer")
  def is_event_organizer?(_user), do: false

  @spec contributor?(User.id() | User.t() | nil) :: boolean()
  def contributor?(nil), do: false

  def contributor?(userid) when is_integer(userid),
    do: contributor?(Account.get_user(userid))

  def contributor?(%User{} = user), do: allow?(user, "Contributor")
  def contributor?(_user), do: false

  @spec verified?(User.id() | User.t() | nil) :: boolean()
  def verified?(nil), do: false

  def verified?(userid) when is_integer(userid),
    do: verified?(Account.get_user(userid))

  def verified?(%User{} = %{roles: roles}), do: Enum.member?(roles, "Verified")
  def verified?(_user), do: false

  @spec admin?(User.id() | User.t() | nil) :: boolean()
  def admin?(nil), do: false
  def admin?(userid) when is_integer(userid), do: admin?(Account.get_user(userid))
  def admin?(%User{} = user), do: allow?(user, "Admin")
  def admin?(_user), do: false

  @spec vip?(User.id() | User.t() | nil) :: boolean()
  def vip?(nil), do: false
  def vip?(userid) when is_integer(userid), do: vip?(Account.get_user(userid))
  def vip?(%User{} = user), do: allow?(user, "VIP")
  def vip?(_user), do: false

  @doc """
  If a user possesses any of these roles it returns true
  """
  @spec has_any_role?(User.id() | User.t() | nil, String.t() | [String.t()]) :: boolean()
  def has_any_role?(nil, _roles), do: false

  def has_any_role?(userid, roles) when is_integer(userid),
    do: has_any_role?(Account.get_user(userid), roles)

  def has_any_role?(%User{} = user, roles) when is_list(roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.any?()
  end

  def has_any_role?(user, role), do: has_any_role?(user, [role])

  @doc """
  If a user possesses all of these roles it returns true, if any are lacking it returns false
  """
  @spec has_all_roles?(User.id() | User.t() | nil, String.t() | [String.t()]) :: boolean()
  def has_all_roles?(nil, _roles), do: false

  def has_all_roles?(userid, roles) when is_integer(userid),
    do: has_all_roles?(Account.get_user(userid), roles)

  def has_all_roles?(%User{} = user, roles) when is_list(roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.all?()
  end

  def has_all_roles?(user, role), do: has_all_roles?(user, [role])

  @spec add_roles(User.id() | User.t() | nil, [String.t()]) :: nil | {:ok, User.t()}
  def add_roles(nil, _roles), do: nil
  def add_roles(_user, []), do: nil
  def add_roles(_user, nil), do: nil

  def add_roles(userid, roles) when is_integer(userid),
    do: add_roles(Account.get_user(userid), roles)

  def add_roles(%User{} = user, roles) do
    new_roles = Enum.uniq(roles ++ user.roles)
    Account.script_update_user(user, %{roles: new_roles})
  end

  @spec remove_roles(User.id() | User.t() | nil, [String.t()]) :: nil | User.t()
  def remove_roles(nil, _roles), do: nil
  def remove_roles(_user, []), do: nil

  def remove_roles(userid, roles) when is_integer(userid),
    do: remove_roles(Account.get_user(userid), roles)

  def remove_roles(%User{} = user, removed_roles) do
    new_roles =
      user.roles
      |> Enum.reject(fn r -> Enum.member?(removed_roles, r) end)

    Account.script_update_user(user, %{roles: new_roles})
  end
end

defmodule Teiserver.Auth.Server do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Server")
end

defmodule Teiserver.Staff.Admin do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Admin")
end

defmodule Teiserver.Staff.Moderator do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Moderator")
end

defmodule Teiserver.Staff.Reviewer do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Reviewer")
end

defmodule Teiserver.Staff.Overwatch do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Overwatch")
end

defmodule Teiserver.Staff.MatchAdmin do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(:show, conn, _data), do: allow?(conn, "Overwatch")
  def authorize(_action, conn, _data), do: allow?(conn, "Moderator")
end

defmodule Teiserver.Auth.Telemetry do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow_any?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow_any?(conn, ~w(Server Engine))
end

defmodule Teiserver.Staff do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "Contributor")
end

defmodule Teiserver.Auth do
  @moduledoc false

  import Teiserver.Account.AuthLib, only: [allow?: 2]
  @behaviour Bodyguard.Policy
  def authorize(_action, conn, _data), do: allow?(conn, "account")
end
