defmodule Teiserver.Clan.TachyonHandler do
  @moduledoc """
  Handle a connection with clans using the tachyon protocol.
  """
  alias Teiserver.Tachyon.{Handler, Schema}

  require Logger
  @behaviour Handler

  @type state :: %{
          user: T.user(),
          sess_monitor: reference(),
          pending_responses: Handler.pending_responses()
        }

  @doc """
  Not used
  """
  @impl Handler
  def connect(_) do
    {:ok, %{}}
  end

  @doc """
  Not used
  """
  @impl Handler
  @spec init(map()) :: Handler.result()
  def init(initial_state) do
    {:ok, initial_state}
  end

  @impl Handler
  def handle_info({:DOWN, _, :process, _, reason}, state) do
    Logger.info("Clan TachyonHandler session process down: #{inspect(reason)}")
    {:stop, :normal, state}
  end

  # Konvertierungsfunktion
  defp convert_clan_to_tachyon_schema(clan) do
    %{
      clanId: clan.id,
      tag: clan.tag,
      name: clan.name,
      description: clan.description,
      clanMembers: []
    }
  end

  @impl Handler
  @spec handle_command(
          Schema.command_id(),
          Schema.message_type(),
          Schema.message_id(),
          term(),
          state()
        ) ::
          {:response, %{clans: [map()]}, state()}
          | {:error_response, :command_unimplemented, String.t(), state()}

  def handle_command("clan/viewList", "request", _message_id, _message, state) do
    clans = Teiserver.Clan.list_clans()

    # Konvertiere die Clans in das Tachyon-Protokoll-Schema
    converted_clans = Enum.map(clans, &convert_clan_to_tachyon_schema/1)

    {:response, %{clans: converted_clans}, state}
  end

  def handle_command(_command_id, _message_type, _message_id, _message, state) do
    {:error_response, :command_unimplemented, "Message from clan handler.", state}
  end
end
