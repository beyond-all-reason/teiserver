defmodule Teiserver.Game.TournamentLib do
  @spec icon :: String.t()
  def icon, do: "fas fa-trophy"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:info)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(tournament) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: tournament.id,
      item_type: "teiserver_tournament",
      item_colour: tournament.colour,
      item_icon: tournament.icon,
      item_label: "#{tournament.name}",
      url: "/teiserver/admin/tournament/#{tournament.id}"
    }
  end
end
