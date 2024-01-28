defmodule BarserverWeb.API.BattleView do
  use BarserverWeb, :view

  def render("create.json", battle = %{outcome: :success}) do
    %{outcome: :success, lobby_id: battle.id}
  end

  def render("create.json", %{outcome: outcome, reason: reason}) do
    %{outcome: outcome, reason: reason}
  end
end
