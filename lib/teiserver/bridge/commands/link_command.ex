defmodule Teiserver.Bridge.Commands.LinkCommand do
  @moduledoc """
  Link Discord and Teiserver accounts
  """
  alias Teiserver.Account
  alias Teiserver.Communication

  require Logger

  @behaviour Teiserver.Bridge.BridgeCommandBehaviour

  @ephemeral 64

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec name() :: String.t()
  def name, do: "link"

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec cmd_definition() :: map()
  def cmd_definition do
    %{
      name: name(),
      description: "Link your Discord and Teiserver accounts",
      options: [
        %{
          # String
          type: 3,
          name: "code",
          description: "The code from your website security page",
          required: true
        }
      ],
      nsfw: false
    }
  end

  @impl Teiserver.Bridge.BridgeCommandBehaviour
  @spec execute(interaction :: Nostrum.Struct.Interaction.t(), options_map :: map()) :: map()
  def execute(interaction, options_map) do
    code_value = String.trim(options_map["code"] || "")

    case Account.get_code(code_value,
           search: [purpose: "discord_link", expired: false],
           preload: [:user]
         ) do
      nil ->
        host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
        security_link = "https://#{host}/teiserver/account/security"

        respond(
          "Provided code is invalid or expired. Generate a new one from your [account's Security page](#{security_link})."
        )

      code ->
        link(code, interaction)
    end
  end

  defp link(code, interaction) do
    case Account.get_userid_by_discord_id(interaction.user.id) do
      nil ->
        do_link(code, interaction)

      id when id == code.user_id ->
        Account.delete_code(code)
        respond("This Discord account is already linked to #{code.user.name}.")

      _other_id ->
        respond(
          "This Discord account is already linked to another user. Use `/unlink` first and then try again."
        )
    end
  end

  defp do_link(code, interaction) do
    case Account.script_update_user(code.user, %{discord_id: interaction.user.id}) do
      {:ok, user} ->
        Account.delete_code(code)
        respond("Linked to #{user.name} successfully.")

      {:error, changeset} ->
        Logger.error("Error while linking user to discord: #{inspect(changeset.errors)}")
        respond("Something went wrong while linking your account.")
    end
  end

  defp respond(message), do: Communication.new_interaction_response(message, @ephemeral)
end
