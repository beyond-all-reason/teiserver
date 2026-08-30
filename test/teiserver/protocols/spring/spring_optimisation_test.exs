defmodule Teiserver.SpringOptimisationTest do
  @moduledoc """
  The lobby client named in `LOGIN` selects how much of the event stream the
  connection receives, via `SpringIn`'s `@optimisation_level`.
  """
  alias Teiserver.Client
  use Teiserver.ServerCase, async: false

  import Teiserver.TeiserverTestLib,
    only: [
      raw_setup: 1,
      _send_raw: 2,
      _recv_raw: 1,
      _recv_until: 1,
      new_user: 0,
      start_spring_server: 1
    ]

  setup :start_spring_server

  setup(context) do
    %{socket: socket} = raw_setup(context)
    {:ok, socket: socket}
  end

  # Logs a fresh user in announcing `lobby`, and returns their client.
  defp login_announcing(socket, lobby) do
    user = new_user()
    _welcome = _recv_raw(socket)

    _send_raw(
      socket,
      "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * #{lobby}\t1993717506 0d04a635e200f308\tb sp\n"
    )

    _reply = _recv_until(socket)
    on_exit(fn -> Client.disconnect(user.id) end)

    Client.get_client_by_name(user.name)
  end

  test "a listed lobby client gets its mapped optimisation level", %{socket: socket} do
    client = login_announcing(socket, "modlobby:0.1.0")

    assert GenServer.call(client.tcp_pid, {:get, :protocol_optimisation}) == :partial

    # `CacheUser.do_login/4` keeps only `^[a-zA-Z ]+` of the lobby field, and that
    # is what has to match an `@optimisation_level` key. Separating the version
    # with a space instead would store "modlobby " and match nothing.
    assert client.lobby_client == "modlobby"
  end

  test "an unlisted lobby client falls back to full optimisation", %{socket: socket} do
    client = login_announcing(socket, "NotARealLobby:1")

    assert GenServer.call(client.tcp_pid, {:get, :protocol_optimisation}) == :full
    assert client.lobby_client == "NotARealLobby"
  end
end
