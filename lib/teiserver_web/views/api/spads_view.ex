defmodule TeiserverWeb.API.SpadsView do
  use TeiserverWeb, :view
  import Central.Helpers.NumberHelper, only: [round: 2]

  def render("rating.json", assigns) do
    %{
      rating_value: assigns.rating_value |> round(2),
      uncertainty: assigns.uncertainty |> round(2)
    }
  end

  def render("balance_battle.json", _assigns) do
    %{
      unbalance_indicator: -1,
      player_assign_hash: %{},
      bot_assign_hash: %{}
    }
  end
end
