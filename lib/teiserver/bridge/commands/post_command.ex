defmodule Teiserver.Bridge.Commands.PostCommand do
  @moduledoc """
  Calls the bot to post report or action in current channel
  """
  alias Teiserver.Account
  alias Teiserver.Bridge.DiscordBridgeBot
  alias Teiserver.Communication
  alias Teiserver.Config
  alias Teiserver.Moderation
  alias Teiserver.Moderation.ActionLib
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
      description: "Post something into the current channel",
      options: [
        %{
          # type  = sub_command
          type: 1,
          name: "report",
          description: "Post a report",
          required: true,
          options: [
            %{
              name: "id",
              description: "ID of the report",
              type: 4,
              required: true
            }
          ]
        },
        %{
          type: 1,
          name: "action",
          description: "Post an Action",
          required: true,
          options: [
            %{
              name: "id",
              description: "ID of the action",
              type: 4,
              required: true
            }
          ]
        },
        %{
          type: 1,
          name: "profile",
          description: "Post the link of a moderation profile",
          required: true,
          options: [
            %{
              name: "name",
              description: "Name of the Account",
              type: 3,
              required: true
            }
          ]
        }
      ],
      nsfw: false
    }
  end

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map()) :: map()
  def execute(interaction, _options_map) do
    subcommand = Enum.at(interaction.data.options, 0)
    args = Enum.at(subcommand.options, 0)

    content =
      case subcommand.name do
        "action" ->
          case Moderation.get_action(args.value) do
            nil ->
              "No action with ID \"#{args.value}\" found"

            action ->
              channel_id =
                Config.get_site_config_cache("teiserver.Discord channel #moderation-actions")

              ActionLib.generate_discord_message_text(action) <>
                "\n**Original:** https://discord.com/channels/#{Communication.get_guild_id()}/#{channel_id}/#{action.discord_message_id}"
          end

        "report" ->
          case Moderation.get_report(args.value, preload: [:reporter, :target]) do
            nil ->
              "No report with ID \"#{args.value}\" found"

            report ->
              DiscordBridgeBot.get_report_message(report)
              |> List.delete_at(-1)
              |> List.insert_at(
                -1,
                "**Original:** https://discord.com/channels/#{Communication.get_guild_id()}/#{DiscordBridgeBot.get_channel_for_report_type(report.type)}/#{report.discord_message_id}"
              )
              |> Enum.join("\n")
          end

        "profile" ->
          name = args.value

          case Account.get_user_by_name(name) do
            nil ->
              "User \"#{name}\" not found"

            user ->
              "https://#{Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]}/moderation/report/user/#{user.id}"
          end
      end

    Communication.new_interaction_response(content)
  end
end
