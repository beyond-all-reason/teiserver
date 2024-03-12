defmodule Barserver.Admin.HourlyCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Barserver.Repo

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    Ecto.Adapters.SQL.query!(Repo, "DELETE FROM account_codes WHERE expires < $1", [Timex.now()])

    chat_log_cleanup()

    :ok
  end

  defp chat_log_cleanup() do
    days = Application.get_env(:teiserver, Barserver)[:retention][:room_chat]

    before_timestamp = Timex.shift(Timex.now(), days: -days)

    query = """
          DELETE FROM teiserver_room_messages
          WHERE inserted_at < $1
    """

    Ecto.Adapters.SQL.query!(Repo, query, [before_timestamp])

    days = Application.get_env(:teiserver, Barserver)[:retention][:lobby_chat]

    before_timestamp = Timex.shift(Timex.now(), days: -days)

    query = """
          DELETE FROM teiserver_lobby_messages
          WHERE inserted_at < $1
    """

    Ecto.Adapters.SQL.query!(Repo, query, [before_timestamp])
  end
end
