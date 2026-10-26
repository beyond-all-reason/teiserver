defmodule Teiserver.Admin.HourlyCleanupTask do
  @moduledoc false

  alias Ecto.Adapters.SQL
  alias Teiserver.Repo

  use Oban.Worker, queue: :cleanup

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_job) do
    SQL.query!(Repo, "DELETE FROM account_codes WHERE expires < $1", [DateTime.utc_now()])

    chat_log_cleanup()

    :ok
  end

  defp chat_log_cleanup do
    chat_tables = [
      {"spring_room_messages", :room_chat},
      {"spring_lobby_messages", :lobby_chat},
      {"spring_direct_messages", :direct_messages},
      {"lobby_messages", :lobby_chat},
      {"direct_messages", :direct_messages},
      {"party_messages", :party_chat},
      {"battle_messages", :battle_chat}
    ]

    for {table, retention_key} <- chat_tables do
      before_timestamp =
        DateTime.shift(DateTime.utc_now(),
          day: -Application.get_env(:teiserver, Teiserver)[:retention][retention_key]
        )

      SQL.query!(Repo, "DELETE FROM #{table} WHERE inserted_at < $1", [before_timestamp])
    end
  end
end
