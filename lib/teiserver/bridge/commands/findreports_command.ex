defmodule Teiserver.Bridge.Commands.FindreportsCommand do
  @moduledoc """
  Calls the bot to link all connected reports discord messages
  """
  alias Teiserver.{Communication, Config}
  alias Teiserver.Moderation
  require Logger

  @behaviour Teiserver.Bridge.BridgeCommandBehaviour
  @ephemeral 64

  @impl true
  @spec name() :: String.t()
  def name(), do: "findreports"

  @impl true
  @spec cmd_definition() :: map()
  def cmd_definition() do
    %{
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
  end

  @impl true
  @spec execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map()) :: map()
  def execute(_interaction, options_map) do
    # Default to message_id
    mode = options_map["mode"] || "message_id"
    id_str = options_map["id"]

    content =
      if is_nil(id_str) do
        "Please provide an id corresponding to the selected mode"
      else
        case mode do
          "report_id" -> handle_report_id(id_str)
          "message_id" -> handle_message_id(id_str)
        end
      end

    Communication.new_interaction_response(content, @ephemeral)
  end

  # Helper Functions

  defp get_channel(type) do
    case type do
      "actions" ->
        Config.get_site_config_cache("teiserver.Discord channel #overwatch-reports")

      "chat" ->
        Config.get_site_config_cache("teiserver.Discord channel #moderation-reports")

      _ ->
        Logger.error("Unknown report type #{type}")
        raise "Unknown report type #{type}"
    end
  end

  defp handle_report_id(id_str) do
    with {report_id, ""} <- Integer.parse(id_str),
         report when not is_nil(report) <- Moderation.get_report(report_id) do
      channel = get_channel(report.type)

      content =
        if report.discord_message_id == nil or channel == nil do
          []
        else
          [
            "**Report Link:**",
            "- https://discord.com/channels/#{Communication.get_guild_id()}/#{channel}/#{report.discord_message_id}"
          ]
        end

      if content == [] do
        "No Report Link or Action Link/Notes available"
      else
        Enum.join(content, "\n")
      end
    else
      :error -> "Please provide a valid report id"
      nil -> "Unable to find a report with the provided report ID"
    end
  end

  defp handle_message_id(id_str) do
    with {message_id, ""} <- Integer.parse(id_str),
         action when not is_nil(action) <-
           Moderation.get_action(search: [discord_message_id: message_id]) do
      reports =
        Moderation.list_reports(
          search: [result_id: action.id, has_discord_message_id: true],
          order_by: "Newest first"
        )

      report_links =
        reports
        |> Enum.map(fn report ->
          channel = get_channel(report.type)

          "- https://discord.com/channels/#{Communication.get_guild_id()}/#{channel}/#{report.discord_message_id}"
        end)

      # Grab notes
      notes = if action.notes != nil, do: ["**Notes:**", action.notes], else: []

      # Combine Report links with notes
      content =
        if report_links == [] do
          []
        else
          ["**Attached Reports:**"] ++ report_links
        end ++ notes

      if content == [] do
        "No attached Reports with links, or Notes"
      else
        Enum.join(content, "\n")
      end
    else
      :error -> "Please provide a valid message id"
      nil -> "Unable to find an action with the provided message ID"
    end
  end
end
