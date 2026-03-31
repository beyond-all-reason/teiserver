defmodule Teiserver.Bridge.Commands.PostCommand do
  @moduledoc """
  Calls the bot to post report or action in current channel
  """
  alias Teiserver.Communication
  alias Teiserver.Moderation
  alias Teiserver.Bridge.DiscordBridgeBot
  require Logger

  @behaviour Teiserver.Bridge.BridgeCommandBehaviour

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec name() :: String.t()
  def name, do: "post"

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec cmd_definition() :: map()
  def cmd_definition do
    %{
      name: "post",
      description: "Post report or action into the current channel",
      options: [
        %{
          # type3 = String
          type: 3,
          name: "type",
          description: "Report or Action",
          required: true,
          choices: [
            %{name: "Report", value: "report"},
            %{name: "Action", value: "action"}
          ]
        },
        %{
          # type3 = String
          type: 3,
          name: "id",
          description: "ID",
          required: true
        }
      ],
      nsfw: false
    }
  end

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map()) :: map()
  def execute(_interaction, options_map) do
    # Default to message_id
    type = options_map["type"]
    id_str = options_map["id"]

    content =
      if is_nil(id_str) do
        "Please provide an id corresponding to the selected type"
      else
        case type do
          "action" ->
            action = Moderation.get_action!(id_str)
            IO.inspect(Moderation.ActionLib.generate_discord_message_text(action))

            channel_id =
              Teiserver.Config.get_site_config_cache(
                "teiserver.Discord channel #moderation-actions"
              )

            Moderation.ActionLib.generate_discord_message_text(action) <>
              "\n**Original:** https://discord.com/channels/#{Communication.get_guild_id()}/#{channel_id}/#{action.discord_message_id}"

          "report" ->
            report = Moderation.get_report!(id_str, preload: [:reporter, :target])

            DiscordBridgeBot.get_report_message(report)
            |> List.delete_at(-1)
            |> List.insert_at(
              -1,
              "**Original:** https://discord.com/channels/#{Communication.get_guild_id()}/#{DiscordBridgeBot.get_channel(report.type)}/#{report.discord_message_id}"
            )
            |> Enum.join("\n")
        end
      end

    Communication.new_interaction_response(content)
  end
end
