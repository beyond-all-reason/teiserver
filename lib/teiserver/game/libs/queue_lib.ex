defmodule Teiserver.Game.QueueLib do
  use TeiserverWeb, :library
  alias Teiserver.Game.Queue

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-list-alt"

  @spec colours :: atom
  def colours, do: :primary2

  @spec make_favourite(Queue.t()) :: map()
  def make_favourite(queue) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),
      item_id: queue.id,
      item_type: "teiserver_game_queue",
      item_colour: queue.colour,
      item_icon: queue.icon,
      item_label: "#{queue.name}",
      url: "/teiserver/admin/queues/#{queue.id}"
    }
  end

  # Queries
  @spec query_queues() :: Ecto.Query.t()
  def query_queues do
    from(queues in Queue)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom, any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from queues in query,
      where: queues.id == ^id
  end

  def _search(query, :name, name) do
    from queues in query,
      where: queues.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from queues in query,
      where: queues.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from queues in query,
      where: ilike(queues.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from queues in query,
      order_by: [asc: queues.name]
  end

  def order_by(query, "Name (Z-A)") do
    from queues in query,
      order_by: [desc: queues.name]
  end

  def order_by(query, "Newest first") do
    from queues in query,
      order_by: [desc: queues.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from queues in query,
      order_by: [asc: queues.inserted_at]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from queues in query,
  #     left_join: things in assoc(queues, :things),
  #     preload: [things: things]
  # end
end
