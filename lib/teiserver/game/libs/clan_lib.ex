defmodule Teiserver.Game.ClanLib do
  @spec icon :: String.t()
  def icon, do: "far fa-globe"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:info)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(clan) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: clan.id,
      item_type: "teiserver_clan",
      item_colour: clan.colour,
      item_icon: clan.icon,
      item_label: "#{clan.name}",
      url: "/teiserver/admin/clan/#{clan.id}"
    }
  end
end
