defmodule Teiserver.Helpers.BoundedQueueTest do
  use ExUnit.Case, async: true

  alias Teiserver.Helpers.BoundedQueue, as: BQ

  test "must provide correct arg" do
    assert_raise ArgumentError, fn ->
      BQ.new(0)
    end
  end

  test "is_empty" do
    q = BQ.new(1)
    assert BQ.is_empty(q)
    assert not BQ.is_empty(BQ.put(q, :coucou))
  end

  test "from and to list" do
    q = BQ.from_list([1, 2, 3], 10)
    assert not BQ.dropped?(q)
    assert BQ.to_list(q) == [1, 2, 3]
  end

  test "from list with lower capacity" do
    q = BQ.from_list([1, 2, 3], 2)
    assert BQ.dropped?(q)
    assert BQ.to_list(q) == [2, 3]
  end

  test "put and length" do
    q = BQ.new(1)
    assert BQ.len(q) == 0
    q = BQ.put(q, :item)
    assert BQ.len(q) == 1
    assert BQ.to_list(q) == [:item]
  end

  test "out" do
    q = BQ.new(1) |> BQ.put(:item)
    assert {{:value, :item}, q2} = BQ.out(q)
    assert BQ.is_empty(q2)
  end

  test "max len" do
    q = BQ.new(2) |> BQ.put(:item) |> BQ.put(:other)
    assert not BQ.dropped?(q)
    q2 = BQ.put(q, :too_many)
    assert BQ.len(q2) == 2
    assert BQ.dropped?(q2)
    assert BQ.to_list(q2) == [:other, :too_many]
  end

  test "resize, increase size" do
    {q, []} = BQ.new(1) |> BQ.put(1) |> BQ.resize(2)
    assert not BQ.dropped?(q)
    assert 1 == BQ.len(q)
    q2 = BQ.put(q, 2)
    assert not BQ.dropped?(q2)
    assert 2 == BQ.len(q2)
    assert [1, 2] == BQ.to_list(q2)
    q3 = BQ.put(q2, 3)
    assert BQ.dropped?(q3)
    assert [2, 3] == BQ.to_list(q3)
  end

  test "resize, no spillover" do
    {q, []} = BQ.new(2) |> BQ.put(1) |> BQ.resize(1)
    assert not BQ.dropped?(q)
    assert 1 == BQ.len(q)
    q2 = BQ.put(q, 2)
    assert BQ.dropped?(q2)
    assert [2] == BQ.to_list(q2)
  end

  test "resize, with spillover" do
    {q, [1, 2]} = BQ.new(3) |> BQ.put(1) |> BQ.put(2) |> BQ.put(3) |> BQ.resize(1)
    assert not BQ.dropped?(q)
    assert 1 == BQ.len(q)
    q2 = BQ.put(q, 4)
    assert BQ.dropped?(q2)
    assert [4] == BQ.to_list(q2)
  end

  describe "split_when" do
    test "match first element" do
      q = BQ.from_list([1, 2, 3], 5)
      {a, b} = BQ.split_when(q, &(&1 == 1))
      assert BQ.to_list(a) == [1]
      assert BQ.to_list(b) == [2, 3]
    end

    test "match last element" do
      q = BQ.from_list([1, 2, 3], 5)
      {a, b} = BQ.split_when(q, &(&1 == 3))
      assert {{:value, 1}, _} = BQ.out(a)
      assert BQ.to_list(a) == [1, 2, 3]
      assert BQ.to_list(b) == []
    end

    test "no match" do
      q = BQ.from_list([1, 2, 3], 5)
      {a, b} = BQ.split_when(q, &(&1 == 10))
      assert BQ.to_list(a) == [1, 2, 3]
      assert b == nil
    end
  end
end
