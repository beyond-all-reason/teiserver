defmodule Teiserver.Tachyon.MessageHandlers.LobbyUpdateMessageHandlers do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.Lobby.{AddUserClientResponse, RemoveUserClientResponse, ClosedResponse}
  alias Teiserver.Tachyon.Responses.User.UpdatedUserClientResponse

  @spec handle(map(), T.tachyon_conn()) ::
          {:ok, T.tachyon_conn()} | {:ok, map() | list(), T.tachyon_conn()}
  def handle(%{event: :add_user} = msg, conn) do
    case AddUserClientResponse.generate(msg.client, msg.lobby_id) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(%{event: :remove_user} = msg, conn) do
    case RemoveUserClientResponse.generate(msg.client.userid, msg.lobby_id) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(%{event: :updated_client_battlestatus} = msg, conn) do
    case UpdatedUserClientResponse.generate(msg.userid, msg.client) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(%{event: :closed} = msg, conn) do
    case ClosedResponse.generate(msg.lobby_id) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(msg, conn) do
    raise "No handler for msg of #{msg.event} in LobbyUpdateMessageHandlers"
    {:ok, [], conn}
  end
end
