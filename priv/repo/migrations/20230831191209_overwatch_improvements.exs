defmodule Teiserver.Repo.Migrations.OverwatchImprovements do
  use Ecto.Migration

  defp create_report_groups do
    (
      Teiserver.Moderation.list_reports(limit: :infinity, preload: [:responses])
      |> Enum.filter(fn report ->
        report.match_id != nil or report.result_id != nil
      end)
      |> Enum.group_by(fn report ->
        {report.target_id, report.match_id}
      end)
      |> Enum.each(fn {{target_id, match_id}, reports} ->
        report_group = Teiserver.Moderation.get_or_make_report_group(
          target_id, match_id
        )

        # Update the relevant action
        action_ids = reports
          |> Enum.map(fn r -> r.result_id end)
          |> Enum.reject(&(&1 == nil))

        query = """
        UPDATE moderation_actions
          SET report_group_id = $1
          WHERE id = ANY($2)
        """
        Ecto.Adapters.SQL.query(Teiserver.Repo, query, [report_group.id, action_ids])

        # Set the report count
        {:ok, report_group} = Teiserver.Moderation.update_report_group(report_group, %{
          vote_count: 0,
          action_count: Enum.count(action_ids),
          report_count: Enum.count(reports)
        })

        report_id_list = reports |> Enum.map(fn r -> r.id end)

        # Now update the timestamps
        first_report_datetime = reports
          |> Enum.map(fn report -> report.inserted_at end)
          |> Enum.min

        query = """
        UPDATE moderation_report_groups
          SET inserted_at = $1, updated_at = $1
          WHERE id = $2
        """
        Ecto.Adapters.SQL.query(Teiserver.Repo, query, [first_report_datetime, report_group.id])

        # Now update the reports themselves to point to this group
        query = """
        UPDATE moderation_reports SET report_group_id = $1 WHERE id = ANY($2)
        """
        Ecto.Adapters.SQL.query(Teiserver.Repo, query, [report_group.id, report_id_list])
      end)
    )

  end

  def change do
    create table(:moderation_report_groups) do
      add :target_id, references(:account_users, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)

      add :action_count, :integer
      add :report_count, :integer
      add :vote_count, :integer

      add :closed, :boolean

      timestamps()
    end

    create index(:moderation_report_groups, [:target_id])

    alter table(:moderation_reports) do
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing)
    end

    create table(:moderation_report_group_votes, primary_key: false) do
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing), primary_key: true
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true

      add :action, :string
      add :accuracy, :string

      timestamps()
    end

    create table(:moderation_report_group_messages) do
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing)
      add :user_id, references(:account_users, on_delete: :nothing)

      add :content, :text

      timestamps()
    end

    alter table(:moderation_actions) do
      add :appeal_status, :string, default: nil
      add :discord_message_id, :integer, default: nil
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing)
    end

    create table(:moderation_appeals_messages) do
      add :action_id, references(:moderation_actions, on_delete: :nothing)
      add :report_group_id, references(:moderation_report_groups, on_delete: :nothing)
      add :user_id, references(:account_users, on_delete: :nothing)

      add :content, :text

      timestamps()
    end

    alter table(:direct_messages) do
      add :delivered, :boolean, default: false
    end

    alter table(:account_relationships) do
      add :ignore, :boolean, default: false
    end

    execute "UPDATE account_relationships SET ignore = true WHERE state IN ('ignore', 'block', 'avoid');"
    execute "UPDATE account_relationships SET state = null WHERE state = 'ignore';"
  end
end
