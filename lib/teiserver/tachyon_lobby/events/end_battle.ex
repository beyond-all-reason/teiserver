defmodule Teiserver.TachyonLobby.Events.EndBattle do
  @moduledoc """
  Battle ended
  """

  defstruct []

  @type t() :: %__MODULE__{}
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.EndBattle do
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonLobby.Events.EndBattle
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%EndBattle{}, %LT.Aggregate{} = agg) do
    data =
      %{agg.data | current_battle: nil}
      |> Map.update!(:monitors, &MC.demonitor_by_val(&1, :current_battle, [:flush]))

    changes = Map.put(agg.changes, :current_battle, nil)
    overview_changes = Map.put(agg.overview_changes, :current_battle, nil)

    %{agg | data: data, changes: changes, overview_changes: overview_changes}
    |> LT.Aggregate.add_log("battle_end")
  end
end
