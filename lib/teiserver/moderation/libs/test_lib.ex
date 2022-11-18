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

  @spec proposal_fixture(map) :: {Moderation.Proposal.t(), Moderation.ProposalVote.t()}
  def proposal_fixture(attrs \\ %{}) do
    proposer = attrs[:proposer] || GeneralTestLib.make_user()

    {:ok, proposal} = Moderation.create_proposal(Map.merge(%{
      proposer_id: proposer.id,
      target_id: GeneralTestLib.make_user().id,
      action_id: nil,

      restrictions: ["Restrict1", "Restrict2"],
      reason: "Reasoning",
      duration: "5 days",

      votes_for: 1,
      votes_against: 0,
      votes_abstain: 0,
    }, attrs))

    {:ok, vote} = Moderation.create_proposal_vote(%{
      proposal_id: proposal.id,
      user_id: proposer.id,
      vote: 1,
    })

    {proposal, vote}
  end
end
