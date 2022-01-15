defmodule Teiserver.Protocols.TachyonTelemetryTest do
  alias Teiserver.Telemetry
  use Central.ServerCase

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, tachyon_tls_setup: 0]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "unauth properties" do
    %{socket: socket} = tachyon_tls_setup()
    assert Enum.count(Telemetry.list_unauth_properties()) == 0

    data = %{cmd: "c.telemetry.update_property", hash: "myhash", property: "tachyon_unauth_test_property", value: "value here"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)

    assert Enum.count(Telemetry.list_unauth_properties()) == 1
    assert reply == :timeout
  end

  test "auth properties", %{socket: socket} do
    assert Enum.count(Telemetry.list_client_properties()) == 0

    data = %{cmd: "c.telemetry.update_property", hash: "myhash", property: "tachyon_test_property", value: "value here"}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)

    assert Enum.count(Telemetry.list_client_properties()) == 1
    assert reply == :timeout
  end

  test "unauth events" do
    %{socket: socket} = tachyon_tls_setup()
    assert Enum.count(Telemetry.list_unauth_events()) == 0

    data = %{cmd: "c.telemetry.log_event", hash: "myhash", event: "tachyon_unauth_test_event", value: %{"key" => "value here"}}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)

    assert Enum.count(Telemetry.list_unauth_events()) == 1
    assert reply == :timeout
  end

  test "auth events", %{socket: socket} do
    assert Enum.count(Telemetry.list_client_events()) == 0

    data = %{cmd: "c.telemetry.log_event", hash: "myhash", event: "tachyon_test_event", value: %{"key" => "value here"}}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)

    assert Enum.count(Telemetry.list_client_events()) == 1
    assert reply == :timeout
  end
end
