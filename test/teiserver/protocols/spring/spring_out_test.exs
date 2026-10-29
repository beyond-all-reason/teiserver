defmodule Teiserver.SpringOutTest do
  alias Teiserver.Account
  alias Teiserver.Client
  alias Teiserver.Config
  alias Teiserver.Coordinator
  alias Teiserver.Coordinator.CoordinatorServer
  alias Teiserver.Moderation
  alias Teiserver.Moderation.RefreshUserRestrictionsTask
  alias Teiserver.Protocols.SpringOut
  alias Teiserver.TeiserverTestLib

  use Teiserver.DataCase, async: false

  import Teiserver.Helper.DateHelper, only: [date_to_str: 2]

  setup do
    sender = TeiserverTestLib.new_user()
    state = TeiserverTestLib.mock_async_state()
    {:ok, sender: sender, state: state}
  end

  test "line breaks inside direct messages become separate SAIDPRIVATE lines", %{
    sender: sender,
    state: state
  } do
    for newline <- ["\n", "\r\n"] do
      messages = ["Reminder:", "First reason#{newline}Second reason"]

      expected =
        "SAIDPRIVATE #{sender.name} Reminder:\n" <>
          "SAIDPRIVATE #{sender.name} First reason\n" <>
          "SAIDPRIVATE #{sender.name} Second reason\n"

      SpringOut.reply(:direct_message, {sender.id, messages, state.user}, nil, state)
      assert_receive ^expected
    end
  end

  test "Coordinator warning reminders are sent in order with multiline reasons", %{
    state: state
  } do
    TeiserverTestLib.start_coordinator!()
    user = state.user

    {:ok, action} =
      Moderation.create_action(%{
        target_id: user.id,
        reason: "First reason\nSecond reason",
        restrictions: ["Warning reminder"],
        expires: DateTime.shift(DateTime.utc_now(), day: 1)
      })

    # Hooks are disabled in tests, so apply the restrictions the hook would normally apply.
    # The user is not logged in yet, so this does not trigger a reminder of its own.
    RefreshUserRestrictionsTask.refresh_user(user.id)

    user.id
    |> Account.get_user_by_id()
    |> Client.login(:test, "127.0.0.1")

    Phoenix.PubSub.subscribe(Teiserver.PubSub, "legacy_user_updates:#{user.id}")
    CoordinatorServer.handle_info({:do_client_inout, :login, user.id}, %{})

    coordinator_id = Coordinator.get_coordinator_userid()
    assert_receive {:direct_message, ^coordinator_id, messages}

    expected =
      [
        "This is a reminder that you received one or more formal moderation actions as listed below:",
        " - First reason",
        "Second reason, expires #{date_to_str(action.expires, format: :ymd_hms)}",
        "If you feel you have been the target of an erroneous or unjust moderation action please use the #open-ticket channel in our discord to appeal/dispute the action.",
        "Attempting to circumvent this moderation with a new account is not okay and can lead to suspension or banning.",
        Config.get_site_config_cache("teiserver.Warning acknowledge prompt")
      ]
      |> Enum.map_join(fn line ->
        "SAIDPRIVATE #{Account.get_username_by_id(coordinator_id)} #{line}\n"
      end)

    SpringOut.reply(:direct_message, {coordinator_id, messages, user}, nil, state)
    assert_receive ^expected
  end
end
