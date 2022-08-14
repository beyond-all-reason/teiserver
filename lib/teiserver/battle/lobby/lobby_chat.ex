defmodule Teiserver.Battle.LobbyChat do
  @moduledoc false
  alias Teiserver.{User, Chat, Battle, Coordinator}
  alias Teiserver.Battle.{Lobby}
  alias Phoenix.PubSub
  alias Teiserver.Chat.WordLib

  @spec say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def say(userid, "!start" <> s, lobby_id), do: say(userid, "!cv start" <> s, lobby_id)
  def say(userid, "!joinas spec", lobby_id), do: say(userid, "!!joinas spec", lobby_id)
  def say(userid, "!joinas" <> s, lobby_id), do: say(userid, "!cv joinas" <> s, lobby_id)
  def say(userid, "!joinq", lobby_id), do: say(userid, "$joinq", lobby_id)
  def say(_userid, "!specafk" <> _, _lobby_id), do: :ok

  def say(userid, msg, lobby_id) do
    msg = String.replace(msg, "!!joinas spec", "!joinas spec")

    case Teiserver.Coordinator.Parser.handle_in(userid, msg, lobby_id) do
      :say -> do_say(userid, msg, lobby_id)
      :handled -> :ok
    end
  end

  @spec do_say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def do_say(userid, "$ " <> msg, lobby_id), do: do_say(userid, "$#{msg}", lobby_id)
  def do_say(userid, msg, lobby_id) do
    msg = trim_message(msg)
    user = User.get_user_by_id(userid)
    if User.is_bot?(user) == false and WordLib.flagged_words(msg) > 0 do
      User.unbridge_user(user, msg, WordLib.flagged_words(msg), "lobby_chat")
    end

    allowed = cond do
      User.is_restricted?(user, ["All chat", "Lobby chat"]) -> false
      String.slice(msg, 0..0) == "!" and User.is_restricted?(user, ["Host commands"]) -> false
      Enum.member?([
        "!y", "!vote y", "!yes", "!vote yes",
        "!n", "!vote n", "!no", "!vote no",
        ], String.downcase(msg)) and User.is_restricted?(user, ["Voting"]) -> false
      true -> true
    end

    if allowed do
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

      :ok
    else
      {:error, "Permission denied"}
    end
  end

  @spec sayex(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def sayex(userid, msg, lobby_id) do
    msg = trim_message(msg)
    user = User.get_user_by_id(userid)
    if User.is_bot?(user) == false and WordLib.flagged_words(msg) > 0 do
      User.unbridge_user(user, msg, WordLib.flagged_words(msg), "lobby_chat")
    end

    allowed = cond do
      User.is_restricted?(user, ["All chat", "Lobby chat", "Direct chat"]) -> false
      String.starts_with?(msg, "!") and User.is_restricted?(user, ["Host commands"]) -> false
      Enum.member?([
        "!y", "!vote y", "!yes", "!vote yes",
        "!n", "!vote n", "!no", "!vote no",
        ], String.downcase(msg)) and User.is_restricted?(user, ["Voting"]) -> false
      true -> true
    end

    if allowed do
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
      :ok
    else
      {:error, "Permission denied"}
    end
  end

  @spec sayprivateex(Types.userid(), Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def sayprivateex(from_id, to_id, msg, lobby_id) do
    msg = trim_message(msg)
    sender = User.get_user_by_id(from_id)

    allowed = cond do
      User.is_restricted?(sender, ["All chat", "Lobby chat", "Direct chat"]) -> false
      String.starts_with?(msg, "!") and User.is_restricted?(sender, ["Host commands"]) -> false
      Enum.member?([
        "!y", "!vote y", "!yes", "!vote yes",
        "!n", "!vote n", "!no", "!vote no",
        ], String.downcase(msg)) and User.is_restricted?(sender, ["Voting"]) -> false
      true -> true
    end

    if allowed do
      PubSub.broadcast(
        Central.PubSub,
        "legacy_user_updates:#{to_id}",
        {:battle_updated, lobby_id, {from_id, msg, lobby_id}, :sayex}
      )

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_client_messages:#{to_id}",
        %{
          channel: "teiserver_client_messages:#{to_id}",
          event: :lobby_direct_announce,
          sender_id: from_id,
          message_content: msg
        }
      )
      :ok
    else
      {:error, "Permission denied"}
    end
  end

  @spec persist_message(T.user(), String.t(), T.lobby_id(), atom) :: any
  def persist_message(user, msg, lobby_id, type) do
    lobby = Lobby.get_lobby(lobby_id)

    persist = cond do
      lobby == nil -> false
      User.is_bot?(user) == true and String.slice(msg, 0..1) == "* " -> false
      true -> true
    end

    {userid, content} = if User.is_bot?(user) do
      case Regex.run(~r/^<(.*?)> (.+)$/u, msg) do
        [_, username, remainder] ->
          userid = User.get_userid(username) || user.id
          {userid, "g: #{remainder}"}
        _ ->
          {user.id, msg}
      end
    else
      {user.id, msg}
    end

    if persist do
      content = case type do
        :sayex -> "sayex: #{content}"
        _ -> content
      end

      Chat.create_lobby_message(%{
        content: content,
        lobby_guid: Battle.get_lobby_match_uuid(lobby_id),
        inserted_at: Timex.now(),
        user_id: userid,
      })
    end
  end

  def persist_system_message(content, lobby_id) do
    Chat.create_lobby_message(%{
      content: "system: #{content}",
      lobby_guid: Battle.get_lobby_match_uuid(lobby_id),
      inserted_at: Timex.now(),
      user_id: Coordinator.get_coordinator_userid(),
    })
  end

  defp trim_message(msg) when is_list(msg) do
    Enum.join(msg, "\n") |> trim_message
  end
  defp trim_message(msg) do
    String.trim(msg)
  end
end
