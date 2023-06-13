defmodule Central.Admin.HourlyCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    before_timestamp = Timex.now()
      |> date_to_str(format: :ymd_hms)

    Ecto.Adapters.SQL.query(Repo, "DELETE FROM account_codes WHERE expires < '#{before_timestamp}'", [])

    chat_log_cleanup()

    :ok
  end

  defp chat_log_cleanup() do
    days = Application.get_env(:central, Teiserver)[:retention][:room_chat]

    before_timestamp =
      Timex.shift(Timex.now(), days: -days)
      |> date_to_str(format: :ymd_hms)

    query = """
          DELETE FROM teiserver_room_messages
          WHERE inserted_at < '#{before_timestamp}'
    """

    Ecto.Adapters.SQL.query(Repo, query, [])

    days = Application.get_env(:central, Teiserver)[:retention][:lobby_chat]

    before_timestamp =
      Timex.shift(Timex.now(), days: -days)
      |> date_to_str(format: :ymd_hms)

    query = """
          DELETE FROM teiserver_lobby_messages
          WHERE inserted_at < '#{before_timestamp}'
    """

    Ecto.Adapters.SQL.query(Repo, query, [])
  end
end
