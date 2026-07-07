defmodule TeiserverWeb.LiveComponents.UserPickerTest do
  alias Phoenix.Component
  alias TeiserverWeb.LiveComponents.UserPicker

  use TeiserverWeb.ConnCase, async: true

  describe "TeiserverWeb.LiveComponents.UserPicker" do
    test "render without form" do
      form = Component.to_form(%{"smurf_user_id" => nil})

      html =
        render_component(UserPicker, %{
          id: "user-picker",
          field: form[:smurf_user_id],
          label: "User to link to:"
        })

      # Assert we have the hidden element and we don't have an error
      # raised rendering it in general
      assert html =~
               ~s(<input type="hidden" name="smurf_user_id" id="smurf_user_id" class="w-full input form-control">)
    end
  end
end
