defmodule Central.Helpers.NestedMapsTest do
  use Central.DataCase, async: true
  alias Central.NestedMaps

  @small_map %{
    "a" => 1,
    "b" => %{
      "c" => 2,
      "d" => %{
        "e" => 3
      }
    }
  }

  @big_map %{
    "a" => 1,
    "b" => 2,
    "c" => %{
      "a" => 11,
      "b" => 12
    },
    "d" => %{
      "a" => %{
        "a" => 111
      },
      "b" => %{
        "a" => 112
      }
    }
  }

  test "test get" do
    assert 1 == NestedMaps.get(@big_map, ~w(a))
    assert 2 == NestedMaps.get(@big_map, ~w(b))
    assert 11 == NestedMaps.get(@big_map, ~w(c a))
    assert 111 == NestedMaps.get(@big_map, ~w(d a a))
  end

  test "test put" do
    # Check nothing changes if we set a value to be what it already is
    assert @small_map == NestedMaps.put(@small_map, ~w(a), 1)
    assert @small_map == NestedMaps.put(@small_map, ~w(b d e), 3)

    # Now check a change takes place when updating
    assert NestedMaps.put(@small_map, ~w(a), 5) == %{
      "a" => 5,
      "b" => %{
        "c" => 2,
        "d" => %{
          "e" => 3
        }
      }
    }

    assert NestedMaps.put(@small_map, ~w(b c), 7) == %{
      "a" => 1,
      "b" => %{
        "c" => 7,
        "d" => %{
          "e" => 3
        }
      }
    }

    # And inserting
    assert NestedMaps.put(@small_map, ~w(b d f), 9) == %{
      "a" => 1,
      "b" => %{
        "c" => 2,
        "d" => %{
          "e" => 3,
          "f" => 9
        }
      }
    }
  end
end
