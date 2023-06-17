defmodule Teiserver.Tachyon.MessageHandlers.LobbyHostMessageHandlers do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Tachyon.Responses.LobbyHost.JoinRequestReponse

  @spec handle(map(), T.tachyon_ws_state()) ::
          {:ok, T.tachyon_ws_state()} | {:ok, map() | list(), T.tachyon_ws_state()}
  def handle(%{event: :user_requests_to_join} = msg, state) do
    case JoinRequestReponse.generate(msg.userid, msg.lobby_id) do
      {command, :success, data} ->
        resp = %{
          "command" => command,
          "status" => "success",
          "data" => data
        }

        {:ok, resp, state}
    end
  end

  # def handle(%{event: :join_lobby_request_response} = msg, state) do
  #   case ReceivedDirectMessageResponse.generate(msg) do
  #     {command, :success, data} ->
  #       resp = %{
  #         "command" => command,
  #         "status" => "success",
  #         "data" => data
  #       }

  #       {:ok, resp, state}
  #   end
  # end

  def handle(msg, state) do
    raise "No handler for msg of #{msg.event} in LobbyHostMessageHandlers"
    {:ok, [], state}
  end
end
