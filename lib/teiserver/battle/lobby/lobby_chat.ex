defmodule Teiserver.Battle.LobbyChat do
  alias Teiserver.{User, Chat}
  alias Teiserver.Battle.{Lobby}
  alias Phoenix.PubSub
  alias Teiserver.Chat.WordLib

  @spec say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def say(userid, "!start" <> s, lobby_id), do: say(userid, "!cv start" <> s, lobby_id)
  def say(userid, "!joinas spec", lobby_id), do: say(userid, "!!joinas spec", lobby_id)
  def say(userid, "!joinas" <> s, lobby_id), do: say(userid, "!cv joinas" <> s, lobby_id)

  def say(userid, msg, lobby_id) do
    msg = String.replace(msg, "!!joinas spec", "!joinas spec")

    case Teiserver.Coordinator.handle_in(userid, msg, lobby_id) do
      :say -> do_say(userid, msg, lobby_id)
      :handled -> :ok
    end
  end

  @spec do_say(Types.userid(), String.t(), Types.lobby_id()) :: :ok
  def do_say(userid, "$ " <> msg, lobby_id), do: do_say(userid, "$#{msg}", lobby_id)
  def do_say(userid, msg, lobby_id) do
    msg = trim_message(msg)
    user = User.get_user_by_id(userid)
    if user.bot == false and WordLib.flagged_words(msg) > 0 do
      User.unbridge_user(user, msg, WordLib.flagged_words(msg), "lobby_chat")
    end

    disallowed = cond do
      User.is_restricted?(user, ["All chat", "Lobby chat"]) -> true
      String.slice(msg, 0..0) == "!" and User.is_restricted?(user, ["Host commands"]) -> true
      Enum.member?(["!y", "!n"], String.downcase(msg)) and User.is_restricted?(user, ["Voting"]) -> true
      true -> false
    end

    if not disallowed do
      persist_message(user, msg, lobby_id, :say)

      PubSub.broadcast(
        Central.PubSub,
        "legacy_battle_updates:#{lobby_id}",
        {:battle_updated, lobby_id, {userid, msg, lobby_id}, :say}
      )

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_lobby_chat:#{lobby_id}",
        {:lobby_chat, :say, lobby_id, userid, msg}
      )

      # Client.chat_flood_check(userid)
    end
    :ok
  end

  @spec sayex(Types.userid(), String.t(), Types.lobby_id()) :: :ok
  def sayex(userid, msg, lobby_id) do
    msg = trim_message(msg)
    user = User.get_user_by_id(userid)
    if user.bot == false and WordLib.flagged_words(msg) > 0 do
      User.unbridge_user(user, msg, WordLib.flagged_words(msg), "lobby_chat")
    end

    disallowed = cond do
      User.is_restricted?(user, ["All chat", "Lobby chat"]) -> true
      String.slice(msg, 0..0) == "!" and User.is_restricted?(user, ["Host commands"]) -> true
      Enum.member?(["!y", "!n"], String.downcase(msg)) and User.is_restricted?(user, ["Voting"]) -> true
      true -> false
    end

    if not disallowed do
      persist_message(user, msg, lobby_id, :sayex)

      PubSub.broadcast(
        Central.PubSub,
        "legacy_battle_updates:#{lobby_id}",
        {:battle_updated, lobby_id, {userid, msg, lobby_id}, :sayex}
      )

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_lobby_chat:#{lobby_id}",
        {:lobby_chat, :announce, lobby_id, userid, msg}
      )

      # Client.chat_flood_check(userid)
    end
    :ok
  end

  @spec sayprivateex(Types.userid(), Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def sayprivateex(from_id, to_id, msg, lobby_id) do
    msg = trim_message(msg)
    sender = User.get_user_by_id(from_id)

    disallowed = cond do
      User.is_restricted?(sender, ["All chat", "Lobby chat", "Direct chat"]) -> true
      String.slice(msg, 0..0) == "!" and User.is_restricted?(sender, ["Host commands"]) -> true
      Enum.member?(["!y", "!n"], String.downcase(msg)) and sender.is_restricted?(sender, ["Voting"]) -> true
      true -> false
    end

    if not disallowed do
      PubSub.broadcast(
        Central.PubSub,
        "legacy_user_updates:#{to_id}",
        {:battle_updated, lobby_id, {from_id, msg, lobby_id}, :sayex}
      )

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_client_messages:#{to_id}",
        {:client_message, :lobby_direct_announce, to_id, {from_id, msg}}
      )
    end
  end

  @spec persist_message(T.user(), String.t(), T.lobby_id(), atom) :: any
  def persist_message(user, msg, lobby_id, type) do
    lobby = Lobby.get_lobby(lobby_id)

    persist = cond do
      lobby == nil -> false
      user.bot == true and String.slice(msg, 0..1) == "* " -> false
      true -> true
    end

    userid = if user.bot do
      case Regex.run(~r/<(.*?)>/u, msg) do
        [_, username] ->
          User.get_userid(username) || user.id
        _ ->
          user.id
      end
    else
      user.id
    end

    if persist do
      msg = case type do
        :sayex -> "sayex: #{msg}"
        _ -> msg
      end

      Chat.create_lobby_message(%{
        content: msg,
        lobby_guid: lobby.tags["server/match/uuid"],
        inserted_at: Timex.now(),
        user_id: userid,
      })
    end
  end

  defp trim_message(msg) when is_list(msg) do
    Enum.join(msg, "\n") |> trim_message
  end
  defp trim_message(msg) do
    String.trim(msg)
  end
end
