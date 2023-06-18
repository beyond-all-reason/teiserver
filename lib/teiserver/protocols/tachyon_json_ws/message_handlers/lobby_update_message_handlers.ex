defmodule Teiserver.Tachyon.MessageHandlers.LobbyUpdateMessageHandlers do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T

  @spec handle(map(), T.tachyon_ws_state()) ::
          {:ok, T.tachyon_ws_state()} | {:ok, map() | list(), T.tachyon_ws_state()}
  # def handle(%{event: :xyz} = msg, state) do
  #   case JoinRequestReponse.generate(msg.userid, msg.lobby_id) do
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
