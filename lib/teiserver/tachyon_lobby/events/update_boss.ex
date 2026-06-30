defmodule Teiserver.TachyonLobby.Events.UpdateBoss do
  @moduledoc """
  Add or remove boss
  """

  alias Teiserver.Account.User

  @enforce_keys [:action, :appointee_id]
  defstruct [:action, :appointee_id]

  @type t() :: %__MODULE__{
          action: :add | :remove,
          appointee_id: User.id()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.UpdateBoss do
  alias Teiserver.TachyonLobby.Events.UpdateBoss
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%UpdateBoss{} = ev, %LT.Aggregate{} = agg) do
    boss? = MapSet.member?(agg.data.bosses, ev.appointee_id)

    cond do
      ev.action == :add and boss? -> agg
      ev.action == :remove and not boss? -> agg
      true -> do_apply_event(ev, agg)
    end
  end

  defp do_apply_event(%UpdateBoss{} = ev, %LT.Aggregate{} = agg) do
    data =
      case ev.action do
        :add ->
          %{agg.data | bosses: MapSet.put(agg.data.bosses, ev.appointee_id)}

        :remove ->
          %{agg.data | bosses: MapSet.delete(agg.data.bosses, ev.appointee_id)}
      end

    changes = agg.changes |> Map.put_new(:bosses, %{})

    changes =
      case ev.action do
        :add -> put_in(changes.bosses[ev.appointee_id], %{})
        :remove -> put_in(changes.bosses[ev.appointee_id], nil)
      end

    %{agg | data: data, changes: changes}
  end
end
