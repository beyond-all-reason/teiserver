defmodule Teiserver.SpringHandleTest do
  @moduledoc """
  These are tests just to ensure no errors are thrown. If you want to 
  check the results coming back ensure you look at the auth and raw tests.
  """
  use Central.DataCase, async: true
  alias Teiserver.TestLib
  alias Teiserver.Protocols.SpringProtocol

  test "LOGIN" do
    state = TestLib.mock_state_raw(SpringProtocol)

    SpringProtocol.handle(
      "LOGIN TestUser X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n",
      state
    )
  end

  test "EXIT" do
    state = TestLib.mock_state_auth(SpringProtocol)
    SpringProtocol.handle("EXIT", state)
  end

  test "LEAVEBATTLE" do
    state = TestLib.mock_state_auth(SpringProtocol)
    new_client = %{state.client | battle_id: 1}
    state = %{state | client: new_client}
    SpringProtocol.handle("LEAVEBATTLE", state)
  end

  test "badly formed commands" do
    values = [
      "REGISTER name",
      "LOGIN name"
    ]

    state = TestLib.mock_state_auth(SpringProtocol)
    new_client = %{state.client | battle_id: 1}
    state = %{state | client: new_client}

    for v <- values do
      resp = SpringProtocol.handle(v, state)
      assert is_map(resp)
      assert Map.has_key?(resp, :user)
      assert Map.has_key?(resp, :client)
    end
  end
end
