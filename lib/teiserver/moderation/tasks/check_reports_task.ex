defmodule Teiserver.Moderation.CheckReportsTask do
  @moduledoc false
  use Oban.Worker, queue: :teiserver
  require Logger

  alias Teiserver.{Account, Moderation}

  @impl Oban.Worker
  @spec perform(any) :: :ok
  def perform(%{args: %{user_id: user_id}} = _job) do
    time_boundary = Timex.now() |> Timex.shift(days: -30)

    report_list =
      Moderation.list_reports(
        search: [
          target_id: user_id,
          no_result: true,
          inserted_after: time_boundary
        ],
        preload: [:reporter]
      )

    analyse_reports(user_id, report_list)

    :ok
  end

  @spec new_report(any) :: {:error, any} | {:ok, Oban.Job.t()}
  def new_report(user_id) do
    %{user_id: user_id}
    |> Teiserver.Moderation.CheckReportsTask.new()
    |> Oban.insert()
  end

  defp analyse_reports(user_id, report_list) do
    types =
      report_list
      |> Enum.group_by(fn r ->
        r.type
      end)

    type_scores =
      types
      |> Map.new(fn {type, reports} ->
        score =
          reports
          |> Enum.map(&score_report/1)
          |> combine_report_scores

        {type, score}
      end)

    user = Account.get_user!(user_id)

    action =
      cond do
        enact_ban?(user, type_scores, report_list) -> perform_ban(user)
        enact_suspension?(user, type_scores, report_list) -> perform_suspension(user)
        enact_complete_mute?(user, type_scores, report_list) -> perform_complete_mute(user)
        enact_game_mute?(user, type_scores, report_list) -> perform_game_mute(user)
        enact_repeated_warn?(user, type_scores, report_list) -> perform_repeated_warn(user)
        enact_one_off_warn?(user, type_scores, report_list) -> perform_one_off_warn(user)
        true -> nil
      end

    # If an action was performed then all those reports need updating
    if action do
      report_list
      |> Enum.each(fn report ->
        Moderation.update_report(report, %{
          result_id: action.id
        })
      end)
    end
  end

  defp score_report(report) do
    age_in_days = Timex.diff(Timex.now(), report.inserted_at, :days)

    age_divisor = max(age_in_days * age_in_days, 1)

    report.reporter.trust_score / age_divisor
  end

  # Given a list of scores, generate a singular value with which to evaluate how
  # bad the report stack is
  @spec combine_report_scores(list) :: number
  defp combine_report_scores(scores) do
    sum = Enum.sum(scores)
    count = Enum.count(scores)

    sum * (1 + count / 10)
  end

  # Enact functions
  @spec enact_ban?(Account.User.t(), map(), list()) :: boolean()
  def enact_ban?(user, _type_scores, _report_list) do
    if user == 1, do: true, else: false
  end

  @spec enact_suspension?(Account.User.t(), map(), list()) :: boolean()
  def enact_suspension?(user, _type_scores, _report_list) do
    if user == 1, do: true, else: false
  end

  @spec enact_complete_mute?(Account.User.t(), map(), list()) :: boolean()
  def enact_complete_mute?(user, _type_scores, _report_list) do
    if user == 1, do: true, else: false
  end

  @spec enact_game_mute?(Account.User.t(), map(), list()) :: boolean()
  def enact_game_mute?(user, _type_scores, _report_list) do
    if user == 1, do: true, else: false
  end

  @spec enact_repeated_warn?(Account.User.t(), map(), list()) :: boolean()
  def enact_repeated_warn?(user, _type_scores, _report_list) do
    if user == 1, do: true, else: false
  end

  @spec enact_one_off_warn?(Account.User.t(), map(), list()) :: boolean()
  def enact_one_off_warn?(user, _type_scores, _report_list) do
    if user == 1, do: true, else: false
  end

  @spec enact_trust_drop?(Account.User.t(), map(), list()) :: boolean()
  def enact_trust_drop?(user, _type_scores, _report_list) do
    if user == 1, do: true, else: false
  end

  # Perform functions
  @spec perform_ban(map()) :: Moderation.Action.t()
  def perform_ban(user) do
    Moderation.create_action(%{
      target_id: user.id,
      reason: "Permanent ban",
      actions: ["Login", "Site"],
      score_modifier: 0,
      expires: nil
    })
  end

  @spec perform_suspension(map) :: Moderation.Action.t()
  def perform_suspension(user) do
    expires = Timex.now() |> Timex.shift(days: 7)

    Moderation.create_action(%{
      target_id: user.id,
      reason: "Temporary suspension",
      actions: ["All chat", "All lobbies", "Warning reminder"],
      score_modifier: -3000,
      expires: expires
    })
  end

  @spec perform_complete_mute(map) :: Moderation.Action.t()
  def perform_complete_mute(user) do
    expires = Timex.now() |> Timex.shift(days: 7)

    Moderation.create_action(%{
      target_id: user.id,
      reason: "Temporary suspension",
      actions: ["All chat", "Warning reminder"],
      score_modifier: -1500,
      expires: expires
    })
  end

  @spec perform_game_mute(map) :: Moderation.Action.t()
  def perform_game_mute(user) do
    expires = Timex.now() |> Timex.shift(days: 7)

    Moderation.create_action(%{
      target_id: user.id,
      reason: "Temporary suspension",
      actions: ["All chat", "All lobbies", "Warning reminder"],
      score_modifier: -1000,
      expires: expires
    })
  end

  @spec perform_repeated_warn(map) :: Moderation.Action.t()
  def perform_repeated_warn(user) do
    expires = Timex.now() |> Timex.shift(days: 7)

    if expires do
      Moderation.create_action(%{
        target_id: user.id,
        reason: "Warning reminder",
        actions: ["Warning reminder"],
        score_modifier: -150,
        expires: expires
      })
    else
      Moderation.create_action(%{
        target_id: user.id,
        reason: "Final warning",
        actions: ["Warning reminder"],
        score_modifier: -1000,
        expires: expires
      })
    end
  end

  @spec perform_one_off_warn(map) :: Moderation.Action.t()
  def perform_one_off_warn(user) do
    expires = Timex.now() |> Timex.shift(days: 7)

    Moderation.create_action(%{
      target_id: user.id,
      reason: "Please improve your behaviour",
      actions: ["Singular warning"],
      score_modifier: -100,
      expires: expires
    })
  end

  # Teiserver.Moderation.CheckReportsTask.perform(%{args: %{user_id: 2}})
end
