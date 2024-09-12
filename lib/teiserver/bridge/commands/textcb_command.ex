defmodule Teiserver.Bridge.Commands.TextcbCommand do
  @moduledoc """
  Calls the bot and tells it to post one of the text-callbacks
  """
  alias Teiserver.{Communication, Logging}

  @behaviour Teiserver.Bridge.BridgeCommandBehaviour

  @impl true
  @spec name() :: String.t()
  def name(), do: "textcb"

  @impl true
  @spec cmd_definition() :: map()
  def cmd_definition() do
    choices =
      Communication.list_text_callbacks()
      |> Enum.map(fn cb ->
        %{
          name: cb.name,
          value: hd(cb.triggers)
        }
      end)

    %{
      name: name(),
      description: "CopyPasta some text",
      options: [
        %{
          # Type3 = String
          type: 3,
          name: "reference",
          description: "The text you wish pasted",
          required: true,
          choices: choices
        }
      ],
      nsfw: false
    }
  end

  @impl true
  @spec execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map) :: map()
  def execute(interaction, options_map) do
    case Communication.lookup_text_callback_from_trigger(options_map["reference"]) do
      nil ->
        nil

      text_callback ->
        if Communication.can_trigger_callback?(text_callback, interaction.channel_id) do
          Logging.add_anonymous_audit_log("Discord.text_callback", %{
            discord_guild_id: interaction.guild_id,
            discord_user_id: interaction.user.id,
            discord_channel_id: interaction.channel_id,
            command: text_callback.id,
            trigger: options_map["reference"]
          })

          Communication.set_last_triggered_time(text_callback, interaction.channel_id)

          %{
            # ChannelMessageWithSource
            type: 4,
            data: %{
              content: text_callback.response
            }
          }
        else
          %{
            # ChannelMessageWithSource
            type: 4,
            data: %{
              content:
                "Sorry, I don't want to spam messages. Give it a few minutes before asking again."
            }
          }
        end
    end
  end
end
