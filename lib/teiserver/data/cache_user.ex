defmodule Teiserver.CacheUser do
  @moduledoc """
  Users here are a combination of Teiserver.Account.User and the data within. They are merged like this into a map as their expected use case is very different.
  """

  alias Argon2
  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.Account.User
  alias Teiserver.Account.UserCacheLib
  alias Teiserver.Battle
  alias Teiserver.CacheUser
  alias Teiserver.Chat
  alias Teiserver.Chat.WordLib
  alias Teiserver.Client
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Moderation
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

  @spec send_direct_message(User.id(), User.id(), String.t()) :: :ok
  def send_direct_message(from_id, to_id, "!joinas" <> s),
    do: send_direct_message(from_id, to_id, "!cv joinas" <> s)

  @spec send_direct_message(User.id(), User.id(), list) :: :ok
  def send_direct_message(sender_id, to_id, message_parts) when is_list(message_parts) do
    msg_str = Enum.join(message_parts, "\n")

    sender_bot? = Auth.is_bot?(sender_id)
    recipient_bot? = Auth.is_bot?(to_id)
    blacklisted? = sender_bot? == false and WordLib.blacklisted_phrase?(msg_str)

    allowed =
      cond do
        blacklisted? -> false
        Account.restricted?(sender_id, ["All chat", "Direct chat"]) -> false
        true -> true
      end

    if blacklisted? do
      shadowban_user(sender_id)
    end

    if allowed do
      save_message =
        cond do
          sender_bot? -> false
          recipient_bot? and not persist_bot_dm?(msg_str) -> false
          true -> true
        end

      # Persist message but not if a JSONRPC being sent to a bot or
      # if the message was from a bot
      if save_message do
        Chat.create_direct_message(%{
          to_id: to_id,
          from_id: sender_id,
          content: msg_str,
          inserted_at: DateTime.utc_now(),
          delivered: true
        })
      end

      PubSub.broadcast(
        Teiserver.PubSub,
        "legacy_user_updates:#{to_id}",
        {:direct_message, sender_id, message_parts}
      )

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_messages:#{to_id}",
        %{
          channel: "teiserver_client_messages:#{to_id}",
          event: :received_direct_message,
          sender_id: sender_id,
          message_content: message_parts
        }
      )
    end

    :ok
  end

  def send_direct_message(_from_id, _to_id, nil), do: :ok

  def send_direct_message(from_id, to_id, message) do
    # Replace SPADS command (starting with !) with lowercase
    # version to prevent bypassing with capitalised command names
    # Ignore !# bot commands like !#JSONRPC
    # Allow voting for joinas if there are AIs in the
    # recipient's lobby, otherwise alias to spec
    message =
      if String.starts_with?(message, "!") and !String.starts_with?(message, "!#") do
        command_parts =
          message
          |> String.trim()
          |> String.downcase()
          |> String.split()

        case command_parts do
          ["!cv", "joinas" | _rest] ->
            has_ai =
              case Client.get_client_by_id(to_id) do
                %{lobby_id: lobby_id} when not is_nil(lobby_id) ->
                  Battle.get_bots(lobby_id) |> Enum.any?()

                _client ->
                  false
              end

            if has_ai, do: message, else: "!cv joinas spec"

          ["!callvote", "joinas" | _rest] ->
            has_ai =
              case Client.get_client_by_id(to_id) do
                %{lobby_id: lobby_id} when not is_nil(lobby_id) ->
                  Battle.get_bots(lobby_id) |> Enum.any?()

                _client ->
                  false
              end

            if has_ai, do: message, else: "!callvote joinas spec"

          ["!joinas" | _rest] ->
            "!joinas spec"

          _other ->
            message
        end
      else
        message
      end

    send_direct_message(from_id, to_id, [message])
  end

  defp persist_bot_dm?(message) do
    not String.starts_with?(message, "!#")
  end

  @spec ring(User.id(), User.id()) :: :ok
  def ring(ringee_id, ringer_id) do
    PubSub.broadcast(
      Teiserver.PubSub,
      "legacy_user_updates:#{ringee_id}",
      {:action, {:ring, ringer_id}}
    )

    PubSub.broadcast(
      Teiserver.PubSub,
      "client_application:#{ringee_id}",
      %{
        channel: "client_application:#{ringee_id}",
        event: :ring,
        userid: ringee_id,
        ringer_id: ringer_id
      }
    )

    :ok
  end

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
