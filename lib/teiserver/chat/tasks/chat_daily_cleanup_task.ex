defmodule Teiserver.Chat.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    before_timestamp = Timex.shift(Timex.now(), days: -14)
      |> date_to_str(format: :ymd_hms)

    query = """
      DELETE FROM teiserver_room_messages
      WHERE inserted_at < #{before_timestamp}
"""
    Ecto.Adapters.SQL.query(Repo, query, [])

    query = """
      DELETE FROM teiserver_lobby_messages
      WHERE inserted_at < #{before_timestamp}
"""
    Ecto.Adapters.SQL.query(Repo, query, [])

    # Chat.list_room_messages(search: [
    #   inserted_before: Timex.shift(Timex.now(), days: -14),
    # ])
    # |> Enum.each(fn chat ->
    #   Chat.delete_room_message(chat)
    # end)

    # Chat.list_lobby_messages(search: [
    #   inserted_before: Timex.shift(Timex.now(), days: -14),
    # ])
    # |> Enum.each(fn chat ->
    #   Chat.delete_lobby_message(chat)
    # end)

    :ok
  end
end
