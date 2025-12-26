defmodule Teiserver.Bridge.DiscordBridgeBot do
  @moduledoc """
  This is the module that receives discord events and passes them to the rest of Teiserver.
  """

  use Nostrum.Consumer
  alias Teiserver.{Room, Moderation, Communication}
  alias Teiserver.Bridge.{BridgeServer, MessageCommands, ChatCommands, CommandLib}
  alias Teiserver.{Config}
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
    dm_sender = Teiserver.cache_get(:discord_bridge_dm_cache, to_string(channel_id))

    discord_bot_user_id = Teiserver.cache_get(:application_metadata_cache, "discord_bot_user_id")

    cond do
      author.id == discord_bot_user_id ->
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

  def handle_event({:THREAD_CREATE, _, _ws}) do
    :ignore
  end

  def handle_event({:MESSAGE_REACTION_ADD, _, _ws}) do
    :ignore
  end

  def handle_event({:CHANNEL_UPDATE, _, _ws}) do
    :ignore
  end

  def handle_event({:INTERACTION_CREATE, %{data: data} = interaction, _ws}) do
    options_map =
      data.options
      |> Map.new(fn %{name: name, value: value} ->
        {name, value}
      end)

    response = CommandLib.handle_command(interaction, options_map)

    # response = case data.name do
    #   "textcb" ->
    #     Teiserver.Bridge.TextcbCommand.execute(interaction, options_map)

    #   _ ->
    #     nil
    # end

    if response do
      Api.create_interaction_response(interaction, response)
    else
      :ignore
    end
  end

  def handle_event({:READY, ready_data, _ws}) do
    discord_bot_user_id = ready_data.user.id
    Teiserver.cache_put(:application_metadata_cache, "discord_bot_user_id", discord_bot_user_id)

    BridgeServer.cast_bridge(:READY)
    add_command(:textcb)
    add_command(:findreport)
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

  # Teiserver.Bridge.DiscordBridgeBot.add_command(:findreport)
  @spec add_command(atom) :: any
  def add_command(:findreport) do
    command = %{
      name: "findreports",
      description: "Find reports by the action message id",
      options: [
        %{
          # type3 = String
          type: 3,
          name: "id",
          description: "Message ID of the actions discord message",
          required: true
        },
        %{
          # type3 = String
          type: 3,
          name: "mode",
          description: "Mode to search with by id",
          required: false,
          choices: [
            %{name: "Message ID", value: "message_id"},
            %{name: "Report ID", value: "report_id"}
          ],
          default_value: "message_id"
        }
      ],
      nsfw: false
    }

    Api.ApplicationCommand.create_guild_command(Communication.get_guild_id(), command)
  end

  # Teiserver.Bridge.DiscordBridgeBot.add_command(:textcb)
  @spec add_command(atom) :: any
  def add_command(:textcb) do
    callbacks = Communication.list_text_callbacks()

    choices =
      callbacks
      |> Enum.map(fn cb ->
        %{
          name: cb.name,
          value: hd(cb.triggers)
        }
      end)
      # 25 is the Discord limit of choices per / command
      |> Enum.take(25)

    command = %{
      name: "textcb",
      description: "CopyPasta some text",
      options: [
        %{
          # Type3 = String
          type: 3,
          name: "reference",
          description: "The name of the reference",
          required: true,
          choices: choices
        }
      ],
      nsfw: false
    }

    Api.ApplicationCommand.create_guild_command(Communication.get_guild_id(), command)
  end

  # Meant to be used manually
  # Teiserver.Bridge.DiscordBridgeBot.delete_guild_application_command(name_here)
  def delete_guild_application_command(name) do
    guild_id = Communication.get_guild_id()

    command = %{
      name: name,
      description: "About to be deleted"
    }

    {:ok, %{id: cmd_id}} = Api.ApplicationCommand.create_guild_command(guild_id, command)
    Api.ApplicationCommand.delete_guild_command(guild_id, cmd_id)
  end

  @spec get_text_to_emoticon_map() :: map()
  def get_text_to_emoticon_map, do: @text_to_emoticon_map

  @spec new_dm_channel(atom | %{:recipients => any, optional(any) => any}) :: :ok
  def new_dm_channel(dm_channel) do
    case dm_channel.recipients do
      [recipient] ->
        Teiserver.cache_put(:discord_bridge_dm_cache, dm_channel.id, recipient["id"])
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
      host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
      url = "https://#{host}/telemetry/infolog/#{infolog.id}"

      message =
        [
          "New infolog uploaded: **#{infolog.metadata["errortype"]}** `#{infolog.metadata["filename"]}`",
          "`#{infolog.metadata["shorterror"]}`",
          "Link: #{url}"
        ]
        |> Enum.join("\n")

      Api.Message.create(channel_id, message)
    end
  end

  # Teiserver.Moderation.get_report!(123) |> Teiserver.Bridge.DiscordBridgeBot.new_report()
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

      host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
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
            "**Outstanding count:** #{outstanding_count} :warning:"

          outstanding_count > 1 ->
            "**Outstanding count:** #{outstanding_count}"

          true ->
            ""
        end

      msg =
        [
          "# [Moderation report #{report.type}/#{report.sub_type}](#{url})#{match_icon}",
          "**Target:** [#{report.target.name}](https://#{host}/moderation/report/user/#{report.target.id})",
          "**Reporter:** [#{report.reporter.name}](https://#{host}/moderation/report/user/#{report.reporter.id})",
          "**Reason:** #{format_link(report.extra_text)}",
          "**Status:** Open"
        ]

      reports =
        if is_nil(report.match_id) do
          []
        else
          Moderation.list_reports(
            search: [match_id: report.match_id, type: report.type],
            order_by: "Oldest first"
          )
        end

      msg =
        with true <- length(reports) > 1,
             first_report <- hd(reports),
             false <- is_nil(first_report.discord_message_id) do
          first_report_link =
            "https://discord.com/channels/#{Communication.get_guild_id()}/#{channel}/#{first_report.discord_message_id}"

          msg ++ ["**First report:** #{first_report_link}"]
        else
          _ -> msg
        end

      msg =
        (msg ++ ["#{outstanding_msg}"])
        |> Enum.join("\n")

      {status, message_data} = Communication.new_discord_message(channel, msg)

      if status == :ok do
        message_id = message_data.id
        Moderation.update_report(report, %{discord_message_id: message_id})

        if length(reports) > 1,
          do: Communication.create_discord_reaction(channel, message_id, "🔼")
      end
    end
  end

  @spec update_report(Moderation.Report.t()) :: any
  def update_report(%{discord_message_id: nil}), do: :ok

  def update_report(report) do
    channel =
      cond do
        report.type == "actions" ->
          Config.get_site_config_cache("teiserver.Discord channel #overwatch-reports")

        true ->
          Config.get_site_config_cache("teiserver.Discord channel #moderation-reports")
      end

    if channel do
      case Communication.get_discord_message(channel, report.discord_message_id) do
        {:ok, msg} ->
          {new_content, reactions} =
            if not is_nil(report.result_id) do
              new_content =
                cond do
                  report.closed ->
                    String.replace(
                      msg.content,
                      "**Status:** Closed :file_folder:",
                      "**Status:** Actioned :hammer:"
                    )

                  true ->
                    String.replace(
                      msg.content,
                      "**Status:** Open",
                      "**Status:** Actioned :hammer:"
                    )
                end

              {new_content, [delete: "📁", create: "🔨"]}
            else
              if report.closed do
                {
                  String.replace(
                    msg.content,
                    "**Status:** Open",
                    "**Status:** Closed :file_folder:"
                  ),
                  [create: "📁"]
                }
              else
                {
                  String.replace(
                    msg.content,
                    "**Status:** Closed :file_folder:",
                    "**Status:** Open"
                  ),
                  [delete: "📁"]
                }
              end
            end

          Enum.each(reactions, fn {action, emoji} ->
            case action do
              :create -> Communication.create_discord_reaction(channel, msg.id, emoji)
              :delete -> Communication.delete_discord_reaction(channel, msg.id, emoji)
            end
          end)

          if msg.content != new_content,
            do: Communication.edit_discord_message(channel, msg.id, new_content)

        {:error, reason} ->
          Logger.warning("Report message #{report.discord_message_id} was not found: #{reason}")
          :error
      end
    end
  end

  def gdt_check() do
    channel_id = 0
    name = ""
    content = ""

    Nostrum.Api.Thread.create(channel_id, %{
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
      |> convert_emoticons()
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
    lookup_table = Teiserver.store_get(:application_metadata_cache, :discord_room_lookup)
    lookup_table[channel_id]
  end

  # @spec start_link :: :ignore | {:error, any} | {:ok, pid}
  # def start_link do
  #   Consumer.start_link(__MODULE__)
  # end

  # Surrounds links with <> to disable link preview in Discord
  defp format_link(link) do
    ~r/(https?:\/\/[^\s]+)/
    |> Regex.replace(link, "<\\1>")
  end
end
