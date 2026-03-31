defmodule Teiserver.Bridge.Commands.PostCommand do
  @moduledoc """
  Calls the bot to post report or action in current channel
  """
  alias Teiserver.Bridge.DiscordBridgeBot
  alias Teiserver.{Account, Communication, Moderation}
  Teiserver.Moderation.ActionLib
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
            %{name: "Action", value: "action"},
            %{name: "Profile", value: "profile"}
          ]
        },
        %{
          # type3 = String
          type: 3,
          name: "args",
          description: "Additional arguments",
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
    args = options_map["args"]

    content =
      if is_nil(args) do
        "Please provide an id corresponding to the selected type"
      else
        case type do
          "action" ->
            action = Moderation.get_action!(args)

            channel_id =
              Teiserver.Config.get_site_config_cache(
                "teiserver.Discord channel #moderation-actions"
              )

            ActionLib.generate_discord_message_text(action) <>
              "\n**Original:** https://discord.com/channels/#{Communication.get_guild_id()}/#{channel_id}/#{action.discord_message_id}"

          "report" ->
            report = Moderation.get_report!(args, preload: [:reporter, :target])

            DiscordBridgeBot.get_report_message(report)
            |> List.delete_at(-1)
            |> List.insert_at(
              -1,
              "**Original:** https://discord.com/channels/#{Communication.get_guild_id()}/#{DiscordBridgeBot.get_channel(report.type)}/#{report.discord_message_id}"
            )
            |> Enum.join("\n")

          "profile" ->
            case Account.get_user_by_name(args) do
              nil ->
                "User \"#{args}\" not found"

              user ->
                "https://#{Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]}/moderation/report/user/#{user.id}"
            end
        end
      end

    Communication.new_interaction_response(content)
  end
end
