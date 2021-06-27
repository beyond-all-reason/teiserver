defmodule Teiserver.Room do
  @moduledoc false
  require Logger
  alias Teiserver.User
  alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T

  @spec create_room(Map.t()) :: Map.t()
  @spec create_room(String.t(), T.userid()) :: Map.t()
  @spec create_room(String.t(), T.userid(), T.clan_id()) :: Map.t()
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

  @spec get_room(String.t()) :: Map.t()
  def get_room(name) do
    ConCache.get(:rooms, name)
  end

  @spec can_join_room?(T.userid(), String.t()) :: true | {false, String.t()}
  def can_join_room?(userid, room_name) do
    room = get_or_make_room(room_name, userid)
    user = User.get_user_by_id(userid)
    cond do
      user == nil ->
        {false, "No user?"}

      user.moderator == true ->
        true

      room.clan_id ->
        if user.clan_id == room.clan_id, do: true, else: {false, "Clan room"}

      true ->
        true
    end
  end

  @spec get_or_make_room(String.t(), T.userid()) :: Map.t()
  @spec get_or_make_room(String.t(), T.userid(), T.clan_id()) :: Map.t()
  def get_or_make_room(name, author_id, clan_id \\ nil) do
    case ConCache.get(:rooms, name) do
      nil ->
        # No room, we need to make one!
        create_room(name, author_id, clan_id)
        |> add_room

      room ->
        room
    end
  end

  def add_user_to_room(userid, room_name) do
    ConCache.update(:rooms, room_name, fn room_state ->
      new_state =
        if Enum.member?(room_state.members, userid) do
          # No change takes place, they're already in the room!
          room_state
        else
          PubSub.broadcast(
            Central.PubSub,
            "room:#{room_name}",
            {:add_user_to_room, userid, room_name}
          )

          new_members = [userid | room_state.members]
          Map.put(room_state, :members, new_members)
        end

      {:ok, new_state}
    end)
  end

  def remove_user_from_room(userid, room_name) do
    ConCache.update(:rooms, room_name, fn room_state ->
      new_state =
        if not Enum.member?(room_state.members, userid) do
          # No change takes place, they've already left the room
          room_state
        else
          PubSub.broadcast(
            Central.PubSub,
            "room:#{room_name}",
            {:remove_user_from_room, userid, room_name}
          )

          new_members = Enum.filter(room_state.members, fn m -> m != userid end)
          Map.put(room_state, :members, new_members)
        end

      {:ok, new_state}
    end)
  end

  @spec remove_user_from_any_room(integer() | nil) :: list()
  def remove_user_from_any_room(nil), do: []

  def remove_user_from_any_room(userid) do
    list_rooms()
    |> Enum.filter(fn r -> r != nil end)
    |> Enum.filter(fn r -> Enum.member?(r.members, userid) end)
    |> Enum.map(fn r ->
      remove_user_from_room(userid, r.name)
      r.name
    end)
  end

  @spec clan_room_name(String.t()) :: String.t()
  def clan_room_name(clan_name) do
    safe_name = clan_name
    |> String.replace(" ", "")
    |> String.replace("-", "")

    "clan_#{safe_name}"
  end

  def add_room(room) do
    ConCache.put(:rooms, room.name, room)

    ConCache.update(:lists, :rooms, fn value ->
      new_value =
        ([room.name | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    room
  end

  def list_rooms() do
    ConCache.get(:lists, :rooms)
    |> Enum.map(fn room_name -> ConCache.get(:rooms, room_name) end)
  end

  def send_message(from_id, room_name, msg) do
    if allow?(from_id, room_name) do
      case get_room(room_name) do
        nil ->
          nil

        room ->
          if from_id in room.members do
            PubSub.broadcast(
              Central.PubSub,
              "room:#{room_name}",
              {:new_message, from_id, room_name, msg}
            )
          end
      end
    end
  end

  def send_message_ex(from_id, room_name, msg) do
    if allow?(from_id, room_name) do
      case get_room(room_name) do
        nil ->
          nil

        room ->
          if from_id in room.members do
            PubSub.broadcast(
              Central.PubSub,
              "room:#{room_name}",
              {:new_message_ex, from_id, room_name, msg}
            )
          end
      end
    end
  end

  @spec allow?(Map.t(), String.t()) :: boolean()
  def allow?(userid, _room_name) do
    user = User.get_user_by_id(userid)

    cond do
      User.is_muted?(user) ->
        false

      true ->
        true
    end
  end
end
