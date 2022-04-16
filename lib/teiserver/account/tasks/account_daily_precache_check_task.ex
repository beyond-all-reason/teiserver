defmodule Teiserver.Account.Tasks.DailyPrecacheCheckTask do
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]
  require Logger

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    # Did they login within the last 24 hours?
    recent_login = round(:erlang.system_time(:seconds) / 60) - (60 * 24)

    # Were they created within the last 24 hours
    recent_creation = date_to_str(Timex.now() |> Timex.shift(days: -1), format: :ymd_t_hms)

    # Everybody stops being pre_cached
    query = "UPDATE account_users SET pre_cache = false;"
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Now set the ones to be true that we want to be true
    query = """
      UPDATE account_users SET pre_cache = true
        WHERE data ->> 'bot' = 'true'
          or data ->> 'last_login' > '#{recent_login}'
          or inserted_at > '#{recent_creation}';
"""
    Ecto.Adapters.SQL.query(Repo, query, [])


    :ok
  end
end
