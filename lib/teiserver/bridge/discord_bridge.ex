defmodule Teiserver.Bridge.DiscordBridge do
  @moduledoc """
  This is the module that receives discord events and passes them to the rest of Teiserver.
  """

  use Nostrum.Consumer
  alias Teiserver.{Room, Moderation}
  alias Teiserver.Bridge.{BridgeServer, MessageCommands, ChatCommands}
  alias Teiserver.{Config}
  alias Teiserver.Helper.TimexHelper
  alias Nostrum.Api
  require Logger

  @emoticon_map %{
    "🙂" => ":)",
    "😒" => ":s",
    "😦" => ":(",
    "😛" => ":p",
    "😄" => ":D"
  }

  @extra_text_emoticons %{
    ":S" => "😒",
    ":P" => "😛"
  }

  @text_to_emoticon_map @emoticon_map
                        |> Map.new(fn {k, v} -> {v, k} end)
                        |> Map.merge(@extra_text_emoticons)

  @max_message_length 100

  # GuildId of nil = DM
  def handle_event({:MESSAGE_CREATE, %{content: "$" <> _, guild_id: nil} = message, _ws}) do
    MessageCommands.handle(message)
  end

  # So this is a public message
  def handle_event({:MESSAGE_CREATE, %{content: "$" <> _} = message, _ws}) do
    ChatCommands.handle(message)
  end

  def handle_event(
        {:MESSAGE_CREATE,
         %{author: author, channel_id: channel_id, attachments: [], content: content} = message,
         _ws}
      ) do
    room = bridge_channel_to_room(channel_id)
    dm_sender = Central.cache_get(:discord_bridge_dm_cache, to_string(channel_id))

    cond do
      author.username == Application.get_env(:central, DiscordBridge)[:bot_name] ->
        nil

      dm_sender != nil ->
        MessageCommands.handle(message)

      room == "moderation-reports" ->
        nil

      room == "moderation-actions" ->
        nil

      String.contains?(content, "http:") ->
        nil

      String.contains?(content, "https:") ->
        nil

      String.length(content) > @max_message_length ->
        nil

      Config.get_site_config_cache("teiserver.Bridge from discord") == false ->
        nil

      room != nil ->
        do_reply(message)

      true ->
        nil
    end
  end

  # Stuff we might want to use
  def handle_event({:MESSAGE_CREATE, _, _ws}) do
    # Has an attachment
    :ignore
  end

  def handle_event({:MESSAGE_UPDATE, _, _ws}) do
    :ignore
  end

  # Events we know we will always want to ignore, kept here so if
  # we do want to test for other events we don't start seeing these
  def handle_event({:TYPING_START, _, _ws}) do
    :ignore
  end

  def handle_event({:GUILD_AVAILABLE, _, _ws}) do
    :ignore
  end

  def handle_event({:GUILD_UNAVAILABLE, _, _ws}) do
    :ignore
  end

  def handle_event({:READY, _, _ws}) do
    :ignore
  end

  def handle_event({:THREAD_CREATE, _, _ws}) do
    :ignore
  end

  def handle_event({:MESSAGE_REACTION_ADD, _, _ws}) do
    :ignore
  end

  def handle_event({:CHANNEL_UPDATE, _, _ws}) do
    :ignore
  end

  # Default event handler, if you don't include this, your consumer WILL crash if
  # you don't have a method definition for each event type.
  def handle_event({_event, _data, _ws}) do
    # IO.puts "handle_event"
    # IO.inspect event
    # IO.inspect data
    # IO.puts ""

    :noop
  end

  @spec get_text_to_emoticon_map() :: Map.t()
  def get_text_to_emoticon_map, do: @text_to_emoticon_map

  @spec new_dm_channel(atom | %{:recipients => any, optional(any) => any}) :: :ok
  def new_dm_channel(dm_channel) do
    case dm_channel.recipients do
      [recipient] ->
        Central.cache_put(:discord_bridge_dm_cache, dm_channel.id, recipient["id"])
        Logger.info("Discord DM Channel #{dm_channel.id} set to #{recipient["id"]}")
        nil

      _ ->
        nil
    end

    :ok
  end

  @spec new_infolog(Teiserver.Telemetry.Infolog.t()) :: any
  def new_infolog(infolog) do
    channel_id = Config.get_site_config_cache("teiserver.Discord channel #telemetry-infologs")

    post_to_discord =
      cond do
        channel_id == nil -> false
        infolog.metadata["shorterror"] == "Errorlog" -> false
        infolog.metadata["private"] == true -> false
        true -> true
      end

    if post_to_discord do
      host = Application.get_env(:central, TeiserverWeb.Endpoint)[:url][:host]
      url = "https://#{host}/telemetry/infolog/#{infolog.id}"

      message =
        [
          "New infolog uploaded: #{infolog.metadata["errortype"]} `#{infolog.metadata["filename"]}`",
          "`#{infolog.metadata["shorterror"]}`",
          "Link: #{url}"
        ]
        |> Enum.join("\n")

      Api.create_message(channel_id, message)
    end
  end

  # Teiserver.Moderation.get_report!(123) |> Teiserver.Bridge.DiscordBridge.new_report()
  @spec new_report(Moderation.Report.t()) :: any
  def new_report(report) do
    channel =
      cond do
        report.type == "actions" ->
          Config.get_site_config_cache("teiserver.Discord channel #overwatch-reports")

        true ->
          Config.get_site_config_cache("teiserver.Discord channel #moderation-reports")
      end

    if channel do
      report = Moderation.get_report!(report.id, preload: [:reporter, :target])

      host = Application.get_env(:central, TeiserverWeb.Endpoint)[:url][:host]
      url = "https://#{host}/moderation/report?target_id=#{report.target_id}"

      match_icon =
        cond do
          report.match_id == nil -> ""
          true -> ":crossed_swords:"
        end

      outstanding_count =
        Moderation.list_outstanding_reports_against_user(report.target_id)
        |> Enum.count()

      outstanding_msg =
        cond do
          outstanding_count > 5 ->
            " (Outstanding count: #{outstanding_count} :warning:)"

          outstanding_count > 1 ->
            " (Outstanding count: #{outstanding_count})"

          true ->
            ""
        end

      msg =
        "#{report.target.name} was reported by #{report.reporter.name} because #{report.type}/#{report.sub_type} #{match_icon} - #{report.extra_text} - #{url}#{outstanding_msg}"

      Api.create_message(channel, "Moderation report: #{msg}")
    end
  end

  # Teiserver.Moderation.get_action!(123) |> Teiserver.Bridge.DiscordBridge.new_action()
  @spec new_action(Moderation.Action.t()) :: any
  def new_action(%{hidden: true}), do: nil

  def new_action(action) do
    action = Moderation.get_action!(action.id, preload: [:target])

    channel_id = Config.get_site_config_cache("teiserver.Discord channel #moderation-actions")

    post_to_discord =
      cond do
        channel_id == nil -> false
        Enum.member?(action.restrictions, "Bridging") -> false
        Enum.member?(action.restrictions, "Note") -> false
        action.reason == "Banned (Automod)" -> false
        true -> true
      end

    if post_to_discord do
      message = generate_action_text(action)

      posting_result = Api.create_message(channel_id, message)
      case posting_result do
        {:ok, %{id: message_id}} ->
          Moderation.update_action(action, %{discord_message_id: message_id})

      end
      posting_result
    else
      nil
    end
  end

  def update_action(%{discord_message_id: message_id} = action) do
    channel_id = Config.get_site_config_cache("teiserver.Discord channel #moderation-actions")
    contents = generate_action_text(action)

    if channel_id && message_id && contents do
      Api.edit_message(channel_id, message_id, content: contents)
    end
  end

  defp generate_action_text(action) do
    until =
      if action.expires do
        "Until: " <> TimexHelper.date_to_str(action.expires, format: :ymd_hms) <> " (UTC)"
      else
        "Permanent"
      end

    restriction_list = action.restrictions |> Enum.join(", ")

    restriction_string =
      if Enum.count(action.restrictions) > 1 do
        "Restrictions: #{restriction_list}"
      else
        "Restriction: #{restriction_list}"
      end

    formatted_reason =
      Regex.replace(~r/https:\/\/discord.gg\/\S+/, action.reason, "--discord-link--")

    [
      "--------------------------------------------",
      "`#{action.target.name}` has been moderated.",
      "Reason: #{formatted_reason}, #{restriction_string}",
      until
    ]
      |> List.flatten()
      |> Enum.join("\n")
      |> String.replace("\n\n", "\n")
  end

  def gdt_check() do
    channel_id = 0
    name = ""
    content = ""

    Nostrum.Api.start_thread(channel_id, %{
      name: name,
      message: %{
        content: content
      },
      type: 11
    })
  end

  defp do_reply(%Nostrum.Struct.Message{
         author: author,
         content: content,
         channel_id: channel_id,
         mentions: mentions
       }) do
    # Mentions come through encoded in a way we don't want to preserve, this substitutes them
    new_content =
      mentions
      |> Enum.reduce(content, fn m, acc ->
        String.replace(acc, "<@!#{m.id}>", m.username)
      end)
      |> String.replace(~r/<#[0-9]+> ?/, "")
      |> convert_emoticons
      |> String.split("\n")

    bridge_user_id = BridgeServer.get_bridge_userid()
    from_id = bridge_user_id

    # Temporarily disabled as the bridge echos itself
    # from_id = case User.get_userid_by_discord_id(author.id) do
    #   nil ->
    #     bridge_user_id
    #   userid ->
    #     case Client.get_client_by_id(userid) do
    #       nil ->
    #         bridge_user_id
    #       _ ->
    #         userid
    #     end
    # end

    message =
      if from_id == bridge_user_id do
        new_content
        |> Enum.map(fn row ->
          "#{author.username}: #{row}"
        end)
      else
        new_content
      end

    room = bridge_channel_to_room(channel_id)
    Room.send_message(from_id, room, message)
  end

  defp convert_emoticons(msg) do
    msg
    |> String.replace(Map.keys(@emoticon_map), fn emoji -> @emoticon_map[emoji] end)
  end

  defp bridge_channel_to_room(channel_id) do
    lookup_table = Central.store_get(:application_metadata_cache, :discord_room_lookup)
    lookup_table[channel_id]
  end

  # @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  # def start_link do
  #   Consumer.start_link(__MODULE__)
  # end
end
