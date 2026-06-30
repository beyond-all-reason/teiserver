defmodule Teiserver.TachyonLobby.Events.Kickban do
  @moduledoc """
  Kick a player from the lobby. May also add a ban duration.
  This also remove all the bots associated with the player
  """

  alias Teiserver.Account.User

  @enforce_keys [:user_id, :ban_until]
  defstruct [:user_id, :ban_until]

  @type t() :: %__MODULE__{
          user_id: User.id(),
          ban_until: DateTime.t()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.Kickban do
  alias Teiserver.TachyonLobby.Event
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.Kickban
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%Kickban{} = ev, %LT.Aggregate{} = agg) do
    effective_ban_until =
      case ev.ban_until do
        nil -> nil
        dt -> if DateTime.compare(dt, DateTime.utc_now()) == :gt, do: dt, else: nil
      end

    target_pid =
      get_in(agg.data.players[ev.user_id].pid) || get_in(agg.data.spectators[ev.user_id].pid)

    agg =
      case effective_ban_until do
        nil ->
          agg

        dt ->
          ms = DateTime.diff(dt, DateTime.utc_now(), :millisecond)
          data = put_in(agg.data, [Access.key!(:banned_users), ev.user_id], dt)

          effects =
            if ms > 0,
              do: [{:send_after, ms, {:ban_expired, ev.user_id}} | agg.side_effects],
              else: []

          %{agg | data: data, side_effects: effects}
      end

    agg =
      if is_map_key(agg.data.players, ev.user_id) do
        Event.apply_event(%Events.RemovePlayerFromLobby{player_id: ev.user_id}, agg)
      else
        Event.apply_event(%Events.RemoveSpecFromLobby{user_id: ev.user_id}, agg)
      end

    effects =
      if target_pid do
        reason = if effective_ban_until != nil, do: "banned", else: "kicked"
        message = {:lobby, agg.data.id, {:left, reason, effective_ban_until}}
        effect = {:send_to_user, target_pid, message}
        [effect | agg.side_effects]
      else
        agg.side_effects
      end

    %{agg | side_effects: effects}
  end
end
