defmodule Teiserver.Chat.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
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

    :ok
  end
end
