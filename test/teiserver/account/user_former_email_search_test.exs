defmodule Teiserver.Account.UserFormerEmailSearchTest do
  @moduledoc false
  alias Ecto.Changeset
  alias Teiserver.Account
  alias Teiserver.Account.UserQueries
  alias Teiserver.AccountFixtures
  alias Teiserver.Repo

  use Teiserver.DataCase, async: true

  defp user_with_history(previous, changed_days_ago) do
    user = AccountFixtures.user_fixture()

    changed_at =
      DateTime.utc_now()
      |> DateTime.add(-changed_days_ago * 86_400)
      |> DateTime.truncate(:second)

    {:ok, user} =
      user
      |> Changeset.change(previous_emails: previous, email_last_changed_at: changed_at)
      |> Repo.update()

    user
  end

  defp ids(query), do: query |> Repo.all() |> Enum.map(& &1.id)

  test "email like only matches current email without options" do
    u = user_with_history(["old-#{System.unique_integer([:positive])}@example.com"], 1)
    [old | _tail] = u.previous_emails

    assert ids(UserQueries.users() |> UserQueries.where_email_like(old, [])) == []
  end

  test "recent option matches latest former email within 30 days only" do
    recent = user_with_history(["recent-a1@old.example", "ancient-a1@old.example"], 5)
    stale = user_with_history(["recent-b2@old.example"], 60)

    q = fn term -> UserQueries.users() |> UserQueries.where_email_like(term, recent: true) end
    assert recent.id in ids(q.("recent-a1"))
    refute recent.id in ids(q.("ancient-a1"))
    refute stale.id in ids(q.("recent-b2"))
  end

  test "all_former option matches any former email" do
    u = user_with_history(["first-c3@old.example", "second-c3@old.example"], 90)

    for term <- ["first-c3", "second-c3"] do
      q = UserQueries.users() |> UserQueries.where_name_or_email_like(term, all_former: true)
      assert u.id in ids(q)
    end
  end

  test "exact name_or_email_with_former" do
    u = user_with_history(["exact-d4@old.example"], 90)

    assert u.id in (Account.list_users(
                      search: [
                        name_or_email_with_former: {"exact-d4@old.example", all_former: true}
                      ]
                    )
                    |> Enum.map(& &1.id))

    assert Account.list_users(
             search: [name_or_email_with_former: {"exact-d4@old.example", all_former: false}]
           ) == []
  end

  test "recent option works in name_or_email_like and exact mode" do
    u = user_with_history(["recent-e5@old.example"], 3)
    stale = user_with_history(["recent-f6@old.example"], 45)

    like = fn term ->
      UserQueries.users() |> UserQueries.where_name_or_email_like(term, recent: true) |> ids()
    end

    exact = fn term ->
      Account.list_users(search: [name_or_email_with_former: {term, [recent: true]}])
      |> Enum.map(& &1.id)
    end

    assert u.id in like.("recent-e5")
    refute stale.id in like.("recent-f6")
    assert u.id in exact.("recent-e5@old.example")
    refute stale.id in exact.("recent-f6@old.example")
  end

  test "30 day boundary for recent option" do
    inside = user_with_history(["edge-g7@old.example"], 29)
    outside = user_with_history(["edge-g7b@old.example"], 31)

    found =
      UserQueries.users() |> UserQueries.where_email_like("edge-g7", recent: true) |> ids()

    assert inside.id in found
    refute outside.id in found
  end

  test "current email still matches when former email options are on" do
    u = user_with_history(["whatever-h8@old.example"], 1)

    for opts <- [[], [recent: true], [all_former: true], [recent: true, all_former: true]] do
      assert u.id in ids(UserQueries.users() |> UserQueries.where_email_like(u.email, opts))

      assert u.id in ids(
               UserQueries.users()
               |> UserQueries.where_name_or_email_like(u.name, opts)
             )

      assert u.id in (Account.list_users(search: [name_or_email_with_former: {u.email, opts}])
                      |> Enum.map(& &1.id))
    end
  end

  test "NULL previous_emails and NULL email_last_changed_at do not break or hide matches" do
    user = AccountFixtures.user_fixture()

    {:ok, user} =
      user
      |> Changeset.change(previous_emails: nil, email_last_changed_at: nil)
      |> Repo.update()

    opts = [recent: true, all_former: true]

    assert user.id in ids(UserQueries.users() |> UserQueries.where_email_like(user.email, opts))
    refute user.id in ids(UserQueries.users() |> UserQueries.where_email_like("nope-i9", opts))

    # recent on its own with a NULL change timestamp but a populated list
    {:ok, user} =
      user
      |> Changeset.change(previous_emails: ["null-ts-j10@old.example"])
      |> Repo.update()

    refute user.id in ids(
             UserQueries.users()
             |> UserQueries.where_email_like("null-ts-j10", recent: true)
           )
  end

  test "count_users uses the former email filter" do
    u = user_with_history(["count-k11@old.example"], 90)

    assert Account.count_users(
             search: [name_or_email_with_former: {"count-k11@old.example", [all_former: true]}]
           ) == 1

    assert Account.count_users(
             search: [name_or_email_with_former: {"count-k11@old.example", [all_former: false]}]
           ) == 0

    assert u.id
  end
end
