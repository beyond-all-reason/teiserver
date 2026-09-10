defmodule Teiserver.Bridge.Commands.TextCommand do
  @moduledoc """
  Returns commonly used text
  """
  alias Teiserver.Communication
  alias Teiserver.Logging

  require Logger

  @behaviour Teiserver.Bridge.BridgeCommandBehaviour

  # Discord limit of choices per option
  @choice_limit 25

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec name() :: String.t()
  def name, do: "text"

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec cmd_definition() :: map()
  def cmd_definition do
    categories = Communication.list_text_callback_categories()

    options =
      categories
      |> Enum.map(&build_category_subcommand/1)

    %{
      name: name(),
      description: "Returns commonly used text by category",
      options: options,
      nsfw: false
    }
  end

  defp build_category_subcommand(category) do
    choices =
      Communication.list_text_callbacks(
        search: [category: category],
        order_by: "Name (A-Z)",
        limit: @choice_limit
      )
      |> Enum.map(fn cb -> %{name: cb.name, value: cb.id} end)

    %{
      type: 1,
      name: category,
      description: category,
      options: [
        %{
          # type4 = Integer
          type: 4,
          name: "text",
          description: "Which text to retrun",
          required: true,
          choices: choices
        }
      ]
    }
  end

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map) :: map()
  def execute(interaction, _options_map) do
    subcommand = Enum.at(interaction.data.options, 0)
    text_option = Enum.at(subcommand.options, 0)

    Logger.info(
      "Discord executing text command #{inspect(subcommand)} +++ #{inspect(text_option)}"
    )

    case Communication.get_text_callback(text_option.value) do
      nil ->
        Communication.new_interaction_response(
          "That entry no longer exists, please run the command again."
        )

      text_callback ->
        if Communication.can_trigger_callback?(text_callback, interaction.channel_id) do
          Logging.add_anonymous_audit_log("Discord.text_callback", %{
            discord_guild_id: interaction.guild_id,
            discord_user_id: interaction.user.id,
            discord_channel_id: interaction.channel_id,
            command: text_callback.id
          })

          Communication.set_last_triggered_time(text_callback, interaction.channel_id)

          Communication.new_interaction_response(text_callback.response)
        else
          Communication.new_interaction_response(
            "Sorry, I don't want to spam messages. Give it a few minutes before asking again."
          )
        end
    end
  end
end
