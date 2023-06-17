defmodule Teiserver.Tachyon.MessageHandlers.ClientMessageHandlers do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.Communication.ReceivedDirectMessageResponse
  alias Teiserver.Tachyon.Responses.Lobby.ReceivedJoinRequestResponseResponse

  @spec handle(map(), T.tachyon_ws_state()) ::
          {:ok, T.tachyon_ws_state()} | {:ok, map() | list(), T.tachyon_ws_state()}
  def handle(%{event: :received_direct_message} = msg, state) do
    case ReceivedDirectMessageResponse.generate(msg) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, state}
    end
  end

  def handle(%{event: :join_lobby_request_response} = msg, state) do
    case ReceivedJoinRequestResponseResponse.generate(msg) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, state}
    end
  end

  def handle(msg, state) do
    raise "No handler for msg of #{msg.event} in ClientMessageHandlers"
    {:ok, [], state}
  end
end
