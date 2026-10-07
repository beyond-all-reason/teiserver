defmodule Teiserver.CacheUser do
  @moduledoc """
  Users here are a combination of Teiserver.Account.User and the data within. They are merged like this into a map as their expected use case is very different.
  """

  alias Argon2
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.User
  alias Teiserver.Account.UserCacheLib
  alias Teiserver.CacheUser
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Plugins

  use Plugins

  require Logger

  # Keys kept from the raw user and merged into the memory user
  @spec keys() :: [atom]
  def keys,
    do:
      ~w(id name password email inserted_at permissions colour icon smurf_of_id last_login last_played last_logout roles discord_id)a

  defstruct [
    # Fields from the User struct itself
    :id,
    :name,
    :email,
    :password,
    :icon,
    :colour,
    :roles,
    :permissions,
    :restrictions,
    :restricted_until,
    :shadowbanned,
    :last_login,
    :last_played,
    :last_logout,
    :discord_id,
    :steam_id,
    :smurf_of_id,
    :inserted_at
  ]

  @type t() :: %CacheUser{
          # User struct attributes
          id: User.id(),
          name: String.t(),
          email: String.t() | nil,
          password: String.t() | nil,
          icon: String.t() | nil,
          colour: String.t() | nil,
          permissions: [String.t()],
          roles: [String.t()],
          restrictions: [String.t()],
          restricted_until: DateTime.t(),
          shadowbanned: boolean(),
          last_login: DateTime.t(),
          last_played: DateTime.t(),
          last_logout: DateTime.t(),
          discord_id: String.t() | nil,
          steam_id: String.t() | nil,
          smurf_of_id: integer() | nil,
          inserted_at: DateTime.t()
        }

  @data_keys [
    :last_login,
    :restrictions,
    :restricted_until,
    :shadowbanned,
    :discord_id,
    :steam_id
  ]
  def data_keys, do: @data_keys

  # Cache functions
  @spec get_username(User.id()) :: String.t() | nil
  defdelegate get_username(userid), to: UserCacheLib

  @spec get_userid_from_name(String.t()) :: integer() | nil
  defdelegate get_userid_from_name(username), to: UserCacheLib

  @spec get_userid_by_discord_id(String.t()) :: User.id() | nil
  defdelegate get_userid_by_discord_id(discord_id), to: UserCacheLib

  @spec deprecated_get_user_by_id(User.id()) :: T.user() | nil
  defdelegate deprecated_get_user_by_id(id), to: UserCacheLib

  @spec deprecated_recache_user(Integer.t()) :: :ok
  defdelegate deprecated_recache_user(id), to: UserCacheLib

  @spec convert_user(T.user()) :: T.user()
  defdelegate convert_user(user), to: UserCacheLib

  @spec add_user(T.user()) :: T.user()
  defdelegate add_user(user), to: UserCacheLib

  @spec deprecated_update_user(T.user(), [persist: boolean()] | nil) :: T.user()
  defdelegate deprecated_update_user(user, persist \\ []), to: UserCacheLib

  @spec decache_user(User.id()) :: :ok | :no_user
  defdelegate decache_user(userid), to: UserCacheLib

  @spec allow?(User.id() | T.user() | nil, String.t() | atom | [String.t()]) :: boolean()
  def allow?(nil, _required), do: false

  def allow?(userid, required) when is_integer(userid),
    do: allow?(Account.get_user_by_id(userid), required)

  def allow?(%User{} = user, required) do
    case required do
      :moderator ->
        Auth.admin?(user) or Auth.moderator?(user)

      :bot ->
        Auth.admin?(user) or Auth.moderator?(user) or Auth.is_bot?(user)

      required ->
        Enum.member?(user.permissions, required)
    end
  end
end
