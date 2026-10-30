defmodule Teiserver.Bridge.DiscordBridgeBot do
  @moduledoc """
  This is the module that receives discord events and passes them to the rest of Teiserver.
  """

  alias Nostrum.Api
  alias Nostrum.Api.ApplicationCommand
  alias Teiserver.Bridge.BridgeServer
  alias Teiserver.Bridge.CommandLib
  alias Teiserver.Communication
  alias Teiserver.Moderation

  use Nostrum.Consumer

  require Logger

  def handle_event({:MESSAGE_CREATE, _message, _ws}) do
    :ignore
  end

  def handle_event({:MESSAGE_UPDATE, _message, _ws}) do
    :ignore
  end

  # Events we know we will always want to ignore, kept here so if
  # we do want to test for other events we don't start seeing these
  def handle_event({:TYPING_START, _data, _ws}) do
    :ignore
  end

  def handle_event({:GUILD_AVAILABLE, _guild, _ws}) do
    :ignore
  end

  def handle_event({:GUILD_UNAVAILABLE, _guild, _ws}) do
    :ignore
  end

  def handle_event({:THREAD_CREATE, _thread, _ws}) do
    :ignore
  end

  def handle_event({:MESSAGE_REACTION_ADD, _reaction, _ws}) do
    :ignore
  end

  def handle_event({:CHANNEL_CREATE, _channel, _ws}) do
    :ignore
  end

  def handle_event({:CHANNEL_UPDATE, _channel, _ws}) do
    :ignore
  end

  def handle_event({:INTERACTION_CREATE, %{data: data} = interaction, _ws}) do
    options_map =
      if data.options do
        data.options
        |> Map.new(fn %{name: name, value: value} ->
          {name, value}
        end)
      else
        %{}
      end

    response = CommandLib.handle_command(interaction, options_map)

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
    CommandLib.register_discord_commands()

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

  # Meant to be used manually
  # Teiserver.Bridge.DiscordBridgeBot.delete_guild_application_command(name_here)
  def delete_guild_application_command(name) do
    guild_id = Communication.get_guild_id()

    command = %{
      name: name,
      description: "About to be deleted"
    }

    {:ok, %{id: cmd_id}} = ApplicationCommand.create_guild_command(guild_id, command)
    ApplicationCommand.delete_guild_command(guild_id, cmd_id)
  end

  @spec new_dm_channel(atom | %{:recipients => any, optional(any) => any}) :: :ok
  def new_dm_channel(dm_channel) do
    case dm_channel.recipients do
      [recipient] ->
        Teiserver.cache_put(:discord_bridge_dm_cache, dm_channel.id, recipient["id"])
        Logger.info("Discord DM Channel #{dm_channel.id} set to #{recipient["id"]}")
        nil

      _other ->
        nil
    end

    :ok
  end

  @spec new_infolog(Teiserver.Telemetry.Infolog.t()) :: any
  def new_infolog(infolog) do
    post_to_discord =
      cond do
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

      Communication.new_discord_message("Error updates", message)
    end
  end

  def get_report_message(report) do
    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    url = "https://#{host}/moderation/report?target_id=#{report.target_id}"

    match_icon =
      if is_nil(report.match_id) do
        ""
      else
        ":crossed_swords:"
      end

    [
      "# [Moderation report #{report.type}/#{report.sub_type}](#{url})#{match_icon}",
      "🎯 [#{report.target.name}](https://#{host}/moderation/report/user/#{report.target.id})",
      "📋 [#{report.reporter.name}](https://#{host}/moderation/report/user/#{report.reporter.id})",
      "**Reason:** #{format_link(report.extra_text)}"
    ] ++
      cond do
        not is_nil(report.result_id) ->
          ["**Status:** Actioned :hammer:"]

        report.closed == true ->
          ["**Status:** Closed :file_folder:"]

        true ->
          ["**Status:** Open"]
      end
  end

  def get_channel_for_report_type(type) do
    name =
      case type do
        "actions" ->
          "Overwatch reports"

        "chat" ->
          "Moderation reports"

        _other ->
          Logger.error("Unknown report type #{type}")
          raise "Unknown report type #{type}"
      end

    case Communication.get_discord_channel(name) do
      nil -> nil
      channel -> channel.channel_id
    end
  end

  # Teiserver.Moderation.get_report!(123) |> Teiserver.Bridge.DiscordBridgeBot.new_report()
  @spec new_report(Moderation.Report.t()) :: any
  def new_report(report) do
    channel = get_channel_for_report_type(report.type)

    if channel do
      report = Moderation.get_report!(report.id, preload: [:reporter, :target])

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

      msg = get_report_message(report)

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
          _other -> msg
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
    channel = get_channel_for_report_type(report.type)

    Logger.info("got channel for action #{inspect(report.type)}: #{channel}")

    if channel do
      msg = Communication.get_discord_message(channel, report.discord_message_id)
      Logger.info("Got discord message for report")

      case msg do
        {:ok, msg} ->
          {new_content, reactions} =
            if is_nil(report.result_id) do
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
            else
              new_content =
                if report.closed do
                  String.replace(
                    msg.content,
                    "**Status:** Closed :file_folder:",
                    "**Status:** Actioned :hammer:"
                  )
                else
                  String.replace(
                    msg.content,
                    "**Status:** Open",
                    "**Status:** Actioned :hammer:"
                  )
                end

              {new_content, [delete: "📁", create: "🔨"]}
            end

          Logger.info("reactions to process: #{inspect(reactions)}")

          Enum.each(reactions, fn {action, emoji} ->
            reaction =
              case action do
                :create -> Communication.create_discord_reaction(channel, msg.id, emoji)
                :delete -> Communication.delete_discord_reaction(channel, msg.id, emoji)
              end

            Logger.info("reaction #{inspect(action)} - #{inspect(emoji)} : #{inspect(reaction)}")
          end)

          if msg.content != new_content do
            Logger.info("editing discord message")
            edit_result = Communication.edit_discord_message(channel, msg.id, new_content)
            Logger.info("edit result: #{inspect(edit_result)}")
          end

        {:error, %{status_code: 404}} ->
          Logger.warning("Report message #{report.discord_message_id} was not found")
          :error

        {:error, reason} ->
          Logger.warning(
            "Error getting report message #{report.discord_message_id} #{inspect(reason)}"
          )

          :error
      end
    end
  end

  # Surrounds links with <> to disable link preview in Discord
  defp format_link(nil), do: ""

  defp format_link(link) do
    ~r/(https?:\/\/[^\s]+)/
    |> Regex.replace(link, "<\\1>")
  end
end
