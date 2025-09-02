defmodule Teiserver.Bridge.Commands.FindreportsCommand do
  @moduledoc """
  Calls the bot to link all connected reports discord messages
  """
  alias Teiserver.Bridge.{BridgeServer}
  alias Teiserver.{Communication, Room, Logging, Config}
  alias Teiserver.Moderation
  import Ecto.Query
  alias Teiserver.Repo
  alias Teiserver.Moderation.Action

  @behaviour Teiserver.Bridge.BridgeCommandBehaviour

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
          name: "message_id",
          description: "Message ID of the actions discord message",
          required: true
        }
      ],
      nsfw: false
    }
  end

  @impl true
  @spec execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map()) :: map()
  def execute(_interaction, options_map) do
    message_id_str = options_map["message_id"]

    content =
      if message_id_str == nil do
        "Please provide a message id"
      else
        case Integer.parse(message_id_str) do
          {message_id, ""} ->
            action =
              from(a in Moderation.Action,
                where: a.discord_message_id == ^message_id
              )
              |> Repo.one()

            if action == nil do
              "Please provide a valid message id"
            else
              reports =
                from(r in Moderation.Report,
                  where: r.result_id == ^action.id
                )
                |> Repo.all()

              report_links =
                reports
                |> Enum.filter(&(&1.discord_message_id != nil))
                |> Enum.map(fn report ->
                  channel =
                    case report.type do
                      "actions" ->
                        Config.get_site_config_cache(
                          "teiserver.Discord channel #overwatch-reports"
                        )

                      "chat" ->
                        Config.get_site_config_cache(
                          "teiserver.Discord channel #moderation-reports"
                        )
                    end

                  "- https://discord.com/channels/#{Communication.get_guild_id()}/#{channel}/#{report.discord_message_id}"
                end)

              # Grab notes
              notes =
                if action.notes == nil do
                  []
                else
                  ["**Notes:**", action.notes]
                end

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
            end

          :error ->
            "Please provide a valid message id"
        end
      end

    Communication.new_interaction_response(content, 64)
  end
end
