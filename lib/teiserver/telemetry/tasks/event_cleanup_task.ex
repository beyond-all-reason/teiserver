defmodule Barserver.Telemetry.EventCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Barserver.Repo

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    days = Application.get_env(:teiserver, Barserver)[:retention][:telemetry_events]

    before_timestamp = Timex.shift(Timex.now(), days: -days)

    [
      "DELETE FROM telemetry_complex_client_events WHERE timestamp < $1",
      "DELETE FROM telemetry_complex_server_events WHERE timestamp < $1",
      # "DELETE FROM telemetry_complex_match_events WHERE timestamp < $1",
      "DELETE FROM telemetry_complex_anon_events WHERE timestamp < $1",
      "DELETE FROM telemetry_simple_client_events WHERE timestamp < $1",
      "DELETE FROM telemetry_simple_server_events WHERE timestamp < $1",
      # "DELETE FROM telemetry_simple_match_events WHERE timestamp < $1",
      "DELETE FROM telemetry_simple_anon_events WHERE timestamp < $1"
    ]
    |> Enum.each(fn query ->
      Ecto.Adapters.SQL.query!(Repo, query, [before_timestamp])
    end)

    :ok
  end
end
