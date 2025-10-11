defmodule Teiserver.Repo.Migrations.UpdateReportGroup do
  use Ecto.Migration

  def up do
    alter table(:moderation_report_groups) do
      remove :target_id
      remove :closed
      remove :vote_count
    end

    drop table(:moderation_report_group_votes)
    drop table(:moderation_report_group_messages)

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
        ARRAY_AGG(id) AS all_ids
      FROM moderation_report_groups
      GROUP BY match_id
      HAVING COUNT(*) > 1
    )
    -- Move actions
    UPDATE moderation_actions a
    SET report_group_id = g.keep_id
    FROM grouped g
    WHERE a.report_group_id = ANY(g.all_ids)
      AND a.report_group_id <> g.keep_id;
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
