defmodule Central.General.ListHelperTest do
  use Central.DataCase, async: true
  alias Central.Helpers.ListHelper

  test "which_is_sublist" do
    params = [
      {[5, 10, 15], [10], :bsub},
      {[10], [5, 10, 15], :asub},
      {[15, 10], [10, 15], :eq},
      {[15, 5], [10, 15], :neither}
    ]

    for {lista, listb, expected} <- params do
      result = ListHelper.which_is_sublist(lista, listb)
      assert result == expected
    end
  end
end
