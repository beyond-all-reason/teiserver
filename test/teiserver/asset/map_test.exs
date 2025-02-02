defmodule Teiserver.Asset.MapTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Asset
  alias Teiserver.AssetFixtures

  # define some valid map attr for convenience
  def qs_attr(),
    do: %{
      spring_name: "Quicksilver Remake 1.24",
      display_name: "Quicksilver",
      thumbnail_url: "http://blah.com/qs.jpg"
    }

  def altore_attr,
    do: %{
      spring_name: "altore divide bar remake 1.6.2",
      display_name: "Altore Divide",
      thumbnail_url: "http://blah.com/map.jpg"
    }

  describe "create maps" do
    test "all valid" do
      map_attrs = [altore_attr(), qs_attr()]

      assert {:ok, [map1, map2]} = Asset.create_maps(map_attrs)
      assert map1.display_name == "Altore Divide"
      assert map2.display_name == "Quicksilver"

      altore_divide = Asset.get_map("altore divide bar remake 1.6.2")
      assert altore_divide.display_name == "Altore Divide"

      assert Enum.count(Asset.get_all_maps()) == 2
    end

    test "missing primary key" do
      map_attrs = [Map.drop(qs_attr(), [:spring_name]), altore_attr()]

      assert {:error, _op_name, _err, _changes_so_far} = Asset.create_maps(map_attrs)
      assert Asset.get_all_maps() == []
    end
  end

  describe "delete" do
    test "all" do
      AssetFixtures.create_map(qs_attr())
      AssetFixtures.create_map(altore_attr())

      assert Asset.delete_all_maps() == 2
    end
  end

  describe "update all" do
    test "works" do
      result = Asset.update_maps([qs_attr()])

      assert {:ok, %{created_count: 1, deleted_count: 0}} == result
    end

    test "replace existing maps" do
      AssetFixtures.create_map(qs_attr())
      AssetFixtures.create_map(altore_attr())

      res =
        Asset.update_maps([
          %{
            spring_name: "Quicksilver Remake 1.24",
            display_name: "Quicksilver",
            thumbnail_url: "http://blah.com/qsNEW.jpg"
          }
        ])

      assert res == {:ok, %{created_count: 1, deleted_count: 2}}
    end

    test "don't wipe existing setup if error" do
      AssetFixtures.create_map(qs_attr())
      AssetFixtures.create_map(altore_attr())

      assert {:error, _} =
               Asset.update_maps([
                 %{
                   display_name: "Quicksilver",
                   thumbnail_url: "http://blah.com/qs.jpg"
                 }
               ])

      assert Enum.count(Asset.get_all_maps()) == 2
    end
  end
end
