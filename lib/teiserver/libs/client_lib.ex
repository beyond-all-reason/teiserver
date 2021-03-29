defmodule Teiserver.ClientLib do
  # Functions
  @spec colours() :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:primary2)
  @spec icon() :: String.t()
  def icon, do: "far fa-plug"

  @spec make_favourite(Map.t()) :: Map.t()
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
