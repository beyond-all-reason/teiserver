defmodule Teiserver.BattleLib do
  # Functions
  def icon, do: "far fa-swords"
  def colours, do: Central.Helpers.StylingHelper.colours(:primary2)

  def make_favourite(battle) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),

      item_id: battle.id,
      item_type: "teiserver_battle",
      item_colour: battle.colour,
      item_icon: battle.icon,
      item_label: "#{battle.name}",

      url: "/teiserver/battle/#{battle.id}"
    }
  end
end
