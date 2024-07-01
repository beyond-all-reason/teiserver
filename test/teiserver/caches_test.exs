defmodule Teiserver.CachesTest do
  use Teiserver.DataCase, async: false

  # This module is merely here to check that
  # Teiserver.TeiserverTestLib.clear_all_con_caches does indeed clear the advertised
  # cache across tests.
  # because all queries rely heavily on caches, it's important to clear them between
  # tests so as not to pollute other tests

  test "Clear user caches 1" do
    name = "ClearDbEachTestUser"
    assert is_nil(Teiserver.CacheUser.get_user_by_name(name))
    user = Teiserver.TeiserverTestLib.new_user(name)
    result = Teiserver.CacheUser.get_user_by_id(user.id)
    assert result[:name] == name
  end

  test "Clear user caches 2" do
    name = "ClearDbEachTestUser"
    assert is_nil(Teiserver.CacheUser.get_user_by_name(name))
    user = Teiserver.TeiserverTestLib.new_user(name)
    result = Teiserver.CacheUser.get_user_by_id(user.id)
    assert result[:name] == name
  end
end
