defmodule Teiserver.Repo.Migrations.CreateUserTotps do
  use Ecto.Migration

  def change do
    create table(:teiserver_account_user_totps, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :delete_all), primary_key: true
      add :secret, :binary, null: false
      add :last_used, :utc_datetime, null: true
      add :wrong_otp, :integer, default: 0, null: false

      timestamps()
    end
  end
end
