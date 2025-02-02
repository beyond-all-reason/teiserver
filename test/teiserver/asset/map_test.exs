defmodule Teiserver.Asset.MapTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Asset
  alias Teiserver.AssetFixtures

  describe "create maps" do
    test "all valid" do
      map_attrs = [
        %{
          spring_name: "altore divide bar remake 1.6.2",
          display_name: "Altore Divide",
          thumbnail_url: "http://blah.com/map.jpg"
        },
        %{
          spring_name: "Quicksilver Remake 1.24",
          display_name: "Quicksilver",
          thumbnail_url: "http://blah.com/qs.jpg"
        }
      ]

      assert {:ok, [map1, map2]} = Asset.create_maps(map_attrs)
      assert map1.display_name == "Altore Divide"
      assert map2.display_name == "Quicksilver"

      altore_divide = Asset.get_map("altore divide bar remake 1.6.2")
      assert altore_divide.display_name == "Altore Divide"

      assert Enum.count(Asset.get_all_maps()) == 2
    end

    test "missing primary key" do
      map_attrs = [
        %{
          display_name: "Altore Divide",
          thumbnail_url: "http://blah.com/map.jpg"
        },
        %{
          spring_name: "Quicksilver Remake 1.24",
          display_name: "Quicksilver",
          thumbnail_url: "http://blah.com/qs.jpg"
        }
      ]

      assert {:error, _op_name, _err, _changes_so_far} = Asset.create_maps(map_attrs)
      assert Asset.get_all_maps() == []
    end
  end

  describe "delete" do
    test "all" do
      AssetFixtures.create_map(%{
        spring_name: "altore divide bar remake 1.6.2",
        display_name: "Altore Divide",
        thumbnail_url: "http://blah.com/map.jpg"
      })

      AssetFixtures.create_map(%{
        spring_name: "Quicksilver Remake 1.24",
        display_name: "Quicksilver",
        thumbnail_url: "http://blah.com/qs.jpg"
      })

      assert Asset.delete_all_maps() == 2
    end
  end
end
