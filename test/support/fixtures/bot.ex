defmodule Teiserver.BotFixtures do
  alias Teiserver.Bot

  def create_bot() do
    name = for _ <- 1..20, into: "", do: <<Enum.random(?a..?z)>>
    create_bot(name)
  end

  def create_bot(name) do
    {:ok, bot} = Bot.create_bot(%{name: name})
    bot
  end
end
