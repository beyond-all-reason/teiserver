defmodule Teiserver.Tachyon.MessageHandlers.ClientMessageHandlers do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub
  alias Teiserver.Tachyon.Responses.Communication.ReceivedDirectMessageResponse
  alias Teiserver.Tachyon.Responses.Lobby.{ReceivedJoinRequestResponseResponse, JoinedResponse}
  alias Teiserver.Tachyon.Responses.User.UpdatedUserClientResponse

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
    case UpdatedUserClientResponse.generate(msg.client) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(%{event: :added_to_lobby, lobby_id: lobby_id} = msg, conn)
      when is_integer(lobby_id) do
    case JoinedResponse.generate(lobby_id, msg.script_password) do
      {command, :success, data} ->
        PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
        PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

        PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
        PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{lobby_id}")

        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, %{conn | lobby_id: lobby_id}}
    end
  end

  def handle(%{event: :connected} = _msg, conn) do
    {:ok, [], conn}
  end

  def handle(%{event: :disconnected} = _msg, conn) do
    {:ok, [], conn}
  end

  def handle(msg, conn) do
    raise "No handler for msg of '#{inspect msg.event}' in ClientMessageHandlers"
    {:ok, [], conn}
  end
end
