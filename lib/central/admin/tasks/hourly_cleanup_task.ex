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

    :ok
  end
end
