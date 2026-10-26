defmodule Teiserver.SpringOutTest do
  alias Teiserver.Account
  alias Teiserver.Client
  alias Teiserver.Config
  alias Teiserver.Coordinator
  alias Teiserver.Coordinator.CoordinatorServer
  alias Teiserver.Moderation
  alias Teiserver.Protocols.SpringOut
  alias Teiserver.TeiserverTestLib

  use Teiserver.DataCase, async: false

  setup do
    sender = TeiserverTestLib.new_user()
    state = TeiserverTestLib.mock_async_state()
    {:ok, sender: sender, state: state}
  end

  test "direct message strings emit a prefixed line for every newline", %{
    sender: sender,
    state: state
  } do
    for newline <- ["\n", "\r\n", "\r", "\u0085", "\u2028", "\u2029"] do
      message = "First reason#{newline}Second reason"

      expected =
        "SAIDPRIVATE #{sender.name} First reason\nSAIDPRIVATE #{sender.name} Second reason\n"

      assert SpringOut.reply(:direct_message, {sender.id, message, state.user}, nil, state) ==
               state

      assert_receive ^expected
    end
  end

  test "direct message lists split embedded newlines and preserve message order", %{
    sender: sender,
    state: state
  } do
    messages = [
      "Moderation reminder:",
      " - First reason\nSecond reason, expires 2026-10-27 12:00:00",
      "Please acknowledge."
    ]

    expected =
      "SAIDPRIVATE #{sender.name} Moderation reminder:\n" <>
        "SAIDPRIVATE #{sender.name}  - First reason\n" <>
        "SAIDPRIVATE #{sender.name} Second reason, expires 2026-10-27 12:00:00\n" <>
        "SAIDPRIVATE #{sender.name} Please acknowledge.\n"

    SpringOut.reply(:direct_message, {sender.id, messages, state.user}, nil, state)
    assert_receive ^expected
  end

  test "direct messages preserve Unicode text and blank lines", %{sender: sender, state: state} do
    message = "Polish: \u0105\r\n\r\nCyrillic: \u0445\n"

    expected =
      "SAIDPRIVATE #{sender.name} Polish: \u0105\n" <>
        "SAIDPRIVATE #{sender.name} \n" <>
        "SAIDPRIVATE #{sender.name} Cyrillic: \u0445\n" <>
        "SAIDPRIVATE #{sender.name} \n"

    SpringOut.reply(:direct_message, {sender.id, message, state.user}, nil, state)
    assert_receive ^expected
    assert String.valid?(expected)
  end

  test "single-line and empty direct messages keep their existing output", %{
    sender: sender,
    state: state
  } do
    for message <- ["Please follow the rules", "Polish: \u0105, Cyrillic: \u0445", ""] do
      expected = "SAIDPRIVATE #{sender.name} #{message}\n"
      SpringOut.reply(:direct_message, {sender.id, message, state.user}, nil, state)
      assert_receive ^expected
    end
  end

  test "Coordinator warning reminders serialize reasons, dispute text, and acknowledgement", %{
    state: state
  } do
    TeiserverTestLib.start_coordinator!()
    user = Account.recache_user(%{state.user | restrictions: ["Warning reminder"]})
    Client.login(user, :test, "127.0.0.1")

    {:ok, _action} =
      Moderation.create_action(%{
        target_id: user.id,
        reason: "First reason\nSecond reason",
        restrictions: ["Warning reminder"],
        expires: DateTime.add(DateTime.utc_now(), 86_400)
      })

    Phoenix.PubSub.subscribe(Teiserver.PubSub, "legacy_user_updates:#{user.id}")
    coordinator_id = Coordinator.get_coordinator_userid()

    header =
      "This is a reminder that you received one or more formal moderation actions as listed below:"

    assert {:noreply, %{}} =
             CoordinatorServer.handle_info({:do_client_inout, :login, user.id}, %{})

    assert_receive {:direct_message, ^coordinator_id, [^header | _remaining_messages] = messages}
    assert Enum.all?(messages, &is_binary/1)
    assert Client.get_client_by_id(user.id).awaiting_warn_ack

    SpringOut.reply(:direct_message, {coordinator_id, messages, user}, nil, state)
    assert_receive output when is_binary(output)

    coordinator_name = Account.get_username_by_id(coordinator_id)
    prefix = "SAIDPRIVATE #{coordinator_name} "
    lines = String.split(output, "\n", trim: true)
    assert Enum.all?(lines, &String.starts_with?(&1, prefix))
    assert (prefix <> " - First reason") in lines
    assert Enum.any?(lines, &String.starts_with?(&1, prefix <> "Second reason, expires "))
    assert Enum.any?(lines, &String.starts_with?(&1, prefix <> "If you feel"))
    assert Enum.any?(lines, &String.starts_with?(&1, prefix <> "Attempting to circumvent"))

    assert List.last(lines) ==
             prefix <> Config.get_site_config_cache("teiserver.Warning acknowledge prompt")
  end
end
