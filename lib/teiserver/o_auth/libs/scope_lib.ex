defmodule Teiserver.OAuth.Libs.ScopeLib do
  @moduledoc """
  OAuth scope related utilities, like auth checks
  """

  alias Teiserver.Account
  alias Teiserver.Account.Auth

  @spec allowed_scopes() :: [String.t()]
  def allowed_scopes do
    ["tachyon.lobby", "admin.map", "admin.engine", "admin.user"]
  end

  @spec all_scopes_allowed?(%Account.User{}, [String.t()]) :: :ok | {:error, [String.t()]}
  def all_scopes_allowed?(%Account.User{} = user, scopes) do
    invalid_scopes =
      Enum.reduce(scopes, [], fn scope, invalid_scopes ->
        if scope_allowed?(scope, user),
          do: invalid_scopes,
          else: [scope | invalid_scopes]
      end)

    if Enum.empty?(invalid_scopes),
      do: :ok,
      else: {:error, invalid_scopes}
  end

  @spec scope_allowed?(scope :: String.t(), Account.User.t()) :: boolean()
  def scope_allowed?("tachyon.lobby", _user), do: true
  def scope_allowed?("admin.map", user), do: Auth.admin?(user)
  def scope_allowed?("admin.engine", user), do: Auth.admin?(user)
  def scope_allowed?("admin.user", user), do: Auth.admin?(user)
  def scope_allowed?(_scope, _user), do: false
end
