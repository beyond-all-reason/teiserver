defmodule Teiserver.Account.AuthAsyncTest do
  use Teiserver.DataCase, async: true

  import Teiserver.Account.AuthLib, only: [allow?: 2]

  describe "role permissions" do
    test "Server Role" do
      user = %{id: 123, roles: ["Server"]}

      assert allow?(user, "Server")
      assert allow?(user, "Admin")
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
      refute allow?(user, "Senior moderator")
      assert allow?(user, "Moderator")
      assert allow?(user, "Overwatch")
      assert allow?(user, "Contributor")
      assert allow?(user, "BAR+")
      assert allow?(user, "VIP")
      assert allow?(user, "Trusted")

      refute allow?(user, "NotARole")
    end
  end
end
