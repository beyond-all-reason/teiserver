defmodule Teiserver.Repo.Migrations.RemoveReportGroups do
  use Ecto.Migration

  def change do
    alter table(:moderation_actions) do
      remove :report_group_id
    end

    alter table(:moderation_reports) do
      remove :report_group_id
    end

    drop table(:moderation_report_groups), mode: :cascade
    drop table(:moderation_report_group_votes)
    drop table(:moderation_report_group_messages)
  end
end
