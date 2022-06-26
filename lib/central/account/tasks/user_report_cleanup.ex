defmodule Central.Account.UserReportCleanupTask do
  @moduledoc false
  use Oban.Worker, queue: :cleanup

  alias Central.Account

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(_) do
    datetime = Timex.now() |> Timex.shift(days: -21)

    params = %{
      "response_action" => "Report expired",
      "expires" => "never",
      "responder_id" => 1,
      "followup" => "",
      "code_references" => [],
      "action_data" => %{"restriction_list" => []},
      "responded_at" => Timex.now(),
    }

    # Clean up all unanswered reports after a certain period of time
    Account.list_reports(
      search: [
        filter: "open",
        inserted_before: datetime
      ]
    )
    |> Enum.each(fn report ->
      Account.update_report(report, params, :respond)
    end)

    :ok
  end
end
