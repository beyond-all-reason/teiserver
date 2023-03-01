defmodule Teiserver.Protocols.V1.TachyonWsRawTest do
  use CentralWeb.ChannelCase, async: true
  # use CentralWeb.ConnCase, async: true
  alias Tachyon.TachyonSocket

  # alias Teiserver.{User, Account}

  # alias Teiserver.TachyonTestLib
  # alias Teiserver.Protocols.TachyonLib

  # setup do
  #   %{socket: socket} = TachyonTestLib.
  #   {:ok, socket: socket}
  # end

  test "basic tachyon" do
    s = socket(TachyonSocket, "tachyon", %{})
    # s = connect(TachyonSocket, %{"some" => "params"}, %{})

    IO.puts ""
    IO.inspect s, label: "Test output"
    IO.puts ""

    # s = connect(TachyonSocket, %{"some" => "params"}, %{})
  end

  # No ws function
  # test "renders select form", %{conn: conn} do
  #   conn = ws(conn, "ws://localhost:4000/tachyon/websocket")
  # end
end
