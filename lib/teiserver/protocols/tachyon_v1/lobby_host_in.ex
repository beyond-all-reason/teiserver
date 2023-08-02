defmodule Teiserver.Protocols.Tachyon.V1.LobbyHostIn do
  alias Teiserver.Lobby
  alias Teiserver.{Coordinator}
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Data.Types, as: T

  @spec do_handle(String.t(), Map.t(), T.tachyon_tcp_state()) :: T.tachyon_tcp_state()
  def do_handle("update_host_status", _, %{userid: nil} = state),
    do: reply(:system, :nouser, nil, state)

  def do_handle("update_host_status", _, %{lobby_id: nil} = state),
    do: reply(:system, :nolobby, nil, state)

  def do_handle("update_host_status", new_status, state) do
    host_data =
      new_status
      |> Map.take(~w(boss teamsize teamcount))
      |> Map.new(fn {k, v} -> {String.to_atom("host_" <> k), int_parse(v)} end)

    if Lobby.allow?(state.userid, :update_host_status, state.lobby_id) do
      Coordinator.cast_consul(state.lobby_id, {:host_update, state.userid, host_data})
    end

    state
  end

  def do_handle("respond_to_join_request", data, %{lobby_id: lobby_id} = state) do
    userid = int_parse(data["userid"])

    case data["response"] do
      "approve" ->
        Lobby.accept_join_request(userid, lobby_id)

      "reject" ->
        Lobby.deny_join_request(userid, lobby_id, data["reason"])

      r ->
        reply(
          :system,
          :error,
          %{
            error: "invalid response type, no handler for '#{r}'",
            location: "c.lobby_host.respond_to_join_request"
          },
          state
        )
    end

    state
  end
end
