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

  @spec proposal_fixture(map) :: {Moderation.Proposal.t(), Moderation.ProposalVote.t()}
  def proposal_fixture(attrs \\ %{}) do
    proposer = attrs[:proposer] || GeneralTestLib.make_user()

    {:ok, proposal} =
      %{
        proposer_id: proposer.id,
        target_id: GeneralTestLib.make_user().id,
        action_id: nil,
        restrictions: ["Restrict1", "Restrict2"],
        reason: "Reasoning",
        duration: "5 days",
        votes_for: 1,
        votes_against: 0,
        votes_abstain: 0
      }
      |> Map.merge(attrs)
      |> Moderation.create_proposal()

    {:ok, vote} =
      Moderation.create_proposal_vote(%{
        proposal_id: proposal.id,
        user_id: proposer.id,
        vote: 1
      })

    {proposal, vote}
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
