defmodule TeiserverWeb.Live.Moderation.ActionLive.SmurfLinkTest do
  alias Teiserver.Account
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest

  describe "SmurfLink" do
    setup [:auth]

    test "searches and links", %{conn: conn} do
      origin = GeneralTestLib.make_user(%{"name" => "origin_user-testname"})
      smurf = GeneralTestLib.make_user(%{"name" => "smurf_user-testname"})

      {:ok, view, html} = live(conn, ~p"/moderation/actions/smurf_link/#{smurf.id}")

      assert html =~ "Marking <strong>#{smurf.name}</strong> as a smurf of:"
      assert_no_results(view)

      # Click the search button
      view
      |> element(~s{.user-picker-search-button})
      |> render_click()

      # Type into the box, result table should show up
      view
      |> element(~s{input.user-picker-search-input})
      |> render_keyup(%{value: "_user-testname"})

      # Even though our user is going to be a name match it should not
      # show up
      refute view
             |> element(~s{div[phx-value-user_id="#{smurf.id}"]})
             |> has_element?()

      # Time to select the origin user
      assert view
             |> element(~s{div[phx-value-user_id="#{origin.id}"]})
             |> render_click()

      # Selection row should now be gone
      refute view
             |> element(~s{div[phx-value-user_id="#{origin.id}"]})
             |> has_element?()

      text_field_html =
        view
        |> element(~s{input[type="text"][name="none"]})
        |> render()

      assert text_field_html ==
               ~s(<input type="text" name="none" value="##{origin.id} - origin_user-testname" class="w-full input" placeholder="Click green button to search"/>)

      hidden_field_html =
        view
        |> element(~s{input[type="hidden"][name="smurf_user_id"]})
        |> render()

      assert hidden_field_html ==
               ~s(<input type="hidden" name="smurf_user_id" id="smurf_user_id" value="#{origin.id}" class="w-full input form-control"/>)

      # Now submit the form
      assert view
             |> form("#smurf-link-form", %{smurf_user_id: origin.id})
             |> render_submit()

      origin = Account.get_user!(origin.id)
      smurf = Account.get_user!(smurf.id)

      assert is_nil(origin.smurf_of_id)
      assert smurf.smurf_of_id == origin.id
    end
  end

  defp assert_no_results(view) do
    refute view
           |> element(~s{.user-picker-search-results})
           |> has_element?()
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
