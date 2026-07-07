defmodule Teiserver.TachyonLobby.Events.MovePlayer do
  @moduledoc """
  Move a player from one team to another
  """

  alias Teiserver.Account.User
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:player_id, :team]
  defstruct [:player_id, :team]

  @type t() :: %__MODULE__{
          player_id: User.id(),
          team: LT.Types.team()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.MovePlayer do
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.MovePlayer
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%MovePlayer{} = ev, %LT.Aggregate{} = agg) do
    data = put_in(agg.data, [Access.key!(:players), ev.player_id, Access.key!(:team)], ev.team)

    changes =
      agg.changes
      |> Map.put_new(:players, %{})
      |> Map.update!(:players, fn players ->
        players
        |> Map.put_new(ev.player_id, %{})
        |> update_in([ev.player_id], fn p ->
          Map.merge(%{team: ev.team, ready?: false, asset_status: :complete}, p)
        end)
      end)

    new_aggregate = %{agg | data: data, changes: changes}
    Teiserver.TachyonLobby.Event.apply_event(%Events.RepackPlayers{}, new_aggregate)
  end
end
