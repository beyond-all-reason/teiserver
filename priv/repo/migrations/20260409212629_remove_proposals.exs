defmodule Teiserver.Repo.Migrations.RemoveProposals do
  use Ecto.Migration

  def up do
    drop table(:moderation_proposal_votes)
    drop table(:moderation_proposals)
  end

  def down() do
    raise "Cannot revert removal of proposals"
  end
end
