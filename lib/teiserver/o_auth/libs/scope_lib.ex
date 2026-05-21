defmodule Teiserver.OAuth.Libs.ScopeLib do
  @moduledoc """
  OAuth scope related utilities, like auth checks
  """

  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Bot.Bot

  @spec allowed_scopes() :: [String.t()]
  def allowed_scopes do
    [
      # this is for blobby/new lobby
      "tachyon.lobby",
      # some scopes for bar specific administration and testing
      "admin.map",
      "admin.engine",
      "admin.user",
      # OpenID connect standard scopes (https://openid.net/specs/openid-connect-core-1_0.html#ScopeClaims)
      "profile",
      "email",
      # that one isn't truly standard but is widely used in practice
      "groups"
    ]
  end

  @spec all_scopes_allowed?(Account.User.t() | Bot.t(), [String.t()]) ::
          :ok | {:error, [String.t()]}
  # bots don't have a concept of permission/roles (yet?) so for now, just
  # assume that whatever scope they request is fine
  # they should not request scopes outside the app they are associated with,
  # but that's checked elsewhere
  def all_scopes_allowed?(%Bot{}, _scopes), do: :ok

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
  def scope_allowed?(scope, _user) when scope in ["tachyon.lobby", "profile", "email", "groups"],
    do: true

  def scope_allowed?("admin.map", user), do: Auth.admin?(user)
  def scope_allowed?("admin.engine", user), do: Auth.admin?(user)
  def scope_allowed?("admin.user", user), do: Auth.admin?(user)
  def scope_allowed?(_scope, _user), do: false

  @doc """
  User facing description of what a scope entails.
  This will ultimately have to be translated somehow, but for now just a
  simple english sentence is enough
  """
  @spec scope_description(String.t()) :: String.t() | nil
  def scope_description("tachyon.lobby"), do: "connect to tachyon for lobby and games"
  def scope_description("admin.map"), do: "for CI, to setup maps data in teiserver"
  def scope_description("admin.engine"), do: "for CI, to setup engine data in teiserver"
  def scope_description("admin.user"), do: "create users programatically. for load testing"
  def scope_description("profile"), do: "can get in game username"
  def scope_description("email"), do: "can get email address"
  def scope_description("groups"), do: "can get the roles for this user"
  def scope_description(_scope), do: nil

end
