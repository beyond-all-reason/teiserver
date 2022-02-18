defmodule Teiserver.Account.Tasks.DailyPrecacheCheckTask do
  use Oban.Worker, queue: :cleanup

  alias Central.Repo
  alias Teiserver.{Account}
  require Logger

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    # Did they login within the last 24 hours?
    recent_login = round(:erlang.system_time(:seconds) / 60) - (60 * 24)

    sql_id_list = Account.list_users(
      search: [
        pre_cache: true,
        inserted_before: Timex.shift(Timex.now(), days: -1),
      ],
      limit: :infinity
    )
    |> Stream.filter(fn user ->
      cond do
        user.data["bot"] -> false
        user.data["last_login"] > recent_login -> false
        true -> true
      end
    end)
    |> Stream.map(fn user -> user.id end)
    |> Enum.join(",")

    query = "UPDATE account_users SET pre_cache = false WHERE id IN (#{sql_id_list});"
    Ecto.Adapters.SQL.query(Repo, query, [])

    :ok
  end
end
