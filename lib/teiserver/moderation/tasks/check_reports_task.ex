defmodule Teiserver.Moderation.CheckReportsTask do
  @moduledoc false
  use Oban.Worker, queue: :teiserver
  require Logger

  alias Teiserver.Moderation

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(%{args: %{user_id: user_id}} = _job) do
    recent_reports = Moderation.list_reports(
      search: [
        target_id: user_id,
        no_result: true
      ],
      preload: [:reporter]
    )

    IO.puts ""
    IO.inspect recent_reports
    IO.puts ""

    :ok
  end

  @spec new_report(any) :: {:error, any} | {:ok, Oban.Job.t()}
  def new_report(user_id) do
    %{user_id: user_id}
      |> Teiserver.Moderation.CheckReportsTask.new()
      |> Oban.insert()
  end

  defp analyse_reports(report_list) do
    types = report_list

  end

  # Teiserver.Moderation.CheckReportsTask.perform(%{args: %{user_id: 2}})
end
