defmodule Teiserver.Account.DataExpiryTaskTest do
  alias Teiserver.Account
  alias Teiserver.Account.DataExpiryTask
  alias Teiserver.AccountFixtures
  alias Teiserver.Coordinator.CoordinatorServer
  alias Teiserver.Moderation

  use Teiserver.DataCase, async: false

  @expired_datetime DateTime.utc_now() |> DateTime.shift(year: -1)

  @active_datetime DateTime.utc_now() |> DateTime.shift(year: 1)

  setup do
    CoordinatorServer.make_and_cache_coordinator_account()
    :ok
  end

  describe "Data expiry task" do
    test "no records to expire" do
      scope = Account.system_scope()
      user = AccountFixtures.user_fixture()

      {:ok, record} =
        Moderation.create_anti_abuse_record(
          %{
            user_id: user.id,
            expires_at: @active_datetime,
            clean: true,
            hashes: %{},
            notes: ""
          },
          scope
        )

      DataExpiryTask.perform(%{})

      # User not deleted
      assert Account.get_user_by_id(user.id)

      # Record not deleted
      assert Moderation.get_anti_abuse_record(record.id, scope)
    end

    test "correctly expire a record" do
      scope = Account.system_scope()
      user = AccountFixtures.user_fixture()

      {:ok, record} =
        Moderation.create_anti_abuse_record(
          %{
            user_id: user.id,
            expires_at: @expired_datetime,
            clean: true,
            hashes: %{},
            notes: ""
          },
          scope
        )

      DataExpiryTask.perform(%{})

      # User is deleted
      refute Account.get_user_by_id(user.id)

      # Record is deleted
      refute Moderation.get_anti_abuse_record(record.id, scope)
    end
  end
end
