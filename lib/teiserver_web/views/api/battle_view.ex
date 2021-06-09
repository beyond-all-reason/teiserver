defmodule TeiserverWeb.API.BattleView do
  use TeiserverWeb, :view

  def render("create.json", battle = %{outcome: :success}) do
    %{outcome: :success, guid: battle.guid}
  end

  def render("create.json", %{outcome: outcome, reason: reason}) do
    %{outcome: outcome, reason: reason}
  end
end
