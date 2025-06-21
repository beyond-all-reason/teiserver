defmodule Teiserver.Lobby.ChatLib do
  @moduledoc false
  alias Teiserver.{Account, CacheUser, Chat, Battle, Coordinator, Moderation, Lobby}
  alias Phoenix.PubSub
  alias Teiserver.Chat.WordLib

  @spec say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def say(nil, _, _), do: {:error, "No userid"}
  def say(_, _, nil), do: {:error, "No lobby"}

  def say(_userid, "!specafk" <> _, _lobby_id), do: :ok

  def say(userid, msg, lobby_id) do
    # Replace SPADS command (starting with !) with lowercase version to prevent bypassing with capitalised command names
    # Ignore !# bot commands like !#JSONRPC
    # Allow voting for joinas if there are AIs in the lobby, otherwise alias to spec
    msg =
      if String.starts_with?(msg, "!") and !String.starts_with?(msg, "!#") do
        msg
        |> String.trim()
        |> String.downcase()
        |> String.split()
        |> case do
          ["!cv", "joinas" | _] ->
            has_ai = Battle.get_bots(lobby_id) |> Enum.any?()
            if not has_ai, do: "!cv joinas spec", else: msg

          ["!callvote", "joinas" | _] ->
            has_ai = Battle.get_bots(lobby_id) |> Enum.any?()
            if not has_ai, do: "!callvote joinas spec", else: msg

          ["!joinas" | _] ->
            "!joinas spec"

          ["!clan"] ->
            clan_command(userid)
            "!clan"

          ["!joinq"] ->
            "$joinq"

          _ ->
            msg
        end
      else
        msg
      end

    case Teiserver.Coordinator.Parser.handle_in(userid, msg, lobby_id) do
      :say -> do_say(userid, msg, lobby_id)
      :handled -> :ok
    end
  end

  @spec do_say(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def do_say(userid, "$ " <> msg, lobby_id), do: do_say(userid, "$#{msg}", lobby_id)

  def do_say(userid, msg, lobby_id) do
    msg = trim_message(msg)
    user = Account.get_user_by_id(userid)

    if CacheUser.is_bot?(user) == false and WordLib.flagged_words(msg) > 0 do
      Moderation.unbridge_user(user, msg, WordLib.flagged_words(msg), "lobby_chat")
    end

    blacklisted = CacheUser.is_bot?(user) == false and WordLib.blacklisted_phrase?(msg)

    if blacklisted do
      CacheUser.shadowban_user(user.id)
    end

    allowed =
      cond do
        CacheUser.is_restricted?(user, ["All chat", "Lobby chat"]) ->
          msg_allowed_when_muted?(msg)

        String.starts_with?(msg, "!") and CacheUser.is_restricted?(user, ["Host commands"]) ->
          false

        blacklisted ->
          false

        Enum.member?(
          [
            "!y",
            "!vote y",
            "!yes",
            "!vote yes",
            "!n",
            "!vote n",
            "!no",
            "!vote no"
          ],
          String.downcase(msg)
        ) and CacheUser.is_restricted?(user, ["Voting"]) ->
          false

        true ->
          true
      end

    if allowed do
      persist_message(user, msg, lobby_id, :say)

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_lobby_chat:#{lobby_id}",
        %{
          channel: "teiserver_lobby_chat:#{lobby_id}",
          event: :say,
          lobby_id: lobby_id,
          userid: userid,
          message: msg
        }
      )

      :ok
    else
      {:error, "Permission denied"}
    end
  end

  @spec sayex(Types.userid(), String.t(), Types.lobby_id()) :: :ok | {:error, any}
  def sayex(userid, msg, lobby_id) do
    msg = trim_message(msg)
    user = CacheUser.get_user_by_id(userid)

    if CacheUser.is_bot?(user) == false and WordLib.flagged_words(msg) > 0 do
      Moderation.unbridge_user(user, msg, WordLib.flagged_words(msg), "lobby_chat")
    end

    blacklisted = CacheUser.is_bot?(user) == false and WordLib.blacklisted_phrase?(msg)

    if blacklisted do
      CacheUser.shadowban_user(user.id)
    end

    allowed =
      cond do
        CacheUser.is_restricted?(user, ["All chat", "Lobby chat", "Direct chat"]) ->
          msg_allowed_when_muted?(msg)

        String.starts_with?(msg, "!") and CacheUser.is_restricted?(user, ["Host commands"]) ->
          false

        blacklisted ->
          false

        Enum.member?(
          [
            "!y",
            "!vote y",
            "!yes",
            "!vote yes",
            "!n",
            "!vote n",
            "!no",
            "!vote no"
          ],
          String.downcase(msg)
        ) and CacheUser.is_restricted?(user, ["Voting"]) ->
          false

        true ->
          true
      end

    if allowed do
      persist_message(user, msg, lobby_id, :sayex)

      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_lobby_chat:#{lobby_id}",
        %{
          channel: "teiserver_lobby_chat:#{lobby_id}",
          event: :announce,
          lobby_id: lobby_id,
          userid: userid,
          message: msg
        }
      )

      :ok
    else
      {:error, "Permission denied"}
    end
  end

  @spec sayprivateex(Types.userid(), Types.userid(), String.t(), Types.lobby_id()) ::
          :ok | {:error, any}
  def sayprivateex(from_id, to_id, msg, lobby_id) do
    msg = trim_message(msg)
    sender = CacheUser.get_user_by_id(from_id)

    blacklisted = CacheUser.is_bot?(from_id) == false and WordLib.blacklisted_phrase?(msg)

    if blacklisted do
      CacheUser.shadowban_user(from_id)
    end

    allowed =
      cond do
        CacheUser.is_restricted?(sender, ["All chat", "Lobby chat", "Direct chat"]) ->
          false

        String.starts_with?(msg, "!") and CacheUser.is_restricted?(sender, ["Host commands"]) ->
          false

        blacklisted ->
          false

        Enum.member?(
          [
            "!y",
            "!vote y",
            "!yes",
            "!vote yes",
            "!n",
            "!vote n",
            "!no",
            "!vote no"
          ],
          String.downcase(msg)
        ) and CacheUser.is_restricted?(sender, ["Voting"]) ->
          false

        true ->
          true
      end

    if allowed do
      PubSub.broadcast(
        Teiserver.PubSub,
        "teiserver_client_messages:#{to_id}",
        %{
          channel: "teiserver_client_messages:#{to_id}",
          event: :lobby_direct_announce,
          lobby_id: lobby_id,
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

    persist =
      cond do
        lobby == nil -> false
        CacheUser.is_bot?(user) == true and String.slice(msg, 0..1) == "* " -> false
        true -> true
      end

    {userid, content} =
      if CacheUser.is_bot?(user) do
        case Regex.run(~r/^<(.*?)> (.+)$/u, msg) do
          [_, username, remainder] ->
            userid = CacheUser.get_userid(username) || user.id
            {userid, "g: #{remainder}"}

          _ ->
            {user.id, msg}
        end
      else
        {user.id, msg}
      end

    if persist do
      content =
        case type do
          :sayex -> "sayex: #{content}"
          _ -> content
        end

      Chat.create_lobby_message(%{
        content: content,
        match_id: Battle.get_lobby_match_id(lobby_id),
        inserted_at: Timex.now(),
        user_id: userid
      })
    end
  end

  def persist_system_message(content, lobby_id) do
    Chat.create_lobby_message(%{
      content: "system: #{content}",
      match_id: Battle.get_lobby_match_id(lobby_id),
      inserted_at: Timex.now(),
      user_id: Coordinator.get_coordinator_userid()
    })
  end

  defp trim_message(msg) when is_list(msg) do
    Enum.join(msg, "\n") |> trim_message
  end

  defp trim_message(msg) do
    String.trim(msg)
  end

  @valid_mute_chat_regex [
    ~r/^!vote( (y|yes|n|no|b|blank))?$/i,
    ~r/^!(y|n|b|ev|endvote|help)$/i,
    ~r/^!(cv |callvote )?balance$/i,
    ~r/^!(cv |callvote )?start$/i,
    ~r/^!(cv |callvote )?stop$/i,
    ~r/^!(cv |callvote )?resign$/i,
    ~r/^!(cv |callvote )?forcestart$/i
  ]
  def msg_allowed_when_muted?(msg) do
    msg = String.replace(msg, ~r/ +/, " ") |> String.trim()

    Enum.any?(@valid_mute_chat_regex, fn regex ->
      String.match?(msg, regex)
    end)
  end

  defp clan_command(user_id) do
    client = Account.get_client_by_id(user_id)

    {:ok, code} =
      Account.create_code(%{
        value: ExULID.ULID.generate(),
        purpose: "one_time_login",
        expires: Timex.now() |> Timex.shift(minutes: 5),
        user_id: user_id,
        metadata: %{
          ip: client.ip,
          redirect: "/teiserver/account/parties"
        }
      })

    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    url = "https://#{host}/one_time_login/#{code.value}"

    Coordinator.send_to_user(user_id, [
      "To access parties please use this link - #{url}",
      "You can use the $explain command to see how balance is being calculated and why you are/are not being teamed with your party",
      "We are working on handling it within the new client and protocol, the website is only a temporary measure."
    ])
  end
end
