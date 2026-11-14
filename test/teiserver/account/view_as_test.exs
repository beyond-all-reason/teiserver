defmodule Teiserver.Account.ViewAsTest do
  use Teiserver.DataCase, async: true

  alias Teiserver.Account.ViewAs
  alias Teiserver.AccountFixtures

  setup do
    admin = AccountFixtures.user_fixture(%{roles: ["Admin"]})
    other = AccountFixtures.user_fixture(%{roles: ["Moderator"]})
    {:ok, admin: admin, other: other}
  end

  test "admin can view as a lesser user", %{admin: admin, other: other} do
    assert ViewAs.can_view_as?(admin, other)
    assert {effective, real} = ViewAs.resolve(admin, to_string(other.id))
    assert effective.id == other.id
    assert real.id == admin.id
  end

  test "cannot view as self or as non-admin viewer", %{admin: admin, other: other} do
    refute ViewAs.can_view_as?(admin, admin)
    refute ViewAs.can_view_as?(other, admin)
    assert {^other, nil} = ViewAs.resolve(other, to_string(admin.id))
  end

  test "garbage session values are ignored", %{admin: admin} do
    assert {^admin, nil} = ViewAs.resolve(admin, "abc")
    assert {^admin, nil} = ViewAs.resolve(admin, nil)
  end

  test "denial_reason explains why viewing as is not allowed", %{admin: admin, other: other} do
    other_admin = AccountFixtures.user_fixture(%{roles: ["Admin"]})

    assert ViewAs.denial_reason(admin, other) == nil
    assert ViewAs.denial_reason(admin, admin) =~ "yourself"
    assert ViewAs.denial_reason(admin, other_admin) =~ "Admin permissions"
  end

  test "can_use? is only true for admins", %{admin: admin, other: other} do
    assert ViewAs.can_use?(admin)
    refute ViewAs.can_use?(other)
    refute ViewAs.can_use?(nil)
  end
end
