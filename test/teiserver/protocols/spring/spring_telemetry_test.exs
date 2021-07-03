defmodule Teiserver.SpringTelemetryTest do
  use Central.ServerCase, async: false
  alias Teiserver.Telemetry
  alias Teiserver.Client
  import Teiserver.TeiserverTestLib,
    only: [auth_setup: 0, _send_raw: 2, _recv_raw: 1, raw_setup: 0]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "test log_client_event call", %{socket: socket} do
    # Bad/malformed data
    _send_raw(socket, "c.telemetry.log_client_event event_name e30=-- rXTrJC0nAdWUmCH8Q7+kWQ==--\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_unauth_events()) == 0
    assert Enum.count(Telemetry.list_client_events()) == 0

    # Good data
    _send_raw(socket, "c.telemetry.log_client_event event_name e30= TXlWYWx1ZUdvZXNoZXJl\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_unauth_events()) == 0
    assert Enum.count(Telemetry.list_client_events()) == 1

    # Unauth
    %{socket: socket_raw} = raw_setup()
    _recv_raw(socket_raw)
    _send_raw(socket_raw, "c.telemetry.log_client_event event_name e30= TXlWYWx1ZUdvZXNoZXJl\n")
    reply = _recv_raw(socket_raw)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_unauth_events()) == 1
    assert Enum.count(Telemetry.list_client_events()) == 1
  end

  test "test update_client_property call", %{socket: socket} do
    # Bad/malformed data
    _send_raw(socket, "c.telemetry.update_client_property property_name e30=-- rXTrJC0nAdWUmCH8Q7+kWQ==--\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_unauth_properties()) == 0
    assert Enum.count(Telemetry.list_client_properties()) == 0

    # Good data
    _send_raw(socket, "c.telemetry.update_client_property property_name e30= TXlWYWx1ZUdvZXNoZXJl\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_unauth_properties()) == 0
    assert Enum.count(Telemetry.list_client_properties()) == 1

    # Unauth
    %{socket: socket_raw} = raw_setup()
    _recv_raw(socket_raw)
    _send_raw(socket_raw, "c.telemetry.update_client_property property_name e30= TXlWYWx1ZUdvZXNoZXJl\n")
    reply = _recv_raw(socket_raw)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_unauth_properties()) == 1
    assert Enum.count(Telemetry.list_client_properties()) == 1
  end

  test "test log_battle_event call", %{user: user, socket: socket} do
    # Bad/malformed data
    _send_raw(socket, "c.telemetry.log_battle_event battle_event_name e30=--\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_battle_events()) == 0

    # Client not in battle
    _send_raw(socket, "c.telemetry.log_battle_event battle_event_name e30=\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_battle_events()) == 0

    # Client in battle
    client = Client.get_client_by_id(user.id)
    Client.update(%{client | battle_id: 1}, :client_updated_status)
    _recv_raw(socket)# Client status update
    _send_raw(socket, "c.telemetry.log_battle_event battle_event_name e30=\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_battle_events()) == 1

    # Unauth
    %{socket: socket_raw} = raw_setup()
    _recv_raw(socket_raw)
    _send_raw(socket_raw, "c.telemetry.log_battle_event battle_event_name e30=\n")
    reply = _recv_raw(socket_raw)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_battle_events()) == 1
  end
end
