defmodule Teiserver.Game.PartyLib do
  @spec icon :: String.t()
  def icon, do: "fas fa-user-friends"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:info)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(party) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: party.id,
      item_type: "teiserver_party",
      item_colour: party.colour,
      item_icon: party.icon,
      item_label: "#{party.name}",
      url: "/teiserver/admin/party/#{party.id}"
    }
  end
end
