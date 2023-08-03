defmodule Teiserver.Account.Tasks.DailyCleanupTask do
  use Oban.Worker, queue: :cleanup
  alias Teiserver.Account

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    days = Application.get_env(:central, Teiserver)[:retention][:account_unverified]

    # Find all unverified users who registered over 14 days ago
    _id_list =
      Account.list_users(
        search: [
          verified: false,
          inserted_before: Timex.shift(Timex.now(), days: -days)
        ],
        select: [:id],
        limit: :infinity
      )
      |> Enum.map(fn %{id: userid} -> userid end)

    :ok
  end
end
