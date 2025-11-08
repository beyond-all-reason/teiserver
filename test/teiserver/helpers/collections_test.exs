defmodule Teiserver.Helpers.CollectionsTest do
  use ExUnit.Case

  describe "transform map" do
    import Teiserver.Helpers.Collections, only: [transform_map: 2]

    test "converts keys" do
      spec = %{foo: :foo, camelBar: :snake_bar}
      data = %{foo: "fooval", camelBar: 1}
      expected = %{foo: "fooval", snake_bar: 1}
      assert transform_map(data, spec) == expected
    end

    test "converts to strings keys" do
      spec = %{foo: "foo", camelBar: "snake_bar"}
      data = %{foo: "fooval", camelBar: 1}
      expected = %{"foo" => "fooval", "snake_bar" => 1}
      assert transform_map(data, spec) == expected
    end

    test "converts from strings keys" do
      spec = %{"foo" => :foo, "camelBar" => :snake_bar}
      data = %{"foo" => "fooval", "camelBar" => 1}
      expected = %{:foo => "fooval", :snake_bar => 1}
      assert transform_map(data, spec) == expected
    end

    test "ignores keys not in the mapping spec" do
      spec = %{foo: :foo}
      data = %{foo: "fooval", other: "will be ignored"}
      expected = %{foo: "fooval"}
      assert transform_map(data, spec) == expected
    end

    test "recursively converts nested maps" do
      spec = %{deepFoo: {:deep_foo, %{nestedBar: :nested_bar}}}
      data = %{deepFoo: %{nestedBar: "bar"}}
      expected = %{deep_foo: %{nested_bar: "bar"}}
      assert transform_map(data, spec) == expected
    end

    test "handle nil when recursing" do
      spec = %{deepFoo: {:deep_foo, %{nestedBar: :nested_bar}}}
      data = %{deepFoo: nil}
      expected = %{deep_foo: nil}
      assert transform_map(data, spec) == expected
    end

    test "map array values" do
      spec = %{iterableFoo: {:iterable_foo, %{key1: :key2}}}
      data = %{iterableFoo: [%{key1: 1}, %{key1: 2}]}
      expected = %{iterable_foo: [%{key2: 1}, %{key2: 2}]}
      assert transform_map(data, spec) == expected
    end

    test "apply function to value" do
      spec = %{toTransform: {:to_transform, &(&1 + 1)}}
      data = %{toTransform: 1}
      expected = %{to_transform: 2}
      assert transform_map(data, spec) == expected
    end

    test "apply given function to value for key" do
      spec = %{toTransform: &Map.put(&1, :new_key, &2)}
      data = %{toTransform: "some value"}
      expected = %{new_key: "some value"}
      assert transform_map(data, spec) == expected
    end

    test "apply function with key and value as arg" do
      spec = %{toTransform: &Map.put(&1, :new_key, to_string(&2) <> " " <> &3)}
      data = %{toTransform: "some value"}
      expected = %{new_key: "toTransform some value"}
      assert transform_map(data, spec) == expected
    end

    test "ignore given function if key not present" do
      spec = %{toTransform: &Map.put(&1, :new_key, &2)}
      data = %{other: "other val"}
      expected = %{}
      assert transform_map(data, spec) == expected
    end

    test "does nil punning" do
      assert transform_map(nil, %{foo: :bar}) == nil
    end

    test "handles nil value recursively" do
      assert transform_map(%{foo: nil}, %{foo: {:bar, %{key1: :key2}}}) == %{bar: nil}
    end

    test "call functions on nil values" do
      spec = %{foo: fn m, _k -> Map.put(m, :key, "nope") end}
      data = %{foo: nil}
      expected = %{key: "nope"}
      assert transform_map(data, spec) == expected
    end
  end
end
