defmodule Teiserver.Support.Tachyon.Matchmaking do
  @moduledoc """
  various utilities to setup or control matchmaking queues for testing
  """

  alias Teiserver.AssetFixtures
  alias Teiserver.Matchmaking.QueueServer

  def queue_attrs(overrides \\ %{}) do
    id = UUID.uuid4()
    map = id |> stg_attr() |> AssetFixtures.create_map()

    defaults = %{
      id: id,
      name: id,
      team_size: 1,
      team_count: 2,
      engines: ["spring", "recoil"],
      games: ["BAR test version", "BAR release version"],
      maps: [map]
    }

    Map.merge(defaults, overrides)
  end

  def start_queue, do: queue_attrs() |> start_queue()

  def start_queue(attrs) do
    initial_state =
      QueueServer.init_state(attrs)

    {:ok, pid} = QueueServer.start_link(initial_state)
    %{state: initial_state, id: attrs.id, pid: pid}
  end

  defp stg_attr(id),
    do: %{
      spring_name: "Supreme that glitters",
      display_name: "Supreme That Glitters",
      thumbnail_url: "https://www.beyondallreason.info/map/?!",
      matchmaking_queues: [id]
    }
end
