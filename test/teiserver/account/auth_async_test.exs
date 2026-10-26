defmodule Teiserver.Account.AuthAsyncTest do
  alias Teiserver.Account.RoleLib

  use Teiserver.DataCase, async: true

  import Teiserver.Account.AuthLib, only: [allow?: 2]

  describe "role permissions" do
    test "Server Role" do
      user = %{id: 123, roles: ["Server"]}

      assert allow?(user, "Server")
      assert allow?(user, "Admin")
      assert allow?(user, "Technician")
      assert allow?(user, "Senior moderator")
      assert allow?(user, "Moderator")
      assert allow?(user, "Overwatch")
      assert allow?(user, "Contributor")
      assert allow?(user, "BAR+")
      assert allow?(user, "VIP")
      assert allow?(user, "Trusted")

      # Normally not allowed but server has automatic allowed access
      assert allow?(user, "NotARole")
    end

    test "Admin Role" do
      user = %{id: 123, roles: ["Admin"]}

      refute allow?(user, "Server")
      assert allow?(user, "Admin")
      assert allow?(user, "Technician")
      assert allow?(user, "Senior moderator")
      assert allow?(user, "Moderator")
      assert allow?(user, "Overwatch")
      assert allow?(user, "Contributor")
      assert allow?(user, "BAR+")
      assert allow?(user, "VIP")
      assert allow?(user, "Trusted")

      refute allow?(user, "NotARole")
    end

    test "Moderator Role" do
      user = %{id: 123, roles: ["Moderator"]}

      refute allow?(user, "Server")
      refute allow?(user, "Admin")
      refute allow?(user, "Technician")
      refute allow?(user, "Senior moderator")
      assert allow?(user, "Moderator")
      assert allow?(user, "Overwatch")
      assert allow?(user, "Contributor")
      assert allow?(user, "BAR+")
      assert allow?(user, "VIP")
      assert allow?(user, "Trusted")

      refute allow?(user, "NotARole")
    end

    test "Technician Role" do
      user = %{id: 123, roles: ["Technician"]}

      assert allow?(user, "Technician")

      for role <- ["Server", "Admin", "Moderator", "Contributor", "Engine"] do
        refute allow?(user, role)
      end
    end

    test "Technician is selectable in the staff group and managed by admins" do
      role = RoleLib.role_data("Technician")

      assert role in RoleLib.grouped_role_data()[:staff]
      assert role.edit_permission == "Admin"
      assert role.contains == []
    end
  end
end
