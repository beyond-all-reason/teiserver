defmodule Teiserver.Tachyon.MessageHandlers.ClientMessageHandlers do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.Communication.ReceivedDirectMessageResponse
  alias Teiserver.Tachyon.Responses.Lobby.{ReceivedJoinRequestResponseResponse, JoinedResponse}
  alias Teiserver.Tachyon.Responses.User.UpdateStatusResponse

  @spec handle(map(), T.tachyon_conn()) ::
          {:ok, T.tachyon_conn()} | {:ok, map() | list(), T.tachyon_conn()}
  def handle(%{event: :received_direct_message} = msg, conn) do
    case ReceivedDirectMessageResponse.generate(msg) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(%{event: :join_lobby_request_response} = msg, conn) do
    case ReceivedJoinRequestResponseResponse.generate(msg) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(%{event: :client_updated} = msg, conn) do
    case UpdateStatusResponse.generate(msg.client) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(%{event: :added_to_lobby} = msg, conn) do
    case JoinedResponse.generate(msg.lobby_id, msg.script_password) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, %{conn | lobby_id: msg.lobby_id}}
    end
  end

  def handle(msg, conn) do
    raise "No handler for msg of #{msg.event} in ClientMessageHandlers"
    {:ok, [], conn}
  end
end
