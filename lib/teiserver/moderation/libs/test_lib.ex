defmodule Teiserver.Moderation.ModerationTestLib do
  alias Central.Helpers.GeneralTestLib
  alias Teiserver.Moderation

  @spec report_fixture(map) :: Moderation.Report.t()
  def report_fixture(attrs \\ %{}) do
    {:ok, report} = Moderation.create_report(Map.merge(%{
      reporter_id: GeneralTestLib.make_user().id,
      target_id: GeneralTestLib.make_user().id,

      type: "type",
      sub_type: "sub_type",
      extra_text: "extra text",

      match_id: nil,
      relationship: nil,
      result_id: nil
    }, attrs))
    report
  end

  @spec action_fixture(map) :: Moderation.Action.t()
  def action_fixture(attrs \\ %{}) do
    {:ok, action} = Moderation.create_action(Map.merge(%{
      target_id: GeneralTestLib.make_user().id,
      reason: "Reason",
      restrictions: ["Site", "Login"],
      score_modifier: 1000,
      expires: Timex.shift(Timex.now(), days: 5)
    }, attrs))
    action
  end
end
