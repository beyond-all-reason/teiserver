defmodule Central.Helpers.SchemaHelperTest do
  use Central.DataCase, async: true

  alias Central.Helpers.SchemaHelper

  # test "test currency" do
  #   params = %{"a" => "132.34"}
  #   names = [:a]

  #   result = SchemaHelper.parse_currency(params, names)
  #   assert result == %{"a" => Decimal.new("132.34")}
  # end

  # test "one date" do
  #   params = %{"a" => "01/01/2017"}
  #   names = [:a]

  #   result = SchemaHelper.parse_dates(params, names)
  #   assert result == %{"a" => %{"day" => "1", "month" => "1", "year" => "2017"}}
  # end

  # test "one date with atom" do
  #   params = %{a: "01/01/2017"}
  #   names = [:a]

  #   result = SchemaHelper.parse_dates(params, names)
  #   assert result == %{a: %{"day" => "1", "month" => "1", "year" => "2017"}}
  # end

  # test "empty dates" do
  #   params = %{"a" => "", "b" => ""}
  #   names = [:a, :b]

  #   result = SchemaHelper.parse_dates(params, names)
  #   assert result == %{"a" => "", "b" => ""}
  # end

  # test "other date values" do
  #   params = %{"a" => "01/01/2017", "b" => "value"}
  #   names = [:a]

  #   result = SchemaHelper.parse_dates(params, names)
  #   assert result == %{"a" => %{"day" => "1", "month" => "1", "year" => "2017"}, "b" => "value"}
  # end

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

  # test "string list" do
  #   params = %{"a" => "", "b" => "abc\ndef"}
  #   names = [:a, :b]

  #   result = SchemaHelper.parse_string_list(params, names)
  #   assert result == %{"a" => [""], "b" => ["abc", "def"]}
  # end

  test "trim strings" do
    params = %{"a" => "abc", "b" => " abc ", "c" => "abc ", "d" => " abc"}
    names = [:a, :b, :c, :d]

    result = SchemaHelper.trim_strings(params, names)
    assert result == %{"a" => "abc", "b" => "abc", "c" => "abc", "d" => "abc"}
  end

  test "parse checkboxes" do
    params = %{"a" => "true"}
    names = [:a, :b]

    result = SchemaHelper.parse_checkboxes(params, names)
    assert result == %{"a" => true, "b" => false}
  end
end
