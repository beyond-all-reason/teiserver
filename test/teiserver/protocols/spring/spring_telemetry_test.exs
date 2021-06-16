defmodule Teiserver.SpringTelemetryTest do
  use Central.ServerCase, async: false
  import Teiserver.TeiserverTestLib,
    only: [auth_setup: 0, _send_raw: 2, _recv_raw: 1]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "test telemetry call", %{socket: socket} do
    _send_raw(socket, "c.telemetry.log_client_event CLIENT_EVENT\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    _send_raw(socket, "c.telemetry.log_battle_event BATTLE_EVENT\n")
    reply = _recv_raw(socket)
    assert reply == :timeout
  end
end
