defmodule Teiserver.Repo.Migrations.UpdateReportGroup do
  use Ecto.Migration

  def up do
    alter table(:moderation_report_groups) do
      remove :target_id
      remove :vote_count
      add :type, :string
    end

    alter table(:moderation_actions) do
      remove :report_group_id
    end

    drop table(:moderation_report_group_votes)
    drop table(:moderation_report_group_messages)

    # Remove report_group_id from reports, which don't have a match id
    execute("""
    UPDATE moderation_reports r
    SET report_group_id = NULL
    WHERE report_group_id IN (
    SELECT id FROM moderation_report_groups WHERE match_id IS NULL
    );
    """)

    # Remove Report Groups without a match
    execute("""
    DELETE FROM moderation_report_groups
    WHERE match_id IS NULL;
    """)

    # Combine duplicate moderation_report_groups by match_id
    execute("""
    WITH grouped AS (
      SELECT
        match_id,
        MIN(id) AS keep_id,
        ARRAY_AGG(id) AS all_ids
      FROM moderation_report_groups
      GROUP BY match_id
      HAVING COUNT(*) > 1
    )
    -- Move reports
    UPDATE moderation_reports r
    SET report_group_id = g.keep_id
    FROM grouped g
    WHERE r.report_group_id = ANY(g.all_ids)
      AND r.report_group_id <> g.keep_id;
    """)

    execute("""
    WITH grouped AS (
      SELECT
        match_id,
        MIN(id) AS keep_id,
        SUM(report_count) AS total_reports,
        SUM(action_count) AS total_actions,
        ARRAY_AGG(id) AS all_ids
      FROM moderation_report_groups
      GROUP BY match_id
      HAVING COUNT(*) > 1
    )
    UPDATE moderation_report_groups mrg
    SET
      report_count = g.total_reports,
      action_count = g.total_actions
    FROM grouped g
    WHERE mrg.id = g.keep_id;
    """)

    execute("""
    WITH grouped AS (
      SELECT
        match_id,
        MIN(id) AS keep_id,
        ARRAY_AGG(id) AS all_ids
      FROM moderation_report_groups
      GROUP BY match_id
      HAVING COUNT(*) > 1
    )
    DELETE FROM moderation_report_groups mrg
    USING grouped g
    WHERE mrg.id = ANY(g.all_ids)
      AND mrg.id <> g.keep_id;
    """)
  end

  def down do
    raise "Irreversible migration: cannot un-merge moderation_report_groups"
  end
end
