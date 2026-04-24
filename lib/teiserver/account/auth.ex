defmodule Teiserver.Account.Auth do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Data.Types, as: T
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
  def authorize(:full_chat, conn, _data), do: allow?(conn, "Reviewer")
  def authorize(:update, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:applying, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:data_search, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:relationships, conn, _data), do: allow?(conn, "Moderator")
  def authorize(:gdpr_clean, conn, _data), do: allow?(conn, "Moderator")
  def authorize(_action, conn, _data), do: allow?(conn, "admin.dev")

  # credo:disable-for-lines:5 Credo.Check.Readability.PredicateFunctionNames
  @spec is_bot?(T.userid() | T.user()) :: boolean()
  def is_bot?(nil), do: false
  def is_bot?(userid) when is_integer(userid), do: is_bot?(Account.get_user_by_id(userid))
  def is_bot?(%{roles: roles}), do: Enum.member?(roles, "Bot")
  def is_bot?(_user), do: false

  @spec moderator?(T.userid() | T.user()) :: boolean()
  def moderator?(nil), do: false

  def moderator?(userid) when is_integer(userid),
    do: moderator?(Account.get_user_by_id(userid))

  def moderator?(%{roles: roles}), do: Enum.member?(roles, "Moderator")
  def moderator?(_user), do: false

  # credo:disable-for-lines:8 Credo.Check.Readability.PredicateFunctionNames
  @spec is_event_organizer?(T.userid() | T.user()) :: boolean()
  def is_event_organizer?(nil), do: false

  def is_event_organizer?(userid) when is_integer(userid),
    do: is_event_organizer?(Account.get_user_by_id(userid))

  def is_event_organizer?(%{roles: roles}), do: Enum.member?(roles, "Event Organizer")
  def is_event_organizer?(_user), do: false

  @spec contributor?(T.userid() | T.user()) :: boolean()
  def contributor?(nil), do: false

  def contributor?(userid) when is_integer(userid),
    do: contributor?(Account.get_user_by_id(userid))

  def contributor?(%{roles: roles}), do: Enum.member?(roles, "Contributor")
  def contributor?(_user), do: false

  @spec verified?(T.userid() | T.user()) :: boolean()
  def verified?(nil), do: false

  def verified?(userid) when is_integer(userid),
    do: verified?(Account.get_user_by_id(userid))

  def verified?(%{roles: roles}), do: Enum.member?(roles, "Verified")
  def verified?(_user), do: false

  @spec admin?(T.userid() | T.user()) :: boolean()
  def admin?(nil), do: false
  def admin?(userid) when is_integer(userid), do: admin?(Account.get_user_by_id(userid))
  def admin?(%{roles: roles}), do: Enum.member?(roles, "Admin")
  def admin?(_user), do: false

  @spec vip?(T.userid() | T.user()) :: boolean()
  def vip?(nil), do: false
  def vip?(userid) when is_integer(userid), do: vip?(Account.get_user_by_id(userid))
  def vip?(%{roles: roles}), do: Enum.member?(roles, "VIP")
  def vip?(_user), do: false

  @doc """
  If a user possesses any of these roles it returns true
  """
  @spec has_any_role?(T.userid() | T.user() | nil, String.t() | [String.t()]) :: boolean()
  def has_any_role?(nil, _roles), do: false

  def has_any_role?(userid, roles) when is_integer(userid),
    do: has_any_role?(Account.get_user_by_id(userid), roles)

  def has_any_role?(user, roles) when is_list(roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.any?()
  end

  def has_any_role?(user, role), do: has_any_role?(user, [role])

  @doc """
  If a user possesses all of these roles it returns true, if any are lacking it returns false
  """
  @spec has_all_roles?(T.userid() | T.user() | nil, String.t() | [String.t()]) :: boolean()
  def has_all_roles?(nil, _roles), do: false

  def has_all_roles?(userid, roles) when is_integer(userid),
    do: has_all_roles?(Account.get_user_by_id(userid), roles)

  def has_all_roles?(user, roles) when is_list(roles) do
    roles
    |> Enum.map(fn role -> Enum.member?(user.roles, role) end)
    |> Enum.all?()
  end

  def has_all_roles?(user, role), do: has_all_roles?(user, [role])
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
