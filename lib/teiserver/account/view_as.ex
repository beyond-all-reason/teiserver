defmodule Teiserver.Account.ViewAs do
  @moduledoc """
  Lets a sufficiently privileged user view the site as another user, e.g. to
  test permissions. The target user id is kept in the session under
  `session_key/0`; the real (logged in) user is never replaced in the
  Guardian token, only the `current_user` assign is swapped.
  """

  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.User

  @session_key "view_as_user_id"
  @permission "Admin"

  def session_key, do: @session_key
  def permission, do: @permission

  @doc """
  Whether `real_user` is allowed to view the site as `target`.
  Nobody may view as themselves, and no-one may view as a user holding
  permissions they don't hold themselves (this prevents privilege escalation).
  """
  @spec can_view_as?(User.t() | nil, User.t() | nil) :: boolean()
  def can_view_as?(%User{} = real, %User{} = target) do
    real.id != target.id and AuthLib.allow?(real, @permission) and
      not AuthLib.allow?(target, @permission)
  end

  def can_view_as?(_real, _target), do: false

  @doc """
  Whether the viewer is allowed to use "view as" at all (used to decide if the
  button should be shown, enabled or not).
  """
  @spec can_use?(User.t() | nil) :: boolean()
  def can_use?(%User{} = real), do: AuthLib.allow?(real, @permission)
  def can_use?(_real), do: false

  @doc """
  Human readable reason why `real` can't view as `target`, or nil if they can.
  """
  @spec denial_reason(User.t() | nil, User.t() | nil) :: String.t() | nil
  def denial_reason(%User{} = real, %User{} = target) do
    cond do
      can_view_as?(real, target) ->
        nil

      real.id == target.id ->
        "You can't view the site as yourself."

      AuthLib.allow?(target, @permission) ->
        "You can't view the site as users with Admin permissions (this includes Server accounts), to prevent privilege escalation."

      true ->
        "You can't view the site as this user."
    end
  end

  def denial_reason(_real, _target), do: nil

  @doc """
  Given the logged-in user and the session value, returns
  `{effective_user, real_user_or_nil}`. Falls back to the real user if the
  request is invalid or no longer permitted.
  """
  @spec resolve(User.t() | nil, term()) :: {User.t() | nil, User.t() | nil}
  def resolve(real_user, session_value) do
    with %User{} <- real_user,
         id when not is_nil(id) <- parse_id(session_value),
         %User{} = target <- Account.get_user(id),
         true <- can_view_as?(real_user, target) do
      {target, real_user}
    else
      _any -> {real_user, nil}
    end
  end

  @doc """
  Parses a user id from the session or from a route param.
  """
  @spec parse_id(term()) :: integer() | nil
  def parse_id(id) when is_integer(id), do: id

  def parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int, ""} -> int
      _any -> nil
    end
  end

  def parse_id(_any), do: nil
end
