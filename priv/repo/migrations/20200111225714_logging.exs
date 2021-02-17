defmodule Central.Repo.Migrations.Logging do
  use Ecto.Migration

  def change do
    create table(:audit_logs) do
      add :action, :string
      add :details, :jsonb
      add :ip, :string

      add :user_id, references(:account_users, on_delete: :nothing)
      add :group_id, references(:account_groups, on_delete: :nothing)

      timestamps()
    end

    create table(:page_view_logs) do
      add :path, :string
      add :section, :string
      add :method, :string
      add :ip, :string
      add :load_time, :integer

      add :status, :integer
      add :user_id, references(:account_users)

      timestamps()
    end

    create table(:aggregate_view_logs, primary_key: false) do
      add :date, :date, primary_key: true

      add :total_views, :integer
      add :total_uniques, :integer
      add :average_load_time, :integer

      add :guest_view_count, :integer
      add :guest_unique_ip_count, :integer

      add :percentile_load_time_95, :integer
      add :percentile_load_time_99, :integer
      add :max_load_time, :integer

      add :hourly_views, {:array, :integer}
      add :hourly_uniques, {:array, :integer}
      add :hourly_average_load_times, {:array, :integer}

      add :user_data, :jsonb
      add :section_data, :jsonb
    end

    create table(:error_logs) do
      add :path, :string
      add :method, :string
      add :reason, :text
      add :traceback, :text
      add :hidden, :boolean, default: false, null: false
      add :data, :jsonb
      add :user_id, references(:account_users, on_delete: :nothing)

      timestamps()
    end

    create index(:error_logs, [:user_id])
  end
end
