defmodule Teiserver.Helper.BimapTest do
  use ExUnit.Case, async: true

  alias Teiserver.Helpers.Bimap

  test "store a value with 2 keys" do
    m = Bimap.new() |> Bimap.put(1, :key, :value)
    assert Bimap.get(m, :key) == :value
    assert Bimap.get(m, 1) == :value
  end

  test "handle two identical keys" do
    m = Bimap.new() |> Bimap.put(1, 1, :value)
    assert Bimap.get(m, 1) == :value
    assert Bimap.delete(m, 1) == Bimap.new()
  end

  test "store several distinct values" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value1) |> Bimap.put(2, :key2, :value2)
    assert Bimap.get(m, :key1) == :value1
    assert Bimap.get(m, 1) == :value1
    assert Bimap.get(m, :key2) == :value2
    assert Bimap.get(m, 2) == :value2
  end

  test "storing a value with key1 overlap" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value1) |> Bimap.put(1, :key2, :value2)
    assert Bimap.get(m, 1) == :value2
    assert Bimap.get(m, :key2) == :value2
    assert Bimap.get(m, :key1) == nil
  end

  test "storing a value with key2 overlap" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value1) |> Bimap.put(2, :key1, :value2)
    assert Bimap.get(m, 1) == nil
    assert Bimap.get(m, 2) == :value2
    assert Bimap.get(m, :key1) == :value2
  end

  test "store nil with key1 overlap" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value1) |> Bimap.put(1, :key2, nil)
    assert Bimap.has_key?(m, :key1) == false
    assert Bimap.get(m, 1) == nil
    assert Bimap.get(m, :key2) == nil
    assert Bimap.has_key?(m, 1) == true
    assert Bimap.has_key?(m, :key2) == true
  end

  test "store nil with key2 overlap" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value1) |> Bimap.put(2, :key1, nil)
    assert Bimap.has_key?(m, 1) == false
    assert Bimap.get(m, 2) == nil
    assert Bimap.get(m, :key1) == nil
    assert Bimap.has_key?(m, 2) == true
    assert Bimap.has_key?(m, :key1) == true
  end

  test "overwrite value" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value1) |> Bimap.put(1, :key1, :value2)
    assert Bimap.get(m, 1) == :value2
    assert Bimap.get(m, :key1) == :value2
  end

  test "overwrite value, the other way around" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value1) |> Bimap.put(:key1, 1, :value2)
    assert Bimap.get(m, 1) == :value2
    assert Bimap.get(m, :key1) == :value2
  end

  test "get value and sibling key" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value)
    assert Bimap.get_other_key(m, 1) == :key1
    assert Bimap.get_other_key(m, :key1) == 1
  end

  test "delete both keys" do
    m = Bimap.new() |> Bimap.put(1, :key1, :value1)
    assert Bimap.delete(m, 1) == Bimap.new()
    assert Bimap.delete(m, :key1) == Bimap.new()
  end
end
