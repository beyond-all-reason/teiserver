defmodule TeiserverWeb.LiveComponents.UserPickerTest do
  alias TeiserverWeb.LiveComponents.UserPicker

  use TeiserverWeb.ConnCase, async: true

  describe "TeiserverWeb.LiveComponents.UserPicker" do
    test "render without form" do
      html =
        render_component(UserPicker, %{
          id: "user-picker",
          name: "user-picker",
          label: "User search",
          value: nil
        })

      assert html =~
               ~s(<input type="text" name="user-picker" id="user-picker" class="w-full input form-control" disabled="disabled" placeholder="">)

      refute html =~ ~s(id="user-picker-search")
    end
  end
end
