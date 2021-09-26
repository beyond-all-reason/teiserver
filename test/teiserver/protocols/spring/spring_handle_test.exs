defmodule Teiserver.SpringHandleTest do
  @moduledoc """
  These are tests just to ensure no errors are thrown. If you want to
  check the results coming back ensure you look at the auth and raw tests.
  """
  use Central.DataCase, async: false
  alias Teiserver.TeiserverTestLib
  alias Teiserver.Protocols.SpringIn
  alias Teiserver.Protocols.SpringOut

  test "LOGIN and EXIT" do
    state = TeiserverTestLib.mock_state_raw(SpringIn, SpringOut)

    SpringIn.handle(
      "LOGIN TestUser X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n",
      state
    )

    SpringIn.handle("EXIT", state)
    # :timer.sleep(1000)
  end

  test "EXIT" do
    state = TeiserverTestLib.mock_state_auth(SpringIn, SpringOut)
    SpringIn.handle("EXIT", state)
  end

  test "LEAVEBATTLE" do
    state = TeiserverTestLib.mock_state_auth(SpringIn, SpringOut)
    state = %{state | lobby_id: 1}
    SpringIn.handle("LEAVEBATTLE", state)
  end

  test "badly formed commands" do
    values = [
      "REGISTER name",
      "LOGIN name",
      ""
    ]

    state = TeiserverTestLib.mock_state_auth(SpringIn, SpringOut)
    state = %{state | lobby_id: 1}

    for v <- values do
      resp = SpringIn.handle(v, state)
      assert is_map(resp)
      assert Map.has_key?(resp, :user)
      assert Map.has_key?(resp, :lobby_host)
    end
  end
end
