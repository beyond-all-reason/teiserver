defmodule Teiserver.Common.ClearDbEachTest do
  @moduledoc """
  Tests that the sandbox db is cleared after each test
  """
  use Teiserver.DataCase, async: true

  test "Sandbox test 1" do
    name = "ClearDbEachTestUser"
    user = Teiserver.TeiserverTestLib.new_user(name)
    result = Teiserver.CacheUser.get_user_by_id(user.id)
    assert result[:name] == name
  end

  test "Sandbox test 2" do
    name = "ClearDbEachTestUser"
    user = Teiserver.TeiserverTestLib.new_user(name)
    result = Teiserver.CacheUser.get_user_by_id(user.id)
    assert result[:name] == name
  end
end
