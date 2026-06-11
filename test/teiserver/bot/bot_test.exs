defmodule Teiserver.Bot.BotTest do
  alias Teiserver.Bot
  use Teiserver.DataCase, async: true

  test "can create bot" do
    {:ok, bot} = Bot.create_bot(%{name: "bot_test"})
    assert bot != nil
    assert Bot.get_by_id(bot.id) == bot
  end

  test "rejects name too short" do
    changeset = Bot.change_bot(%Bot.Bot{}, %{name: "a"})
    assert %{name: ["should be at least 3 character(s)"]} = errors_on(changeset)
  end

  test "rejects name too long" do
    changeset = Bot.change_bot(%Bot.Bot{}, %{name: String.duplicate("a", 40)})
    assert %{name: ["should be at most 30 character(s)"]} = errors_on(changeset)
  end
end
