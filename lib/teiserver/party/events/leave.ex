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
  alias Teiserver.Party.Types, as: PT

  def apply_event(%Leave{} = ev, %PT.Aggregate{} = agg) do
    case Map.pop(agg.data.members, ev.leaver_id) do
      {nil, _members} ->
        agg

      {_member, rest} when map_size(rest) == 0 ->
        put_in(agg.data.members, %{})

      {_member, new_members} ->
        new_aggregate =
          agg
          |> put_in([Access.key!(:data), Access.key!(:members)], new_members)
          |> update_in(
            [Access.key!(:data), Access.key!(:monitors)],
            &MC.demonitor_by_val(&1, ev.leaver_id)
          )
          |> update_in([Access.key!(:side_effects)], fn side_effects ->
            side_effects ++ [:notify_updated]
          end)

        new_aggregate
    end
  end
end
