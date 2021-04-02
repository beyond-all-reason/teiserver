defmodule Teiserver.Game.QueueLib do
  @spec icon :: String.t()
  def icon, do: "fas fa-list-alt"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:info)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(queue) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),
      item_id: queue.id,
      item_type: "teiserver_queue",
      item_colour: queue.colour,
      item_icon: queue.icon,
      item_label: "#{queue.name}",
      url: "/teiserver/admin/queue/#{queue.id}"
    }
  end
end
