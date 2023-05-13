defmodule Teiserver.Account.NewUserFunnelReport do
  alias Teiserver.{Account, Telemetry, Battle}

  @spec icon() :: String.t()
  def icon(), do: "fa-regular fa-filter"

  @spec permissions() :: String.t()
  def permissions(), do: "Admin"

  @spec run(Plug.Conn.t(), map()) :: {map(), map()}
  def run(_conn, _params) do
    start_date =
      Timex.today()
      |> Timex.shift(days: -14)
      |> Timex.to_datetime()

    # Get accounts registered in this timeframe, they are our population for this report
    accounts =
      Account.list_users(
        search: [
          inserted_after: start_date
        ],
        limit: :infinity
      )

    total_count = Enum.count(accounts)

    # Verified
    verified_userids =
      accounts
      |> Enum.filter(fn %{data: data} -> data["verified"] == true end)
      |> Enum.map(fn %{id: id} -> id end)

    verified = Enum.count(verified_userids)

    # Singleplayer
    event_type_ids = [
      Telemetry.get_or_add_event_type("game_start:singleplayer:lone_other_skirmish"),
      Telemetry.get_or_add_event_type("game_start:singleplayer:scenario_start")
    ]

    events =
      Telemetry.list_client_events(
        search: [
          event_type_id_in: event_type_ids,
          user_id_in: verified_userids
        ],
        limit: :infinity,
        select: [:user_id]
      )
      |> Enum.map(fn %{user_id: user_id} -> user_id end)
      |> Enum.uniq()

    single_player_telemetry = Enum.count(events)

    # Online
    event_type_ids = [
      Telemetry.get_or_add_event_type("game_start:multiplayer:connecting"),
      Telemetry.get_or_add_event_type("lobby:multiplayer:hostgame")
    ]

    events =
      Telemetry.list_client_events(
        search: [
          event_type_id_in: event_type_ids,
          user_id_in: verified_userids
        ],
        limit: :infinity,
        select: [:user_id]
      )
      |> Enum.map(fn %{user_id: user_id} -> user_id end)
      |> Enum.uniq()

    online_player_telemetry = Enum.count(events)

    # Online but DB based
    match_memberships =
      Battle.list_match_memberships(
        search: [
          user_id_in: verified_userids
        ],
        limit: :infinity,
        select: [:user_id]
      )
      |> Enum.map(fn %{user_id: user_id} -> user_id end)
      |> Enum.uniq()

    online_player_db = Enum.count(match_memberships)

    assigns = %{}

    {%{
       total_count: total_count,
       verified: verified,
       single_player_telemetry: single_player_telemetry,
       online_player_telemetry: online_player_telemetry,
       online_player_db: online_player_db
     }, assigns}
  end
end
