defmodule Teiserver.Helper.SchemaHelperTest do
  alias Teiserver.Helper.SchemaHelper

  use Teiserver.DataCase, async: true

  test "trim strings" do
    params = %{"a" => "abc", "b" => " abc ", "c" => "abc ", "d" => " abc"}
    names = [:a, :b, :c, :d]

    result = SchemaHelper.trim_strings(params, names)
    assert result == %{"a" => "abc", "b" => "abc", "c" => "abc", "d" => "abc"}
  end
end
