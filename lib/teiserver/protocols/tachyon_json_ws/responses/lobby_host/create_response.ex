defmodule Barserver.Tachyon.Responses.LobbyHost.CreateResponse do
  @moduledoc """
  Updated status response - https://github.com/beyond-all-reason/tachyon/blob/master/src/schema/lobby_host.ts
  """

  alias Phoenix.PubSub
  alias Barserver.Data.Types, as: T

  @spec generate({:error, String.t()} | T.lobby()) :: {T.tachyon_command(), T.tachyon_object()}
  def generate({:error, reason}) do
    {"lobbyHost/create/request", :error, reason}
  end

  def generate({:ok, lobby}) do
    PubSub.unsubscribe(Barserver.PubSub, "teiserver_lobby_host_message:#{lobby.id}")
    PubSub.unsubscribe(Barserver.PubSub, "teiserver_lobby_updates:#{lobby.id}")
    PubSub.unsubscribe(Barserver.PubSub, "teiserver_lobby_chat:#{lobby.id}")

    PubSub.subscribe(Barserver.PubSub, "teiserver_lobby_host_message:#{lobby.id}")
    PubSub.subscribe(Barserver.PubSub, "teiserver_lobby_updates:#{lobby.id}")
    PubSub.subscribe(Barserver.PubSub, "teiserver_lobby_chat:#{lobby.id}")

    {"lobbyHost/create/response", :success, lobby}
  end
end
