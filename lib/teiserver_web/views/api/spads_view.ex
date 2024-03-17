defmodule TeiserverWeb.API.SpadsView do
  use TeiserverWeb, :view
  import Teiserver.Helper.NumberHelper, only: [round: 2]

  def render("rating.json", assigns) do
    %{
      rating_value: assigns.rating_value |> round(2),
      uncertainty: assigns.uncertainty |> round(2)
    }
  end

  def render("empty.json", _assigns) do
    %{}
  end

  def render("balance_battle.json", assigns) do
    %{
      unbalance_indicator: assigns.deviation,
      player_assign_hash: assigns.players,
      bot_assign_hash: assigns.bots
    }
  end
end
