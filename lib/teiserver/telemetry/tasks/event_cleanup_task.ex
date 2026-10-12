defmodule Teiserver.Telemetry.EventCleanupTask do
  @moduledoc false

  alias Ecto.Adapters.SQL
  alias Teiserver.Repo

  use Oban.Worker, queue: :cleanup

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    days = Application.get_env(:teiserver, Teiserver)[:retention][:telemetry_events]

    before_timestamp = DateTime.shift(DateTime.utc_now(), day: -days)

    [
      "DELETE FROM telemetry_complex_client_events WHERE timestamp < $1",
      "DELETE FROM telemetry_complex_server_events WHERE timestamp < $1",
      "DELETE FROM telemetry_complex_anon_events WHERE timestamp < $1",
      "DELETE FROM telemetry_simple_client_events WHERE timestamp < $1",
      "DELETE FROM telemetry_simple_server_events WHERE timestamp < $1",
      "DELETE FROM telemetry_simple_anon_events WHERE timestamp < $1",

      # This currently has a timestamp, probably a copy-paste error
      # when the table was first created
      "DELETE FROM telemetry_complex_match_events WHERE timestamp < $1",

      # These do not have their own timestamp so instead we remove them based
      # on the age of the match itself
      "DELETE FROM telemetry_simple_match_events events
        USING teiserver_battle_matches matches
        WHERE events.match_id = matches.id
          AND matches.inserted_at < $1;"
    ]
    |> Enum.each(fn query ->
      SQL.query!(Repo, query, [before_timestamp])
    end)

    :ok
  end
end
