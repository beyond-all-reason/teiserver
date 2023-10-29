defmodule Teiserver.Bridge.UnitNamesTest do
  use Teiserver.ServerCase, async: true
  alias Teiserver.Bridge.UnitNames

  test "unit names" do
    assert UnitNames.get_name("sumo") == {:reused, {{"corsumo", "mammoth"}, {"corcan", "can"}}}
    assert UnitNames.get_name("tiger") == {:found_new, {"correap", "reaper"}}
    assert UnitNames.get_name("zipper") == {:found_old, {"armfast", "sprinter"}}
    assert UnitNames.get_name("archangel") == {:unchanged, {"armaak", "archangel"}}
    assert UnitNames.get_name("armbull") == {:code, "bull"}
    assert UnitNames.get_name("not a unit") == nil
  end
end
