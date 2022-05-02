defmodule Teiserver.Telemetry.InfologCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Teiserver.Telemetry

  @max_age_in_days 25

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    Telemetry.list_infologs(search: [inserted_before: Timex.now |> Timex.shift(days: -@max_age_in_days)])
    |> Enum.each(fn i ->
      Telemetry.delete_infolog(i)
    end)

    :ok
  end
end
