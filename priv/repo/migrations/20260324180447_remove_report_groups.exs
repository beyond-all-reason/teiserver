defmodule Teiserver.Repo.Migrations.RemoveReportGroups do
  use Ecto.Migration

  def up do
    alter table(:moderation_actions) do
      remove :report_group_id
    end

    alter table(:moderation_reports) do
      remove :report_group_id
    end

    drop table(:moderation_report_groups)
    drop table(:moderation_report_group_votes)
    drop table(:moderation_report_group_messages)

  end

  def down do
    raise "Irreversible migration: cannot un-delete moderation_report_groups"
  end
end
