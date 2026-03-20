defmodule Teiserver.Helper.SchemaHelperTest do
  alias Teiserver.Helper.SchemaHelper

  use Teiserver.DataCase, async: true

  test "one datetime" do
    params = %{"a" => "01:02:03 01/01/2017"}
    names = [:a]

    result = SchemaHelper.parse_datetimes(params, names)

    assert result == %{
             "a" => %{
               "day" => "1",
               "month" => "1",
               "year" => "2017",
               "hour" => "1",
               "minute" => "2",
               "second" => "3"
             }
           }
  end

  test "one datetime with atom" do
    params = %{a: "01:02:03 01/01/2017"}
    names = [:a]

    result = SchemaHelper.parse_datetimes(params, names)

    assert result == %{
             a: %{
               "day" => "1",
               "month" => "1",
               "year" => "2017",
               "hour" => "1",
               "minute" => "2",
               "second" => "3"
             }
           }
  end

  test "empty datetimes" do
    params = %{"a" => "", "b" => ""}
    names = [:a, :b]

    result = SchemaHelper.parse_datetimes(params, names)
    assert result == %{"a" => "", "b" => ""}
  end

  test "other datetime values" do
    params = %{"a" => "01:02:03 01/01/2017", "b" => "value"}
    names = [:a]

    result = SchemaHelper.parse_datetimes(params, names)

    assert result == %{
             "a" => %{
               "day" => "1",
               "month" => "1",
               "year" => "2017",
               "hour" => "1",
               "minute" => "2",
               "second" => "3"
             },
             "b" => "value"
           }
  end

  test "trim strings" do
    params = %{"a" => "abc", "b" => " abc ", "c" => "abc ", "d" => " abc"}
    names = [:a, :b, :c, :d]

    result = SchemaHelper.trim_strings(params, names)
    assert result == %{"a" => "abc", "b" => "abc", "c" => "abc", "d" => "abc"}
  end
end
