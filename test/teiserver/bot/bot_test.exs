defmodule Teiserver.Bot.BotTest do
  alias Teiserver.Bot
  use Teiserver.DataCase, async: true

  test "can create bot" do
    {:ok, bot} = Bot.create_bot(%{name: "bot_test"})
    assert bot != nil
    assert Bot.get_by_id(bot.id) == bot
  end
end
