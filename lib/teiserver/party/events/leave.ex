defmodule Teiserver.Party.Events.Leave do
  @moduledoc """
  leave the party
  """
  alias Teiserver.Account.User

  @enforce_keys [:leaver_id]
  defstruct [:leaver_id]

  @type t() :: %__MODULE__{
          leaver_id: User.id()
        }
end

defimpl Teiserver.Party.Event, for: Teiserver.Party.Events.Leave do
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.Party.Events.Leave
  alias Teiserver.Party.Types.Aggregate
  import Access, only: [key!: 1]

  def apply_event(%Leave{} = ev, %Aggregate{} = agg) do
    case Map.pop(agg.data.members, ev.leaver_id) do
      {nil, _members} ->
        agg

      {_member, rest} when map_size(rest) == 0 ->
        put_in(agg.data.members, %{})

      {_member, new_members} ->
        new_aggregate =
          agg
          |> Aggregate.put_in_data([key!(:members)], new_members)
          |> Aggregate.update_in_data([key!(:monitors)], &MC.demonitor_by_val(&1, ev.leaver_id))
          |> Aggregate.add_side_effect(:notify_updated)

        new_aggregate
    end
  end
end
