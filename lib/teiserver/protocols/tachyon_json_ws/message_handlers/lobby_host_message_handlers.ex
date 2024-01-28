defmodule Barserver.Tachyon.MessageHandlers.LobbyHostMessageHandlers do
  @moduledoc """

  """
  alias Barserver.Data.Types, as: T
  alias Barserver.Tachyon.Responses.LobbyHost.JoinRequestReponse

  @spec handle(map(), T.tachyon_conn()) ::
          {:ok, T.tachyon_conn()} | {:ok, map() | list(), T.tachyon_conn()}
  def handle(%{event: :user_requests_to_join} = msg, conn) do
    case JoinRequestReponse.generate(msg.userid, msg.lobby_id) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, conn}
    end
  end

  def handle(%{event: :add_user} = msg, _conn) do
    raise inspect(msg)
  end

  def handle(msg, conn) do
    raise "No handler for msg of #{msg.event} in LobbyHostMessageHandlers"
    {:ok, [], conn}
  end
end
