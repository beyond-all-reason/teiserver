defmodule Teiserver.Helpers.EnumHelper do
  @moduledoc """
  A set of helpers to extend Enum
  """

  @doc """
  Converts a pair of enumerables into MapSets and runs MapSet.intersection
  """
  def intersection(enum1, enum2) do
    set1 = MapSet.new(enum1)
    set2 = MapSet.new(enum2)

    MapSet.intersection(set1, set2)
  end

  @doc """
  Given two enumerables, do they have any intersections?
  """
  def intersects?(enum1, enum2) do
    result = intersection(enum1, enum2)
    not Enum.empty?(result)
  end
end
