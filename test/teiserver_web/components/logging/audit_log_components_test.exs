defmodule TeiserverWeb.Components.Logging.AuditLogComponentsTest do
  alias TeiserverWeb.Components.Logging.AuditLogComponents

  use TeiserverWeb.ConnCase, async: true

  describe "AuditLogComponents.section_menu" do
    test "render" do
      html =
        render_component(&AuditLogComponents.section_menu/1, %{
          colour: "neutral",
          active: "index"
        })

      # The links we expect to see
      assert html =~ "/logging/audit"
      assert html =~ "/logging/audit/search"
    end
  end
end
