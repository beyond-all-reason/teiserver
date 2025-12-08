defmodule Teiserver.SpringTelemetryTest do
  use Teiserver.ServerCase, async: false
  alias Teiserver.Telemetry

  import Teiserver.TeiserverTestLib,
    only: [auth_setup: 1, _send_raw: 2, _recv_raw: 1, raw_setup: 1, start_spring_server: 1]

  setup :start_spring_server

  setup(context) do
    %{socket: socket, user: user} = auth_setup(context)
    {:ok, socket: socket, user: user}
  end

  test "upload_infolog call", %{socket: socket} = context do
    # No match
    _send_raw(socket, "c.telemetry.upload_infolog event_name e30=-- rXTrJC0nAdWUmCH8Q7+kWQ==--\n")
    reply = _recv_raw(socket)
    assert reply == "NO cmd=upload_infolog - no match\n"

    # Bad metadata base64
    _send_raw(
      socket,
      "c.telemetry.upload_infolog log_type user_hash rXTrJC0nAdWUmCH8Q7+kWQ==-- contents\n"
    )

    reply = _recv_raw(socket)
    assert reply == "NO cmd=upload_infolog - metadata decode - Base64 decode error\n"

    # Bad metadata json
    _send_raw(socket, "c.telemetry.upload_infolog log_type user_hash MTEtMTE= contents\n")
    reply = _recv_raw(socket)
    assert reply == "NO cmd=upload_infolog - metadata decode - Json decode error at position 2\n"

    # Bad infolog base64
    _send_raw(
      socket,
      "c.telemetry.upload_infolog log_type user_hash e30= rXTrJC0nAdWUmCH8Q7+kWQ==--\n"
    )

    reply = _recv_raw(socket)
    assert reply == "NO cmd=upload_infolog - infolog contents url_decode64 error\n"

    # Bad gzip
    metadata =
      %{key: "value", list: [1, 2, 3]}
      |> Jason.encode!()
      |> Base.url_encode64()

    contents =
      "Lorem ipsum\n\n''\\'^&&!"
      |> Base.url_encode64()

    _send_raw(socket, "c.telemetry.upload_infolog log_type user_hash #{metadata} #{contents}\n")
    reply = _recv_raw(socket)
    assert reply == "NO cmd=upload_infolog - infolog gzip error\n"

    # And finally the correct infolog format
    contents =
      "Lorem ipsum\n\n''\\'^&&!"
      |> :zlib.compress()
      |> Base.url_encode64()

    _send_raw(socket, "c.telemetry.upload_infolog log_type user_hash #{metadata} #{contents}\n")
    reply = _recv_raw(socket)
    assert reply =~ "OK cmd=upload_infolog - id:"
    [_, _, _, s] = reply |> String.trim() |> String.split(" ")
    [_, id] = String.split(s, ":")

    infolog = Telemetry.get_infolog(id)
    assert infolog.log_type == "log_type"
    assert infolog.metadata == %{"key" => "value", "list" => [1, 2, 3]}
    assert infolog.contents == "Lorem ipsum\n\n''\\'^&&!"

    # Unauth
    %{socket: socket_raw} = raw_setup(context)
    _recv_raw(socket_raw)

    _send_raw(
      socket_raw,
      "c.telemetry.upload_infolog log_type user_hash #{metadata} #{contents}\n"
    )

    reply = _recv_raw(socket_raw)
    assert reply =~ "OK cmd=upload_infolog - id:"
    [_, _, _, s] = reply |> String.trim() |> String.split(" ")
    [_, id] = String.split(s, ":")

    infolog = Telemetry.get_infolog(id)
    assert infolog.log_type == "log_type"
    assert infolog.metadata == %{"key" => "value", "list" => [1, 2, 3]}
    assert infolog.contents == "Lorem ipsum\n\n''\\'^&&!"
  end

  @tag :needs_attention
  test "log_client_event call", %{socket: socket} = context do
    # Bad/malformed data
    _send_raw(
      socket,
      "c.telemetry.log_client_event event_name e30=-- rXTrJC0nAdWUmCH8Q7+kWQ==--\n"
    )

    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.empty?(Telemetry.list_complex_anon_events())
    assert Enum.count(Telemetry.list_complex_client_events())

    # Good data
    _send_raw(socket, "c.telemetry.log_client_event event_name e30= TXlWYWx1ZUdvZXNoZXJl\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.empty?(Telemetry.list_complex_anon_events())
    assert Enum.count(Telemetry.list_complex_client_events()) == 1

    # Unauth
    %{socket: socket_raw} = raw_setup(context)
    _recv_raw(socket_raw)
    _send_raw(socket_raw, "c.telemetry.log_client_event event_name e30= TXlWYWx1ZUdvZXNoZXJl\n")
    reply = _recv_raw(socket_raw)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_complex_anon_events()) == 1
    assert Enum.count(Telemetry.list_complex_client_events()) == 1
  end

  @tag :needs_attention
  test "update_client_property call", %{socket: socket} = context do
    # Bad/malformed data
    _send_raw(
      socket,
      "c.telemetry.update_client_property property_name e30=-- rXTrJC0nAdWUmCH8Q7+kWQ==--\n"
    )

    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.empty?(Telemetry.list_complex_anon_events())

    # Good data
    _send_raw(
      socket,
      "c.telemetry.update_client_property property_name e30= TXlWYWx1ZUdvZXNoZXJl\n"
    )

    reply = _recv_raw(socket)
    assert reply == :timeout

    assert Enum.empty?(Telemetry.list_complex_anon_events())

    # Unauth
    %{socket: socket_raw} = raw_setup(context)
    _recv_raw(socket_raw)

    _send_raw(
      socket_raw,
      "c.telemetry.update_client_property property_name e30= TXlWYWx1ZUdvZXNoZXJl\n"
    )

    reply = _recv_raw(socket_raw)
    assert reply == :timeout

    assert Enum.count(Telemetry.list_complex_anon_events()) == 1
  end
end
