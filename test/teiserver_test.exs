defmodule TeiserverTest do
  use ExUnit.Case
  doctest Teiserver

  test "greets the world" do
    assert Teiserver.hello() == :world
  end
end
