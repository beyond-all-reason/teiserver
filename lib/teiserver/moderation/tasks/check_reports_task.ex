defmodule Teiserver.Moderation.CheckReportsTask do
  @moduledoc false
  use Oban.Worker, queue: :teiserver
  require Logger

  alias Teiserver.Moderation

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(%{args: %{user_id: user_id}} = _job) do
    report_list = Moderation.list_reports(
      search: [
        target_id: user_id,
        no_result: true
      ],
      preload: [:reporter]
    )

    analyse_reports(report_list)

    :ok
  end

  @spec new_report(any) :: {:error, any} | {:ok, Oban.Job.t()}
  def new_report(user_id) do
    %{user_id: user_id}
      |> Teiserver.Moderation.CheckReportsTask.new()
      |> Oban.insert()
  end

  defp analyse_reports(report_list) do
    IO.puts ""
    IO.inspect report_list
    IO.puts ""

    types = report_list
      |> Enum.group_by(fn r ->
        r.type
      end)

    type_scores = types
      |> Map.new(fn {type, reports} -> {type, Enum.count(reports)} end)

    IO.puts ""
    IO.inspect type_count
    IO.puts ""

  end

  # Teiserver.Moderation.CheckReportsTask.perform(%{args: %{user_id: 2}})
end
