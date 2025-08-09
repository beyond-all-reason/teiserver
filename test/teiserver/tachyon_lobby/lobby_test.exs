defmodule Teiserver.TachyonLobby.LobbyTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1]
  alias Teiserver.TachyonLobby, as: Lobby

  @moduletag :tachyon

  test "create a lobby" do
    {:ok, %{pid: pid, id: id}} = Lobby.create()
    p = poll_until_some(fn -> Lobby.lookup(id) end)
    assert p == pid
  end
end
