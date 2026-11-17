defmodule Teiserver.TachyonLobby.Events.StartBattle do
  @moduledoc """
  Battle started
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:battle]
  defstruct [:battle]

  @type t() :: %__MODULE__{
          battle: LT.CurrentBattle.t()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.StartBattle do
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonLobby.Events.StartBattle
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%StartBattle{battle: battle}, %LT.Aggregate{} = agg) do
    data =
      %{agg.data | current_battle: battle}
      |> Map.update!(:monitors, &MC.monitor(&1, battle.pid, :current_battle))

    changes = Map.put(agg.changes, :current_battle, battle)

    overview_changes =
      Map.put(agg.overview_changes, :current_battle, %{started_at: battle.started_at})

    %{agg | data: data, changes: changes, overview_changes: overview_changes}
    |> LT.Aggregate.add_log("battle_start")
  end
end
