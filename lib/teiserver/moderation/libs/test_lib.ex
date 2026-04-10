defmodule Teiserver.Moderation.ModerationTestLib do
  @moduledoc false
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Moderation

  @spec report_fixture(map) :: Moderation.Report.t()
  def report_fixture(attrs \\ %{}) do
    {:ok, report} =
      %{
        reporter_id: GeneralTestLib.make_user().id,
        target_id: GeneralTestLib.make_user().id,
        type: "type",
        sub_type: "sub_type",
        extra_text: "extra text",
        match_id: nil,
        relationship: nil,
        result_id: nil
      }
      |> Map.merge(attrs)
      |> Moderation.create_report()

    report
  end

  @spec action_fixture(map) :: Moderation.Action.t()
  def action_fixture(attrs \\ %{}) do
    {:ok, action} =
      %{
        target_id: GeneralTestLib.make_user().id,
        reason: "Reason",
        restrictions: ["Login"],
        score_modifier: 1000,
        expires: Timex.shift(Timex.now(), days: 5)
      }
      |> Map.merge(attrs)
      |> Moderation.create_action()

    action
  end

  @spec ban_fixture(map) :: Moderation.Action.t()
  def ban_fixture(attrs \\ %{}) do
    {:ok, ban} =
      %{
        source_id: GeneralTestLib.make_user().id,
        added_by_id: GeneralTestLib.make_user().id,
        key_values: ["key1", "key2"],
        enabled: true,
        reason: "Reason goes here"
      }
      |> Map.merge(attrs)
      |> Moderation.create_ban()

    ban
  end
end
