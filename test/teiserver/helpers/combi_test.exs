defmodule Teiserver.Helpers.CombiTest do
  use ExUnit.Case, async: true

  alias Teiserver.Helpers.Combi

  test "works for numbers" do
    result = Combi.combinations([1, 2, 3], 2) |> Enum.to_list()
    expected = [[1, 2], [1, 3], [2, 3]]
    assert result == expected
  end

  test "works for lists" do
    result = Combi.combinations([[1], [2], [3]], 2) |> Enum.to_list()
    expected = [[[1], [2]], [[1], [3]], [[2], [3]]]
    assert result == expected
  end

  test "works for bigger lists" do
    assert [[[3]]] == Combi.combinations([[1, 2], [3]], 1) |> Enum.to_list()
    assert [[[1, 2]]] == Combi.combinations([[1, 2], [3]], 2) |> Enum.to_list()
  end

  test "works for mixed sized lists" do
    result = Combi.combinations([[1, 2], [3], [4]], 2) |> Enum.to_list()
    expected = [[[1, 2]], [[3], [4]]]
    assert result == expected

    result = Combi.combinations([[1, 2], [3], [4]], 3) |> Enum.to_list()
    expected = [[[1, 2], [3]], [[1, 2], [4]]]
    assert result == expected
  end

  test "works for edge conditions" do
    # this mimicks what itertools.combinations does in python
    assert [[]] == Combi.combinations([1, 2, 3], 0) |> Enum.to_list()
    assert [] == Combi.combinations([1, 2, 3], 4) |> Enum.to_list()
  end
end
