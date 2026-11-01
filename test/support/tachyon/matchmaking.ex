defmodule Teiserver.Support.Tachyon.Matchmaking do
  @moduledoc """
  various utilities to setup or control matchmaking queues for testing
  """

  alias Teiserver.Asset
  alias Teiserver.AssetFixtures
  alias Teiserver.Matchmaking
  alias Teiserver.Matchmaking.QueueServer
  alias Teiserver.Matchmaking.QueueSupervisor

  def queue_attrs(overrides \\ %{}) do
    id = UUID.uuid4()
    id |> stg_attr() |> AssetFixtures.create_map()
    ensure_mm_engine()
    ensure_mm_game()

    defaults = %{
      id: id,
      name: id,
      team_size: 1,
      team_count: 2,
      algo: :ignore_os
    }

    Map.merge(defaults, overrides)
  end

  defp ensure_mm_engine do
    case Asset.get_engine(in_matchmaking: true) do
      nil -> AssetFixtures.create_engine(%{name: "recoil-xxx", in_matchmaking: true})
      e -> e
    end
  end

  defp ensure_mm_game do
    case Asset.get_game(in_matchmaking: true) do
      nil -> AssetFixtures.create_game(%{name: "bar test version", in_matchmaking: true})
      e -> e
    end
  end

  def start_queue, do: queue_attrs() |> start_queue()

  def start_queue(attrs) do
    initial_state =
      QueueServer.init_state(attrs)

    {:ok, pid} = QueueSupervisor.start_queue!(initial_state)

    {_q_id, queue_data} =
      Enum.find(Matchmaking.list_queues(), fn {q_id, _data} -> q_id == initial_state.id end)

    %{
      state: initial_state,
      id: attrs.id,
      version: queue_data.version,
      pid: pid,
      attrs: attrs
    }
  end

  defp stg_attr(id),
    do: %{
      spring_name: "Supreme that glitters #{id}",
      display_name: "Supreme That Glitters",
      thumbnail_url: "https://www.beyondallreason.info/map/?!",
      matchmaking_queues: [id]
    }

  defdelegate match_players(queue_pid), to: QueueServer
end
