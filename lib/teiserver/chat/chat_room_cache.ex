defmodule Teiserver.Room do
  @moduledoc false
  require Logger
  alias Teiserver.{Account, CacheUser, Chat, Coordinator, Moderation}
  alias Teiserver.Chat.WordLib
  alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T

  @type room :: Chat.RoomServer.room()

  @spec create_room(map()) :: map()
  def create_room(%{name: _} = room) do
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
    Chat.RoomServer.stop_room(room_name)
  end

  @spec get_room(String.t()) :: room() | nil
  defdelegate get_room(name), to: Chat.RoomServer

  @spec can_join_room?(T.userid(), String.t()) :: true | {false, String.t()}
  def can_join_room?(userid, room_name) do
    user = Account.get_user_by_id(userid)

    cond do
      user == nil ->
        {false, "No user"}

      CacheUser.is_moderator?(user) == true ->
        true

      true ->
        case Chat.RoomServer.can_join_room?(room_name, user) do
          :invalid_room ->
            get_or_make_room(room_name, userid, user.clan_id)
            true

          x ->
            x
        end
    end
  end

  @spec get_or_make_room(String.t(), T.userid(), T.clan_id() | nil) :: Chat.RoomServer.room()
  def get_or_make_room(name, author_id, clan_id \\ nil) do
    case Chat.RoomServer.get_room(name) do
      nil ->
        {:ok, _pid} = Chat.RoomSupervisor.start_room(name, author_id, "", "", clan_id)
        get_or_make_room(name, author_id, clan_id)

      room ->
        room
    end
  end

  def add_user_to_room(userid, room_name) do
    case Chat.RoomServer.join_room(room_name, userid) do
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
    Teiserver.cache_update(:rooms, room_name, fn room_state ->
      new_state =
        if Enum.member?(room_state.members, userid) do
          PubSub.broadcast(
            Teiserver.PubSub,
            "room:#{room_name}",
            {:remove_user_from_room, userid, room_name}
          )

          new_members = Enum.filter(room_state.members, fn m -> m != userid end)
          Map.put(room_state, :members, new_members)
        else
          # No change takes place, they've already left the room
          room_state
        end

      {:ok, new_state}
    end)
  end

  @spec remove_user_from_any_room(integer() | nil) :: list()
  def remove_user_from_any_room(nil), do: []

  def remove_user_from_any_room(userid) do
    list_rooms()
    |> Enum.filter(fn r -> r && Enum.member?(r.members, userid) end)
    |> Enum.map(fn r ->
      remove_user_from_room(userid, r.name)
      r.name
    end)
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
  defdelegate list_rooms(), to: Chat.RoomRegistry

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
    if CacheUser.is_bot?(user) == false and WordLib.flagged_words(msg) > 0 do
      Moderation.unbridge_user(user, msg, WordLib.flagged_words(msg), "public_chat:#{room_name}")
    end

    blacklisted = CacheUser.is_bot?(user) == false and WordLib.blacklisted_phrase?(msg)

    if blacklisted do
      CacheUser.shadowban_user(user.id)
    end

    if allow?(user.id) do
      Chat.RoomServer.send_message(room_name, user.id, msg)
    end
  end

  @spec send_message_ex(T.userid(), String.t(), String.t()) :: nil | :ok
  def send_message_ex(from_id, room_name, msg) do
    user = Account.get_user_by_id(from_id)

    if CacheUser.is_bot?(user) == false and WordLib.flagged_words(msg) > 0 do
      Moderation.unbridge_user(user, msg, WordLib.flagged_words(msg), "public_chat:#{room_name}")
    end

    blacklisted = CacheUser.is_bot?(user) == false and WordLib.blacklisted_phrase?(msg)

    if blacklisted do
      CacheUser.shadowban_user(user.id)
    end

    if allow?(from_id) do
      Chat.RoomServer.send_message_ex(room_name, from_id, msg)
    end

    :ok
  end

  @spec allow?(T.userid()) :: boolean()
  def allow?(userid) do
    cond do
      CacheUser.is_shadowbanned?(userid) ->
        false

      CacheUser.is_restricted?(userid, ["All chat", "Room chat"]) ->
        false

      true ->
        true
    end
  end
end
