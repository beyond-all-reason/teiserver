defmodule Teiserver.Account.UserFormerEmailSearchTest do
  @moduledoc false
  alias Ecto.Changeset
  alias Teiserver.Account.UserQueries
  alias Teiserver.AccountFixtures
  alias Teiserver.Repo

  use Teiserver.DataCase, async: true

  setup do
    {:ok, user} =
      AccountFixtures.user_fixture()
      |> Changeset.change(previous_emails: ["former-address@example.com"])
      |> Repo.update()

    {:ok, user: user}
  end

  test "where_email_like matches former emails", %{user: user} do
    ids =
      UserQueries.users()
      |> UserQueries.where_email_like("former-address")
      |> Repo.all()
      |> Enum.map(& &1.id)

    assert ids == [user.id]
  end

  test "where_name_or_email_like matches former emails", %{user: user} do
    ids =
      UserQueries.users()
      |> UserQueries.where_name_or_email_like("FORMER-address")
      |> Repo.all()
      |> Enum.map(& &1.id)

    assert ids == [user.id]
  end
end
