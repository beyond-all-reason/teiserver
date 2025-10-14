defmodule Teiserver.Repo.Migrations.UpdateReportGroup do
  use Ecto.Migration

  def up do
    alter table(:moderation_report_groups) do
      remove :target_id
      remove :vote_count
      add :type, :string
    end

    drop table(:moderation_report_group_votes)
    drop table(:moderation_report_group_messages)

    # Remove entries without a match
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

    # Make match id the primary key
    #    execute("""
    #    ALTER TABLE moderation_report_group DROP CONSTRAINT moderation_report_group_pkey;
    #    """)
    #
    #    alter table(:moderation_report_group) do
    #      remove :id
    #    end
    #
    #    alter table(:moderation_report_group) do
    #      modify :match_id, references(:matches, type: :integer, on_delete: :delete_all), null: false
    #    end
  end

  def down do
    raise "Irreversible migration: cannot un-merge moderation_report_groups"
  end
end
