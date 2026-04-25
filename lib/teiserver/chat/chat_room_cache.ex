defmodule Teiserver.Room do
  @moduledoc false

  alias Phoenix.PubSub
  alias Teiserver.Account
  alias Teiserver.Account.Auth
  alias Teiserver.CacheUser
  alias Teiserver.Chat
  alias Teiserver.Chat.RoomRegistry
  alias Teiserver.Chat.RoomServer
  alias Teiserver.Chat.RoomSupervisor
  alias Teiserver.Chat.WordLib
  alias Teiserver.Coordinator
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Moderation
  alias Teiserver.Plugins

  use Plugins

  require Logger

  @type room :: Chat.RoomServer.room()

  @spec create_room(map()) :: map()
  def create_room(%{name: _name} = room) do
    Map.merge(
      %{
        members: [],
        password: "",
        clan_id: nil
      },
      room
    )
  end

  @spec create_room(String.t(), T.userid(), T.clan_id() | nil) :: map()
  def create_room(room_name, author_id, clan_id \\ nil) do
    %{
      name: room_name,
      members: [],
      author_id: author_id,
      topic: "topic",
      password: "",
      clan_id: clan_id
    }
  end

  def remove_room(room_name) do
    RoomServer.stop_room(room_name)
  end

  @spec get_room(String.t()) :: room() | nil
  defdelegate get_room(name), to: RoomServer

  @spec can_join_room?(T.userid(), String.t()) :: true | {false, String.t()}
  def can_join_room?(userid, room_name) do
    user = Account.get_user_by_id(userid)

    cond do
      user == nil ->
        {false, "No user"}

      Auth.admin?(user) or Auth.moderator?(user) == true ->
        true

      true ->
        case RoomServer.can_join_room?(room_name, user) do
          :invalid_room ->
            get_or_make_room(room_name, userid, user.clan_id)
            true

          x ->
            x
        end
    end
  end

  @spec get_or_make_room(String.t(), T.userid(), T.clan_id() | nil) :: RoomServer.room()
  def get_or_make_room(name, author_id, clan_id \\ nil) do
    case RoomServer.get_room(name) do
      nil ->
        case RoomSupervisor.start_room(name, author_id, "", "", clan_id) do
          {:ok, _pid} -> get_or_make_room(name, author_id, clan_id)
          {:ok, _pid, _info} -> get_or_make_room(name, author_id, clan_id)
          {:error, {:already_started, _pid}} -> get_or_make_room(name, author_id, clan_id)
        end

      room ->
        room
    end
  end

  def add_user_to_room(userid, room_name, pid \\ self()) do
    case RoomServer.join_room(room_name, userid, pid) do
      {:ok, :already_present} ->
        :ok

      {:ok, :joined} ->
        PubSub.broadcast(
          Teiserver.PubSub,
          "room:#{room_name}",
          {:add_user_to_room, userid, room_name}
        )

        :ok

      # not great, but we keep the same semantics from ets based impl
      {:error, :invalid_room} ->
        :ok
    end
  end

  def remove_user_from_room(userid, room_name) do
    RoomServer.leave_room(room_name, userid)
  end

  @spec clan_room_name(String.t()) :: String.t()
  def clan_room_name(clan_name) do
    safe_name =
      clan_name
      |> String.replace(" ", "")
      |> String.replace("-", "")

    "clan_#{safe_name}"
  end

  @spec list_rooms() :: [{String.t(), member_count :: non_neg_integer()}]
  defdelegate list_rooms(), to: RoomRegistry

  @spec send_message(T.userid() | T.user(), String.t(), String.t() | [String.t()]) :: nil | :ok
  def send_message(from_id, _room_name, "$" <> msg) do
    CacheUser.send_direct_message(from_id, Coordinator.get_coordinator_userid(), "$" <> msg)
  end

  def send_message(from_id, room_name, messages) when is_list(messages) do
    user = Account.get_user_by_id(from_id)
    if user != nil, do: Enum.map(messages, fn msg -> send_message(user, room_name, msg) end)
  end

  def send_message(from_id, room_name, msg) when is_integer(from_id) do
    user = Account.get_user_by_id(from_id)
    if user != nil, do: send_message(user, room_name, msg)
  end

  def send_message(user, room_name, msg) do
    if Auth.is_bot?(user) == false and WordLib.flagged_words(msg) > 0 do
      Moderation.unbridge_user(user, msg, WordLib.flagged_words(msg), "public_chat:#{room_name}")
    end

    cond do
      allow?(user.id) == false ->
        nil

      Auth.is_bot?(user) == false and WordLib.blacklisted_phrase?(msg) ->
        CacheUser.shadowban_user(user.id)
        nil

      true ->
        do_send_message(room_name, user, msg)
    end
  end

  @decorate Plugins.plugin(:send_chat_message)
  defp do_send_message(room_name, %{id: user_id}, msg) do
    RoomServer.send_message(room_name, user_id, msg)
  end

  @spec send_message_ex(T.userid(), String.t(), String.t()) :: nil | :ok
  def send_message_ex(from_id, room_name, msg) do
    user = Account.get_user_by_id(from_id)

    if Auth.is_bot?(user) == false and WordLib.flagged_words(msg) > 0 do
      Moderation.unbridge_user(user, msg, WordLib.flagged_words(msg), "public_chat:#{room_name}")
    end

    cond do
      allow?(user.id) == false ->
        nil

      Auth.is_bot?(user) == false and WordLib.blacklisted_phrase?(msg) ->
        CacheUser.shadowban_user(user.id)
        nil

      true ->
        do_send_message_ex(room_name, user, msg)
    end
  end

  @decorate Plugins.plugin(:send_chat_message_ex)
  defp do_send_message_ex(room_name, %{id: user_id}, msg) do
    RoomServer.send_message_ex(room_name, user_id, msg)
  end

  @spec allow?(T.userid()) :: boolean()
  def allow?(userid) do
    cond do
      CacheUser.is_shadowbanned?(userid) ->
        false

      CacheUser.restricted?(userid, ["All chat", "Room chat"]) ->
        false

      true ->
        true
    end
  end
end
