defmodule TeiserverWeb.API.BattleView do
  use TeiserverWeb, :view

  def render("create.json", %{outcome: :success} = battle) do
    %{outcome: :success, lobby_id: battle.id}
  end

  def render("create.json", %{outcome: outcome, reason: reason}) do
    %{outcome: outcome, reason: reason}
  end
end
