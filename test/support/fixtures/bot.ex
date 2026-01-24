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

  def start_script() do
    %{
      engine_version: "engineversion",
      game_name: "game name",
      map_name: "very map",
      start_pos_type: :fixed,
      ally_teams: [
        %{
          teams: [%{user_id: 123, name: "player name", password: "123"}]
        }
      ]
    }
  end
end
