defmodule Teiserver.SpringOutTest do
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
end
