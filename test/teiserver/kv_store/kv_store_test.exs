defmodule Teiserver.KvStore.KvStoreTest do
  use Teiserver.DataCase, aync: false

  alias Teiserver.KvStore, as: KV

  test "can write and read single blob" do
    :ok = KV.put("test_store", "key1", "foo_val")
    res = KV.get("test_store", "key1")
    assert res.value == "foo_val"
  end

  test "get nil if nothing matches" do
    assert KV.get("test_store", "nothing") == nil
  end

  test "overwrite blob if already there" do
    :ok = KV.put("test_store", "key1", "val1")
    :ok = KV.put("test_store", "key1", "val2")
    res = KV.get("test_store", "key1")
    assert res.value == "val2"
  end

  test "put_many works" do
    :ok =
      KV.put_many([
        %{store: "test_store", key: "key1", value: "val1"},
        %{store: "test_store", key: "key2", value: "val2"}
      ])

    assert KV.get("test_store", "key1").value == "val1"
    assert KV.get("test_store", "key2").value == "val2"
  end

  test "put_many is atomic" do
    {:error, [err]} =
      KV.put_many([
        %{store: "test_store", key: :invalid_type, value: "val1"},
        %{store: "test_store", key: "key2", value: "val2"}
      ])

    refute err.valid?
  end

  test "put_many can upsert" do
    KV.put("test_store", "key1", "to be overwritten")

    :ok =
      KV.put_many([
        %{store: "test_store", key: "key1", value: "val1"},
        %{store: "test_store", key: "key2", value: "val2"}
      ])

    assert KV.get("test_store", "key1").value == "val1"
    assert KV.get("test_store", "key2").value == "val2"
  end

  test "scan all keys for a given store" do
    :ok = KV.put("test_store1", "key1", "val1")
    :ok = KV.put("test_store1", "key2", "val2")
    :ok = KV.put("test_store2", "key1", "val1")

    blobs =
      KV.scan("test_store1")
      |> Enum.map(&Map.take(&1, [:store, :key, :value]))
      |> MapSet.new()

    assert MapSet.new([
             %{store: "test_store1", key: "key1", value: "val1"},
             %{store: "test_store1", key: "key2", value: "val2"}
           ]) == blobs
  end
end
