defmodule Teiserver.Bridge.Commands.UnlinkCommand do
  @moduledoc """
  Unlink Discord and Tesierver accounts
  """
  alias Teiserver.Account
  alias Teiserver.Communication

  require Logger

  @behaviour Teiserver.Bridge.BridgeCommandBehaviour

  @ephemeral 64

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec name() :: String.t()
  def name, do: "unlink"

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec cmd_definition() :: map()
  def cmd_definition do
    %{
      name: name(),
      description: "Unlink your Discord and Teiserver accounts",
      options: [],
      nsfw: false
    }
  end

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map()) :: map()
  def execute(interaction, _options_map) do
    case Account.get_userid_by_discord_id(interaction.user.id) do
      nil ->
        respond("This Discord account isn't linked")

      id ->
        user = Account.get_user!(id)

        case Account.script_update_user(user, %{discord_id: nil}) do
          {:ok, _user} ->
            respond("Unlinked from #{user.name}.")

          {:error, changeset} ->
            Logger.error("Error while unlinking user from Discord: #{inspect(changeset.errors)}")
            respond("Something went wrong while unlinking your account.")
        end
    end
  end

  defp respond(message), do: Communication.new_interaction_response(message, @ephemeral)
end
