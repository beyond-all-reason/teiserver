defmodule Teiserver.TachyonLobby.Events.AddSpectator do
  @moduledoc """
  Adding a brand new player to the lobby, as a spectator
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:spec]
  defstruct [:spec]

  @type t() :: %__MODULE__{
          spec: LT.Spectator.t()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.AddSpectator do
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.TachyonLobby.Events.AddSpectator
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%AddSpectator{} = ev, %LT.Aggregate{} = agg) do
    data =
      agg.data
      |> put_in([Access.key!(:spectators), ev.spec.id], ev.spec)
      |> update_in([Access.key!(:monitors)], &MC.monitor(&1, ev.spec.pid, {:user, ev.spec.id}))

    changes =
      agg.changes
      |> Map.put_new(:spectators, %{})
      |> put_in([:spectators, ev.spec.id], Map.take(ev.spec, [:join_queue_position]))

    %{agg | data: data, changes: changes}
  end
end
